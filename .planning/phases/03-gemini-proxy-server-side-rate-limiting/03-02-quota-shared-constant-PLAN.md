---
phase: 03-gemini-proxy-server-side-rate-limiting
plan: 02
type: execute
wave: 1
depends_on: ["03-01"]
files_modified:
  - functions/src/lib/quota.ts
  - functions/src/__tests__/quota.test.ts
autonomous: true
requirements: [AI-04]
pr_group: PR-1
tags: [quota_tz_shared, dhaka_date_key, monthly_key, pitfalls_3, intl_datetimeformat, ts_side]

must_haves:
  truths:
    - "D-CONTEXT specifics §`QUOTA_TZ = 'Asia/Dhaka'` honored: TS side ships in this plan; Dart side (`lib/core/constants/quota.dart`) ships in plan 03-10 — both files reference each other in a header comment so future drift is loud"
    - "PITFALLS #3 closed: `getDhakaDateKey(now)` uses `Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Dhaka' })` — NEVER `new Date().toISOString().slice(0,10)` (which is UTC)"
    - "AI-04 partially delivered: the QUOTA_TZ + day-key utility is the shared foundation; the actual transactional enforcement lands in plan 03-05; the Dart-side mirror lands in plan 03-10"
    - "Helpers are pure functions accepting `now: Date = new Date()` so unit tests pin a fixed instant — no real-time dependency in CI"
    - "Cross-instant correctness asserted: `getDhakaDateKey(new Date('2026-05-18T18:00:00.000Z'))` returns `'2026-05-19'` (UTC 18:00 = Dhaka 00:00 UTC+6 next day)"
    - "DST-safe: Dhaka observes no DST in 2026 per IANA tzdata; the Intl API would handle it anyway"
  artifacts:
    - path: "functions/src/lib/quota.ts"
      provides: "QUOTA_TZ constant + getDhakaDateKey(now) + monthKey(now) helpers"
      contains: "Asia/Dhaka"
    - path: "functions/src/__tests__/quota.test.ts"
      provides: "Unit tests covering QUOTA_TZ value, day-key cross-UTC-midnight correctness, month-key shape"
      contains: "QUOTA_TZ"
  key_links:
    - from: "functions/src/lib/quota.ts"
      to: "functions/src/lib/rate_limit.ts (plan 03-05)"
      via: "rate_limit.ts imports `getDhakaDateKey` + `monthKey` for usage doc + system quota doc keys"
      pattern: "getDhakaDateKey|monthKey"
    - from: "functions/src/lib/quota.ts header comment"
      to: "lib/core/constants/quota.dart (plan 03-10)"
      via: "MIRROR: comment explicitly names the Dart-side file"
      pattern: "lib/core/constants/quota.dart"
---

<objective>
Create `functions/src/lib/quota.ts` with the shared `QUOTA_TZ = 'Asia/Dhaka'` constant and two pure helpers: `getDhakaDateKey(now: Date)` returning `'YYYY-MM-DD'` in the Dhaka calendar, and `monthKey(now: Date)` returning `'YYYY-MM'`. Both use `Intl.DateTimeFormat('en-CA', { timeZone: QUOTA_TZ })` — never raw `toISOString().slice(...)` (PITFALLS #3). Add unit tests in `functions/src/__tests__/quota.test.ts` proving cross-UTC-midnight correctness.

Purpose: AI-04 mandates a UTC+6 day boundary for the 30-text-message / 3-image-message daily cap. The day-key is the document ID for `/users/{uid}/usage/{dateKey}`; the month-key is the doc ID for `/system/quota/{YYYY-MM}` (D-10). Both must be timezone-correct from the first call — a student at 11:55 PM Dhaka on day N must be on day-key N, not day-key N+1 (UTC tomorrow). The TS side ships here; the Dart-side mirror (`lib/core/constants/quota.dart`) ships in plan 03-10.

Output: 2 files NEW (`functions/src/lib/quota.ts`, `functions/src/__tests__/quota.test.ts`). Single commit. `npm test -- --testPathPattern=quota` exits 0.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-CONTEXT.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-RESEARCH.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-PATTERNS.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md
@functions/tsconfig.json
@functions/src/lib/admin.ts
@CLAUDE.md

<interfaces>
<!-- Patterns from 03-PATTERNS.md §functions/src/lib/quota.ts lines 49-78 + 03-RESEARCH §Pattern 7 lines 580-597 -->

functions/src/lib/quota.ts (NEW — full file, copy verbatim):

```typescript
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
```

functions/src/__tests__/quota.test.ts (NEW — full file):

```typescript
import { getDhakaDateKey, monthKey, QUOTA_TZ } from '../lib/quota';

describe('quota helpers', () => {
  it('QUOTA_TZ is the Asia/Dhaka IANA zone identifier', () => {
    expect(QUOTA_TZ).toBe('Asia/Dhaka');
  });

  describe('getDhakaDateKey', () => {
    it("returns Dhaka calendar date for a known UTC instant just before Dhaka midnight rollover", () => {
      // 2026-05-18 17:59 UTC = 2026-05-18 23:59 Dhaka — same Dhaka day
      const beforeRollover = new Date('2026-05-18T17:59:00.000Z');
      expect(getDhakaDateKey(beforeRollover)).toBe('2026-05-18');
    });

    it("returns next Dhaka calendar day right after Dhaka midnight rollover", () => {
      // 2026-05-18 18:00 UTC = 2026-05-19 00:00 Dhaka (UTC+6)
      const atRollover = new Date('2026-05-18T18:00:00.000Z');
      expect(getDhakaDateKey(atRollover)).toBe('2026-05-19');
    });

    it("does NOT use UTC date — UTC midnight is mid-day Dhaka, still same day", () => {
      // 2026-05-19 00:00 UTC = 2026-05-19 06:00 Dhaka — same Dhaka day, NOT 2026-05-18
      const atUtcMidnight = new Date('2026-05-19T00:00:00.000Z');
      expect(getDhakaDateKey(atUtcMidnight)).toBe('2026-05-19');
    });

    it('handles late-evening Dhaka time correctly (PITFALLS #3 regression)', () => {
      // 2026-05-19 17:59 UTC = 2026-05-19 23:59 Dhaka — still the same Dhaka day, not next
      const lateDhakaEvening = new Date('2026-05-19T17:59:00.000Z');
      expect(getDhakaDateKey(lateDhakaEvening)).toBe('2026-05-19');
    });
  });

  describe('monthKey', () => {
    it("returns YYYY-MM for a known instant", () => {
      const instant = new Date('2026-05-18T18:00:00.000Z');
      expect(monthKey(instant)).toBe('2026-05');
    });

    it("rolls over the month at Dhaka midnight, not UTC midnight", () => {
      // 2026-05-31 18:00 UTC = 2026-06-01 00:00 Dhaka — month rolls to June
      const monthRollover = new Date('2026-05-31T18:00:00.000Z');
      expect(monthKey(monthRollover)).toBe('2026-06');
    });
  });
});
```

Why `en-CA`:
  - The `en-CA` locale formats dates as `YYYY-MM-DD` (ISO-like) which is the exact shape Firestore document IDs need.
  - Other locales would produce `MM/DD/YYYY` or `DD/MM/YYYY` which break sortability and rule path matching.
  - Reference: MDN `Intl.DateTimeFormat` — `en-CA` is documented as ISO-style.

Why `now: Date = new Date()` (not just no-arg):
  - Tests pin a fixed instant and assert against it. If `now` were always `new Date()`, tests would be non-deterministic.
  - Production calls invoke `getDhakaDateKey()` (no arg, default `new Date()`) at the top of every callable handler.

What this plan does NOT do:
  - Does NOT add the Dart-side `lib/core/constants/quota.dart` — that's plan 03-10 (PR-3).
  - Does NOT use the helpers in any callable yet — that's plan 03-05 (rate_limit.ts) and plan 03-06 (mentorBotChat handler).
  - Does NOT change `tsconfig.json` or `package.json` (Jest is already in place from plan 03-01).
  - Does NOT add a `Timestamp.now()` helper — `admin.firestore.Timestamp.now()` is used directly in plan 03-05.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Create functions/src/lib/quota.ts with QUOTA_TZ + getDhakaDateKey + monthKey; add functions/src/__tests__/quota.test.ts; npm test green</name>
  <files>functions/src/lib/quota.ts, functions/src/__tests__/quota.test.ts</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-RESEARCH.md (§Pattern 7 lines 580-597 — TS helper shape; §Pitfall P-3 lines 664-668 — UTC vs Dhaka day-key bug)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-PATTERNS.md (§functions/src/lib/quota.ts lines 49-78 — full file skeleton)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-CONTEXT.md (§Specifics — QUOTA_TZ mirror contract)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md (row `03-02-quota-shared-constant` line 55 — Automated Command verbatim)
    - /Users/arnobrizwan/Mentor-Mind/functions/tsconfig.json (confirm `strict: true` + `outDir: lib` — ts-jest uses this same config)
  </read_first>
  <behavior>
    - QUOTA_TZ exports the literal string `'Asia/Dhaka'`.
    - getDhakaDateKey(new Date('2026-05-18T18:00:00.000Z')) → '2026-05-19'.
    - getDhakaDateKey(new Date('2026-05-18T17:59:00.000Z')) → '2026-05-18'.
    - getDhakaDateKey(new Date('2026-05-19T00:00:00.000Z')) → '2026-05-19'.
    - getDhakaDateKey(new Date('2026-05-19T17:59:00.000Z')) → '2026-05-19'.
    - monthKey(new Date('2026-05-18T18:00:00.000Z')) → '2026-05'.
    - monthKey(new Date('2026-05-31T18:00:00.000Z')) → '2026-06'.
  </behavior>
  <action>
    Step A — TDD RED: Create `functions/src/__tests__/quota.test.ts` with the exact content from the `<interfaces>` block. Imports `getDhakaDateKey`, `monthKey`, `QUOTA_TZ` from `'../lib/quota'` (the module doesn't exist yet — TS compile + Jest will both fail).
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind/functions
      npm test -- --testPathPattern=quota 2>&1 | tee /tmp/p3-02-red.log
      # Expect: Cannot find module '../lib/quota' OR ENOENT — RED phase confirmed.
      ```

    Step B — TDD GREEN: Create `functions/src/lib/quota.ts` with the exact content from the `<interfaces>` block. Three exports: `QUOTA_TZ` constant, `getDhakaDateKey(now)` function, `monthKey(now)` function. The header comment names the Dart-side mirror file explicitly.

    Step C — Run unit tests:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind/functions
      npm test -- --testPathPattern=quota 2>&1 | tee /tmp/p3-02-green.log
      # Expect: 7 passed, 7 total (1 QUOTA_TZ + 4 getDhakaDateKey + 2 monthKey)
      ```

    Step D — Run full TS quick gate to confirm no regression in plan 03-01's bootstrap:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind/functions
      npm run lint 2>&1 | tail -5  # exits 0
      npm run build 2>&1 | tail -5  # exits 0 — confirms quota.ts compiles cleanly
      ```
      If `npm run lint` fires on `quota.ts` (e.g. unused-vars on the `_now` shorthand, or `prefer-const`), fix per project ESLint config and retest.

    Step E — Anti-pattern grep (Pitfall P-3 regression gate):
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      ! grep -rE 'toISOString\(\)\.slice|toIsoString\(\)\.substring' functions/src/
      # The grep MUST find nothing — Phase 3 forbids the UTC day-key pattern anywhere in TS source.
      ```

    Step F — Commit:
      `git add functions/src/lib/quota.ts functions/src/__tests__/quota.test.ts`
      Commit message: `feat(functions): add QUOTA_TZ + Dhaka date/month-key helpers (Phase 3 PR-1; AI-04 / PITFALLS #3)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && test -f functions/src/lib/quota.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && test -f functions/src/__tests__/quota.test.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && grep -q "'Asia/Dhaka'" functions/src/lib/quota.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && grep -q "Intl.DateTimeFormat" functions/src/lib/quota.ts && grep -q "'en-CA'" functions/src/lib/quota.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && grep -q "export const QUOTA_TZ" functions/src/lib/quota.ts && grep -q "export function getDhakaDateKey" functions/src/lib/quota.ts && grep -q "export function monthKey" functions/src/lib/quota.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && ! grep -rE 'toISOString\(\)\.slice|toIso8601String\(\)\.substring' functions/src/</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && grep -q "MIRROR.*lib/core/constants/quota.dart" functions/src/lib/quota.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions && npm test -- --testPathPattern=quota 2>&1 | tee /tmp/p3-02-final.log | grep -qE 'Tests:\s+7 passed,\s+7 total|7 passed'</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions && npm run lint 2>&1 | tail -3; test $? -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions && npm run build 2>&1 | tail -3; test $? -eq 0</automated>
  </verify>
  <acceptance_criteria>
    - functions/src/lib/quota.ts exists with exports: QUOTA_TZ, getDhakaDateKey(now), monthKey(now).
    - functions/src/__tests__/quota.test.ts exists with 7 test cases.
    - All 7 tests pass under `npm test -- --testPathPattern=quota`.
    - `Intl.DateTimeFormat` + `'Asia/Dhaka'` + `'en-CA'` literals all present.
    - The header comment names `lib/core/constants/quota.dart` (the planned Dart mirror — plan 03-10).
    - Zero hits in `grep -rE 'toISOString().slice|toIso8601String().substring' functions/src/` (PITFALLS #3 regression gate).
    - npm run lint + npm run build both exit 0.
  </acceptance_criteria>
  <done>
    The TS-side QUOTA_TZ + day-key + month-key helpers are committed. Plan 03-05 (rate_limit.ts) and plan 03-06 (mentorBotChat handler) can now import them. Plan 03-10 will mirror the constant on the Dart side.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| quota.ts ⇄ rate_limit.ts | rate_limit.ts (plan 03-05) imports `getDhakaDateKey` + `monthKey`; the doc-ID contract is the boundary. Drift in helper output = orphaned usage docs. |
| TS quota.ts ⇄ Dart quota.dart | Two languages, same constant. The header comment cross-references; if they drift, client-side display quota count and server-side enforcement disagree. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-3-02-UTC-DAY-KEY-REGRESSION | Tampering | A future contributor "simplifies" `getDhakaDateKey` to `new Date().toISOString().slice(0,10)` for performance; production quota resets at UTC midnight (6 hours early for Dhaka users) | mitigate | Verify gate runs `! grep -rE 'toISOString\(\)\.slice' functions/src/` on every commit. Plan 03-15 closeout re-runs the gate. The 7-test suite is the second backstop — anyone changing the helper without updating tests fails CI. |
| T-3-02-TZ-DRIFT | Tampering | Dart-side (plan 03-10) ships with `Asia/Dacca` (legacy IANA alias) or a hardcoded `Duration(hours: 6)` (no DST awareness — coincidentally correct for Dhaka but fragile) | mitigate | TS file header explicitly names the Dart mirror path. Plan 03-10's verify gate greps for `'Asia/Dhaka'` (exact string) in `lib/core/constants/quota.dart`. |
| T-3-02-LOCALE-DRIFT | Tampering | A code-formatter or "code-quality" rewrite changes `'en-CA'` to `'en-US'`; output flips from `2026-05-19` to `5/19/2026` and breaks Firestore document IDs | mitigate | The 7-test suite asserts the exact `YYYY-MM-DD` shape; an `'en-US'` regression returns `5/19/2026` which fails `expect(...).toBe('2026-05-19')`. |
| T-3-02-LIB-IMPORT-CYCLE | Tampering | A future contributor imports `gemini.ts` or `rate_limit.ts` from `quota.ts`, creating a circular module graph | accept | `quota.ts` has zero imports (only `Intl` global). The file is leaf-level by design; circular dep would be a TS compile error. |
</threat_model>

<verification>
- functions/src/lib/quota.ts exists with the three exports.
- functions/src/__tests__/quota.test.ts has 7 tests, all green.
- `'Asia/Dhaka'` + `Intl.DateTimeFormat` + `'en-CA'` literals present.
- Header comment cross-references the Dart-side mirror file.
- No `toISOString().slice` anywhere in functions/src/.
- npm lint + build green.
</verification>

<success_criteria>
- AI-04 day-boundary primitive shipped on the TS side.
- PITFALLS #3 regression gate active (grep + test backstop).
- Plan 03-05 (rate_limit) and plan 03-06 (callable handler) can import `getDhakaDateKey` + `monthKey`.
- Plan 03-10 will mirror the constant on the Dart side using the header-comment contract.
</success_criteria>

<output>
Create `.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-02-quota-shared-constant-SUMMARY.md` when done. Record:
1. Final functions/src/lib/quota.ts content.
2. Final functions/src/__tests__/quota.test.ts content + jest output (7/7 pass).
3. Lint + build exit codes.
4. Anti-pattern grep output (`grep -rE 'toISOString().slice' functions/src/` — empty).
5. Commit SHA.
6. Forward-pointer: plan 03-05 imports `getDhakaDateKey` + `monthKey`; plan 03-10 mirrors on the Dart side.
</output>
</content>
</invoke>