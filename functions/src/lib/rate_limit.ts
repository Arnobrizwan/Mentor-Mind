// Phase 3 interface — stub only. Do NOT implement in Phase 2.

export interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  resetAt: number; // Unix ms timestamp when the counter resets (midnight UTC+6)
}

export async function checkAndIncrement(
  _uid: string,
  _kind: "text" | "image"
): Promise<RateLimitResult> {
  throw new Error("not implemented — see Phase 3");
}
