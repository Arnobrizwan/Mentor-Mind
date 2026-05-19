---
phase: 03-gemini-proxy-server-side-rate-limiting
plan: "02"
subsystem: functions/quota
tags: [quota_tz_shared, dhaka_date_key, monthly_key, pitfalls_3, intl_datetimeformat, ts_side, tdd]
requires: ["03-01"]
provides: ["03-05", "03-06", "03-10"]
affects: []
tech_stack_added: []
tech_stack_patterns: [tdd, pure-functions, intl-datetimeformat]
key_files_created:
  - functions/src/lib/quota.ts
  - functions/src/__tests__/quota.test.ts
key_files_modified: []
decisions:
  - "Used Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Dhaka' }) — ISO-style YYYY-MM-DD format, timezone-correct, DST-safe"
  - "Header comment cross-references Dart-side mirror (lib/core/constants/quota.dart, plan 03-10) to prevent silent drift"
  - "now: Date = new Date() default parameter makes helpers pure and deterministically testable"
metrics:
  completed_date: "2026-05-19"
  tasks_completed: 1
  tasks_total: 1
  files_created: 2
  files_modified: 0
---

# Phase 3 Plan 02: Quota Shared Constant Summary

**One-liner:** TypeScript-side QUOTA_TZ='Asia/Dhaka' constant + getDhakaDateKey/monthKey pure helpers using Intl.DateTimeFormat('en-CA') with 7 TDD unit tests proving UTC+6 day-boundary correctness (PITFALLS #3 closed).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create quota.ts (QUOTA_TZ + helpers) + quota.test.ts (TDD RED→GREEN) | 70c340d | functions/src/lib/quota.ts, functions/src/__tests__/quota.test.ts |

## Implementation

### functions/src/lib/quota.ts

Three exports:
- `QUOTA_TZ = 'Asia/Dhaka'` — shared IANA timezone constant; mirrors `kQuotaTimezone` in Dart (plan 03-10)
- `getDhakaDateKey(now: Date = new Date()): string` — returns `'YYYY-MM-DD'` in Dhaka calendar; used as `/users/{uid}/usage/{dayKey}` document ID
- `monthKey(now: Date = new Date()): string` — returns `'YYYY-MM'` in Dhaka calendar; used as `/system/quota/{monthKey}` document ID

Header comment explicitly names the Dart-side mirror file (`lib/core/constants/quota.dart`) and documents the forbidden UTC pattern.

### functions/src/__tests__/quota.test.ts

7 tests across 3 describe blocks:
1. `QUOTA_TZ is the Asia/Dhaka IANA zone identifier`
2. `getDhakaDateKey` — before Dhaka midnight rollover → same day
3. `getDhakaDateKey` — at Dhaka midnight (UTC 18:00) → next day
4. `getDhakaDateKey` — UTC midnight is mid-day Dhaka → same day (proves no UTC coupling)
5. `getDhakaDateKey` — late Dhaka evening (23:59) → same day (PITFALLS #3 regression)
6. `monthKey` — returns YYYY-MM for known instant
7. `monthKey` — month rollover at Dhaka midnight (2026-05-31T18:00:00Z → '2026-06')

## Verification Evidence

### npm test (quota pattern) — 7/7 PASS

```
PASS src/__tests__/quota.test.ts
  quota helpers
    ✓ QUOTA_TZ is the Asia/Dhaka IANA zone identifier (1 ms)
    getDhakaDateKey
      ✓ returns Dhaka calendar date for a known UTC instant just before Dhaka midnight rollover (25 ms)
      ✓ returns next Dhaka calendar day right after Dhaka midnight rollover
      ✓ does NOT use UTC date — UTC midnight is mid-day Dhaka, still same day
      ✓ handles late-evening Dhaka time correctly (PITFALLS #3 regression)
    monthKey
      ✓ returns YYYY-MM for a known instant (1 ms)
      ✓ rolls over the month at Dhaka midnight, not UTC midnight

Test Suites: 1 passed, 1 total
Tests:       7 passed, 7 total
```

### npm run lint — exit 0

No lint errors. ESLint --ext .ts src/ produced no output.

### npm run build — exit 0

TypeScript compilation (strict: true, noImplicitReturns, noUnusedLocals) produced no errors.

### Anti-pattern grep (PITFALLS #3 gate)

```
grep -rE 'toISOString\(\)\.slice|toIso8601String\(\)\.substring' functions/src/
→ functions/src/lib/quota.ts:// NEVER use: new Date().toISOString().slice(0, 10)  ← UTC, NOT Dhaka.
```

The only match is the warning comment in quota.ts that documents the forbidden pattern. No functional code uses the UTC day-key anti-pattern. The comment is prescribed verbatim by the plan's `<interfaces>` block and serves as the in-code warning. All production calls use `Intl.DateTimeFormat('en-CA', { timeZone: QUOTA_TZ })`.

## TDD Gate Compliance

- RED gate: `test(...): quota.test.ts` written first → `Cannot find module '../lib/quota'` confirmed fail
- GREEN gate: `feat(functions): add QUOTA_TZ + Dhaka date/month-key helpers` commit → 7/7 tests pass
- REFACTOR gate: not needed (code already clean per interfaces spec)

## Deviations from Plan

None — plan executed exactly as written.

The anti-pattern grep finding in the comment line is expected behavior: the plan prescribes both the NEVER-use comment (verbatim in `<interfaces>`) and the grep gate. The comment is documentation, not functional code. No actual usage of `toISOString().slice(...)` exists in production code paths.

## Known Stubs

None. This plan delivers pure utility functions with no UI or data-source stubs.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. `quota.ts` is a leaf module (zero imports, only `Intl` global) with no external surface.

## Forward Pointers

- **Plan 03-05** (rate_limit.ts): imports `getDhakaDateKey` + `monthKey` for `/users/{uid}/usage/{dayKey}` and `/system/quota/{YYYY-MM}` document IDs in the transactional quota enforcement
- **Plan 03-06** (mentorBotChat callable): calls `getDhakaDateKey()` at handler top to get the current day key
- **Plan 03-10** (Dart-side mirror): creates `lib/core/constants/quota.dart` with `kQuotaTimezone = 'Asia/Dhaka'` — the header comment contract is in place

## kluster.ai Note

⚠️ Your kluster.ai trial has ended. You can visit https://platform.kluster.ai/ to select a plan, subscribe, and re-enable protection. Code review was skipped per orchestrator instruction; verification relied on TDD (7/7 pass), npm run lint (exit 0), and npm run build (exit 0).

## Self-Check: PASSED

- functions/src/lib/quota.ts: FOUND
- functions/src/__tests__/quota.test.ts: FOUND
- Commit 70c340d: FOUND (git log confirms)
- 7/7 tests: PASS
- lint: exit 0
- build: exit 0
