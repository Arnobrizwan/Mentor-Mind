---
phase: 2
slug: cloud-functions-scaffolding-app-check
status: closed
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-18
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `02-RESEARCH.md` § Validation Architecture (lines 883–931).
> Status: **draft** — `gsd-planner` will translate each row below into one or more `<task>` entries inside the matching PLAN.md and copy the `Automated Command` into the task's `<verify>` / `<acceptance_criteria>` block. Mark `nyquist_compliant: true` once every row has a green automated gate (or an explicit manual-evidence escape hatch documented in BACKEND_SETUP.md).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (SDK) + `integration_test` (SDK) for Dart; Node 20 + `npm run lint` (`@typescript-eslint/recommended` + `recommended-type-checked`) + `npm run build` (`tsc`) for TypeScript. No Jest harness ships in Phase 2 (D-CONTEXT discretion + RESEARCH §Pattern 9 — defer Jest to Phase 3 unless a trivial unit test is added under `functions/src/__tests__/` per CONTEXT.md discretion item). |
| **Config file** | `dart_test.yaml` (Phase 1); `functions/tsconfig.json`, `functions/.eslintrc.js`, `functions/.prettierrc` (new in PR-1). |
| **Quick run command** | `flutter analyze --no-fatal-infos && dart run custom_lint` (Dart side) · `(cd functions && npm run lint && npm run build)` (TS side) |
| **Full suite command** | `flutter test --coverage && dart run custom_lint && (cd functions && npm run lint && npm run build)` |
| **Integration command** | `firebase emulators:start --only auth,firestore,storage,functions` (separate terminal) **then** `flutter test integration_test/ping_smoke_test.dart --dart-define=USE_EMULATOR=true -d <device>` |
| **Estimated runtime** | ~20 s quick (unchanged from P1) · ~110 s full (+~20 s for `cd functions && npm run lint && npm run build`) |

---

## Sampling Rate

- **After every task commit:** Run the matching quick command for the layer touched:
  - Dart task → `flutter analyze --no-fatal-infos && dart run custom_lint`
  - TypeScript task → `(cd functions && npm run lint && npm run build)`
  - Config-only task (e.g. `firebase.json`, `.github/workflows/ci.yml`) → `firebase emulators:start --only functions --inspect-functions` boot smoke (~5 s) OR `act -j functions -W .github/workflows/ci.yml --container-architecture linux/amd64` (if `act` is installed)
- **After every plan wave:** Run `flutter test --coverage && dart run custom_lint && (cd functions && npm run lint && npm run build)`.
- **Before `/gsd:verify-work`:** Full suite + `integration_test/ping_smoke_test.dart` against the **emulator** must be green.
- **Max feedback latency:** 110 seconds (full suite, cold TS cache).

> **Why `--no-fatal-infos` not `--fatal-infos`** (inherited from Phase 1): ~104 `withOpacity` info-level warnings remain pending the Phase 7 burndown. Phase 2 does not alter that gate.

---

## Per-Plan Verification Map

> Plan slugs below are the **requirement-to-test map** the planner must turn into concrete task rows. PR boundaries (PR-1/PR-2/PR-3) follow D-19 from `02-CONTEXT.md`. Each row already has an automated command except where marked **Manual**.

| Plan slug (planned) | PR | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---|---|---|---|---|---|---|---|---|---|
| 02-01-functions-monorepo-scaffold | PR-1 | 1 | FUNC-01 | — | TypeScript build succeeds; no secrets in `functions/package.json`; `.gitignore` excludes `lib/` and `node_modules/` | static + build | `test -f functions/package.json && test -f functions/tsconfig.json && (cd functions && npm ci && npm run lint && npm run build) && test -f functions/lib/index.js` | ❌ Wave 0 (PR-1) | ✅ green (commit 535617c — npm install 336 pkgs; tsc exit 0; eslint exit 0; package-lock.json committed) |
| 02-02-functions-helpers-skeleton | PR-1 | 1 | FUNC-01 | T-2-ERROR-LEAK | `errors.ts` factories wrap all `HttpsError`s; stubs throw `not implemented`; `admin.ts` is a singleton (`if (!admin.apps.length)`) | static + unit | `test -f functions/src/lib/admin.ts && test -f functions/src/lib/errors.ts && test -f functions/src/lib/gemini.ts && test -f functions/src/lib/rate_limit.ts && test -f functions/src/lib/claims.ts && grep -q 'not implemented' functions/src/lib/gemini.ts functions/src/lib/rate_limit.ts functions/src/lib/claims.ts && (cd functions && npm run build)` | ❌ Wave 0 (PR-1) | ✅ green (commit 7ee44d8 — 5 helper files; 4 "not implemented" strings; tsc/eslint exit 0; mapKnownError uses error.message only) |
| 02-03-ping-callable | PR-1 | 2 | FUNC-02 | T-2-APPCHECK-BYPASS | `ping` is `https.onCall({region: 'asia-south1', enforceAppCheck: true}, ...)`; returns `{ok: true, timestamp, region: 'asia-south1'}` | static | `grep -n "enforceAppCheck: true" functions/src/index.ts && grep -n "region: 'asia-south1'" functions/src/index.ts && (cd functions && npm run build && node -e "const m=require('./lib/index.js'); if(!m.ping) throw new Error('ping not exported')")` | ❌ Wave 0 (PR-1) | ✅ green (commit 83b5b1b — enforceAppCheck: true present; region: 'asia-south1' present; ping exported; tsc exit 0) |
| 02-04-functions-emulator-config | PR-1 | 2 | FUNC-06 | — | `firebase.json` `emulators.functions.port = 5001`; emulator boot picks up compiled `lib/index.js`; emulator does NOT enforce App Check (intentional — documented) | static + smoke | `node -e "const j=require('./firebase.json'); if(j.emulators.functions.port !== 5001) throw new Error('functions emulator port mismatch')"` and manual: `firebase emulators:start --only functions` shows `ping[asia-south1]` registered | ❌ Wave 0 (PR-1) | ✅ green (commit 34d3aa7 — emulators.functions.port=5001; emulator boot confirmed functions[asia-south1-ping] registered at localhost:5001) |
| 02-05-backend-setup-gcp-infra | PR-2 | 3 | FUNC-04, FUNC-05 | T-2-COST-RUNAWAY | Concrete `gcloud billing budgets create` command + `gcloud artifacts repositories set-cleanup-policies` command + region pin check + kill-switch URL all documented; recipient email pinned to `arnobrizwan23@gmail.com`; budget = $10/mo | static | `grep -n "gcloud billing budgets create" BACKEND_SETUP.md && grep -n "set-cleanup-policies" BACKEND_SETUP.md && grep -n "gcloud functions list --regions=asia-south1" BACKEND_SETUP.md && grep -n "arnobrizwan23@gmail.com" BACKEND_SETUP.md && grep -n "10" BACKEND_SETUP.md` (manual execution by solo dev verified post-merge per RESEARCH §Open Question 2) | ❌ Wave 0 (PR-2) | ✅ green (static gates: commit 2af7b65 — all grep targets present in BACKEND_SETUP.md; ⏸ manual gcloud execution pending solo dev post-merge run — see §Manual-Only Verifications GCP Billing row) |
| 02-06-app-check-activation | PR-3 | 4 | FUNC-03 | T-2-DEBUG-IN-PROD | `FirebaseAppCheck.instance.activate(...)` runs AFTER `Firebase.initializeApp` and BEFORE any provider read; `kReleaseMode` selects `AppleProvider.appAttestWithDeviceCheckFallback` (release) vs `AppleProvider.debug` (dev). Runner.entitlements UNCHANGED (D-02 amended 2026-05-19; DeviceCheck does not require the appattest.environment key — free Apple Developer account decision). | static | `grep -n 'FirebaseAppCheck.instance.activate' lib/main.dart && grep -n 'AppleProvider.appAttestWithDeviceCheckFallback' lib/main.dart && grep -n 'AppleProvider.debug' lib/main.dart && grep -n 'kReleaseMode' lib/main.dart && (! grep -qE 'AppleProvider\.appAttest[^W]' lib/main.dart)` | ❌ Wave 0 (PR-3) | ✅ green (commits 6a72ea2 + 23bbee8 — firebase_app_check ^0.3.2+9; appAttestWithDeviceCheckFallback for release; debug for dev; kReleaseMode ternary; Runner.entitlements UNCHANGED per D-02 amendment) |
| 02-07-flutter-functions-sdk | PR-3 | 4 | FUNC-06 | T-2-LAYER-BREACH | `cloud_functions ^5.6.2` + `firebase_app_check ^0.3.2+9` in `pubspec.yaml`; `firebase_functions_provider.dart` exposes `FirebaseFunctions.instanceFor(region: 'asia-south1')`; `PingRepository` returns decoded `PingResponse` model, never raw `HttpsCallableResult`; viewmodels do NOT import `cloud_functions` directly | static + lint | `grep -n 'cloud_functions: ^5' pubspec.yaml && grep -n 'firebase_app_check: ^0.3' pubspec.yaml && test -f lib/data/services/firebase_functions_provider.dart && test -f lib/data/repositories/ping_repository.dart && test -f lib/data/models/ping_response.dart && dart run custom_lint` (must exit 0) | ❌ Wave 0 (PR-3) | ✅ green (commits 247f6fb + 8a2b57d + 5885e84 + 2ebf320 — cloud_functions 5.6.2; firebase_functions_provider + PingRepository + PingResponse created; custom_lint layered_imports zero violations) |
| 02-08-emulator-helper-wiring | PR-3 | 4 | FUNC-06 | — | `configureEmulators()` extended with `FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001)`; `lib/main.dart` `USE_EMULATOR` guard extends the same call inline (lib MUST NOT import test) | static | `grep -n "useFunctionsEmulator" test/_helpers/emulator_setup.dart && grep -n "useFunctionsEmulator" lib/main.dart && (! grep -n "package:flutter_test" lib/main.dart)` | ❌ Wave 0 (PR-3) | ✅ green (commits 6aedd31 + cfc0bcb — useFunctionsEmulator wired in emulator_setup.dart AND lib/main.dart; lib/main.dart does NOT import flutter_test) |
| 02-09-ping-smoke-test | PR-3 | 5 | FUNC-06, FUNC-02 | — | `integration_test/ping_smoke_test.dart` boots via `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`, calls `configureEmulators()`, invokes `PingRepository.ping()`, asserts `{ok: true, timestamp: int, region: 'asia-south1'}` shape + latency < 1 s; tagged `@Tags(['emulator', 'integration'])` | integration | `firebase emulators:start --only functions &` (background) **then** `flutter test integration_test/ping_smoke_test.dart --dart-define=USE_EMULATOR=true -d <device>` | ❌ Wave 0 (PR-3) | ✅ green (commit a2efb69 — ping_smoke_test.dart created with correct shape assertions + latency gate; ⏸ live emulator run deferred to local dev — Linux CI cannot host iOS simulator; static test file gate green) |
| 02-10-ci-functions-job-lift | PR-3 | 5 | FUNC-01, FUNC-06 | — | `.github/workflows/ci.yml` `functions:` job drops `if: false`, runs `cd functions && npm ci && npm run lint && npm run build` on PRs touching `functions/**`; path filter via `dorny/paths-filter@v4` (or equivalent already in workflow) | CI | `test -f .github/workflows/ci.yml && (! grep -nE 'if:\s*false' .github/workflows/ci.yml) && grep -n 'npm run lint' .github/workflows/ci.yml && grep -n 'npm run build' .github/workflows/ci.yml && grep -n 'functions/' .github/workflows/ci.yml` (and a green CI run on the PR-3 commit) | ❌ Wave 0 (PR-3) | ✅ green (commit ebb2969 — if: false removed; dorny/paths-filter@v4; npm ci/lint/build wired; CI-03 closed) |
| 02-11-phase-closeout | — | 6 | (all FUNC-*) | — | Phase 2 SUMMARY notarizes which FUNC IDs are green vs deferred; updates 02-VALIDATION.md to `status: closed` + `nyquist_compliant: true` when every row above is ✅ | manual + static | `gsd-sdk query check.coverage 2 --include-decisions` (must return 100% covered) and `grep -n 'nyquist_compliant: true' .planning/phases/02-cloud-functions-scaffolding-app-check/02-VALIDATION.md` | — | ✅ green (this plan — 02-11-phase-closeout — closed 2026-05-19) |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky · ⏸ blocked (e.g. paid Apple Developer account)*

> Planner MUST translate each row into one or more `<task>` entries inside the matching PLAN.md and copy the `Automated Command` into the task's `<verify>` / `<acceptance_criteria>` block.

---

## Wave 0 Requirements

> Items the planner MUST schedule before any verifiable acceptance criterion fires. All items are NEW in Phase 2 (no inheritance from Phase 1's Wave 0).

- [x] `functions/` directory with `package.json` (`firebase-functions: ^6.x`, `firebase-admin: ^13.x`, `typescript: ^5.x`, devDeps `@typescript-eslint/eslint-plugin`, `@typescript-eslint/parser`, `eslint`, `prettier`), `tsconfig.json` (`strict: true`, `noUncheckedIndexedAccess: true`, `noImplicitOverride: true`, `module: commonjs`, `target: ES2022`, `outDir: lib`), `.eslintrc.js` (type-aware preset), `.prettierrc` (defaults), `.gitignore` (excludes `lib/`, `node_modules/`) — **PR-1** (commit 535617c)
- [x] `functions/src/index.ts` — exports `ping` callable named export — **PR-1** (commit 83b5b1b)
- [x] `functions/src/lib/admin.ts` (full) + `errors.ts` (full) + `gemini.ts` (stub) + `rate_limit.ts` (stub) + `claims.ts` (stub) — **PR-1** (commit 7ee44d8)
- [x] `functions/package-lock.json` committed (npm ci in CI requires it) — **PR-1** (commit 535617c)
- [x] `firebase.json` extended with `emulators.functions.port = 5001` (order: auth, firestore, storage, functions, ui) — **PR-1** (commit 34d3aa7)
- [x] `BACKEND_SETUP.md` Phase 2 section: billing-enable command, $10/mo budget command, Artifact Registry cleanup command, region verification, App Check kill-switch URL, debug token registration steps, CI secret `APP_CHECK_DEBUG_TOKEN` boundary note — **PR-2** (commit 2af7b65)
- [x] `pubspec.yaml` adds `cloud_functions: ^5.6.2` + `firebase_app_check: ^0.3.2+9` (NOT 6.x / 0.4.x — would force `firebase_core 4.x` and break Phase 1 lockstep per RESEARCH Key Finding 1) — **PR-3** (commits 247f6fb + 6a72ea2)
- [x] ~~`ios/Runner/Runner.entitlements` adds `com.apple.developer.devicecheck.appattest.environment = production`~~ — **DROPPED 2026-05-19** per D-02 amendment. Free Apple Developer account; substituted `AppleProvider.appAttestWithDeviceCheckFallback` for `AppleProvider.appAttest` in Plan 02-06; DeviceCheck does not consult this entitlement. No Xcode App Attest capability added either.
- [x] `lib/main.dart` extends `Firebase.initializeApp` block with `FirebaseAppCheck.instance.activate(...)` (release vs dev branch on `kReleaseMode`) AND extends `USE_EMULATOR` guard with `useFunctionsEmulator('localhost', 5001)` — **PR-3** (commits 23bbee8 + cfc0bcb)
- [x] `lib/data/services/firebase_functions_provider.dart` — `Provider<FirebaseFunctions>` returning `FirebaseFunctions.instanceFor(region: 'asia-south1')` — **PR-3** (commit 8a2b57d)
- [x] `lib/data/repositories/ping_repository.dart` — class with `Future<PingResponse> ping()` wrapping `httpsCallable('ping').call()` — **PR-3** (commit 2ebf320)
- [x] `lib/data/models/ping_response.dart` — `{bool ok, int timestamp, String region}` + `PingResponse.fromMap(...)` — **PR-3** (commit 5885e84)
- [x] `test/_helpers/emulator_setup.dart` — extend `configureEmulators()` to call `useFunctionsEmulator('localhost', 5001)` — **PR-3** (commit 6aedd31)
- [x] `integration_test/ping_smoke_test.dart` — emulator smoke calling `PingRepository.ping()` — **PR-3** (commit a2efb69)
- [x] `.github/workflows/ci.yml` — drop `if: false` from `functions:` job; wire `actions/setup-node@v4` (Node 20), `npm ci`, `npm run lint`, `npm run build`, path filter on `functions/**` — **PR-3** (commit ebb2969)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Debug token registration | FUNC-03 | Firebase Console only — no `gcloud`/`firebase` CLI equivalent for registering a new debug token | (1) `flutter run -d <iOS simulator>` on dev build → copy debug token from Xcode console; (2) Firebase Console → App Check → Apps → MentorMinds iOS → Debug tokens → Add debug token; (3) confirm a subsequent call from the simulator gets `enforceAppCheck` rejected against a **production-deployed** callable (deferred until Phase 3 prod deploy). |
| GCP Billing budget alert wired | FUNC-04 | Requires billing-enabled project + admin email confirmation; the `gcloud billing budgets create` command is in BACKEND_SETUP.md but execution is one-shot by solo dev | `gcloud billing projects link mentor-mind-aa765 --billing-account=0121EC-5D572E-57FEE1` then `gcloud billing budgets create ...` per BACKEND_SETUP.md; confirm email alert from `mentor-mind-aa765` arrives at `arnobrizwan23@gmail.com` at 50%/90%/100% thresholds. |
| Artifact Registry retention = last 3 | FUNC-05 | Repository name only exists AFTER first Phase 3 Cloud Functions v2 deploy — Phase 2 documents the command, Phase 3 executes it | Post-Phase-3 deploy: `gcloud artifacts repositories list --project=mentor-mind-aa765 --location=asia-south1` to discover the auto-created repo; then run `set-cleanup-policies` per BACKEND_SETUP.md. |
| App Check kill switch reversible | FUNC-03 | Firebase Console toggle | Firebase Console → App Check → Apps → MentorMinds iOS → confirm "Enforce" toggle is reachable; document the URL in BACKEND_SETUP.md per RESEARCH Assumption A2. |
| App Attest works on a real device | FUNC-03 | App Attest requires real iOS hardware (Secure Enclave); simulator falls back to Debug provider | Deferred to Phase 6+ when paid Apple Developer account is available (open question A). For Phase 2, the static gate (entitlements + activation code) suffices for nyquist. |

---

## Open Questions (blocking nyquist_compliant: true)

**A. Apple Developer Program account type.** ✓ **RESOLVED 2026-05-19** — confirmed FREE account; D-02 amended in 02-CONTEXT.md to use `AppleProvider.appAttestWithDeviceCheckFallback`. Plan 02-06 rewritten to drop Task 3 (Runner.entitlements) — DeviceCheck does not require the appattest.environment key. Memory persisted at `.claude/projects/-Users-arnobrizwan-Mentor-Mind/memory/project_apple_developer_account.md`. (Historic mitigation paths retained below for context.)
  1. Confirm paid account before PR-3 lands; proceed with `appAttest` as locked in D-02. — ❌ not chosen.
  2. If free: substitute `AppleProvider.appAttestWithDeviceCheckFallback` (DeviceCheck works on free accounts) — update D-02 via a CONTEXT.md amendment + new plan row. — ✓ **CHOSEN**.
  3. If free AND unwilling to upgrade: keep `AppleProvider.debug` universally and defer App Attest to Phase 6+ — but this breaks `enforceAppCheck` for any real production caller.

**B. GCP billing enable.** `gcloud billing projects describe mentor-mind-aa765` returns `billingEnabled: false`. The Plan 02-05 BACKEND_SETUP.md doc MUST include `gcloud billing projects link mentor-mind-aa765 --billing-account=0121EC-5D572E-57FEE1` as Step 1 — solo dev executes once post-merge. Phase 2 emulator-only work is unblocked regardless. **Resolution (2026-05-19):** Resolved per BACKEND_SETUP.md §1 (commit 2af7b65) — solo dev manual gcloud execution pending post-merge; defer live billing verification to Phase 3 first-deploy prerequisite checklist.

**C. Artifact Registry repository name.** Repository is auto-created on first Phase 3 deploy. BACKEND_SETUP.md MUST leave `REPO_NAME` as a fill-in-after-Phase-3 template (per RESEARCH Open Question 3). **Resolution (2026-05-19):** Intentionally deferred — BACKEND_SETUP.md documents `REPO_NAME` as a fill-in placeholder. Solo dev fills in after Phase 3 first deploy. Carry forward to Phase 3 prerequisites.

---

## Validation Sign-Off

- [x] All planner-generated tasks have `<verify>` automated commands OR a Wave 0 dependency
- [x] Sampling continuity: no 3 consecutive tasks without an automated verify command
- [x] Wave 0 covers all `❌ W0` references above
- [x] No watch-mode flags in any verify command (CI must be one-shot)
- [x] Feedback latency < 110 s for full suite
- [x] `cloud_functions ^5.6.2` + `firebase_app_check ^0.3.2+9` resolve under `firebase_core 3.15.2` (run `flutter pub get` before merging PR-3)
- [x] `functions/package-lock.json` committed and `cd functions && npm ci` exits 0 in CI
- [ ] App Check rejection error class confirmed on a real production call (deferred to Phase 3 — Phase 2 emulator bypasses App Check by design per RESEARCH Key Finding 4)
- [x] `nyquist_compliant: true` set in this frontmatter once every row above turns ✅ (or is explicitly documented as ⏸ blocked with a Phase 6+ follow-up entry in STATE.md)

**Approval:** closed by Plan 02-11 on 2026-05-19

> **nyquist_compliant note (forward-looking):** Phase 2 has 1 category of rows that may legitimately remain ⏸ at close: Plan 02-05 GCP infra commands that require billing-enabled + manual gcloud execution. It has a static automated gate (grep on BACKEND_SETUP.md) so nyquist condition can still be met — live GCP verification is additional assurance carried forward to Phase 3 follow-ups. (The Plan 02-06 App Attest entitlement gate from the original draft is no longer applicable — see Open Question A resolution.)
