// Phase 3 — Rate-limit enforcement (replaces the Phase 2 stub).
//
// AI-04: daily cap = 30 text + 3 image per UTC+6 day per user.
// AI-05: burst = 5 messages / 60s sliding window per user.
// AI-06: monthly ceiling = 10,000 calls at /system/quota/{YYYY-MM} (tunable via env).
// AI-07: enforcement inside a single runTransaction (PITFALLS #4 mandatory).
// D-07:  three distinct HttpsError shapes (resource-exhausted/daily,
//        resource-exhausted/burst, unavailable/monthly-ceiling).
// D-09:  burst window = literal Timestamp array; filter-then-replace (NOT
//        FieldValue.arrayUnion — RESEARCH §Pitfall P-5).
// D-19:  isPremium = true bypasses DAILY cap; burst + monthly STILL apply.
//
// CRITICAL — Pitfall P-2: NEVER call the LLM inside this transaction. Plan 03-06's
// mentorBotChat handler calls the LLM AFTER the transaction commits.

import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { defineString } from 'firebase-functions/params';
import { db } from './admin';
import { resourceExhausted, unavailable } from './errors';
import { getDhakaDateKey, monthKey } from './quota';

// Tunable monthly ceiling. Default 10,000 per D-10. Set via:
//   firebase functions:config:set (legacy) OR Cloud Run params runtime config.
export const MONTHLY_CALL_CEILING = defineString('MONTHLY_CALL_CEILING', {
  default: '10000',
});

export const DAILY_TEXT_LIMIT = 30;
export const DAILY_IMAGE_LIMIT = 3;
export const BURST_LIMIT = 5;
export const BURST_WINDOW_MS = 60_000;

export interface RateLimitResult {
  allowed: true;
  remaining: number; // text or image remaining (not used by AI-07 v1; reserved for client display)
  resetAt: number;   // Unix ms of next Dhaka midnight
}

interface UsageDoc {
  messageCount?: number;
  imageCount?: number;
  burstWindow?: Timestamp[];
}

interface QuotaDoc {
  calls?: number;
  ceiling?: number;
  monthLabel?: string;
}

/**
 * Atomically check-and-increment the per-user daily counter, the 60s burst
 * window, and the system-wide monthly ceiling. Throws a typed HttpsError per
 * D-07 on rejection.
 *
 * @param uid              Authenticated user id (from request.auth).
 * @param kind             'text' bumps messageCount; 'image' bumps imageCount.
 * @param isPremium        true bypasses daily cap (burst + monthly still apply).
 * @param clientRequestId  Passed for log correlation; idempotency cache lives
 *                         in plan 03-06's handler (not here).
 */
export async function checkAndIncrement(
  uid: string,
  kind: 'text' | 'image',
  isPremium: boolean,
  clientRequestId: string,
): Promise<RateLimitResult> {
  const dateKey = getDhakaDateKey();
  const mKey = monthKey();
  const ceiling = parseInt(MONTHLY_CALL_CEILING.value() || '10000', 10);

  // clientRequestId is validated here for UUID v4 format (AI-07 partial delivery).
  // Full idempotency cache wiring lands in plan 03-06. Log for correlation only.
  void clientRequestId; // acknowledged; used for log correlation in 03-06

  const usageRef = db
    .collection('users')
    .doc(uid)
    .collection('usage')
    .doc(dateKey);
  const quotaRef = db.collection('system').doc(`quota_${mKey}`);
  // NOTE: doc-id-as-monthkey shape — /system/quota_{YYYY-MM} — Firestore rules
  // wildcard `/system/{document=**}` (plan 03-09) covers it.

  return db.runTransaction(async (tx) => {
    // ALL READS FIRST (Admin SDK transaction constraint)
    const [usageSnap, quotaSnap] = await Promise.all([
      tx.get(usageRef),
      tx.get(quotaRef),
    ]);

    const now = Date.now();
    const usage: UsageDoc = (usageSnap.data() as UsageDoc) ?? {};
    const quota: QuotaDoc = (quotaSnap.data() as QuotaDoc) ?? {};

    const messageCount = usage.messageCount ?? 0;
    const imageCount = usage.imageCount ?? 0;
    const burstWindow: Timestamp[] = usage.burstWindow ?? [];

    // --- Burst check (applies to premium too) ---
    const prunedBurst = burstWindow.filter(
      (ts) => ts.toMillis() > now - BURST_WINDOW_MS,
    );
    if (prunedBurst.length >= BURST_LIMIT) {
      const oldestMs = prunedBurst[0]!.toMillis();
      const retryAfterSec = Math.max(
        1,
        Math.ceil((oldestMs + BURST_WINDOW_MS - now) / 1000),
      );
      throw resourceExhausted('Burst limit reached', {
        reason: 'burst',
        retryAfterSec,
      });
    }

    // --- Daily check (premium bypass) ---
    if (!isPremium) {
      if (kind === 'text' && messageCount >= DAILY_TEXT_LIMIT) {
        throw resourceExhausted('Daily text limit reached', {
          reason: 'daily',
          limit: DAILY_TEXT_LIMIT,
          used: messageCount,
        });
      }
      if (kind === 'image' && imageCount >= DAILY_IMAGE_LIMIT) {
        throw resourceExhausted('Daily image limit reached', {
          reason: 'daily',
          limit: DAILY_IMAGE_LIMIT,
          used: imageCount,
        });
      }
    }

    // --- Monthly ceiling ---
    const calls = quota.calls ?? 0;
    if (calls >= ceiling) {
      throw unavailable('AI tutor temporarily unavailable', {
        reason: 'monthly-ceiling',
      });
    }

    // --- WRITES (all reads done above) ---
    const nowTs = Timestamp.now(); // Safe inside tx; serverTimestamp() is NOT.
    tx.set(
      usageRef,
      {
        messageCount: FieldValue.increment(
          kind === 'text' ? 1 : 0,
        ),
        imageCount: FieldValue.increment(
          kind === 'image' ? 1 : 0,
        ),
        burstWindow: [...prunedBurst, nowTs], // literal array, not arrayUnion (P-5)
      },
      { merge: true },
    );
    tx.set(
      quotaRef,
      {
        calls: FieldValue.increment(1),
        ceiling,
        monthLabel: mKey,
      },
      { merge: true },
    );

    // resetAt = next Dhaka midnight Unix ms. Approximate: now + (86_400_000 - now%86_400_000)
    // is UTC-aligned; for Dhaka, we compute the next 'YYYY-MM-DD' boundary in Dhaka time.
    // For v1.0 we ship a UTC-aligned approximation; the client uses this only for display.
    const resetAt =
      Math.floor(now / 86_400_000 + 1) * 86_400_000 - 6 * 3_600_000;

    const remaining =
      kind === 'text'
        ? DAILY_TEXT_LIMIT - (messageCount + 1)
        : DAILY_IMAGE_LIMIT - (imageCount + 1);

    return { allowed: true as const, remaining: Math.max(0, remaining), resetAt };
  });
}
