// MIRROR: lib/core/constants/quota.dart exports `kQuotaTimezone = 'Asia/Dhaka'`
// (plan 03-10). If this constant drifts from the Dart side, day-key mismatch
// causes the daily quota to reset at UTC midnight instead of Dhaka midnight
// (PITFALLS #3). The shared constant is the contract.
//
// NEVER use: new Date().toISOString().slice(0, 10)  ← UTC, NOT Dhaka.
// ALWAYS use: Intl.DateTimeFormat('en-CA', { timeZone: QUOTA_TZ })  ← Dhaka.

export const QUOTA_TZ = 'Asia/Dhaka';

/**
 * Returns the Dhaka calendar day key for [now], formatted 'YYYY-MM-DD'.
 * Used as the document ID for /users/{uid}/usage/{dayKey}.
 *
 * @example
 *   // UTC 18:00 on 2026-05-18 is Dhaka 00:00 on 2026-05-19 (UTC+6)
 *   getDhakaDateKey(new Date('2026-05-18T18:00:00.000Z'))  // → '2026-05-19'
 */
export function getDhakaDateKey(now: Date = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: QUOTA_TZ,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now);
}

/**
 * Returns the Dhaka calendar month key for [now], formatted 'YYYY-MM'.
 * Used as the document ID for /system/quota/{monthKey} (D-10).
 */
export function monthKey(now: Date = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: QUOTA_TZ,
    year: 'numeric',
    month: '2-digit',
  })
    .format(now)
    .slice(0, 7);
}
