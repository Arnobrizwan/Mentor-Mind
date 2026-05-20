---
plan: 03-09
phase: 03-gemini-proxy-server-side-rate-limiting
status: complete
requirements: [AI-08]
decisions: [D-17]
date: 2026-05-20
---

# Plan 03-09 — Firestore Rules Lockdown (AI-08, D-17)

## Outcome

- `firestore.rules` extended with two locks (15 net lines added):
  - `/users/{uid}/usage/{dateKey}` — was `allow read, write: if isOwner(uid) || isAdmin()`; now `allow read: if isOwner(uid)` + `allow write: if false`. Admin SDK writes via `functions/src/lib/rate_limit.ts` (Admin SDK bypasses rules).
  - `/system/{document=**}` (NEW) — `allow read, write: if false`. Covers `/system/quota_{YYYY-MM}` (plan 03-05) and `/system/usage_log_{YYYY-MM-DD}` (plan 03-07). Clients never touch these docs.
- Session subcollection lockdown intentionally deferred to Phase 4 (D-17).
- `functions/src/__tests__/rules.test.ts` — 7 rules-unit tests, all passing against the Firestore emulator (via `@firebase/rules-unit-testing@5.0.1`).
- `functions/package.json` — added `firebase@^12.13.0` to devDependencies (rules.test.ts imports the modular `firebase/firestore` client SDK).

## Verification (local emulator — no live deploy)

```
firebase emulators:exec --only firestore --project mentor-mind-aa765-rules-test \
  "cd functions && FIRESTORE_EMULATOR_HOST=localhost:8080 npm test -- --testPathPattern=rules"
```

Result:
```
PASS src/__tests__/rules.test.ts
  AI-08: /users/{uid}/usage/{date} client access (D-17)
    ✓ 1. Owner CAN read their own usage doc (327 ms)
    ✓ 2. Owner CANNOT write to their own usage doc (admin-only) (28 ms)
    ✓ 3. Other user CANNOT read alice usage doc (33 ms)
  AI-08: /system/quota_* client access (D-17)
    ✓ 4. Client CANNOT read /system/quota_2026-05 (36 ms)
    ✓ 5. Client CANNOT write /system/quota_2026-05 (17 ms)
  AI-08: /system/usage_log_* client access (D-17)
    ✓ 6. Client CANNOT read /system/usage_log_2026-05-19 (28 ms)
    ✓ 7. Client CANNOT write /system/usage_log_2026-05-19 (18 ms)

Test Suites: 1 passed, 1 total
Tests:       7 passed, 7 total
```

Full suite (35/35): `quota.test.ts` 7 + `gemini.test.ts` 8 + `rate_limit.test.ts` 13 + `rules.test.ts` 7. Build + lint clean.

## Files changed

- `firestore.rules` (+15 lines, -1 line)
- `functions/src/__tests__/rules.test.ts` (NEW, 132 lines)
- `functions/package.json` (+1 dep: `firebase@^12.13.0`)
- `functions/package-lock.json` (regenerated)

## Deviations / notes

- **Original executor agent died on a 401 mid-flight.** It had written the firestore.rules diff and rules.test.ts but had not yet committed, run the tests, or written this SUMMARY. The orchestrator salvaged both files from the orphan worktree (`/Users/arnobrizwan/Mentor-Mind/.claude/worktrees/agent-af1a6f86631ba7ba3`) before tearing it down, then added the missing `firebase` devDep, ran the rules tests under `firebase emulators:exec`, and committed.
- **Firestore emulator UI port :4000 conflict** — switched from `emulators:start` to `emulators:exec` which runs the test command then shuts the emulator down (UI never starts). Standard practice for one-shot rules-unit suites.
- **`firebase deploy --only firestore:rules` deliberately NOT run** — GCP billing is disabled on `mentor-mind-aa765`. Rules text lands in `firestore.rules`; deployment is a Phase 3 closeout-time human action documented in BACKEND_SETUP.md.
- Plan 03-01 listed `@firebase/rules-unit-testing@^5.0.1` but did not also pin the matching `firebase` client SDK. Adding it as a 03-09 dep keeps the rules suite self-contained.

## kluster.ai

⚠️ Your kluster.ai trial has ended. You can visit https://platform.kluster.ai/ to select a plan, subscribe, and re-enable protection.

The orchestrator ran `kluster_dependency_check` on the new `firebase` devDep — the response confirmed trial expiration and returned no findings. The four other devDeps added in plan 03-01 were already pre-verified in 03-RESEARCH §Package Legitimacy Audit.

## Next plan

03-10 (Dart-side `uuid` + quota mirror). 03-04 (live Vertex probe) and 03-15 (closeout) remain pending the GCP billing reopen.
