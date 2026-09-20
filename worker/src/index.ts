import { generateRoomCode } from "./crypto";
import type { Env } from "./env";
import { errorResponse, json, readJson } from "./http";
import { ApiError, PROTOCOL_VERSION, normaliseRoomCode, parseJoinBody } from "./protocol";

export { PartyRoom } from "./partyRoom";
export { RateLimiter } from "./rateLimiter";

/** Creating rooms: a handful per hour is far more than a family needs. */
const CREATE_LIMIT = { count: 12, windowMs: 60 * 60_000 };
/** Failed joins (no such code, wrong password) from one address. */
const FAILURE_LIMIT = { count: 12, windowMs: 10 * 60_000 };
/** Every join or reconnect attempt, however it turns out. */
const ATTEMPT_LIMIT = { count: 120, windowMs: 60_000 };

/**
 * Who a request counts against. Outside production a test may name itself
 * with X-Test-Client-Id so parallel tests do not share one throttle. In
 * production the header is ignored.
 */
function clientAddress(request: Request, env: Env): string {
  if (env.ENVIRONMENT !== "production") {
    const claimed = request.headers.get("X-Test-Client-Id");
    if (claimed && /^[a-z0-9-]{1,40}$/i.test(claimed)) return `test-${claimed}`;
  }
  return request.headers.get("CF-Connecting-IP") ?? "local";
}

function limiterFor(env: Env, kind: string, address: string) {
  return env.RATE_LIMITER.get(env.RATE_LIMITER.idFromName(`${kind}:${address}`));
}

async function throttle(env: Env, kind: string, request: Request, limit: { count: number; windowMs: number }) {
  const status = await limiterFor(env, kind, clientAddress(request, env)).peek(limit.count, limit.windowMs);
  if (!status.allowed) {
    throw new ApiError("rate_limited", "Too many attempts. Try again in a little while.", 429, {
      retryAfter: Math.ceil(status.retryAfterMs / 1000),
    });
  }
}

function roomStub(env: Env, code: string) {
  return env.PARTY_ROOM.get(env.PARTY_ROOM.idFromName(code));
}

async function createRoom(request: Request, env: Env): Promise<Response> {
  await throttle(env, "create", request, { count: CREATE_LIMIT.count, windowMs: CREATE_LIMIT.windowMs });
  const text = await readJson(request, 2_000);
  // Validate here too, so a bad request never costs a room object.
  parseJoinBody(text);
  await limiterFor(env, "create", clientAddress(request, env)).record(CREATE_LIMIT.windowMs);

  for (let attempt = 0; attempt < 8; attempt++) {
    const code = generateRoomCode();
    const response = await roomStub(env, code).fetch(
      new Request(`https://room.internal/v1/rooms/${code}/create`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(text),
      }),
    );
    if (response.status !== 409) return response;
  }
  throw new ApiError("internal", "Could not find a free room code. Try again.", 503);
}

async function joinRoom(request: Request, env: Env, code: string): Promise<Response> {
  await throttle(env, "attempt", request, ATTEMPT_LIMIT);
  await throttle(env, "failure", request, FAILURE_LIMIT);
  const body = await readJson(request, 2_000);
  parseJoinBody(body);
  const response = await roomStub(env, code).fetch(
    new Request(`https://room.internal/v1/rooms/${code}/join`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
    }),
  );
  await limiterFor(env, "attempt", clientAddress(request, env)).record(ATTEMPT_LIMIT.windowMs);
  if (response.status === 404 || response.status === 403) {
    // A wrong guess, at the code or at the password.
    await limiterFor(env, "failure", clientAddress(request, env)).record(FAILURE_LIMIT.windowMs);
  }
  return response;
}

async function connectSocket(request: Request, env: Env, code: string): Promise<Response> {
  await throttle(env, "attempt", request, ATTEMPT_LIMIT);
  await limiterFor(env, "attempt", clientAddress(request, env)).record(ATTEMPT_LIMIT.windowMs);
  const response = await roomStub(env, code).fetch(
    new Request(`https://room.internal/v1/rooms/${code}/ws`, { method: "GET", headers: request.headers }),
  );
  if (response.status === 401 || response.status === 404) {
    await limiterFor(env, "failure", clientAddress(request, env)).record(FAILURE_LIMIT.windowMs);
  }
  return response;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const parts = url.pathname.split("/").filter(Boolean);
    try {
      if (parts.length === 0 || (parts.length === 1 && parts[0] === "health")) {
        return json({ ok: true, service: "fate-lost-multiplayer", protocol: PROTOCOL_VERSION, environment: env.ENVIRONMENT });
      }
      if (parts[0] !== "v1" || parts[1] !== "rooms") throw new ApiError("bad_request", "Unknown route.", 404);

      if (parts.length === 2 && request.method === "POST") return await createRoom(request, env);

      if (parts.length === 4) {
        const code = normaliseRoomCode(parts[2]);
        if (!code) throw new ApiError("room_not_found", "That is not a room code.", 404);
        if (parts[3] === "join" && request.method === "POST") return await joinRoom(request, env, code);
        if (parts[3] === "ws" && request.method === "GET") return await connectSocket(request, env, code);
      }
      throw new ApiError("bad_request", "Unknown route.", 404);
    } catch (error) {
      return errorResponse(error);
    }
  },
} satisfies ExportedHandler<Env>;
