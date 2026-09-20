import { DurableObject } from "cloudflare:workers";
import {
  constantTimeEqual,
  generateMemberId,
  generateRunId,
  generateSeed,
  generateToken,
  hashPassword,
  sha256Hex,
  verifyPassword,
  type PasswordRecord,
} from "./crypto";
import type { Env } from "./env";
import { errorResponse, json, readJson } from "./http";
import { TokenBucket } from "./limits";
import {
  ApiError,
  BinaryKind,
  MAX_BINARY_KIND,
  MAX_CLIENT_BINARY,
  MAX_BATCH_ENTRIES,
  MAX_HOST_BATCH,
  MAX_HOST_BINARY,
  MAX_PLAYERS,
  MAX_TEXT_FRAME,
  MIN_PLAYERS_TO_START,
  PROTOCOL_VERSION,
  TARGET_ALL,
  parseClientMessage,
  parseJoinBody,
  type ClientMessage,
  type MemberView,
  type Phase,
  type RoomView,
} from "./protocol";

/** How long a run waits for a host who dropped off before it is abandoned. */
export const HOST_GRACE_RUN_MS = 45_000;
/** How long a lobby waits for its host before handing the lobby to someone else. */
export const HOST_GRACE_LOBBY_MS = 60_000;
/** A room nobody is connected to is dropped after this long. */
export const ABANDONED_MS = 30 * 60_000;
/** A lobby that is open but has gone quiet is dropped after this long. */
export const IDLE_LOBBY_MS = 2 * 60 * 60_000;

/** The lifetimes above, which the test environment shortens through vars. */
interface Timing {
  hostGraceRun: number;
  hostGraceLobby: number;
  abandoned: number;
  idleLobby: number;
}
const PASSWORD_FAILURES_BEFORE_LOCK = 8;
const PASSWORD_LOCK_MS = 60_000;

interface Member {
  id: string;
  name: string;
  fateId: string;
  slot: number;
  /** SHA-256 of the room credential. The credential itself is never kept. */
  tokenHash: string;
  ready: boolean;
  joinedAt: number;
  weapon: string;
  hero: Record<string, unknown> | null;
}

interface RoomState {
  code: string;
  createdAt: number;
  lastActivity: number;
  hostId: string;
  password: PasswordRecord | null;
  phase: Phase;
  runNumber: number;
  realm: string;
  run: { runId: string; seed: string; startedAt: number } | null;
  lastRun: { runId: string; outcome: string; summary: unknown } | null;
  members: Member[];
  /** When the host is due back by, if they are away. */
  hostGraceEndsAt: number | null;
  passwordFailures: number;
  lockedUntil: number;
}

function safeCloseCode(code: number): number {
  return code >= 1000 && code <= 4999 && code !== 1005 && code !== 1006 && code !== 1015 ? code : 1000;
}

/**
 * One Fate Lost party.
 *
 * A party outlives its runs: it is created once, plays as many runs as the
 * players like, and ends only when the host closes it, everyone leaves or it
 * is abandoned. The room is authoritative for who is in it, who hosts, the
 * ready states and the run lifecycle. It does not simulate the game: during a
 * run the host device does, and this object relays binary frames.
 *
 * Sockets use the hibernation API, so an idle lobby costs nothing while the
 * object sleeps. Nothing keeps it awake: there are no timers, and keep-alive
 * pings are answered by the runtime without waking it.
 */
export class PartyRoom extends DurableObject<Env> {
  private room: RoomState | null = null;
  private readonly buckets = new Map<string, TokenBucket>();
  private readonly strikes = new Map<string, number>();
  private chain: Promise<unknown> = Promise.resolve();

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    ctx.blockConcurrencyWhile(async () => {
      this.room = (await ctx.storage.get<RoomState>("room")) ?? null;
    });
    ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair("ping", "pong"));
  }

  // MARK: - HTTP

  override async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const action = url.pathname.split("/").filter(Boolean).pop() ?? "";
    try {
      if (request.method === "POST" && action === "create") {
        return json(await this.exclusive(() => this.create(request)), 201);
      }
      if (request.method === "POST" && action === "join") {
        return json(await this.exclusive(() => this.join(request)));
      }
      if (request.method === "GET" && action === "ws") {
        return await this.upgrade(request);
      }
      throw new ApiError("bad_request", "Unknown route.", 404);
    } catch (error) {
      return errorResponse(error);
    }
  }

  /** Runs one join or create at a time: they await password hashing. */
  private exclusive<T>(work: () => Promise<T>): Promise<T> {
    const result = this.chain.then(work, work);
    this.chain = result.catch(() => undefined);
    return result;
  }

  private timing(): Timing {
    const read = (value: string | undefined, fallback: number): number => {
      const parsed = Number.parseInt(value ?? "", 10);
      return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
    };
    return {
      hostGraceRun: read(this.env.HOST_GRACE_RUN_MS, HOST_GRACE_RUN_MS),
      hostGraceLobby: read(this.env.HOST_GRACE_LOBBY_MS, HOST_GRACE_LOBBY_MS),
      abandoned: read(this.env.ABANDONED_MS, ABANDONED_MS),
      idleLobby: read(this.env.IDLE_LOBBY_MS, IDLE_LOBBY_MS),
    };
  }

  private iterations(): number {
    const value = Number.parseInt(this.env.PBKDF2_ITERATIONS, 10);
    return Number.isFinite(value) && value >= 1000 ? value : 20_000;
  }

  private async create(request: Request): Promise<unknown> {
    if (this.room) throw new ApiError("bad_state", "That code is taken.", 409);
    const code = new URL(request.url).pathname.split("/").filter(Boolean).at(-2) ?? "";
    const body = parseJoinBody(await readJson(request, 2_000));
    const password = body.password ? await hashPassword(body.password, this.iterations()) : null;
    if (this.room) throw new ApiError("bad_state", "That code is taken.", 409);

    const token = generateToken();
    const now = Date.now();
    const host = await this.makeMember(body.name, body.fateId, token, 0, now);
    this.room = {
      code,
      createdAt: now,
      lastActivity: now,
      hostId: host.id,
      password,
      phase: "lobby",
      runNumber: 0,
      // The campaign's first realm, which every player has open.
      realm: "ashenWilds",
      run: null,
      lastRun: null,
      members: [host],
      hostGraceEndsAt: null,
      passwordFailures: 0,
      lockedUntil: 0,
    };
    await this.persist();
    return { code, playerId: host.id, token, room: this.view() };
  }

  private async join(request: Request): Promise<unknown> {
    const room = this.requireRoom();
    const now = Date.now();
    if (room.lockedUntil > now) {
      throw new ApiError("rate_limited", "Too many wrong passwords. Try again shortly.", 429, {
        retryAfter: Math.ceil((room.lockedUntil - now) / 1000),
      });
    }
    const body = parseJoinBody(await readJson(request, 2_000));

    if (room.password) {
      if (!body.password) {
        throw new ApiError("password_required", "This lobby needs a password.", 401);
      }
      const ok = await verifyPassword(body.password, room.password);
      if (!ok) {
        room.passwordFailures += 1;
        if (room.passwordFailures >= PASSWORD_FAILURES_BEFORE_LOCK) {
          room.passwordFailures = 0;
          room.lockedUntil = Date.now() + PASSWORD_LOCK_MS;
        }
        await this.persist();
        throw new ApiError("wrong_password", "That password is not right.", 403);
      }
      room.passwordFailures = 0;
    }

    // Checked after the awaits above: another join may have landed meanwhile.
    if (room.phase !== "lobby") {
      throw new ApiError("run_in_progress", "That party is mid-run. Try again when they are back in the lobby.", 409);
    }
    if (room.members.length >= MAX_PLAYERS) {
      throw new ApiError("room_full", "That party is full.", 409);
    }

    const token = generateToken();
    const slot = this.freeSlot(room);
    const member = await this.makeMember(body.name, body.fateId, token, slot, Date.now());
    room.members.push(member);
    room.lastActivity = Date.now();
    await this.persist();
    this.broadcastRoom();
    return { code: room.code, playerId: member.id, token, room: this.view() };
  }

  private async makeMember(name: string, fateId: string, token: string, slot: number, now: number): Promise<Member> {
    return {
      id: generateMemberId(),
      name,
      fateId,
      slot,
      tokenHash: await sha256Hex(token),
      ready: false,
      joinedAt: now,
      weapon: "sword",
      hero: null,
    };
  }

  private freeSlot(room: RoomState): number {
    for (let slot = 0; slot < MAX_PLAYERS; slot++) {
      if (!room.members.some((member) => member.slot === slot)) return slot;
    }
    throw new ApiError("room_full", "That party is full.", 409);
  }

  private requireRoom(): RoomState {
    if (!this.room) throw new ApiError("room_not_found", "No party has that code.", 404);
    return this.room;
  }

  // MARK: - WebSocket

  private async upgrade(request: Request): Promise<Response> {
    if (request.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
      throw new ApiError("bad_request", "Expected a WebSocket upgrade.", 426);
    }
    if (request.headers.get("X-Fate-Protocol") !== String(PROTOCOL_VERSION)) {
      throw new ApiError("protocol_mismatch", "This version of Fate Lost cannot play with the party service.", 426, {
        serverProtocol: PROTOCOL_VERSION,
      });
    }
    const room = this.requireRoom();
    const header = request.headers.get("Authorization") ?? "";
    const token = header.startsWith("Bearer ") ? header.slice(7) : "";
    if (token.length < 20 || token.length > 100) throw new ApiError("unauthorized", "Not signed in to this party.", 401);
    const hash = await sha256Hex(token);
    let member: Member | undefined;
    for (const candidate of room.members) {
      // No early exit: every member is compared the same way.
      if (constantTimeEqual(candidate.tokenHash, hash)) member = candidate;
    }
    if (!member) throw new ApiError("unauthorized", "Not signed in to this party.", 401);

    const pair = new WebSocketPair();
    const client = pair[0];
    const server = pair[1];
    for (const previous of this.liveSockets(member.id)) {
      this.send(previous, { t: "replaced" });
      previous.close(4000, "replaced");
    }
    this.ctx.acceptWebSocket(server, [member.id]);
    this.strikes.delete(member.id);

    room.lastActivity = Date.now();
    let hostBack = false;
    if (member.id === room.hostId && room.hostGraceEndsAt !== null) {
      room.hostGraceEndsAt = null;
      hostBack = true;
    }
    await this.persist();

    this.send(server, { t: "welcome", you: member.id, room: this.view() });
    if (room.phase === "inRun") {
      this.send(server, await this.runStartMessage(room, member, true));
      if (member.id !== room.hostId) {
        this.sendToHost({ t: "peer", id: member.id, slot: member.slot, event: "connected" });
      } else if (hostBack) {
        this.broadcastExcept(member.id, { t: "hostBack" });
      }
    }
    this.broadcastRoom();
    return new Response(null, { status: 101, webSocket: client });
  }

  override async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
    const room = this.room;
    const memberId = this.ctx.getTags(ws)[0];
    const member = room?.members.find((candidate) => candidate.id === memberId);
    if (!room || !member) {
      ws.close(4001, "unknown member");
      return;
    }
    const now = Date.now();
    let bucket = this.buckets.get(member.id);
    if (!bucket) {
      // The host sends a stream to every client; a client sends only inputs.
      bucket = member.id === room.hostId ? new TokenBucket(400, 300, now) : new TokenBucket(160, 100, now);
      this.buckets.set(member.id, bucket);
    }
    if (!bucket.take(now)) {
      const strikes = (this.strikes.get(member.id) ?? 0) + 1;
      this.strikes.set(member.id, strikes);
      if (strikes > 600) ws.close(1008, "slow down");
      return;
    }

    try {
      if (typeof message === "string") {
        if (message.length > MAX_TEXT_FRAME) throw new ApiError("too_large", "Message is too large.", 413);
        let parsed: unknown;
        try {
          parsed = JSON.parse(message);
        } catch {
          throw new ApiError("bad_request", "Message is not valid JSON.", 400);
        }
        await this.handle(member, parseClientMessage(parsed));
      } else {
        this.relay(room, member, message);
      }
    } catch (error) {
      if (error instanceof ApiError) {
        this.send(ws, { t: "error", code: error.code, message: error.message });
      } else {
        console.error("message handler failed");
        this.send(ws, { t: "error", code: "internal", message: "Something went wrong." });
      }
    }
  }

  override async webSocketClose(ws: WebSocket, code: number): Promise<void> {
    try {
      ws.close(safeCloseCode(code), "closed");
    } catch {
      // Already closed.
    }
    await this.connectionLost(ws);
  }

  override async webSocketError(ws: WebSocket): Promise<void> {
    await this.connectionLost(ws);
  }

  private async connectionLost(ws: WebSocket): Promise<void> {
    const room = this.room;
    const memberId = this.ctx.getTags(ws)[0];
    const member = room?.members.find((candidate) => candidate.id === memberId);
    if (!room || !member) return;
    // Another live socket (a quick reconnect) means they never left.
    if (this.liveSockets(member.id, ws).length > 0) return;

    room.lastActivity = Date.now();
    if (member.id === room.hostId) {
      const timing = this.timing();
      room.hostGraceEndsAt = Date.now() + (room.phase === "inRun" ? timing.hostGraceRun : timing.hostGraceLobby);
      if (room.phase === "inRun") this.broadcastExcept(member.id, { t: "hostAway", until: room.hostGraceEndsAt });
    } else if (room.phase === "inRun") {
      this.sendToHost({ t: "peer", id: member.id, slot: member.slot, event: "disconnected" });
    }
    await this.persist();
    this.broadcastRoom();
  }

  // MARK: - Messages

  private async handle(member: Member, message: ClientMessage): Promise<void> {
    const room = this.requireRoom();
    const isHost = member.id === room.hostId;
    room.lastActivity = Date.now();

    switch (message.t) {
      case "ready": {
        this.requirePhase(room, "lobby");
        member.ready = message.ready;
        break;
      }
      case "loadout": {
        this.requirePhase(room, "lobby");
        member.weapon = message.loadout.weapon;
        member.hero = message.loadout.hero;
        await this.ctx.storage.put(`legacy:${member.id}`, message.loadout.legacy);
        break;
      }
      case "rename": {
        member.name = message.name;
        break;
      }
      case "setRealm": {
        this.requireHost(isHost);
        this.requirePhase(room, "lobby");
        room.realm = message.realm;
        for (const other of room.members) other.ready = false;
        break;
      }
      case "start": {
        this.requireHost(isHost);
        this.requirePhase(room, "lobby");
        await this.startRun(room);
        return;
      }
      case "kick": {
        this.requireHost(isHost);
        const target = room.members.find((candidate) => candidate.id === message.target);
        if (!target) throw new ApiError("bad_request", "That player is not here.", 404);
        if (target.id === room.hostId) throw new ApiError("forbidden", "The host cannot be kicked.", 403);
        await this.removeMember(room, target, "kicked");
        return;
      }
      case "close": {
        this.requireHost(isHost);
        await this.destroy("closed");
        return;
      }
      case "leave": {
        await this.removeMember(room, member, "left");
        return;
      }
      case "runEnd": {
        this.requireHost(isHost);
        this.requirePhase(room, "inRun");
        if (room.run?.runId !== message.runId) throw new ApiError("bad_state", "That is not the current run.", 409);
        await this.finishRun(room, message.outcome, message.summary);
        return;
      }
    }
    await this.persist();
    this.broadcastRoom();
  }

  private requireHost(isHost: boolean): void {
    if (!isHost) throw new ApiError("forbidden", "Only the host can do that.", 403);
  }

  private requirePhase(room: RoomState, phase: Phase): void {
    if (room.phase !== phase) {
      throw new ApiError("bad_state", phase === "lobby" ? "The party is mid-run." : "The party is not in a run.", 409);
    }
  }

  private async startRun(room: RoomState): Promise<void> {
    if (room.members.length < MIN_PLAYERS_TO_START) {
      throw new ApiError("not_enough_players", "A run needs at least two players.", 409);
    }
    for (const member of room.members) {
      if (member.id === room.hostId) continue;
      if (!this.isConnected(member.id) || !member.ready) {
        throw new ApiError("not_ready", `${member.name} is not ready.`, 409);
      }
    }
    if (!this.isConnected(room.hostId)) throw new ApiError("bad_state", "The host is not connected.", 409);

    room.runNumber += 1;
    room.phase = "inRun";
    room.run = { runId: generateRunId(), seed: generateSeed(), startedAt: Date.now() };
    room.hostGraceEndsAt = null;
    room.lastRun = null;
    await this.persist();

    for (const member of room.members) {
      const message = await this.runStartMessage(room, member, false);
      for (const ws of this.liveSockets(member.id)) this.send(ws, message);
    }
    this.broadcastRoom();
  }

  /**
   * What a member needs to enter the run. The host also gets everyone's
   * Legacy node ids, because it is the host that builds each hero.
   */
  private async runStartMessage(room: RoomState, recipient: Member, resumed: boolean): Promise<Record<string, unknown>> {
    const forHost = recipient.id === room.hostId;
    const legacy: Record<string, string[]> = {};
    if (forHost) {
      for (const member of room.members) {
        legacy[member.id] = (await this.ctx.storage.get<string[]>(`legacy:${member.id}`)) ?? [];
      }
    }
    return {
      t: "runStart",
      resumed,
      runId: room.run?.runId,
      runNumber: room.runNumber,
      seed: room.run?.seed,
      realm: room.realm,
      hostId: room.hostId,
      you: recipient.id,
      roster: room.members.map((member) => ({
        id: member.id,
        name: member.name,
        fateId: member.fateId,
        slot: member.slot,
        weapon: member.weapon,
        hero: member.hero,
        ...(forHost ? { legacy: legacy[member.id] ?? [] } : {}),
      })),
    };
  }

  private async finishRun(room: RoomState, outcome: string, summary: unknown): Promise<void> {
    const runId = room.run?.runId ?? "";
    room.lastRun = { runId, outcome, summary };
    room.phase = "lobby";
    room.run = null;
    room.hostGraceEndsAt = null;
    for (const member of room.members) member.ready = false;
    await this.persist();
    this.broadcast({ t: "runEnd", runId, outcome, summary });
    this.broadcastRoom();
  }

  private async removeMember(room: RoomState, member: Member, reason: "kicked" | "left"): Promise<void> {
    const wasHost = member.id === room.hostId;
    for (const ws of this.liveSockets(member.id)) {
      this.send(ws, { t: reason === "kicked" ? "kicked" : "left" });
      ws.close(reason === "kicked" ? 4003 : 1000, reason);
    }
    room.members = room.members.filter((candidate) => candidate.id !== member.id);
    await this.ctx.storage.delete(`legacy:${member.id}`);
    this.buckets.delete(member.id);

    if (room.members.length === 0) {
      await this.destroy("empty");
      return;
    }
    if (room.phase === "inRun") this.sendToHost({ t: "peer", id: member.id, slot: member.slot, event: "left" });
    if (wasHost) {
      // Someone else takes over first, so nobody ever sees a lobby without a
      // host. A run cannot outlive its host: the simulation went with them.
      this.promoteHost(room);
      if (room.phase === "inRun") await this.finishRun(room, "aborted", { reason: "hostLeft" });
    }
    await this.persist();
    this.broadcastRoom();
  }

  private promoteHost(room: RoomState): void {
    const ordered = [...room.members].sort((a, b) => a.joinedAt - b.joinedAt);
    const next = ordered.find((candidate) => this.isConnected(candidate.id)) ?? ordered[0];
    if (!next) return;
    room.hostId = next.id;
    room.hostGraceEndsAt = null;
    for (const member of room.members) member.ready = false;
    this.broadcast({ t: "newHost", id: next.id });
  }

  private async destroy(reason: "closed" | "empty" | "expired"): Promise<void> {
    for (const ws of this.ctx.getWebSockets()) {
      this.send(ws, { t: "closed", reason });
      ws.close(4004, reason);
    }
    this.room = null;
    this.buckets.clear();
    await this.ctx.storage.deleteAlarm();
    await this.ctx.storage.deleteAll();
  }

  // MARK: - Relay

  /**
   * Passes gameplay frames between the host and the clients. The server
   * checks size, kind and direction and nothing else: the host decides what a
   * frame means.
   *
   * From a client: [kind, ...payload]. The host receives [kind, slot, ...payload].
   * From the host: [kind, target, ...payload]. A client receives [kind, ...payload].
   */
  private relay(room: RoomState, sender: Member, data: ArrayBuffer): void {
    if (room.phase !== "inRun") return;
    const bytes = new Uint8Array(data);
    if (bytes.length < 2) return;
    const kind = bytes[0] ?? 0;
    if (kind < BinaryKind.input || kind > MAX_BINARY_KIND) return;

    if (sender.id === room.hostId) {
      if (kind === BinaryKind.batch) {
        this.relayBatch(room, bytes);
        room.lastActivity = Date.now();
        return;
      }
      if (bytes.length > MAX_HOST_BINARY) return;
      const target = bytes[1] ?? TARGET_ALL;
      const out = new Uint8Array(bytes.length - 1);
      out[0] = kind;
      out.set(bytes.subarray(2), 1);
      this.deliver(room, target, out);
    } else {
      if (kind === BinaryKind.batch) return;
      if (bytes.length > MAX_CLIENT_BINARY) return;
      const out = new Uint8Array(bytes.length + 1);
      out[0] = kind;
      out[1] = sender.slot;
      out.set(bytes.subarray(1), 2);
      for (const ws of this.liveSockets(room.hostId)) ws.send(out);
    }
    // Traffic in a run is activity, but it is not worth a write.
    room.lastActivity = Date.now();
  }

  /** Sends one frame to a seat, or to every client. */
  private deliver(room: RoomState, target: number, frame: Uint8Array): void {
    for (const member of room.members) {
      if (member.id === room.hostId) continue;
      if (target !== TARGET_ALL && member.slot !== target) continue;
      for (const ws of this.liveSockets(member.id)) ws.send(frame);
    }
  }

  /**
   * Unpacks a host's batch and hands each entry to its target. The whole
   * batch is checked before any of it is sent, so a malformed one is dropped
   * rather than half delivered.
   */
  private relayBatch(room: RoomState, bytes: Uint8Array): void {
    if (bytes.length > MAX_HOST_BATCH || bytes.length < 2) return;
    const count = bytes[1] ?? 0;
    if (count === 0 || count > MAX_BATCH_ENTRIES) return;
    const frames: Array<{ target: number; frame: Uint8Array }> = [];
    let offset = 2;
    for (let index = 0; index < count; index++) {
      if (offset + 4 > bytes.length) return;
      const target = bytes[offset] ?? TARGET_ALL;
      const kind = bytes[offset + 1] ?? 0;
      const length = ((bytes[offset + 2] ?? 0) << 8) | (bytes[offset + 3] ?? 0);
      offset += 4;
      if (kind < BinaryKind.input || kind > MAX_BINARY_KIND || kind === BinaryKind.batch) return;
      if (length > MAX_HOST_BINARY || offset + length > bytes.length) return;
      const frame = new Uint8Array(length + 1);
      frame[0] = kind;
      frame.set(bytes.subarray(offset, offset + length), 1);
      offset += length;
      frames.push({ target, frame });
    }
    if (offset !== bytes.length) return;
    for (const { target, frame } of frames) this.deliver(room, target, frame);
  }

  // MARK: - Alarm

  /** Decides what time-driven change is due, if any, and when to look next. */
  override async alarm(): Promise<void> {
    const room = this.room;
    if (!room) return;
    const now = Date.now();

    if (room.hostGraceEndsAt !== null && now >= room.hostGraceEndsAt) {
      room.hostGraceEndsAt = null;
      if (room.phase === "inRun") {
        await this.finishRun(room, "aborted", { reason: "hostLost" });
      } else if (!this.isConnected(room.hostId)) {
        const others = room.members.filter((member) => member.id !== room.hostId && this.isConnected(member.id));
        if (others.length > 0) {
          this.promoteHost(room);
          await this.persist();
          this.broadcastRoom();
        }
      }
    }

    const timing = this.timing();
    const connected = room.members.some((member) => this.isConnected(member.id));
    const quietFor = now - room.lastActivity;
    if (!connected && quietFor >= timing.abandoned) {
      await this.destroy("expired");
      return;
    }
    if (connected && room.phase === "lobby" && quietFor >= timing.idleLobby) {
      await this.destroy("expired");
      return;
    }
    await this.scheduleAlarm();
  }

  private async scheduleAlarm(): Promise<void> {
    const room = this.room;
    if (!room) return;
    const connected = room.members.some((member) => this.isConnected(member.id));
    const timing = this.timing();
    let next = room.lastActivity + (connected ? timing.idleLobby : timing.abandoned);
    if (connected && room.phase === "inRun") next = Date.now() + 10 * 60_000;
    if (room.hostGraceEndsAt !== null) next = Math.min(next, room.hostGraceEndsAt);
    await this.ctx.storage.setAlarm(Math.max(next, Date.now() + 1000));
  }

  // MARK: - Helpers

  private async persist(): Promise<void> {
    if (!this.room) return;
    await this.ctx.storage.put("room", this.room);
    await this.scheduleAlarm();
  }

  private liveSockets(memberId: string, excluding?: WebSocket): WebSocket[] {
    return this.ctx
      .getWebSockets(memberId)
      .filter((socket) => socket !== excluding && socket.readyState === WebSocket.READY_STATE_OPEN);
  }

  private isConnected(memberId: string): boolean {
    return this.liveSockets(memberId).length > 0;
  }

  /** The room as every member may see it: no credentials, no verifiers. */
  private view(): RoomView {
    const room = this.requireRoom();
    const members: MemberView[] = room.members.map((member) => ({
      id: member.id,
      name: member.name,
      fateId: member.fateId,
      slot: member.slot,
      host: member.id === room.hostId,
      ready: member.ready,
      connected: this.isConnected(member.id),
      weapon: member.weapon,
      hero: member.hero,
    }));
    return {
      code: room.code,
      protocol: PROTOCOL_VERSION,
      hostId: room.hostId,
      phase: room.phase,
      runNumber: room.runNumber,
      hasPassword: room.password !== null,
      maxPlayers: MAX_PLAYERS,
      realm: room.realm,
      members,
      run: room.run,
      lastRun: room.lastRun,
      hostGraceEndsAt: room.hostGraceEndsAt,
    };
  }

  private send(ws: WebSocket, message: unknown): void {
    try {
      ws.send(JSON.stringify(message));
    } catch {
      // The socket is gone; its close handler tidies up.
    }
  }

  private broadcast(message: unknown): void {
    for (const ws of this.ctx.getWebSockets()) this.send(ws, message);
  }

  private broadcastExcept(memberId: string, message: unknown): void {
    for (const ws of this.ctx.getWebSockets()) {
      if (this.ctx.getTags(ws)[0] !== memberId) this.send(ws, message);
    }
  }

  private broadcastRoom(): void {
    if (!this.room) return;
    this.broadcast({ t: "room", room: this.view() });
  }

  private sendToHost(message: unknown): void {
    const room = this.room;
    if (!room) return;
    for (const ws of this.liveSockets(room.hostId)) this.send(ws, message);
  }
}
