# Phase 2: Cloud Functions Scaffolding + App Check - Context

**Gathered:** 2026-05-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Stand up the `functions/` TypeScript monorepo at the repo root (Node 20, `firebase-functions ^6.x` v2 API), deploy a no-op `ping` callable in `asia-south1` with day-1 hard `enforceAppCheck: true`, wire App Check end-to-end (App Attest provider on iOS 14+ release builds, Debug provider on dev/CI), provision day-zero GCP guardrails (`$10/mo` billing alert + Artifact Registry retention = last 3), and wire `cloud_functions ^5.x` Flutter SDK through `lib/data/services/` with a "call ping" smoke test against the Firebase Functions Emulator (newly added to firebase.json).

**Proves the plumbing GREEN before any real callable lands** — the ping endpoint is a deliberate canary so that an App Check misconfiguration in Phase 3 (Gemini proxy) doesn't manifest as "the AI tutor is down" but as "the ping smoke test is red."

**Requirements covered:** FUNC-01, FUNC-02, FUNC-03, FUNC-04, FUNC-05, FUNC-06.
**Depends on:** Phase 1 (iOS 14.2 deployment target unlocks App Attest; layered architecture provides the `lib/data/services/` insertion point for the Functions SDK wrapper).

</domain>

<decisions>
## Implementation Decisions

### App Check enforcement (FUNC-02, FUNC-03)

- **D-01:** **Day-1 hard enforcement.** `ping` callable ships with `enforceAppCheck: true` from PR-merge (no soft-launch period). Per PITFALLS #1 and ROADMAP rationale: a no-op endpoint is the deliberate canary that proves enforcement works before the Gemini proxy in Phase 3 depends on it. The risk surface (a dev simulator without a registered debug token sees `permission-denied` on a no-op endpoint) is manageable and forces the team to register debug tokens correctly from day one rather than discovering the gap when a real callable matters.
- **D-02:** **App Attest provider** on iOS 14+ release builds (unlocked by Phase 1's iOS 14.2 deployment-target bump — ARCH-05). **Debug provider** on dev simulators + CI. Provider selection lives in `main.dart` immediately after `Firebase.initializeApp(...)` and BEFORE any provider/repository reads — wired via `FirebaseAppCheck.instance.activate(...)`. Release vs dev branch via `kReleaseMode` (Flutter constant).

### Functions monorepo shape (FUNC-01, FUNC-06)

- **D-03:** **TypeScript Node 20** runtime (per ROADMAP non-negotiable; matches `firebase-functions ^6.x` v2 API min). `functions/package.json` pins `firebase-functions: ^6.x`, `firebase-admin: ^13.x`, `typescript: ^5.x`. Lint: `eslint` + `@typescript-eslint` (recommended preset; no custom rules); format: `prettier` defaults.
- **D-04:** **CommonJS output** (`tsconfig.json` `"module": "commonjs"`, `"target": "ES2022"`). ESM is technically supported by firebase-functions v6 but the docs + community examples assume CJS — staying on the well-trodden path avoids late-stage deploy-time surprises.
- **D-05:** **All 5 helper files** ship in Phase 2 under `functions/src/lib/`, but only `admin.ts` and `errors.ts` are fully implemented:
  - `admin.ts` — `firebase-admin` SDK init (`initializeApp()`, singleton export). Fully implemented.
  - `errors.ts` — `HttpsError` factory wrappers (`unauthenticated(msg)`, `permissionDenied(msg)`, `failedPrecondition(msg)`, etc.) + a `mapKnownError(error)` helper that translates Firestore / Auth / Storage SDK errors into appropriate HttpsError codes. Fully implemented.
  - `gemini.ts` — TypeScript interface stub (`callGemini(prompt: string, opts?: GeminiCallOptions): Promise<GeminiResponse>`) + `throw new Error('not implemented — see Phase 3')`. Stable import contract for Phase 3.
  - `rate_limit.ts` — TypeScript interface stub for the transactional UTC+6 daily counter (`checkAndIncrement(uid: string, kind: 'text' | 'image'): Promise<RateLimitResult>`) + throws. Stable for Phase 3.
  - `claims.ts` — TypeScript interface stub for custom-claim helpers (`setPremium(uid: string, isPremium: boolean): Promise<void>`, `getRole(uid: string): Promise<UserRole>`) + throws. Stable for Phase 5.
- **D-06:** **Single deployable function in Phase 2: `ping`.** Region `asia-south1`. Returns `{ ok: true, timestamp: <server-time-ms> }`. Implementation: 5–10 LOC. No `minInstances`, no `memory` override (defaults are fine for a no-op).
- **D-07:** **No `cors`, `cookies`, or HTTP-style routing.** `ping` is a `onCall` callable (firebase-functions v2 `https.onCall`), not `onRequest`. App Check enforcement only attaches to `onCall` callables — `onRequest` would require manual header verification, which is out of scope.

### Debug token lifecycle (FUNC-03)

- **D-08:** **Per-developer simulator tokens** + **single shared CI token**.
  - Each developer registers their simulator's debug token via Firebase Console → App Check → Apps → MentorMinds iOS → Debug tokens → "Add debug token". The token is printed in Xcode console on first launch of a dev build; copy-paste into Console.
  - CI uses a single shared `APP_CHECK_DEBUG_TOKEN` GitHub Actions secret (also registered in Firebase Console). Loaded into the Flutter test process via `--dart-define=APP_CHECK_DEBUG_TOKEN=$SECRET` and consumed by `FirebaseAppCheck.instance.activate(appleProvider: AppleProvider.debug, ...)`.
- **D-09:** **Rotation cadence**: dev tokens never auto-expire (Firebase doesn't enforce expiry) — devs manage their own. CI token manually rotated **quarterly** (calendar reminder); rotation procedure documented in BACKEND_SETUP.md. **Revocation procedure**: any token can be removed instantly from the Firebase Console → App Check → Apps → MentorMinds iOS → Debug tokens screen.
- **D-10:** **Documentation**: every debug token registration step lives in `BACKEND_SETUP.md` under a new "Phase 2 — App Check Debug Tokens" section, with screenshots for the Firebase Console flow + the exact Xcode console log line to copy.

### CI integration (FUNC-04, FUNC-06)

- **D-11:** **Phase 1 integration test stays untouched.** The existing `integration_test/login_smoke_test.dart` exercises Auth + Firestore + Storage emulators which DO NOT enforce App Check. No need to wire the debug token into that test.
- **D-12:** **New Phase 2 integration test: `integration_test/ping_smoke_test.dart`.** Calls the `ping` callable through the Functions emulator (which also doesn't enforce App Check by default). Asserts: response shape `{ok: true, timestamp: number}`, latency < 1s. Tagged `emulator` + `integration` (same as Phase 1 login smoke).
- **D-13:** **CI secret name: `APP_CHECK_DEBUG_TOKEN`** (capital, underscores). Stored in GitHub Actions repository secrets. NOT used by Phase 2's emulator integration test (emulator bypasses App Check); reserved for Phase 3+ when CI calls real-Firebase enforcement paths. Phase 2 ships the secret + env var plumbing so Phase 3 has zero CI setup overhead.

### GCP infra delivery (FUNC-05)

- **D-14:** **`gcloud` CLI commands documented in `BACKEND_SETUP.md`**, not Terraform. Solo dev shipping v1.0; Terraform IaC is overkill until there are multiple environments. The commands are idempotent (re-running them is a no-op if state matches).
- **D-15:** **Billing alert recipient: `arnobrizwan23@gmail.com`** (admin email). $10/mo budget with alert thresholds at 50% / 90% / 100%. Concrete `gcloud billing budgets create` command in BACKEND_SETUP.md. The alert is for the **`mentor-mind-aa765`** project specifically (not org-wide).
- **D-16:** **Artifact Registry retention = last 3 versions per image**, via `gcloud artifacts repositories set-cleanup-policies` against the project's default `gcr.io` repository. Older images auto-deleted. Concrete command in BACKEND_SETUP.md. Cost rationale: `minInstances: 1` defaulted costs ~$25/mo at zero traffic — combined with image bloat, naive deploys leak money fast.
- **D-17:** **Region pin verification**: BACKEND_SETUP.md includes a `gcloud functions list --regions=asia-south1` check + a "DO NOT" warning against `us-central1`. `asia-south1` is non-negotiable for Bangladesh users (per ROADMAP rationale); cross-region latency would degrade the "useful answer in <10s" core value promise.

### Functions emulator wiring + PR sequencing (FUNC-06)

- **D-18:** **Functions emulator activated in Phase 2.** `firebase.json` emulators block extends to add `functions: { port: 5001 }`. `test/_helpers/emulator_setup.dart` `configureEmulators()` extends to add `FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001)`. `lib/main.dart`'s `--dart-define=USE_EMULATOR=true` branch also extends with the same wiring (inline; lib MUST NOT import test).
- **D-19:** **PR sequencing — 3 PRs**, matching Phase 1's pattern:
  - **PR-1 — functions/ monorepo + ping callable**: `functions/package.json`, `functions/tsconfig.json`, `functions/src/index.ts` exporting `ping`, all 5 helper files (admin/errors fully + 3 stubs), `functions/.eslintrc.js` + `.prettierrc`, `functions/.gitignore` (excludes `lib/`, `node_modules/`). Includes deploying `ping` to the Functions emulator and confirming it returns `{ok: true, ...}` from a manual `curl` against the emulator URL. NO App Check wiring yet.
  - **PR-2 — GCP infra**: `BACKEND_SETUP.md` updated with the `gcloud billing budgets create` + `gcloud artifacts repositories set-cleanup-policies` + region verification commands. Solo dev runs them once; this PR is doc-only (no code) but matters because it locks the day-zero guardrails before any real callable launches.
  - **PR-3 — App Check end-to-end**: server-side `enforceAppCheck: true` added to `ping` (`https.onCall({enforceAppCheck: true}, ...)`); client-side `FirebaseAppCheck.activate(...)` in `lib/main.dart`; new `lib/data/services/firebase_functions_provider.dart` exposing `FirebaseFunctions.instance`; new `lib/data/repositories/ping_repository.dart` wrapping the `ping` callable (matches Phase 1's repository pattern); debug token registration documented in BACKEND_SETUP.md; CI secret `APP_CHECK_DEBUG_TOKEN` documented; functions emulator added to `firebase.json` + `configureEmulators()`; new `integration_test/ping_smoke_test.dart` exercises the round trip.

### Phase 2's NO-GOs (explicit non-scope)

- **D-20:** **NO Gemini code.** `gemini.ts` is a stub; no actual Gemini SDK install in `functions/package.json`; no API key handling. Phase 3 owns all Gemini work.
- **D-21:** **NO server-side rate limiting.** `rate_limit.ts` is a stub. Phase 3 implements the transactional UTC+6 counter.
- **D-22:** **NO custom claims wiring.** `claims.ts` is a stub. Phase 5 implements `setPremium` callable + claims-based gating.
- **D-23:** **NO production deploy of `ping`.** Phase 2 deploys `ping` only to the Functions emulator. Production deploy (`firebase deploy --only functions:ping`) is deferred to Phase 3 alongside the real `mentorBotChat` callable to amortize deploy cost + Artifact Registry bloat.
- **D-24:** **NO Phase 1 integration test changes.** The existing `login_smoke_test` continues to exercise Auth + Firestore + Storage emulators only.

### Claude's Discretion

- Specific TypeScript style choices beyond the lint preset (semi-colons, single vs double quotes, trailing commas) — pick prettier defaults; document the choice in `functions/.prettierrc` so it's auto-enforced.
- Exact directory layout under `functions/src/` (e.g. `src/index.ts` vs `src/main.ts` vs `src/callables/`) — pick the firebase-functions v6 convention (`src/index.ts` exports each callable as a named export).
- TypeScript `tsconfig.json` strict-mode flags — turn on `strict: true`, `noUncheckedIndexedAccess: true`, `noImplicitOverride: true`. Catches the long tail of TS footguns at compile time.
- The `ping` callable's response shape beyond `{ ok: true, timestamp: number }` — fine to add `region: 'asia-south1'` for sanity-check observability.
- Whether to add a `functions/src/__tests__/` directory in PR-1 — yes, with one trivial unit test exercising `errors.ts` (`mapKnownError(new Error('foo'))` returns the default HttpsError). Proves the test harness works.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner) MUST read these before planning or implementing.**

### Phase scope + traceability
- `.planning/ROADMAP.md` §"Phase 2: Cloud Functions Scaffolding + App Check" — phase goal, success criteria (5 items), non-negotiables (PITFALLS #1 + #8), rationale (asia-south1, App Attest on iOS 14+, billing day-zero)
- `.planning/REQUIREMENTS.md` §Cloud Functions & App Check (FUNC-01..FUNC-06)
- `.planning/PROJECT.md` §Constraints — locks: Firebase backend (no self-hosted); Flutter 3.41 / Dart 3.11; iOS-only v1.0

### Phase 1 baseline (downstream MUST honor)
- `.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-CONTEXT.md` — Phase 1 decisions D-01..D-16, especially:
  - D-01..D-04 (repository pattern + Riverpod providers — Phase 2's `PingRepository` follows this)
  - D-05..D-07 (no codegen / no DI containers — Phase 2 TypeScript code has no parallel constraint, but the Flutter side stays vanilla)
  - D-10 (emulator scope was Auth+Firestore+Storage in Phase 1; Phase 2 extends to add Functions emulator per D-18 here)
  - D-15 (iOS 14.2 deployment target — required for App Attest per D-02 here)
- `.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md` — Nyquist-compliant verification map; Phase 2's verification follows the same pattern (one row per requirement with automated command)
- `.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-09-emulator-integration-smoke-SUMMARY.md` — `configureEmulators()` helper shape + dart_test.yaml emulator/integration tags pattern
- `.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-10-github-actions-ci-SUMMARY.md` — CI workflow shape; Phase 2 adds the `functions/**` job (currently a no-op stub at `.github/workflows/ci.yml`'s `functions:` job per Plan 01-10's deferral)

### Firebase + App Check official docs (researcher: fetch via WebFetch in research phase)
- https://firebase.google.com/docs/app-check/flutter/default-providers — App Attest + Debug provider setup
- https://firebase.google.com/docs/app-check/flutter/debug-provider — Debug token registration flow
- https://firebase.google.com/docs/functions/callable?gen=2nd — v2 callable API, `enforceAppCheck` option
- https://firebase.google.com/docs/emulator-suite/connect_functions — Functions emulator setup
- https://firebase.google.com/docs/app-check/cloud-functions — server-side enforcement details

### GCP infra
- https://cloud.google.com/billing/docs/how-to/budgets#gcloud — `gcloud billing budgets create` reference
- https://cloud.google.com/artifact-registry/docs/repositories/cleanup-policy — Artifact Registry cleanup policy reference

### Phase 3+ forward-pointers (NOT to be implemented in Phase 2)
- Phase 3 PLAN (TBD) — will fill `gemini.ts` + `rate_limit.ts` stubs from D-05
- Phase 5 PLAN (TBD) — will fill `claims.ts` stub from D-05

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/data/services/firebase_providers.dart` (Plan 01-05) — pattern for new `firebase_functions_provider.dart` to follow. Single `Provider<FirebaseFunctions>` exposed for test override via `ProviderScope.overrides`.
- `lib/data/repositories/users_repository.dart` (Plan 01-05) — pattern for `PingRepository` to follow. Class constructor takes the SDK provider via `ref.read`; methods take primitive args and return domain models (here: `Future<PingResponse>` decoded from the callable's raw `HttpsCallableResult`).
- `test/_helpers/emulator_setup.dart` (Plan 01-09) — extend `configureEmulators()` with `useFunctionsEmulator('localhost', 5001)`. Add `kUseEmulator` already exists; reuse.
- `lib/main.dart` (Plan 01-09) — extend the `USE_EMULATOR` guarded block with the same `useFunctionsEmulator` call. The guard pattern + import constraints (lib MUST NOT import test) already established.
- `firebase.json` (Plan 01-01 + Plan 01-06's flutterfire-driven update) — extend the `emulators:` block with `functions: { port: 5001 }`. Existing block order: auth(9099) / firestore(8080) / storage(9199) / ui(4000); add functions before ui.
- `integration_test/login_smoke_test.dart` (Plan 01-09) — pattern for the new `ping_smoke_test.dart`. Same `setUpAll` + `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` + `configureEmulators()` shape; library-level `@Tags(['emulator', 'integration'])`.
- `.github/workflows/ci.yml` (Plan 01-10) — currently has a `functions:` job stubbed with `if: false`. Phase 2's PR-3 (or PR-1 if convenient) removes the `if: false` and replaces the `echo` step with `cd functions && npm ci && npm run lint && npm run build` per the inline TODO comment.

### Established Patterns
- **Per-collection repositories with decoded domain models, never raw snapshots** (Phase 1 D-02) — `PingRepository.ping()` returns a `PingResponse` model (new file at `lib/data/models/ping_response.dart`), never the raw `HttpsCallableResult`.
- **SDK singletons exposed as Riverpod providers** (Phase 1 D-04) — `firebase_functions_provider.dart` follows the existing pattern at `lib/data/services/firebase_providers.dart`. Test override via `ProviderScope.overrides`.
- **Package-style imports for all cross-layer references** (Phase 1 D-14 / Plan 03) — every new file in Phase 2 uses `package:mentor_minds/...` imports.
- **No body edits in pure git mv refactors** — Phase 2 has no `git mv` work, but the principle (atomic commits, one logical change per commit) carries.
- **`-no-fatal-infos` analyze gate, `--fatal-warnings` default** (Phase 1 / Plan 01-10) — Phase 2's TS code adds a separate gate (`npm run lint && npm run build`) that operates orthogonally to flutter analyze.
- **Layered_imports custom_lint rule** (Phase 1 / Plan 01-02 + 05) — Phase 2 new Dart files MUST honor this rule. `PingRepository` may import `cloud_functions`; viewmodels (if any consumer lands) may NOT import `cloud_functions` directly — must go through the repo.

### Integration Points
- **`lib/data/services/firebase_functions_provider.dart`** — NEW. Exposes `firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) => FirebaseFunctions.instanceFor(region: 'asia-south1'))`. The `instanceFor(region:)` call pins the client to asia-south1 (D-17).
- **`lib/data/repositories/ping_repository.dart`** — NEW. Single method `Future<PingResponse> ping()`. Wraps `firebaseFunctions.httpsCallable('ping').call()`.
- **`lib/data/models/ping_response.dart`** — NEW. Single class with `bool ok`, `int timestamp`. Factory `PingResponse.fromMap(Map<String, dynamic>)`.
- **`lib/main.dart`** — minimal edit. Add the `FirebaseAppCheck.instance.activate(...)` call after `Firebase.initializeApp` (production path). Inside the `useEmulator` block, also add `useFunctionsEmulator('localhost', 5001)`.
- **NO viewmodel consumer in Phase 2.** `PingRepository` exists for the integration test to call directly. Phase 3's `MentorBotViewModel` is the first real consumer of repositories that go through Functions; Phase 2 only proves the wiring works.

</code_context>

<specifics>
## Specific Ideas

- **Ping response shape:** `{ ok: true, timestamp: <ms-since-epoch>, region: 'asia-south1' }`. The `region` field is intentional sanity-check observability — confirms the asia-south1 pin from the client's perspective (the callable's `region` is set server-side but the client doesn't otherwise see proof).
- **TypeScript strictness:** `strict: true` + `noUncheckedIndexedAccess: true` + `noImplicitOverride: true`. The `noUncheckedIndexedAccess` flag is non-default but catches a major class of "is this array slot defined?" bugs that hit JS-trained TypeScript devs.
- **eslint preset:** `eslint-config-google` is the Firebase docs' historical default but is now in maintenance mode. Use `@typescript-eslint/recommended` + `@typescript-eslint/recommended-requiring-type-checking` (the type-aware preset). Adds ~30s to CI lint step but catches real bugs (floating promises, no-misused-promises).
- **Functions emulator port: 5001** (Firebase default). No custom port — matches every example in the Firebase docs.

</specifics>

<deferred>
## Deferred Ideas

- **Production deploy of `ping`** — Phase 3 amortizes the deploy cost with `mentorBotChat`. Phase 2 only proves the emulator round trip.
- **Per-developer Apple ID enrollment in the Apple Developer Program** — separate from this phase; required before Phase 5 (App Store submission) but doesn't block Phase 2. Note: Plan 01-07's deferred device QA is also gated on this.
- **Server-side observability (structured logging, Cloud Trace)** — Phase 7 polish work. Phase 2's helpers use `console.log` / `console.error` only.
- **Authenticated callable variants (`enforceAppCheck` + token-required-on-callable)** — Phase 3 adds `auth!.uid`-required gating to `mentorBotChat`. `ping` is intentionally unauthenticated (App Check verifies the *device*, not the *user*) so we can also verify enforcement from un-signed-in dev simulators.
- **Functions emulator export/import seeding** — analogous to `tool/emulator-data/` for Auth+Firestore+Storage. Probably unnecessary because Functions emulator state is purely in-memory invocations; no persistent state to seed. Revisit only if Phase 3's rate-limit unit tests need it.

</deferred>

---

*Phase: 2-cloud-functions-scaffolding-app-check*
*Context gathered: 2026-05-18*
