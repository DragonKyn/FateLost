import { describe, expect, it } from "vitest";
import {
  BASE_URL,
  Client,
  PROTOCOL,
  TIMING_TESTS,
  createRoom,
  fateId,
  joinRoom,
  joined,
  post,
  sleep,
  testClientId,
  type Session,
} from "./harness";

const ALPHABET = /^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$/;

/** A host and `count - 1` guests, all connected, all ready. */
async function party(count: number, password?: string) {
  const hostSession = await createRoom("Jesse", password);
  const host = await Client.connect(hostSession);
  const guests: Client[] = [];
  const names = ["Whitney", "Kevin", "Robin"];
  for (let index = 0; index < count - 1; index++) {
    const session = await joined(hostSession.code, names[index] ?? `Guest${index}`, password);
    guests.push(await Client.connect(session));
  }
  return { code: hostSession.code, host, guests, all: [host, ...guests] };
}

async function readyUp(guests: Client[]) {
  const last = guests[guests.length - 1];
  // Only messages that arrive after this point count: an earlier lobby
  // snapshot may already show everyone ready from a previous run.
  const mark = last ? last.messages.length : 0;
  for (const guest of guests) guest.send({ t: "ready", ready: true });
  if (last) {
    await last.room((room) => room.members.filter((m: any) => m.ready).length === guests.length, 4000, mark);
  }
}

async function startRun(host: Client, guests: Client[]) {
  await readyUp(guests);
  const marks = [host, ...guests].map((client) => client.messages.length);
  host.send({ t: "start" });
  const starts = await Promise.all(
    [host, ...guests].map((client, index) =>
      client.waitFor((m) => m.t === "runStart" && !m.resumed, 4000, marks[index] ?? 0),
    ),
  );
  return starts;
}

describe("creating and joining", () => {
  it("creates a lobby with a friendly six character code", async () => {
    const session = await createRoom("Jesse");
    expect(session.code).toMatch(ALPHABET);
    expect(session.token.length).toBeGreaterThanOrEqual(40);
    const host = await Client.connect(session);
    const welcome = await host.waitFor((m) => m.t === "welcome");
    expect(welcome.room.members).toHaveLength(1);
    expect(welcome.room.members[0]).toMatchObject({ name: "Jesse", host: true, connected: true, ready: false });
    expect(welcome.room.phase).toBe("lobby");
    expect(welcome.room.hasPassword).toBe(false);
    host.close();
  });

  it("lets a second player join and shows both players their lobby", async () => {
    const { host, guests, code } = await party(2);
    const room = await host.room((r) => r.members.length === 2);
    expect(room.code).toBe(code);
    expect(room.members.map((m: any) => m.name).sort()).toEqual(["Jesse", "Whitney"]);
    const guestRoom = await guests[0]!.room((r) => r.members.length === 2);
    expect(guestRoom.members.find((m: any) => m.host).name).toBe("Jesse");
    host.close();
    guests[0]!.close();
  });

  it("reports an unknown room code clearly", async () => {
    const result = await joinRoom("ZZZZZZ", "Whitney");
    expect(result.status).toBe(404);
    expect(result.body.error.code).toBe("room_not_found");
  });

  it("rejects a code that could not exist", async () => {
    const result = await joinRoom("0OIL1", "Whitney");
    expect(result.status).toBe(404);
  });

  it("keeps people out of a full room", async () => {
    const { code, all } = await party(4);
    const fifth = await joinRoom(code, "Extra");
    expect(fifth.status).toBe(409);
    expect(fifth.body.error.code).toBe("room_full");
    all.forEach((client) => client.close());
  });

  it("does not let anyone join mid-run", async () => {
    const { code, host, guests } = await party(2);
    await startRun(host, guests);
    const late = await joinRoom(code, "Late");
    expect(late.status).toBe(409);
    expect(late.body.error.code).toBe("run_in_progress");
    host.close();
    guests[0]!.close();
  });

  it("refuses a protocol it does not speak", async () => {
    const result = await post("/v1/rooms", { protocol: 999, name: "Jesse", fateId: fateId() }, testClientId());
    expect(result.status).toBe(426);
    expect(result.body.error.code).toBe("protocol_mismatch");
    expect(result.body.error.serverProtocol).toBe(PROTOCOL);

    const session = await createRoom("Jesse");
    await expect(Client.connect(session, { "X-Fate-Protocol": "999" })).rejects.toThrow(/426/);
  });
});

describe("display names", () => {
  const attempt = (name: unknown) =>
    post("/v1/rooms", { protocol: PROTOCOL, name, fateId: fateId() }, testClientId());

  it("accepts ordinary names, trimmed and tidied", async () => {
    const result = await attempt("  Jesse   Lee  ");
    expect(result.status).toBe(201);
    expect(result.body.room.members[0].name).toBe("Jesse Lee");
  });

  it("accepts names in other scripts", async () => {
    expect((await attempt("Whitney \u{1F409}")).status).toBe(201);
    expect((await attempt("小明")).status).toBe(201);
  });

  it.each([
    ["empty", ""],
    ["blank", "   "],
    ["invisible", "​​"],
    ["control characters", "BadName"],
    ["a right-to-left override", "Jesse‮"],
    ["too long", "A".repeat(17)],
    ["not a string", 42],
  ])("rejects a name that is %s", async (_label, name) => {
    const result = await attempt(name);
    expect(result.status).toBe(400);
  });
});

describe("passwords", () => {
  it("asks for a password, rejects a wrong one and accepts the right one", async () => {
    const host = await createRoom("Jesse", "hunter22");
    const missing = await joinRoom(host.code, "Whitney");
    expect(missing.status).toBe(401);
    expect(missing.body.error.code).toBe("password_required");
    const wrong = await joinRoom(host.code, "Whitney", "nope");
    expect(wrong.status).toBe(403);
    expect(wrong.body.error.code).toBe("wrong_password");
    const right = await joinRoom(host.code, "Whitney", "hunter22");
    expect(right.status).toBe(200);
  });

  it("never returns or exposes the password or its verifier", async () => {
    const created = await post(
      "/v1/rooms",
      { protocol: PROTOCOL, name: "Jesse", fateId: fateId(), password: "correct horse" },
      testClientId(),
    );
    expect(created.status).toBe(201);
    expect(JSON.stringify(created.body)).not.toContain("correct horse");
    expect(created.body.room.hasPassword).toBe(true);
    expect(JSON.stringify(created.body.room)).not.toMatch(/salt|hash|verifier/i);

    const client = await Client.connect({
      code: created.body.code,
      playerId: created.body.playerId,
      token: created.body.token,
      name: "Jesse",
      clientId: testClientId(),
    });
    const welcome = await client.waitFor((m) => m.t === "welcome");
    expect(JSON.stringify(welcome)).not.toMatch(/correct horse|salt|tokenHash/i);
    client.close();
  });

  it("locks a room after repeated wrong guesses", async () => {
    const host = await createRoom("Jesse", "letmein");
    let last = 0;
    for (let index = 0; index < 9; index++) {
      last = (await joinRoom(host.code, "Guesser", `wrong${index}`)).status;
    }
    expect(last).toBe(429);
    // Even the right password waits out the lock.
    expect((await joinRoom(host.code, "Whitney", "letmein")).status).toBe(429);
  });

  it("does not require a password on an open room", async () => {
    const host = await createRoom("Jesse");
    expect((await joinRoom(host.code, "Whitney", "unneeded")).status).toBe(200);
  });
});

describe("lobby", () => {
  it("shares ready states", async () => {
    const { host, guests } = await party(3);
    guests[0]!.send({ t: "ready", ready: true });
    const room = await host.room((r) => r.members.some((m: any) => m.name === "Whitney" && m.ready));
    expect(room.members.find((m: any) => m.name === "Kevin").ready).toBe(false);
    guests[0]!.send({ t: "ready", ready: false });
    await host.room((r) => r.members.every((m: any) => !m.ready));
    [host, ...guests].forEach((c) => c.close());
  });

  it("shares renames, loadouts and the chosen realm", async () => {
    const { host, guests } = await party(2);
    guests[0]!.send({ t: "rename", name: "Whit" });
    guests[0]!.send({
      t: "loadout",
      loadout: { weapon: "bow", hero: { build: "lithe", cloak: "hooded" }, legacy: ["vigor-1"] },
    });
    host.send({ t: "setRealm", realm: "hollow-wood" });
    const room = await host.room(
      (r) => r.realm === "hollow-wood" && r.members.some((m: any) => m.name === "Whit" && m.weapon === "bow"),
    );
    const whit = room.members.find((m: any) => m.name === "Whit");
    expect(whit.hero).toEqual({ build: "lithe", cloak: "hooded" });
    // Legacy is the host's business only.
    expect(JSON.stringify(room)).not.toContain("vigor-1");
    host.close();
    guests[0]!.close();
  });

  it("only lets the host start, kick, close or change the realm", async () => {
    const { host, guests } = await party(3);
    const guest = guests[0]!;
    const target = (await host.room((r) => r.members.length === 3)).members.find((m: any) => m.name === "Kevin");
    for (const message of [
      { t: "start" },
      { t: "kick", target: target.id },
      { t: "close" },
      { t: "setRealm", realm: "elsewhere" },
    ]) {
      const before = guest.messages.length;
      guest.send(message);
      const error = await guest.waitFor((m) => m.t === "error", 4000, before);
      expect(error.code).toBe("forbidden");
    }
    [host, ...guests].forEach((c) => c.close());
  });

  it("refuses to start with one player, or before everyone is ready", async () => {
    const solo = await createRoom("Jesse");
    const soloHost = await Client.connect(solo);
    soloHost.send({ t: "start" });
    expect((await soloHost.waitFor((m) => m.t === "error")).code).toBe("not_enough_players");

    const { host, guests } = await party(3);
    guests[0]!.send({ t: "ready", ready: true });
    await host.room((r) => r.members.some((m: any) => m.ready));
    const before = host.messages.length;
    host.send({ t: "start" });
    const error = await host.waitFor((m) => m.t === "error", 4000, before);
    expect(error.code).toBe("not_ready");
    soloHost.close();
    [host, ...guests].forEach((c) => c.close());
  });

  it("kicks a player, and their old credential stops working", async () => {
    const { host, guests, code } = await party(3);
    const victim = guests[1]!;
    const room = await host.room((r) => r.members.length === 3);
    const victimId = room.members.find((m: any) => m.name === "Kevin").id;
    host.send({ t: "kick", target: victimId });

    expect(await victim.waitForClose()).toBe(4003);
    const after = await host.room((r) => r.members.length === 2);
    expect(after.members.map((m: any) => m.name)).not.toContain("Kevin");

    await expect(Client.connect(victim.session)).rejects.toThrow(/401/);
    // The seat is free again.
    expect((await joinRoom(code, "Newcomer")).status).toBe(200);
    host.close();
    guests[0]!.close();
  });

  it("does not let the host be kicked", async () => {
    const { host, guests } = await party(2);
    const room = await host.room((r) => r.members.length === 2);
    const hostId = room.members.find((m: any) => m.host).id;
    const before = host.messages.length;
    host.send({ t: "kick", target: hostId });
    expect((await host.waitFor((m) => m.t === "error", 4000, before)).code).toBe("forbidden");
    host.close();
    guests[0]!.close();
  });

  it("ends the lobby for everyone when the host closes it", async () => {
    const { host, guests, code } = await party(3);
    host.send({ t: "close" });
    for (const guest of guests) {
      expect((await guest.waitFor((m) => m.t === "closed")).reason).toBe("closed");
      expect(await guest.waitForClose()).toBe(4004);
    }
    expect((await joinRoom(code, "Late")).status).toBe(404);
  });

  it("hands the lobby to someone else when the host leaves", async () => {
    const { host, guests } = await party(3);
    const room = await host.room((r) => r.members.length === 3);
    host.send({ t: "leave" });
    const next = await guests[0]!.room((r) => r.members.length === 2 && r.hostId !== room.hostId);
    expect(next.members.find((m: any) => m.host)).toBeTruthy();
    expect(next.hostId).not.toBe(room.hostId);
    guests.forEach((c) => c.close());
  });

  it("replaces an older connection from the same member", async () => {
    const session = await createRoom("Jesse");
    const first = await Client.connect(session);
    await first.waitFor((m) => m.t === "welcome");
    const second = await Client.connect(session);
    expect(await first.waitForClose()).toBe(4000);
    await second.waitFor((m) => m.t === "welcome");
    second.close();
  });
});

describe("a run", () => {
  it("starts for everyone with one seed", async () => {
    const { host, guests } = await party(3);
    const starts = await startRun(host, guests);
    const seeds = new Set(starts.map((m) => m.seed));
    expect(seeds.size).toBe(1);
    expect(starts[0].seed).toMatch(/^\d+$/);
    expect(starts.every((m) => m.runNumber === 1)).toBe(true);
    expect(new Set(starts.map((m) => m.runId)).size).toBe(1);
    // Everyone is on the roster with a distinct slot.
    expect(starts[0].roster.map((m: any) => m.slot).sort()).toEqual([0, 1, 2]);
    // Only the host is told what each player owns.
    expect(starts[0].roster.every((m: any) => Array.isArray(m.legacy))).toBe(true);
    expect(starts[1].roster.some((m: any) => "legacy" in m)).toBe(false);
    expect(starts[1].you).toBe(guests[0]!.session.playerId);
    [host, ...guests].forEach((c) => c.close());
  });

  it("relays gameplay frames: inputs to the host, snapshots to clients", async () => {
    const { host, guests } = await party(3);
    await startRun(host, guests);
    const [a, b] = guests as [Client, Client];
    const slotA = 1;
    const slotB = 2;

    a.sendBinary([1, 10, 20, 30]);
    const input = await host.waitForFrame((f) => f[0] === 1 && f[1] === slotA);
    expect(Array.from(input)).toEqual([1, slotA, 10, 20, 30]);

    // To everyone.
    host.sendBinary([2, 0xff, 7, 7]);
    expect(Array.from(await a.waitForFrame((f) => f[0] === 2))).toEqual([2, 7, 7]);
    expect(Array.from(await b.waitForFrame((f) => f[0] === 2))).toEqual([2, 7, 7]);

    // To one.
    host.sendBinary([5, slotB, 9]);
    expect(Array.from(await b.waitForFrame((f) => f[0] === 5))).toEqual([5, 9]);
    await sleep(200);
    expect(a.frames.some((f) => f[0] === 5)).toBe(false);
    [host, a, b].forEach((c) => c.close());
  });

  it("unpacks a host batch and hands each entry to its own client", async () => {
    const { host, guests } = await party(3);
    await startRun(host, guests);
    const [a, b] = guests as [Client, Client];
    // [6, count] then per entry [target, kind, lenHi, lenLo, ...payload].
    host.sendBinary([
      6, 4,
      1, 2, 0, 3, 11, 12, 13, // snapshot for seat 1
      2, 2, 0, 2, 21, 22, // snapshot for seat 2
      1, 4, 0, 1, 31, // events for seat 1
      0xff, 5, 0, 0, // an empty self state for everyone
    ]);
    const aSnapshot = await a.waitForFrame((f) => f[0] === 2);
    const bSnapshot = await b.waitForFrame((f) => f[0] === 2);
    expect(Array.from(aSnapshot)).toEqual([2, 11, 12, 13]);
    expect(Array.from(bSnapshot)).toEqual([2, 21, 22]);
    expect(Array.from(await a.waitForFrame((f) => f[0] === 4))).toEqual([4, 31]);
    expect(Array.from(await a.waitForFrame((f) => f[0] === 5))).toEqual([5]);
    expect(Array.from(await b.waitForFrame((f) => f[0] === 5))).toEqual([5]);
    // Seat 2 was never sent seat 1's events.
    await sleep(150);
    expect(b.frames.some((f) => f[0] === 4)).toBe(false);
    [host, a, b].forEach((c) => c.close());
  });

  it("drops a malformed batch whole, and a batch from a client", async () => {
    const { host, guests } = await party(2);
    await startRun(host, guests);
    const guest = guests[0]!;
    // The second entry claims more bytes than the frame holds: nothing is sent.
    host.sendBinary([6, 2, 1, 2, 0, 1, 9, 1, 2, 0, 9, 1]);
    // A count of zero, an unknown kind, a nested batch, and trailing bytes.
    host.sendBinary([6, 0]);
    host.sendBinary([6, 1, 1, 99, 0, 0]);
    host.sendBinary([6, 1, 1, 6, 0, 0]);
    host.sendBinary([6, 1, 1, 2, 0, 1, 7, 8]);
    // A guest may not send one at all.
    guest.sendBinary([6, 1, 0, 2, 0, 1, 5]);
    // Then a good frame, which proves the earlier ones were simply ignored.
    host.sendBinary([2, 0xff, 42]);
    expect(Array.from(await guest.waitForFrame((f) => f[0] === 2))).toEqual([2, 42]);
    expect(guest.frames).toHaveLength(1);
    expect(host.frames).toHaveLength(0);
    host.close();
    guest.close();
  });

  it("drops oversized, unknown and out-of-run frames", async () => {
    const { host, guests } = await party(2);
    const guest = guests[0]!;
    // Not in a run yet.
    guest.sendBinary([1, 1, 1]);
    await sleep(150);
    expect(host.frames).toHaveLength(0);

    await startRun(host, guests);
    guest.sendBinary([1, ...new Array(5000).fill(3)]);
    guest.sendBinary([99, 1, 2]);
    guest.sendBinary([1, 4, 4]);
    const frame = await host.waitForFrame((f) => f[0] === 1);
    expect(Array.from(frame)).toEqual([1, 1, 4, 4]);
    expect(host.frames).toHaveLength(1);
    host.close();
    guest.close();
  });

  it("returns everyone to the SAME lobby when the run ends, and plays again", async () => {
    const { code, host, guests } = await party(3, "sekrit");
    const first = await startRun(host, guests);
    const runId = first[0].runId;

    // A guest cannot end the run.
    const guest = guests[0]!;
    const before = guest.messages.length;
    guest.send({ t: "runEnd", runId, outcome: "defeated", summary: {} });
    expect((await guest.waitFor((m) => m.t === "error", 4000, before)).code).toBe("forbidden");

    // A stale run id is refused.
    const hostBefore = host.messages.length;
    host.send({ t: "runEnd", runId: "deadbeef", outcome: "defeated", summary: {} });
    expect((await host.waitFor((m) => m.t === "error", 4000, hostBefore)).code).toBe("bad_state");

    const marks = [host, ...guests].map((c) => c.messages.length);
    host.send({ t: "runEnd", runId, outcome: "defeated", summary: { wave: 7, secondsSurvived: 412 } });
    const lobbies = await Promise.all(
      [host, ...guests].map((c, i) => c.room((r) => r.phase === "lobby", 4000, marks[i] ?? 0)),
    );
    for (const room of lobbies) {
      expect(room.code).toBe(code);
      expect(room.hasPassword).toBe(true);
      expect(room.members).toHaveLength(3);
      expect(room.members.every((m: any) => m.ready === false)).toBe(true);
      expect(room.members.find((m: any) => m.host).name).toBe("Jesse");
      expect(room.lastRun.outcome).toBe("defeated");
      expect(room.lastRun.summary.wave).toBe(7);
      expect(room.run).toBeNull();
    }
    expect(host.messages.some((m) => m.t === "runEnd" && m.runId === runId)).toBe(true);

    // Nobody re-enters the room code or the password: the same sockets play run two.
    const second = await startRun(host, guests);
    expect(second[0].runNumber).toBe(2);
    expect(second[0].runId).not.toBe(runId);
    expect(second[0].seed).not.toBe(first[0].seed);
    expect(second.every((m) => m.seed === second[0].seed)).toBe(true);
    [host, ...guests].forEach((c) => c.close());
  });

  it("aborts the run and picks a new host when the host leaves mid-run", async () => {
    const { host, guests } = await party(3);
    await startRun(host, guests);
    const marks = guests.map((c) => c.messages.length);
    host.send({ t: "leave" });
    const ended = await guests[0]!.waitFor((m) => m.t === "runEnd", 4000, marks[0]);
    expect(ended.outcome).toBe("aborted");
    const room = await guests[0]!.room((r) => r.phase === "lobby" && r.members.length === 2, 4000, marks[0]);
    expect(room.members.some((m: any) => m.host)).toBe(true);
    guests.forEach((c) => c.close());
  });
});

describe("reconnecting", () => {
  it("restores a dropped player to the same seat, without a duplicate", async () => {
    const { host, guests } = await party(3);
    const victim = guests[0]!;
    await host.room((r) => r.members.every((m: any) => m.connected));
    const mark = host.messages.length;
    victim.socket.terminate();
    const gone = await host.room((r) => r.members.some((m: any) => m.name === "Whitney" && !m.connected), 4000, mark);
    expect(gone.members).toHaveLength(3);

    const back = await Client.connect(victim.session);
    const welcome = await back.waitFor((m) => m.t === "welcome");
    expect(welcome.you).toBe(victim.session.playerId);
    const room = await host.room((r) => r.members.every((m: any) => m.connected), 4000, mark);
    expect(room.members).toHaveLength(3);
    expect(room.members.filter((m: any) => m.name === "Whitney")).toHaveLength(1);
    [host, back, guests[1]!].forEach((c) => c.close());
  });

  it("puts a returning player back into the run and tells the host", async () => {
    const { host, guests } = await party(2);
    await startRun(host, guests);
    const victim = guests[0]!;
    const marks = host.messages.length;
    victim.socket.terminate();
    const lost = await host.waitFor((m) => m.t === "peer" && m.event === "disconnected", 4000, marks);
    expect(lost.slot).toBe(1);

    const back = await Client.connect(victim.session);
    const resumed = await back.waitFor((m) => m.t === "runStart");
    expect(resumed.resumed).toBe(true);
    expect(resumed.you).toBe(victim.session.playerId);
    await host.waitFor((m) => m.t === "peer" && m.event === "connected", 4000, marks);
    // Relay works again straight away.
    back.sendBinary([1, 5, 5]);
    expect(Array.from(await host.waitForFrame((f) => f[0] === 1 && f[2] === 5))).toEqual([1, 1, 5, 5]);
    host.close();
    back.close();
  });

  it.runIf(TIMING_TESTS)("abandons a run whose host never comes back", async () => {
    const { host, guests } = await party(2);
    await startRun(host, guests);
    const guest = guests[0]!;
    const mark = guest.messages.length;
    host.socket.terminate();
    const away = await guest.waitFor((m) => m.t === "hostAway", 4000, mark);
    expect(away.until).toBeGreaterThan(Date.now() - 1000);
    const ended = await guest.waitFor((m) => m.t === "runEnd", 8000, mark);
    expect(ended.outcome).toBe("aborted");
    expect(ended.summary.reason).toBe("hostLost");
    const lobby = await guest.room((r) => r.phase === "lobby", 4000, mark);
    expect(lobby.members).toHaveLength(2);
    guest.close();
  });

  it.runIf(TIMING_TESTS)("lets a host who returns in time carry on", async () => {
    const { host, guests } = await party(2);
    await startRun(host, guests);
    const guest = guests[0]!;
    const mark = guest.messages.length;
    host.socket.terminate();
    await guest.waitFor((m) => m.t === "hostAway", 4000, mark);
    const back = await Client.connect(host.session);
    const resumed = await back.waitFor((m) => m.t === "runStart");
    expect(resumed.resumed).toBe(true);
    await guest.waitFor((m) => m.t === "hostBack", 4000, mark);
    await sleep(1800);
    const room = await guest.room((r) => r.phase === "inRun", 4000, mark);
    expect(room.hostGraceEndsAt).toBeNull();
    back.close();
    guest.close();
  });

  it.runIf(TIMING_TESTS)("hands a lobby to another player when the host stays away", async () => {
    const { host, guests } = await party(3);
    const room = await guests[0]!.room((r) => r.members.length === 3);
    host.socket.terminate();
    const next = await guests[0]!.room((r) => r.hostId !== room.hostId, 8000);
    expect(next.members).toHaveLength(3);
    guests.forEach((c) => c.close());
  });
});

describe("expiry", () => {
  it.runIf(TIMING_TESTS)("drops a room nobody is connected to", async () => {
    const session = await createRoom("Jesse");
    const client = await Client.connect(session);
    await client.waitFor((m) => m.t === "welcome");
    client.socket.terminate();
    await sleep(4500);
    const result = await joinRoom(session.code, "Whitney");
    expect(result.status).toBe(404);
  });

  it.runIf(TIMING_TESTS)("keeps a room that still has someone in it", async () => {
    const session = await createRoom("Jesse");
    const client = await Client.connect(session);
    await client.waitFor((m) => m.t === "welcome");
    await sleep(4500);
    expect((await joinRoom(session.code, "Whitney")).status).toBe(200);
    client.close();
  });
});

describe("abuse", () => {
  it("throttles someone guessing room codes", async () => {
    const clientId = testClientId();
    let blocked = false;
    for (let index = 0; index < 20; index++) {
      const result = await joinRoom("ZZZZZ2", "Guesser", undefined, clientId);
      if (result.status === 429) {
        blocked = true;
        expect(result.body.error.code).toBe("rate_limited");
        break;
      }
    }
    expect(blocked).toBe(true);
    // Somebody else is not affected.
    const host = await createRoom("Jesse");
    expect((await joinRoom(host.code, "Whitney")).status).toBe(200);
  });

  it("throttles room creation", async () => {
    const clientId = testClientId();
    let blocked = false;
    for (let index = 0; index < 16; index++) {
      const result = await post("/v1/rooms", { protocol: PROTOCOL, name: "Spam", fateId: fateId() }, clientId);
      if (result.status === 429) {
        blocked = true;
        break;
      }
    }
    expect(blocked).toBe(true);
  });

  it("rejects malformed and oversized requests", async () => {
    const id = testClientId();
    expect((await post("/v1/rooms", "{not json", id)).status).toBe(400);
    expect((await post("/v1/rooms", [], id)).status).toBe(400);
    expect((await post("/v1/rooms", { protocol: PROTOCOL, name: "x", fateId: "nope" }, id)).status).toBe(400);
    const huge = { protocol: PROTOCOL, name: "Jesse", fateId: fateId(), padding: "x".repeat(5000) };
    expect((await post("/v1/rooms", huge, id)).status).toBe(413);
  });

  it("answers bad socket messages with errors and keeps the connection", async () => {
    const session = await createRoom("Jesse");
    const client = await Client.connect(session);
    await client.waitFor((m) => m.t === "welcome");
    client.socket.send("not json");
    expect((await client.waitFor((m) => m.t === "error")).code).toBe("bad_request");
    client.send({ t: "teleport" });
    client.send({ t: "ready", ready: "yes" });
    client.send({ t: "loadout", loadout: { weapon: "../../etc/passwd" } });
    client.send({ t: "rename", name: "​" });
    await sleep(300);
    expect(client.messages.filter((m) => m.t === "error").length).toBeGreaterThanOrEqual(5);
    expect(client.closeCode).toBeNull();
    client.send({ t: "ready", ready: true });
    await client.room((r) => r.members[0].ready);
    client.close();
  });

  it("does not let a stranger connect", async () => {
    const session = await createRoom("Jesse");
    const stranger: Session = { ...session, token: "A".repeat(43) };
    await expect(Client.connect(stranger)).rejects.toThrow(/401/);
    const nobody: Session = { ...session, code: "ZZZZZ3" };
    await expect(Client.connect(nobody)).rejects.toThrow(/404|401/);
  });

  it("serves a health check", async () => {
    const response = await fetch(`${BASE_URL}/health`);
    const body: any = await response.json();
    expect(body.ok).toBe(true);
    expect(body.protocol).toBe(PROTOCOL);
  });
});
