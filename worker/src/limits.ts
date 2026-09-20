/**
 * Small pure helpers for throttling, kept free of Workers-only imports so
 * they can be unit tested in plain Node.
 */

/** A sliding window: how many events fell inside it, and when room frees up. */
export function windowStatus(
  timestamps: readonly number[],
  now: number,
  limit: number,
  windowMs: number,
): { allowed: boolean; retryAfterMs: number; recent: number[] } {
  const recent = timestamps.filter((stamp) => now - stamp < windowMs);
  if (recent.length < limit) return { allowed: true, retryAfterMs: 0, recent };
  // The oldest event still inside the window is the one that has to age out.
  const oldest = recent[recent.length - limit] ?? recent[0] ?? now;
  return { allowed: false, retryAfterMs: Math.max(0, oldest + windowMs - now), recent };
}

/**
 * A token bucket. Cheap enough to keep one per socket, and forgiving of a
 * burst (a snapshot and a few events at once) while still stopping a flood.
 */
export class TokenBucket {
  private tokens: number;
  private last: number;

  constructor(
    private readonly capacity: number,
    private readonly refillPerSecond: number,
    now: number,
  ) {
    this.tokens = capacity;
    this.last = now;
  }

  take(now: number, cost = 1): boolean {
    const elapsed = Math.max(0, now - this.last) / 1000;
    this.last = now;
    this.tokens = Math.min(this.capacity, this.tokens + elapsed * this.refillPerSecond);
    if (this.tokens < cost) return false;
    this.tokens -= cost;
    return true;
  }
}
