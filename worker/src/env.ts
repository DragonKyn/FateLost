import type { PartyRoom } from "./partyRoom";
import type { RateLimiter } from "./rateLimiter";

export interface Env {
  PARTY_ROOM: DurableObjectNamespace<PartyRoom>;
  RATE_LIMITER: DurableObjectNamespace<RateLimiter>;
  ENVIRONMENT: string;
  /** PBKDF2 rounds for lobby passwords, as text (vars are strings). */
  PBKDF2_ITERATIONS: string;
  /** Optional lifetimes in milliseconds. Only the test environment sets them. */
  HOST_GRACE_RUN_MS?: string;
  HOST_GRACE_LOBBY_MS?: string;
  ABANDONED_MS?: string;
  IDLE_LOBBY_MS?: string;
}
