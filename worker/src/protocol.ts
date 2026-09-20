/**
 * The wire protocol between the Fate Lost app and the party service.
 *
 * Control traffic (the lobby) is JSON text. Gameplay traffic (inputs,
 * snapshots) is binary and opaque to the server: it only checks who is
 * allowed to send it, how big it is and how often, then relays it. See
 * docs/MULTIPLAYER_PROTOCOL.md.
 *
 * Every client is untrusted, so nothing here trusts a shape: each inbound
 * message goes through a validator that returns a typed value or an error.
 */

/** Bumped when a change would confuse an older app. */
export const PROTOCOL_VERSION = 1;

export const MAX_PLAYERS = 4;
export const MIN_PLAYERS_TO_START = 2;

export const ROOM_CODE_LENGTH = 6;
/** No 0/O, 1/I or L: read aloud or off a screen, none can be mistaken. */
export const ROOM_CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

export const NAME_MAX_LENGTH = 16;
export const PASSWORD_MAX_LENGTH = 64;
export const PASSWORD_MIN_LENGTH = 1;

/** Largest JSON text frame, in bytes. */
export const MAX_TEXT_FRAME = 20_000;
/** Largest binary frame from a client: an input packet is tiny, a build command a few KB. */
export const MAX_CLIENT_BINARY = 4096;
/** Largest binary frame from the host (a snapshot). */
export const MAX_HOST_BINARY = 24_000;
/**
 * Largest batch from the host: one frame carrying a snapshot, events and
 * self state for every client. A message the host sends counts against the
 * free plan's request allowance once, however many clients it reaches, so
 * one batch a tick is far cheaper than one frame per client.
 */
export const MAX_HOST_BATCH = 64_000;
/** The most entries one batch may carry. */
export const MAX_BATCH_ENTRIES = 24;
export const MAX_LOADOUT_BYTES = 16_000;
export const MAX_SUMMARY_BYTES = 6_000;

/** Binary frame kinds. The server only inspects the first two bytes. */
export const BinaryKind = {
  /** Client to host: movement and ability presses. */
  input: 1,
  /** Host to client: a world snapshot. */
  snapshot: 2,
  /** Client to host: a build command (allocate skills, pick a relic). */
  command: 3,
  /** Host to client: a semantic event batch (hits, kills, revive progress). */
  events: 4,
  /** Host to client: the client's own progression/build state. */
  selfState: 5,
  /**
   * Host to room: several frames in one. [6, count] then, per entry,
   * [target, kind, lengthHigh, lengthLow, ...payload]. Each entry reaches its
   * target as an ordinary [kind, ...payload] frame.
   */
  batch: 6,
} as const;
export const MAX_BINARY_KIND = 15;
/** Target byte meaning "every other member". */
export const TARGET_ALL = 0xff;

export type Phase = "lobby" | "inRun";

export interface MemberView {
  id: string;
  name: string;
  fateId: string;
  slot: number;
  host: boolean;
  ready: boolean;
  connected: boolean;
  /** How the member looks and what they carry; small, public to the party. */
  weapon: string;
  hero: Record<string, unknown> | null;
}

export interface RoomView {
  code: string;
  protocol: number;
  hostId: string;
  phase: Phase;
  runNumber: number;
  hasPassword: boolean;
  maxPlayers: number;
  realm: string;
  members: MemberView[];
  /** Present while a run is on. */
  run: { runId: string; seed: string; startedAt: number } | null;
  /** The last finished run's outcome, for the results panel. */
  lastRun: { runId: string; outcome: string; summary: unknown } | null;
  /** When the host went quiet during a run; the run is abandoned at this time. */
  hostGraceEndsAt: number | null;
}

export interface Loadout {
  weapon: string;
  hero: Record<string, unknown> | null;
  /** Ids of Legacy nodes the player owns, so the host can compute stats. */
  legacy: string[];
}

// MARK: - Errors

export type ErrorCode =
  | "bad_request"
  | "protocol_mismatch"
  | "room_not_found"
  | "room_full"
  | "wrong_password"
  | "password_required"
  | "run_in_progress"
  | "rate_limited"
  | "unauthorized"
  | "forbidden"
  | "not_ready"
  | "not_enough_players"
  | "bad_state"
  | "too_large"
  | "internal";

export class ApiError extends Error {
  constructor(
    public readonly code: ErrorCode,
    message: string,
    public readonly status: number,
    public readonly extra: Record<string, unknown> = {},
  ) {
    super(message);
  }
}

// MARK: - Names

/**
 * Anything invisible, control or formatting: those let a name look empty or
 * spoof another. Zero-width joiners fall in here too, which costs a few
 * compound emoji and buys names that always mean what they show.
 */
const FORBIDDEN_NAME_CHARACTERS = /[\p{Cc}\p{Cf}\p{Cn}\p{Co}\p{Cs}\p{Zl}\p{Zp}ㅤᅟᅠﾠ⠀឴឵͏]/u;
const VISIBLE_NAME_CHARACTER = /[\p{L}\p{N}\p{S}\p{P}]/u;

/** Returns the cleaned name, or null if it cannot be used. */
export function cleanDisplayName(input: unknown): string | null {
  if (typeof input !== "string") return null;
  if (input.length > NAME_MAX_LENGTH * 4) return null;
  const raw = input.normalize("NFC");
  // Checked before any tidying: trimming would quietly swallow a byte-order
  // mark or a tab that has no business in a name.
  if (FORBIDDEN_NAME_CHARACTERS.test(raw)) return null;
  const normalised = raw.replace(/\s+/gu, " ").trim();
  if (normalised.length === 0) return null;
  if (!VISIBLE_NAME_CHARACTER.test(normalised)) return null;
  if (Array.from(normalised).length > NAME_MAX_LENGTH) return null;
  return normalised;
}

/** The public, meaningless id shown to players: FL-8K4P-72QM. */
const FATE_ID = /^FL-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$/;

export function isFateId(input: unknown): input is string {
  return typeof input === "string" && FATE_ID.test(input);
}

export function normaliseRoomCode(input: unknown): string | null {
  if (typeof input !== "string") return null;
  const code = input.trim().toUpperCase();
  if (code.length !== ROOM_CODE_LENGTH) return null;
  for (const character of code) {
    if (!ROOM_CODE_ALPHABET.includes(character)) return null;
  }
  return code;
}

// MARK: - Validators

type Json = Record<string, unknown>;

export function isObject(value: unknown): value is Json {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function fail(message: string): never {
  throw new ApiError("bad_request", message, 400);
}

function id(value: unknown, field: string): string {
  if (typeof value !== "string" || !/^[a-z0-9_-]{1,40}$/i.test(value)) fail(`${field} is not valid`);
  return value;
}

/** A short plain identifier for content (a weapon, a realm). */
export function contentId(value: unknown, field: string): string {
  if (typeof value !== "string" || !/^[A-Za-z0-9_.-]{1,40}$/.test(value)) fail(`${field} is not valid`);
  return value;
}

/** Small JSON of numbers, strings and booleans, with bounded depth. */
function plainObject(value: unknown, field: string, maxKeys = 40): Record<string, unknown> {
  if (!isObject(value)) fail(`${field} must be an object`);
  const keys = Object.keys(value);
  if (keys.length > maxKeys) fail(`${field} has too many fields`);
  for (const key of keys) {
    const entry = value[key];
    if (key.length > 40) fail(`${field} has a long key`);
    const type = typeof entry;
    if (type === "string") {
      if ((entry as string).length > 80) fail(`${field}.${key} is too long`);
    } else if (type === "number") {
      if (!Number.isFinite(entry as number)) fail(`${field}.${key} is not finite`);
    } else if (type !== "boolean" && entry !== null) {
      fail(`${field}.${key} has an unsupported type`);
    }
  }
  return value;
}

export function parseLoadout(value: unknown): Loadout {
  if (!isObject(value)) fail("loadout must be an object");
  const legacyRaw = value.legacy;
  let legacy: string[] = [];
  if (legacyRaw !== undefined) {
    if (!Array.isArray(legacyRaw) || legacyRaw.length > 1000) fail("legacy is not valid");
    legacy = legacyRaw.map((entry) => {
      if (typeof entry !== "string" || entry.length > 40 || !/^[A-Za-z0-9_.-]+$/.test(entry)) {
        fail("legacy has a bad entry");
      }
      return entry;
    });
  }
  const hero = value.hero === undefined || value.hero === null ? null : plainObject(value.hero, "hero");
  return { weapon: contentId(value.weapon, "weapon"), hero, legacy };
}

export interface JoinBody {
  protocol: number;
  name: string;
  fateId: string;
  password: string | null;
}

/** The body of a create or join request. */
export function parseJoinBody(raw: unknown): JoinBody {
  if (!isObject(raw)) fail("body must be a JSON object");
  if (raw.protocol !== PROTOCOL_VERSION) {
    throw new ApiError("protocol_mismatch", "This version of Fate Lost cannot play with the party service.", 426, {
      serverProtocol: PROTOCOL_VERSION,
    });
  }
  const name = cleanDisplayName(raw.name);
  if (name === null) fail("That name cannot be used");
  if (!isFateId(raw.fateId)) fail("fateId is not valid");
  let password: string | null = null;
  if (raw.password !== undefined && raw.password !== null && raw.password !== "") {
    if (
      typeof raw.password !== "string" ||
      raw.password.length < PASSWORD_MIN_LENGTH ||
      raw.password.length > PASSWORD_MAX_LENGTH
    ) {
      fail(`Passwords are ${PASSWORD_MIN_LENGTH} to ${PASSWORD_MAX_LENGTH} characters`);
    }
    password = raw.password;
  }
  return { protocol: raw.protocol, name, fateId: raw.fateId, password };
}

/** What a client may send over the socket as text. */
export type ClientMessage =
  | { t: "ready"; ready: boolean }
  | { t: "loadout"; loadout: Loadout }
  | { t: "rename"; name: string }
  | { t: "setRealm"; realm: string }
  | { t: "start" }
  | { t: "kick"; target: string }
  | { t: "close" }
  | { t: "leave" }
  | { t: "runEnd"; runId: string; outcome: "defeated" | "conquered" | "aborted"; summary: unknown };

export function parseClientMessage(raw: unknown): ClientMessage {
  if (!isObject(raw) || typeof raw.t !== "string") fail("message needs a type");
  switch (raw.t) {
    case "ready":
      if (typeof raw.ready !== "boolean") fail("ready must be a boolean");
      return { t: "ready", ready: raw.ready };
    case "loadout":
      return { t: "loadout", loadout: parseLoadout(raw.loadout) };
    case "rename": {
      const name = cleanDisplayName(raw.name);
      if (name === null) fail("That name cannot be used");
      return { t: "rename", name };
    }
    case "setRealm":
      return { t: "setRealm", realm: contentId(raw.realm, "realm") };
    case "start":
    case "close":
    case "leave":
      return { t: raw.t };
    case "kick":
      return { t: "kick", target: id(raw.target, "target") };
    case "runEnd": {
      if (raw.outcome !== "defeated" && raw.outcome !== "conquered" && raw.outcome !== "aborted") {
        fail("outcome is not valid");
      }
      const summary = raw.summary ?? null;
      if (JSON.stringify(summary).length > MAX_SUMMARY_BYTES) {
        throw new ApiError("too_large", "summary is too large", 413);
      }
      return { t: "runEnd", runId: id(raw.runId, "runId"), outcome: raw.outcome, summary };
    }
    default:
      fail("unknown message type");
  }
}
