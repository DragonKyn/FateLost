import { DurableObject } from "cloudflare:workers";
import { windowStatus } from "./limits";

/**
 * Counts events for one caller (an address and a kind of request) inside a
 * sliding window. Guessing room codes and passwords is throttled here, before
 * a request ever reaches a room.
 *
 * One instance per caller, so the state is tiny and expires by itself.
 */
export class RateLimiter extends DurableObject {
  /** Whether another event is allowed, without counting one. */
  async peek(limit: number, windowMs: number): Promise<{ allowed: boolean; retryAfterMs: number }> {
    const now = Date.now();
    const stored = (await this.ctx.storage.get<number[]>("events")) ?? [];
    const { allowed, retryAfterMs } = windowStatus(stored, now, limit, windowMs);
    return { allowed, retryAfterMs };
  }

  /** Counts an event. */
  async record(windowMs: number): Promise<void> {
    const now = Date.now();
    const stored = (await this.ctx.storage.get<number[]>("events")) ?? [];
    const recent = stored.filter((stamp) => now - stamp < windowMs);
    recent.push(now);
    await this.ctx.storage.put("events", recent.slice(-200));
    await this.ctx.storage.setAlarm(now + windowMs + 1000);
  }

  /** Counts an event if allowed, in one step. */
  async take(limit: number, windowMs: number): Promise<{ allowed: boolean; retryAfterMs: number }> {
    const status = await this.peek(limit, windowMs);
    if (status.allowed) await this.record(windowMs);
    return status;
  }

  override async alarm(): Promise<void> {
    await this.ctx.storage.deleteAll();
  }
}
