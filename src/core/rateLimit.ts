// Simple fixed-window rate limiter (pure). State is stored per user in Firestore.

export interface RateLimitState {
  windowStartMs: number;
  count: number;
}

export function checkRateLimit(
  state: RateLimitState | undefined | null,
  nowMs: number,
  limit: number,
  windowMs: number,
): { allowed: boolean; next: RateLimitState; retryAfterSeconds: number } {
  if (!state || nowMs - state.windowStartMs >= windowMs || nowMs < state.windowStartMs) {
    return { allowed: true, next: { windowStartMs: nowMs, count: 1 }, retryAfterSeconds: 0 };
  }
  if (state.count >= limit) {
    return {
      allowed: false,
      next: state,
      retryAfterSeconds: Math.ceil((state.windowStartMs + windowMs - nowMs) / 1000),
    };
  }
  return { allowed: true, next: { windowStartMs: state.windowStartMs, count: state.count + 1 }, retryAfterSeconds: 0 };
}
