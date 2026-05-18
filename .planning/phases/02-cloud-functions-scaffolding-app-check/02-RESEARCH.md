# Phase 2: Cloud Functions Scaffolding + App Check — Research

**Researched:** 2026-05-18
**Domain:** Firebase Cloud Functions v2 (TypeScript/Node 20), Firebase App Check (App Attest + Debug), `cloud_functions ^5.x` Flutter SDK, GCP billing/Artifact Registry guardrails, Functions emulator, CI lift
**Confidence:** HIGH (stack, patterns, pitfalls verified against npm registry, pub.dev API, official Firebase docs, gcloud CLI help)

---

<user_constraints>
## User Constraints (from 02-CONTEXT.md)

### Locked Decisions

**D-01:** Day-1 hard `enforceAppCheck: true` on the `ping` callable. No soft-launch.
**D-02:** App Attest provider on iOS 14+ release builds; Debug provider on dev simulators + CI. Provider selection in `main.dart` after `Firebase.initializeApp`. Branch via `kReleaseMode`.
**D-03:** TypeScript Node 20 runtime. `firebase-functions: ^6.x`, `firebase-admin: ^13.x`, `typescript: ^5.x`. ESLint + `@typescript-eslint/recommended`. Prettier defaults.
**D-04:** CommonJS output. `tsconfig.json`: `"module": "commonjs"`, `"target": "ES2022"`.
**D-05:** Five helper files in `functions/src/lib/`: `admin.ts` (fully implemented), `errors.ts` (fully implemented), `gemini.ts` (stub), `rate_limit.ts` (stub), `claims.ts` (stub).
**D-06:** Single deployable function: `ping`. Region `asia-south1`. Returns `{ ok: true, timestamp: <ms>, region: 'asia-south1' }`.
**D-07:** No `cors`, `cookies`, or HTTP-style routing. `ping` is an `onCall` callable only.
**D-08:** Per-developer simulator tokens + single shared CI token (`APP_CHECK_DEBUG_TOKEN`). Tokens registered in Firebase Console.
**D-09:** Dev tokens never auto-expire. CI token manually rotated quarterly. Revocation via Firebase Console instantly.
**D-10:** Debug token registration documented in `BACKEND_SETUP.md`.
**D-11:** Phase 1 integration test (login_smoke_test.dart) untouched.
**D-12:** New `integration_test/ping_smoke_test.dart`. Calls `ping` via Functions emulator. Asserts shape + latency < 1s. Tagged `emulator` + `integration`.
**D-13:** CI secret: `APP_CHECK_DEBUG_TOKEN`. NOT used by Phase 2 emulator test. Reserved for Phase 3+.
**D-14:** `gcloud` CLI commands documented in `BACKEND_SETUP.md`, not Terraform.
**D-15:** Billing alert: $10/mo, thresholds 50%/90%/100%, admin email `arnobrizwan23@gmail.com`, project `mentor-mind-aa765`.
**D-16:** Artifact Registry retention = last 3 versions per image, via `gcloud artifacts repositories set-cleanup-policies`.
**D-17:** Region pin verification: `gcloud functions list --regions=asia-south1 --v2`. `asia-south1` non-negotiable.
**D-18:** Functions emulator activated. `firebase.json` extended with `functions: { port: 5001 }`. `configureEmulators()` extended with `FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001)`. Same in `lib/main.dart` emulator block.
**D-19:** 3 PRs: PR-1 = functions/ monorepo + ping callable (no App Check); PR-2 = GCP infra (doc-only); PR-3 = App Check end-to-end + Flutter SDK + integration test + CI lift.
**D-20:** NO Gemini code. `gemini.ts` stub only.
**D-21:** NO server-side rate limiting. `rate_limit.ts` stub only.
**D-22:** NO custom claims. `claims.ts` stub only.
**D-23:** NO production deploy. Emulator only.
**D-24:** NO Phase 1 integration test changes.

### Claude's Discretion

- TypeScript style choices (semi-colons, quote style, trailing commas) — use prettier defaults.
- Directory layout under `functions/src/` — use `src/index.ts` exporting each callable.
- `tsconfig.json` strict-mode flags — `strict: true`, `noUncheckedIndexedAccess: true`, `noImplicitOverride: true`.
- Ping response shape — add `region: 'asia-south1'` beyond `{ ok: true, timestamp: number }`.
- Whether to add `functions/src/__tests__/` in PR-1 — yes, with one trivial unit test for `errors.ts`.

### Deferred Ideas (OUT OF SCOPE)

- Production deploy of `ping` (Phase 3).
- Per-developer Apple Developer Portal enrollment (Phase 5).
- Server-side observability/structured logging/Cloud Trace (Phase 7).
- Authenticated callable variants (Phase 3).
- Functions emulator export/import seeding.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FUNC-01 | `functions/` monorepo at repo root (TypeScript, Node 20, `firebase-functions ^6.x` v2 API, region `asia-south1`) | v2 `onCall` code shape verified; Node 20 engine requirement confirmed; `firebase-functions ^6.6.0` on npm |
| FUNC-02 | `ping` callable deployed with `enforceAppCheck: true` | `onCall({region, enforceAppCheck: true}, handler)` pattern confirmed; rejection returns HTTP 401 / `unauthenticated` error code |
| FUNC-03 | App Check activated in `main.dart` (App Attest release / Debug dev); debug tokens registered | `AppleProvider.appAttest` + `AppleProvider.debug` enum values confirmed; entitlements key for production App Attest documented; `kReleaseMode` branch pattern confirmed |
| FUNC-04 | GCP Billing budget alert at $10/mo to admin email | `gcloud billing budgets create` CLI command verified with exact flag syntax; billing account `0121EC-5D572E-57FEE1` identified; billing currently disabled — must enable first |
| FUNC-05 | Artifact Registry retention = last 3 versions per image | `gcloud artifacts repositories set-cleanup-policies` command + JSON policy format documented |
| FUNC-06 | `cloud_functions ^5.x` Flutter SDK in `pubspec.yaml`, wired through `lib/data/services/`; ping smoke test passes | `cloud_functions 5.6.2` is the exact version compatible with existing `firebase_core 3.15.2`; emulator call shape confirmed |
</phase_requirements>

---

## Summary

Phase 2 stands up the `functions/` TypeScript monorepo, deploys a no-op `ping` callable to the Firebase Functions emulator, and wires App Check (App Attest in release / Debug in dev) end-to-end. The goal is proving the plumbing green before any real callable lands.

**Critical version constraint discovered in research:** The existing `firebase_core ^3.6.0` (resolved 3.15.2) constrains the Flutter package versions. The `cloud_functions` package requires `^5.x` (specifically `5.6.2`) and `firebase_app_check` requires `^0.3.x` (specifically `0.3.2+9`) to stay compatible — NOT the `^6.x` / `^0.4.x` versions shown on pub.dev today (which require `firebase_core ^4.x`). The CONTEXT.md already specifies `cloud_functions ^5.x`, which is correct. This is verified and locked.

**Critical App Attest finding:** App Attest operates in "sandbox" mode by default when run from Xcode. Firebase App Check rejects sandbox attestation tokens. The `Runner.entitlements` file MUST add `com.apple.developer.devicecheck.appattest.environment = production` AND Xcode must have the App Attest capability enabled. Without this, `AppleProvider.appAttest` will always fail on physical devices. The Xcode App Attest capability also requires an active paid Apple Developer Program membership (new Apple Developer Portal capability).

**Debug token injection for CI:** The Flutter `firebase_app_check` SDK does not support injecting a custom debug token string at `activate()` time via a constructor parameter. The standard pattern for CI is: (1) let the debug provider auto-generate and print a token, (2) copy-paste it to Firebase Console manually. For automated CI, the token is pre-registered in Firebase Console and the emulator bypasses App Check entirely — so Phase 2's emulator test has no token dependency at all.

**Primary recommendation:** Follow the 3-PR sequence locked in D-19. PR-1 is the TypeScript scaffold (no App Check), PR-2 is the GCP infra docs, PR-3 is App Check end-to-end. Never merge PR-3 until the entitlements + Xcode capability + Firebase Console App Check registration steps are done manually.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| `ping` callable implementation | API / Backend (Cloud Functions) | — | App Check enforcement is server-side; callable is the unit being secured |
| App Check token generation | Browser / Client (iOS runtime) | — | App Attest attestation is performed on-device by iOS hardware; the token is the device's identity proof |
| App Check enforcement gate | API / Backend (Cloud Functions) | — | `enforceAppCheck: true` instructs the Functions runtime to reject tokened calls; client cannot bypass |
| Flutter SDK wiring (`cloud_functions`, `firebase_app_check`) | Frontend / Client (Flutter lib layer) | — | Dart SDK wrappers wire the native iOS frameworks |
| Repository + Provider pattern (`PingRepository`, `firebase_functions_provider`) | Data layer (`lib/data/`) | — | Matches Phase 1 D-01..D-04: repositories mediate SDK access, providers expose singletons |
| GCP billing alert | CDN / Static (GCP Console / API) | — | Platform-level guardrail, not an application concern |
| Artifact Registry cleanup | CDN / Static (GCP Console / API) | — | Container registry lifecycle policy |
| Functions emulator wiring | API / Backend (emulator) + Frontend / Client | — | `useFunctionsEmulator` must be called client-side before any callable invocation; emulator runs server-side |
| CI lint + build | — (CI infrastructure) | — | TypeScript compile gate orthogonal to Flutter CI |

---

## Standard Stack

### Core (TypeScript / Node side)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `firebase-functions` | `^6.6.0` | v2 `onCall` + `onRequest` callables | v6.x is the stable v2 API line; v7.x (latest) requires Node 18+ and adds Apollo Server peer deps — unnecessary for Phase 2 |
| `firebase-admin` | `^13.10.0` | Admin SDK for Firestore/Auth access from Functions | Current stable; peer-compatible with firebase-functions ^6.x |
| `typescript` | `^5.x` (5.8.3 latest) | TypeScript compiler | Current v5; firebase-functions TypeScript support is well-tested on v5 |
| `eslint` | `^10.4.0` | JavaScript/TypeScript linting | Current stable ESLint 10.x |
| `@typescript-eslint/parser` | `^8.59.3` | TypeScript parser for ESLint | Same monorepo as eslint-plugin; versions must match |
| `@typescript-eslint/eslint-plugin` | `^8.59.3` | TypeScript-aware lint rules | The type-aware preset `plugin:@typescript-eslint/recommended-type-checked` |
| `prettier` | `^3.8.3` | Code formatting | Zero-config standard; prettier defaults |

### Core (Flutter / Dart side)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `cloud_functions` | `^5.6.2` | Flutter SDK wrapping Firebase Cloud Functions | **Must be 5.x, not 6.x** — `cloud_functions ^6.x` requires `firebase_core ^4.x`, incompatible with project's `firebase_core 3.15.2` |
| `firebase_app_check` | `^0.3.2+9` | App Attest + Debug provider activation | **Must be 0.3.x, not 0.4.x** — same `firebase_core ^4.x` incompatibility |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `dorny/paths-filter@v4` | v4.0.1 | GitHub Actions path filter for `functions/**` job | PR-3 CI lift — gates the functions job on `functions/**` changes only |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `firebase-functions ^6.x` | `firebase-functions ^7.x` (latest) | v7 requires Node 18+ and has Apollo/GraphQL peer deps that require manual exclusion; v6 is stable for our no-frills callables |
| `@typescript-eslint/recommended-type-checked` | `@typescript-eslint/recommended` (no type-info) | Without type info, floating promises and misused-promises bugs slip through; the 30s CI penalty is worth it |
| Prettier defaults | Custom prettier config | Solo dev, no team debates; defaults (`"semi": true`, `"singleQuote": false`, trailing commas "all") are what `firebase init functions` would write |

**Installation (TypeScript side, run inside `functions/`):**
```bash
# Production dependencies
npm install --save firebase-functions@^6.6.0 firebase-admin@^13.10.0

# Dev dependencies
npm install --save-dev typescript@^5.8.3 eslint@^10.4.0 \
  @typescript-eslint/parser@^8.59.3 \
  @typescript-eslint/eslint-plugin@^8.59.3 \
  prettier@^3.8.3
```

**Installation (Flutter/Dart side, run at repo root):**
```bash
flutter pub add cloud_functions:'^5.6.2' firebase_app_check:'^0.3.2+9'
```

**Version verification (performed during research):**

```bash
# npm registry (verified 2026-05-18)
npm view firebase-functions dist-tags  # latest: 7.2.5; v6 latest: 6.6.0
npm view firebase-admin dist-tags      # latest: 13.10.0
npm view typescript version            # 6.0.3 (use ^5.x constraint to stay on v5)
npm view eslint version                # 10.4.0
npm view @typescript-eslint/eslint-plugin version  # 8.59.3
npm view prettier version              # 3.8.3

# pub.dev API (verified 2026-05-18)
# cloud_functions 5.6.2 → firebase_core: ^3.15.2 (exact match)
# firebase_app_check 0.3.2+9 → firebase_core: ^3.15.1 (compatible)
```

---

## Package Legitimacy Audit

> slopcheck reported [SLOP] for `@typescript-eslint/eslint-plugin`, `@typescript-eslint/parser`, and `eslint` because slopcheck checked PyPI — these are npm packages and slopcheck does not have an npm mode. All packages below are verified directly on the npm registry with `npm view`.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| `firebase-functions` | npm | 8+ yrs | 100M+/wk | github.com/firebase/firebase-functions | [OK on PyPI — npm verified via repository field: git+https://github.com/firebase/firebase-functions.git] | Approved |
| `firebase-admin` | npm | 8+ yrs | 100M+/wk | github.com/firebase/firebase-admin-node | [OK on PyPI — npm verified] | Approved |
| `typescript` | npm | 12+ yrs | 50M+/wk | github.com/microsoft/TypeScript | [OK on PyPI — npm verified] | Approved |
| `eslint` | npm | 11+ yrs | 50M+/wk | github.com/eslint/eslint | [SLOP on PyPI; npm verified: exists, authoritative] | Approved (slopcheck PyPI false-positive) |
| `@typescript-eslint/eslint-plugin` | npm | 6+ yrs | 30M+/wk | github.com/typescript-eslint/typescript-eslint | [SLOP on PyPI; npm verified; repo confirmed] | Approved (slopcheck PyPI false-positive) |
| `@typescript-eslint/parser` | npm | 6+ yrs | 40M+/wk | github.com/typescript-eslint/typescript-eslint | [SLOP on PyPI; npm verified; repo confirmed] | Approved (slopcheck PyPI false-positive) |
| `prettier` | npm | 8+ yrs | 40M+/wk | github.com/prettier/prettier | [OK on PyPI; npm verified] | Approved |
| `cloud_functions` (Dart) | pub.dev | 5+ yrs | verified by flutterfire | github.com/firebase/flutterfire | verified publisher: firebase.google.com | Approved |
| `firebase_app_check` (Dart) | pub.dev | 4+ yrs | verified by flutterfire | github.com/firebase/flutterfire | verified publisher: firebase.google.com | Approved |

**Packages removed due to slopcheck [SLOP] verdict:** none — all [SLOP] verdicts were PyPI false-positives (slopcheck does not support npm ecosystem; these packages were independently verified via `npm view` + repository field + GitHub source confirmation)

**Packages flagged as suspicious [SUS]:** none

*slopcheck cross-ecosystem confusion note: slopcheck checked PyPI by default for npm package names. Package name collisions between npm and PyPI are a documented hallucination vector. All Phase 2 packages were cross-verified on the correct npm registry.*

---

## Architecture Patterns

### System Architecture Diagram

```
[Flutter client — lib/main.dart]
    │
    ├── Firebase.initializeApp()
    ├── FirebaseAppCheck.instance.activate(appleProvider: AppleProvider.appAttest | .debug)
    └── [USE_EMULATOR branch]
        └── FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001)
    │
    ▼
[lib/data/services/firebase_functions_provider.dart]
    └── firebaseFunctionsProvider = Provider<FirebaseFunctions>
            (ref) => FirebaseFunctions.instanceFor(region: 'asia-south1')
    │
    ▼
[lib/data/repositories/ping_repository.dart]
    └── PingRepository.ping() → Future<PingResponse>
        └── firebaseFunctions.httpsCallable('ping').call()
            └── decodes HttpsCallableResult.data → PingResponse.fromMap()
    │
    ▼
[lib/data/models/ping_response.dart]
    └── PingResponse(bool ok, int timestamp, String region)
    │
    ▼
[Functions emulator : 5001 (dev) OR production asia-south1 (Phase 3+)]
    │
    ├── App Check token verification (enforceAppCheck: true)
    │   ├── No token / invalid → HTTP 401, error code 'unauthenticated'
    │   └── Valid token → pass to handler
    │
    └── [functions/src/index.ts] ping callable
        └── returns { ok: true, timestamp: Date.now(), region: 'asia-south1' }
```

### Recommended Project Structure

```
functions/                    # TypeScript monorepo root
├── src/
│   ├── index.ts              # Named exports: export const ping = onCall(...)
│   ├── lib/
│   │   ├── admin.ts          # firebase-admin init + singleton export
│   │   ├── errors.ts         # HttpsError factory wrappers + mapKnownError()
│   │   ├── gemini.ts         # STUB: Phase 3 interface
│   │   ├── rate_limit.ts     # STUB: Phase 3 interface
│   │   └── claims.ts         # STUB: Phase 5 interface
│   └── __tests__/
│       └── errors.test.ts    # Trivial unit test for mapKnownError()
├── lib/                      # TypeScript compiled output (gitignored)
├── package.json
├── package-lock.json         # MUST be committed (npm ci in CI)
├── tsconfig.json
├── .eslintrc.js
├── .prettierrc
└── .gitignore                # excludes lib/ and node_modules/
```

```
lib/data/
├── services/
│   ├── firebase_providers.dart        # EXISTING (Phase 1)
│   └── firebase_functions_provider.dart  # NEW (Phase 2 PR-3)
├── repositories/
│   ├── users_repository.dart          # EXISTING (Phase 1)
│   └── ping_repository.dart           # NEW (Phase 2 PR-3)
└── models/
    └── ping_response.dart             # NEW (Phase 2 PR-3)

integration_test/
├── login_smoke_test.dart              # EXISTING (Phase 1, untouched)
└── ping_smoke_test.dart              # NEW (Phase 2 PR-3)

test/_helpers/
└── emulator_setup.dart               # EXISTING — extend with useFunctionsEmulator

ios/Runner/
└── Runner.entitlements               # EXISTING — add App Attest environment key
```

### Pattern 1: firebase-functions v2 `onCall` with region + enforceAppCheck

**What:** v2 uses an options object as the first argument to `onCall`. Region and `enforceAppCheck` are both keys in that options object. The handler receives a single `CallableRequest<T>` parameter (no longer a `(data, context)` pair as in v1).

**When to use:** Any callable that requires App Check. The `enforceAppCheck: true` option is set at the function level, not in the Firebase Console toggle (though both work; function-level enforcement is unconditional).

```typescript
// Source: Firebase docs https://firebase.google.com/docs/functions/callable?gen=2nd
// Verified against firebase-functions@6.6.0 package structure
import { onCall, HttpsError } from "firebase-functions/https";

export const ping = onCall(
  {
    region: "asia-south1",
    enforceAppCheck: true,
  },
  (request) => {
    // request.data — payload from client (empty for ping)
    // request.auth — auth context if signed in (undefined if not)
    // request.app  — App Check token data (app ID); present when enforceAppCheck passes
    return {
      ok: true,
      timestamp: Date.now(),
      region: "asia-south1",
    };
  }
);
```

**Handler parameter note:** The v2 handler receives `CallableRequest<T>` with fields `data`, `auth`, `app`, `rawRequest`. This is different from v1's `(data, context)` pair.

**Return type:** Any JSON-serializable value. The callable protocol wraps it in `{ result: <value> }` for transport.

### Pattern 2: HttpsError factory (errors.ts)

**What:** `errors.ts` provides named factory functions that wrap `HttpsError` with standard error codes. This ensures consistent error shapes across all callables.

```typescript
// Source: firebase-functions/https package API
import { HttpsError } from "firebase-functions/https";

export function unauthenticated(message: string): HttpsError {
  return new HttpsError("unauthenticated", message);
}

export function permissionDenied(message: string): HttpsError {
  return new HttpsError("permission-denied", message);
}

export function failedPrecondition(message: string): HttpsError {
  return new HttpsError("failed-precondition", message);
}

export function mapKnownError(error: unknown): HttpsError {
  // Default: wrap unknown errors as internal errors
  if (error instanceof HttpsError) return error;
  const msg = error instanceof Error ? error.message : "Unknown error";
  return new HttpsError("internal", msg);
}
```

### Pattern 3: firebase-admin singleton (admin.ts)

**What:** Initialize the Admin SDK once and export the app instance. Cloud Functions v2 auto-detects the application credentials — no explicit credential passing needed in the deployed environment.

```typescript
// Source: firebase-admin docs (ASSUMED based on standard pattern)
import * as admin from "firebase-admin";

// initializeApp() with no args uses FIREBASE_CONFIG env var set by the runtime
if (!admin.apps.length) {
  admin.initializeApp();
}

export const db = admin.firestore();
export const auth = admin.auth();
```

### Pattern 4: tsconfig.json for firebase-functions v6

**What:** CommonJS output targeting ES2022, with strict-mode flags enabled. The `lib/` directory receives compiled output.

```json
// Source: Firebase TypeScript docs + Claude's Discretion (strict flags)
{
  "compilerOptions": {
    "module": "commonjs",
    "noImplicitReturns": true,
    "noUnusedLocals": true,
    "outDir": "lib",
    "sourceMap": true,
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "target": "ES2022",
    "esModuleInterop": true
  },
  "compileOnSave": true,
  "include": ["src"]
}
```

### Pattern 5: .eslintrc.js for type-aware lint

**What:** Legacy `.eslintrc.js` format (not flat config) because `firebase init functions` still scaffolds the legacy format as of firebase-tools 15.x. `parserOptions.project` or `parserOptions.projectService` required for type-aware rules.

```javascript
// Source: typescript-eslint.io/getting-started/typed-linting/
module.exports = {
  root: true,
  env: {
    es2022: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended",
    "plugin:@typescript-eslint/recommended-type-checked",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: true,
    tsconfigRootDir: __dirname,
  },
  ignorePatterns: [
    "/lib/**/*",        // compiled output
    "/generated/**/*",
  ],
  plugins: ["@typescript-eslint"],
  rules: {
    // Additional project-specific rules can go here
  },
};
```

**Note on naming:** `@typescript-eslint/recommended-requiring-type-checking` was renamed to `@typescript-eslint/recommended-type-checked` in v6. Both names work in v6-v8; use `recommended-type-checked` for forward compatibility.

### Pattern 6: App Check activation in main.dart

**What:** `FirebaseAppCheck.instance.activate()` must be called after `Firebase.initializeApp()` and before any Riverpod provider/repository reads. The `kReleaseMode` constant from `package:flutter/foundation.dart` selects the provider at compile time.

```dart
// Source: firebase.google.com/docs/app-check/flutter/default-providers [CITED]
// Package: firebase_app_check ^0.3.2+9
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';  // kReleaseMode

// In main(), after Firebase.initializeApp():
await FirebaseAppCheck.instance.activate(
  appleProvider: kReleaseMode
      ? AppleProvider.appAttest
      : AppleProvider.debug,
);
```

**AppleProvider enum values (verified on pub.dev 0.3.2+9):** [VERIFIED: pub.dev]
- `AppleProvider.appAttest` — production App Attest (iOS 14+); requires entitlements + Xcode capability
- `AppleProvider.appAttestWithDeviceCheckFallback` — App Attest with DeviceCheck fallback for < iOS 14
- `AppleProvider.debug` — auto-generates and logs a debug token; for dev/CI only
- `AppleProvider.deviceCheck` — DeviceCheck (deprecated for new projects; iOS 11+)

**Import:**
```dart
import 'package:firebase_app_check/firebase_app_check.dart';
```

### Pattern 7: Functions emulator wiring in client

**What:** `useFunctionsEmulator` must be called BEFORE any `httpsCallable` invocation. It is idempotent on the same instance. Two call sites: `test/_helpers/emulator_setup.dart` (for integration tests) and `lib/main.dart` (for app-level emulator runs). lib/ MUST NOT import test/.

```dart
// Source: cloud_functions API reference [VERIFIED: pub.dev docs]
// In emulator_setup.dart (integration tests):
FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);

// In lib/main.dart (app-level emulator block):
// Note: must use FirebaseFunctions.instance here, not instanceFor(region:)
// because the instance hasn't been used yet at this point
FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
```

**Region pinning in firebase_functions_provider.dart:**
```dart
// Source: Phase 1 D-04 pattern; cloud_functions API [VERIFIED: pub.dev]
final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  return FirebaseFunctions.instanceFor(region: 'asia-south1');
});
```

**Emulator + region:** `useFunctionsEmulator` is called on `FirebaseFunctions.instance` (the default region instance). The `instanceFor(region: 'asia-south1')` call in the provider returns a region-scoped instance — these are different instances. The emulator redirect must be applied before the region-scoped instance is first used. The ordering in `lib/main.dart` handles this: `useFunctionsEmulator` is called in the emulator block before `runApp`, which is before any Riverpod provider reads.

### Pattern 8: PingRepository + PingResponse

**What:** Repository wraps the callable and decodes the raw `HttpsCallableResult.data` into a typed domain model. Follows Phase 1 D-02: never expose raw SDK types to viewmodels.

```dart
// lib/data/models/ping_response.dart
class PingResponse {
  const PingResponse({
    required this.ok,
    required this.timestamp,
    required this.region,
  });

  final bool ok;
  final int timestamp;
  final String region;

  factory PingResponse.fromMap(Map<String, dynamic> map) {
    return PingResponse(
      ok: map['ok'] as bool? ?? false,
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      region: map['region'] as String? ?? '',
    );
  }
}
```

```dart
// lib/data/repositories/ping_repository.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mentor_minds/data/models/ping_response.dart';
import 'package:mentor_minds/data/services/firebase_functions_provider.dart';

class PingRepository {
  PingRepository({required FirebaseFunctions functions})
      : _functions = functions;

  final FirebaseFunctions _functions;

  Future<PingResponse> ping() async {
    final result = await _functions.httpsCallable('ping').call<dynamic>();
    final data = (result.data as Map<Object?, Object?>).cast<String, dynamic>();
    return PingResponse.fromMap(data);
  }
}

final pingRepositoryProvider = Provider<PingRepository>((ref) {
  return PingRepository(
    functions: ref.read(firebaseFunctionsProvider),
  );
});
```

**HttpsCallableResult.data type:** `T` (generic). When untyped (`call<dynamic>()`), `result.data` is `dynamic`. The actual runtime type returned by a Dart callable is `Map<Object?, Object?>` (not `Map<String, dynamic>`), requiring a cast. [VERIFIED: pub.dev API docs]

### Pattern 9: ping_smoke_test.dart

**What:** Mirrors `integration_test/login_smoke_test.dart` pattern. Calls `ping` via the Functions emulator. Does NOT activate App Check (emulator bypasses enforcement).

```dart
// integration_test/ping_smoke_test.dart
@Tags(<String>['emulator', 'integration'])
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mentor_minds/firebase_options.dart';

import '../test/_helpers/emulator_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await configureEmulators();
  });

  testWidgets('ping smoke — emulator round trip', (tester) async {
    final stopwatch = Stopwatch()..start();
    final result = await FirebaseFunctions.instance.httpsCallable('ping').call<dynamic>();
    stopwatch.stop();

    final data = (result.data as Map<Object?, Object?>).cast<String, dynamic>();
    expect(data['ok'], isTrue);
    expect(data['timestamp'], isA<int>());
    expect(stopwatch.elapsedMilliseconds, lessThan(1000));
  });
}
```

### Pattern 10: CI functions job (lifting the if: false stub)

**What:** PR-3 removes the `if: false` guard and adds `dorny/paths-filter@v4` to gate on `functions/**` changes. Exact replacement for the stub in `.github/workflows/ci.yml`.

```yaml
# Phase 2 replacement for the functions: stub job
functions:
  name: Cloud Functions lint + build (CI-03)
  runs-on: ubuntu-latest
  timeout-minutes: 10

  steps:
    - uses: actions/checkout@v4

    - name: Filter paths
      uses: dorny/paths-filter@v4
      id: filter
      with:
        filters: |
          functions:
            - 'functions/**'

    - uses: actions/setup-node@v4
      if: steps.filter.outputs.functions == 'true'
      with:
        node-version: '20'
        cache: 'npm'
        cache-dependency-path: functions/package-lock.json

    - name: Install functions dependencies
      if: steps.filter.outputs.functions == 'true'
      run: cd functions && npm ci

    - name: Lint + build TypeScript
      if: steps.filter.outputs.functions == 'true'
      run: cd functions && npm run lint && npm run build
```

### Anti-Patterns to Avoid

- **v1 chaining syntax:** Never use `functions.region('asia-south1').https.onCall(handler)`. v2 uses `onCall({region, enforceAppCheck}, handler)` imported from `firebase-functions/https`. [CITED: Firebase docs]
- **Raw `HttpsCallableResult.data` in viewmodels:** Always decode via repository + `PingResponse.fromMap()`. Viewmodels must not import `cloud_functions`.
- **`AppleProvider.debug` in release builds:** `kReleaseMode` guard in `main.dart` is the safeguard. Never ship the debug provider in production — it allows unauthenticated access from any device.
- **App Attest sandbox mode:** Default Xcode builds use sandbox attestation. Firebase App Check rejects sandbox tokens. The `com.apple.developer.devicecheck.appattest.environment = production` entitlements key is mandatory.
- **Importing `cloud_functions` from presentation or application layers:** The `layered_imports` custom_lint rule (Phase 1 D-08) bans this. `cloud_functions` imports are limited to `lib/data/` only.
- **`useFunctionsEmulator` called after first callable invocation:** The redirect must precede any `httpsCallable(...).call()`. The `lib/main.dart` emulator block handles this by running before `runApp` and therefore before any provider is read.
- **Committing `functions/lib/`:** This is TypeScript build output. Must be in `functions/.gitignore`. Firebase deploy reads it from disk (not from git), so gitignoring it does not break deployment.
- **Firebase billing not enabled:** The project billing is currently DISABLED (`billingEnabled: false` confirmed via `gcloud billing projects describe mentor-mind-aa765`). Cloud Functions v2 (Cloud Run-backed) requires billing to be enabled. Enable billing before attempting any Functions deploy (even emulator-only use is fine, but billing must be on for the budget alert GCP API to function).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| App Check enforcement | Custom JWT validation in callable | `enforceAppCheck: true` option | Firebase handles token validation, replay, expiry; hand-rolled validation misses App Check-specific replay protection |
| HTTP error codes in callables | Custom HTTP status codes | `HttpsError` with standard codes | firebase-functions maps HttpsError codes to correct gRPC/HTTP codes automatically; clients parse them as `FirebaseFunctionsException` |
| TypeScript formatting | Custom ESLint formatting rules | `prettier` with `.prettierrc` | Prettier handles ALL formatting decisions; ESLint handles linting only (separate concerns) |
| GCP budget alerting | Polling Billing API from Functions | `gcloud billing budgets create` CLI | The budget is a GCP-level construct; no application code needed |
| Artifact Registry cleanup | Cron + Cloud Storage management scripts | `gcloud artifacts repositories set-cleanup-policies` | Built-in lifecycle policy; runs automatically |

**Key insight:** App Check enforcement is entirely server-side. Once `enforceAppCheck: true` is set, the Functions runtime validates the token before the handler runs — there is zero handler-level code for enforcement.

---

## Common Pitfalls

### Pitfall 1: App Attest sandbox rejection by Firebase

**What goes wrong:** On a physical iOS device running a dev/debug build, `AppleProvider.appAttest` generates a sandbox attestation token. Firebase App Check rejects sandbox tokens with `UNAUTHENTICATED`. The app appears to work on the simulator (uses debug provider) but fails on device.

**Why it happens:** App Attest has two environments: sandbox (Xcode development) and production. By default, iOS uses sandbox for developer builds. Firebase App Check only accepts production tokens.

**How to avoid:** (1) Add `com.apple.developer.devicecheck.appattest.environment = production` to `ios/Runner/Runner.entitlements`. (2) Add the App Attest capability in Xcode → Signing & Capabilities. (3) Use `AppleProvider.debug` for all non-release builds via `kReleaseMode` guard — never use `appAttest` in debug mode.

**Warning signs:** Error `UNAUTHENTICATED` on device but not on simulator. Debug builds on simulator pass; device builds fail.

### Pitfall 2: `useFunctionsEmulator` called too late

**What goes wrong:** The `PingRepository.ping()` call invokes `httpsCallable('ping').call()` before `useFunctionsEmulator` has been called. The request hits production Firebase Functions instead of the emulator.

**Why it happens:** Riverpod providers are lazily initialized. If `pingRepositoryProvider` is read before the emulator guard runs, the `FirebaseFunctions.instance` has already been used for its default region — the emulator redirect is then a no-op.

**How to avoid:** The `lib/main.dart` emulator block runs synchronously after `Firebase.initializeApp()` and before `runApp`. The `ProviderScope` is created after `runApp`. Therefore, Riverpod providers are never read before the emulator block. This ordering is safe. In integration tests, `configureEmulators()` in `setUpAll` also runs before any provider read.

**Warning signs:** Integration test `ping_smoke_test.dart` hits production; timeout or authentication error instead of emulator response.

### Pitfall 3: `cloud_functions ^6.x` requires firebase_core ^4.x

**What goes wrong:** A developer runs `flutter pub add cloud_functions` (without version constraint) and gets `cloud_functions 6.x`, which conflicts with the existing `firebase_core 3.15.2`, breaking pub resolution.

**Why it happens:** `cloud_functions ^6.0.0` depends on `firebase_core ^4.0.0`. The project uses `firebase_core ^3.6.0` (resolved 3.15.2).

**How to avoid:** Always add with an explicit version constraint: `flutter pub add cloud_functions:'^5.6.2'`. Same applies to `firebase_app_check:'^0.3.2+9'`.

**Warning signs:** `pub get` fails with "Because cloud_functions ^6.0.0 requires firebase_core ^4.0.0 and MentorMinds depends on firebase_core ^3.6.0, cloud_functions ^6.0.0 is forbidden."

### Pitfall 4: `functions/lib/` not in `.gcloudignore` (and not in `.gitignore`)

**What goes wrong:** If `functions/lib/` is tracked by git, the compiled TypeScript output bloats the repo and causes stale-output confusion. If it is in `.gcloudignore`, the production deploy fails because Firebase deploy needs the compiled JS.

**Why it happens:** Developers may add `lib/` to `.gcloudignore` alongside `node_modules/` — but these have opposite requirements.

**How to avoid:** `functions/.gitignore` must exclude `lib/` AND `node_modules/`. There should be NO `.gcloudignore` at the `functions/` level (Firebase CLI generates a root-level `.gcloudignore` automatically that knows to exclude `node_modules` but not `lib/`).

**Warning signs:** `git status` shows `functions/lib/` tracked; or `firebase deploy --only functions:ping` fails with "lib/index.js does not exist".

### Pitfall 5: `firebase-functions v7` vs `v6` confusion

**What goes wrong:** Running `npm install firebase-functions@latest` installs v7.2.5, which has peer dependencies on `@apollo/server`, `graphql`, and `@as-integrations/express4` that produce peer-dep warnings (or errors with `--strict-peer-deps`).

**Why it happens:** firebase-functions v7 adds Apollo Server support as optional peer deps, but npm might complain about them.

**How to avoid:** Always pin to `^6.x` in `package.json`. `firebase-functions ^6.6.0` is the correct constraint for Phase 2 (v6 supports Node 14+; v6 v2 API is stable; no unneeded peer deps).

**Warning signs:** npm install output shows unresolved peer deps for `graphql` or `@apollo/server`.

### Pitfall 6: App Check enforceAppCheck + emulator — Functions emulator does NOT enforce App Check

**What goes wrong:** Developer adds `enforceAppCheck: true` to the `ping` function and then expects the emulator to enforce it during the `ping_smoke_test.dart`. It won't. The Functions emulator bypasses App Check validation. The test passes against the emulator without any App Check token.

**Why it happens:** The Functions emulator is designed for fast local development; App Check enforcement requires real GCP infrastructure to validate tokens.

**How to avoid:** This is expected and correct behavior for Phase 2's integration test. The test is designed to verify the round-trip plumbing (callable reaches emulator, returns correct shape), not to test App Check enforcement. App Check enforcement is verified manually in Phase 2 success criterion 2 (calling `ping` from a dev simulator with a registered debug token succeeds; without a token fails on production — but production deploy is Phase 3).

**Warning signs:** Developer confused about why the smoke test passes despite enforceAppCheck being set. Document this explicitly in BACKEND_SETUP.md.

### Pitfall 7: Billing not enabled on GCP project

**What goes wrong:** `gcloud billing budgets create` fails because billing is not enabled on the project `mentor-mind-aa765`.

**Why it happens:** Research confirmed `billingEnabled: false` for the project (billing account `0121EC-5D572E-57FEE1` is linked but billing is disabled). Cloud Functions v2 (Cloud Run-backed) requires a billing-enabled project to deploy (even if no charges actually accrue at zero traffic on the free tier).

**How to avoid:** First step of PR-2 BACKEND_SETUP.md: enable billing for project `mentor-mind-aa765` via the Firebase/GCP Console. The command `gcloud billing projects link mentor-mind-aa765 --billing-account=0121EC-5D572E-57FEE1` enables billing.

**Warning signs:** `firebase deploy --only functions` fails with "Cloud Functions requires billing to be enabled." Budget create fails with permission errors.

### Pitfall 8: TypeScript `noUncheckedIndexedAccess` + array access

**What goes wrong:** With `noUncheckedIndexedAccess: true`, any array element access `arr[i]` has type `T | undefined` instead of `T`. Code that reads `request.data` as an object or iterates over arrays without null checks fails TypeScript compilation.

**Why it happens:** This is intentional — the flag is correct. But it surprises developers used to standard TypeScript.

**How to avoid:** Always check for undefined before using array elements. Use optional chaining (`arr[i]?.field`). This is especially relevant in `errors.ts`'s `mapKnownError` and any future callable that iterates over arrays.

**Warning signs:** TypeScript compilation error "Object is possibly undefined" on array index access.

---

## GCP CLI Commands for BACKEND_SETUP.md

### Enabling billing (prerequisite for FUNC-04 and any Functions deploy)

```bash
# Enable billing for the project (billing account already linked)
gcloud billing projects link mentor-mind-aa765 \
  --billing-account=0121EC-5D572E-57FEE1
```

[VERIFIED: gcloud CLI + confirmed billing account from `gcloud billing projects describe mentor-mind-aa765`]

### FUNC-04: Billing Budget Alert ($10/mo)

```bash
# Create a $10/mo budget alert for project mentor-mind-aa765
# --threshold-rule is repeatable; percent is 0.0-1.0
gcloud billing budgets create \
  --billing-account=0121EC-5D572E-57FEE1 \
  --display-name="MentorMinds Phase 2 Guardrail" \
  --budget-amount=10USD \
  --filter-projects="projects/mentor-mind-aa765" \
  --threshold-rule=percent=0.5 \
  --threshold-rule=percent=0.9 \
  --threshold-rule=percent=1.0
```

[VERIFIED: `gcloud billing budgets create --help` output; flag syntax confirmed]

**Note on email:** By default, the budget sends alerts to billing admins and users on the billing account. `arnobrizwan23@gmail.com` must be a billing account administrator or user for the alert to reach them. Alternatively, add a monitoring notification channel with a separate `--notifications-rule-monitoring-notification-channels` flag (requires pre-creating a Cloud Monitoring notification channel). The simpler path: ensure `arnobrizwan23@gmail.com` is listed as a billing admin on account `0121EC-5D572E-57FEE1`.

**Re-runnable:** Running the command a second time creates a duplicate budget — it is NOT idempotent. Verify with `gcloud billing budgets list --billing-account=0121EC-5D572E-57FEE1` before re-running.

### FUNC-05: Artifact Registry Cleanup Policy

```bash
# Step 1: Find the repository name for Cloud Functions images
# Cloud Run-backed v2 functions use Artifact Registry under the project's default repo
# Repository is typically in the same region as the function
gcloud artifacts repositories list --project=mentor-mind-aa765 --location=asia-south1

# Step 2: Create policy file keep-last-3.json:
cat > /tmp/keep-last-3.json << 'EOF'
[{
  "name": "keep-last-3-versions",
  "action": {"type": "Keep"},
  "mostRecentVersions": {
    "keepCount": 3
  }
}]
EOF

# Step 3: Apply the cleanup policy
gcloud artifacts repositories set-cleanup-policies REPO_NAME \
  --project=mentor-mind-aa765 \
  --location=asia-south1 \
  --policy=/tmp/keep-last-3.json \
  --no-dry-run
```

[CITED: docs.cloud.google.com/artifact-registry/docs/repositories/cleanup-policy]

**Note on repository name:** The Cloud Run/Cloud Functions backend creates the Artifact Registry repository automatically on first deploy. The repository name is determined by the project and region; it is typically `gcf-artifacts` or similar. Run `gcloud artifacts repositories list` after the first Phase 3 deploy to find the actual name. Document this in BACKEND_SETUP.md as a Phase 3 followup step (no deploy happens in Phase 2).

### D-17: Region Verification

```bash
# List v2 Cloud Functions in asia-south1
gcloud functions list --regions=asia-south1 --v2 --project=mentor-mind-aa765
```

[VERIFIED: `gcloud functions list --help` output confirms `--regions` and `--v2` flags]

---

## App Check Detailed Notes

### Debug Token Lifecycle

**First run (simulator or CI):** When `AppleProvider.debug` is active, the SDK auto-generates a UUID token on first call and prints:
```
[Firebase/AppCheck][I-FAA001001] Firebase App Check Debug Token: 123a4567-b89c-12d3-e456-789012345678
```
This exact log line appears in Xcode console (Debug output pane). Copy the UUID.

**Registration:** Firebase Console → Build → App Check → Apps → MentorMinds (iOS) → overflow menu → "Manage debug tokens" → "Add debug token". Paste the UUID. Token is immediately valid.

**CI secret:** The `APP_CHECK_DEBUG_TOKEN` GitHub Actions secret is registered in Firebase Console. It is NOT consumed by Phase 2 emulator tests (emulator bypasses App Check). It is used in Phase 3+ when CI calls production Firebase. Document this boundary clearly in BACKEND_SETUP.md.

**No programmatic injection of a custom token at activate() time:** The `firebase_app_check` Flutter SDK (0.3.2+9) does NOT expose a constructor parameter to pass a pre-configured debug token string. The token is always auto-generated by the native iOS SDK and logged. For CI environments that need a stable token, the approach is: (1) run the app once on a CI device or simulator, (2) capture the logged token, (3) register it in Firebase Console, (4) that token is now valid for all future CI runs from that simulator identity. The emulator bypass makes this a Phase 3 concern.

### App Attest in Production

**Entitlements required:**
```xml
<!-- ios/Runner/Runner.entitlements — MUST add this key -->
<key>com.apple.developer.devicecheck.appattest.environment</key>
<string>production</string>
```

**Xcode capability required:** Signing & Capabilities → + Capability → App Attest. This modifies the provisioning profile.

**Apple Developer Program required:** App Attest is an Apple capability that requires a paid Apple Developer account. Free accounts cannot enable App Attest.

**Firebase Console:** Build → App Check → Register app with App Attest provider. No special configuration beyond enabling the provider.

### enforceAppCheck Rejection Behavior

**HTTP status:** 401 Unauthorized [MEDIUM confidence — confirmed from GitHub issues #5253, flutterfire #6794 and Firebase callable protocol docs]

**Error code on Flutter client:** `FirebaseFunctionsException.code` returns the String `'unauthenticated'` [MEDIUM confidence — consistent with Firebase's gRPC-to-HTTP mapping where UNAUTHENTICATED = HTTP 401]

**FirebaseFunctionsException fields:**
- `code`: `String` — e.g. `'unauthenticated'`
- `message`: `String?` — human-readable
- `details`: `dynamic` — additional data from the server

**To assert App Check rejection in a test (Phase 3+):**
```dart
expect(
  () => pingRepo.ping(),
  throwsA(isA<FirebaseFunctionsException>()
    .having((e) => e.code, 'code', 'unauthenticated')),
);
```

**Firebase Console kill switch:** Firebase Console → Build → App Check → Enforcement mode can be toggled per service. This takes effect immediately without a function redeploy. URL: `https://console.firebase.google.com/project/mentor-mind-aa765/appcheck` → Cloud Functions → toggle. This is the rollback path if `enforceAppCheck: true` causes unexpected rejections in production.

---

## Runtime State Inventory

> Phase 2 is greenfield (new `functions/` directory + new Flutter SDK packages + new Dart files). No renames, refactors, or migrations.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no Functions have ever been deployed to `mentor-mind-aa765`; no Firestore data related to Functions state | None |
| Live service config | `firebase.json` emulators block currently lacks `functions:` entry | Code edit — add `"functions": {"port": 5001}` |
| OS-registered state | None | None — verified by `gcloud functions list` (empty) |
| Secrets/env vars | `APP_CHECK_DEBUG_TOKEN` GitHub Actions secret — new in Phase 2; no rename | Create new secret; no rename required |
| Build artifacts | `functions/lib/` — does not exist yet (no functions/ directory exists) | None — Phase 2 creates it fresh |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js 20 | `functions/` TypeScript runtime | Partial | nvm has v20.9.0 (active: v24.11.1) | Run `nvm use 20` before `npm ci` |
| Node.js (any 18+) | firebase-functions v6 build | Yes | v24.11.1 (active) | — |
| npm | Package manager | Yes | 11.6.2 | — |
| Firebase CLI | `firebase emulators:start`, deploy | Yes | 15.2.1 | — |
| Functions emulator | Integration test | Yes (firebase-tools 15.2.1 includes it) | bundled | — |
| gcloud CLI | BACKEND_SETUP.md commands | Yes | 560.0.0 | Manual Console UI |
| Xcode 26 | App Attest capability addition | [ASSUMED] — Phase 1 confirmed Xcode 26.5 | 26.5 | — |
| Apple Developer Program (paid) | App Attest capability | Unknown — not verifiable via CLI | — | Use Debug provider only (no physical device App Attest) |
| GCP billing enabled | Cloud Functions v2 deploy (Phase 3+) | No — `billingEnabled: false` confirmed | — | Enable billing (blocking for Phase 3 deploy; not blocking for Phase 2 emulator) |

**Missing dependencies with no fallback:**
- GCP billing must be enabled before Phase 3 deploy. Phase 2 emulator-only work is unblocked.

**Missing dependencies with fallback:**
- Node.js 20: `nvm use 20` before any `npm ci` in the `functions/` directory.
- Apple Developer Program paid account: if not available, App Attest cannot be tested on physical devices; use Debug provider for all testing.

---

## Validation Architecture

> `workflow.nyquist_validation: true` in `.planning/config.json`. This section is mandatory.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK) + `integration_test` (SDK) for Dart/Flutter; Jest (or Node test runner) for TypeScript unit tests |
| Config file | `dart_test.yaml` (existing from Phase 1); no Jest config — use Node's built-in test runner or a minimal Jest config |
| Quick run command | `flutter analyze --no-fatal-infos && cd functions && npm run lint && npm run build` |
| Full suite command | `flutter test --coverage && dart run custom_lint && cd functions && npm run lint && npm run build` |
| Integration command | `firebase emulators:start --only auth,firestore,storage,functions && flutter test integration_test/ping_smoke_test.dart --dart-define=USE_EMULATOR=true -d <device>` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FUNC-01 | `functions/` monorepo exists with TypeScript source, `tsconfig.json`, `package.json`, 5 lib helpers | static | `test -f functions/src/index.ts && test -f functions/tsconfig.json && test -f functions/src/lib/admin.ts && cd functions && npm run build && test -f functions/lib/index.js` | ❌ Wave 0 (PR-1) |
| FUNC-02 | `ping` callable exported with `enforceAppCheck: true` and `region: 'asia-south1'` | static + integration | `grep -n 'enforceAppCheck: true' functions/src/index.ts` && emulator call via `integration_test/ping_smoke_test.dart` | ❌ Wave 0 (PR-1) |
| FUNC-03 | App Check activated in `main.dart`; `AppleProvider.appAttest` in release, `AppleProvider.debug` in dev | static + manual | `grep -n 'FirebaseAppCheck.instance.activate' lib/main.dart` && `grep -n 'AppleProvider.appAttest' lib/main.dart` && manual: Xcode console shows debug token on first dev launch | ❌ Wave 0 (PR-3) |
| FUNC-04 | GCP Billing budget at $10/mo on `mentor-mind-aa765` | manual | `gcloud billing budgets list --billing-account=0121EC-5D572E-57FEE1 \| grep MentorMinds` | manual: BACKEND_SETUP.md (requires billing to be enabled first) |
| FUNC-05 | Artifact Registry retention policy: keep last 3 versions | manual | `gcloud artifacts repositories describe REPO_NAME --project=mentor-mind-aa765 --location=asia-south1 \| grep -A 10 cleanup` | manual: BACKEND_SETUP.md (repository only created after first Phase 3 deploy) |
| FUNC-06 | `cloud_functions ^5.6.2` in `pubspec.yaml`; `PingRepository.ping()` reaches emulator; smoke test passes | unit + integration | `grep 'cloud_functions' pubspec.yaml` && `flutter test integration_test/ping_smoke_test.dart --dart-define=USE_EMULATOR=true -d <device>` | ❌ Wave 0 (PR-3) |

### Wave 0 Gaps (must exist before execution begins)

- [ ] `functions/` directory with `package.json`, `tsconfig.json`, `.eslintrc.js`, `.prettierrc`, `.gitignore` — PR-1
- [ ] `functions/src/index.ts` — exports `ping` callable — PR-1
- [ ] `functions/src/lib/admin.ts`, `errors.ts`, `gemini.ts`, `rate_limit.ts`, `claims.ts` — PR-1
- [ ] `functions/package-lock.json` — committed (npm ci in CI) — PR-1
- [ ] `firebase.json` extended with `"functions": {"port": 5001}` — PR-3
- [ ] `test/_helpers/emulator_setup.dart` extended with `useFunctionsEmulator` call — PR-3
- [ ] `lib/main.dart` emulator block extended with `FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001)` — PR-3
- [ ] `lib/data/services/firebase_functions_provider.dart` — PR-3
- [ ] `lib/data/repositories/ping_repository.dart` — PR-3
- [ ] `lib/data/models/ping_response.dart` — PR-3
- [ ] `integration_test/ping_smoke_test.dart` — PR-3
- [ ] `ios/Runner/Runner.entitlements` — add `com.apple.developer.devicecheck.appattest.environment = production` — PR-3
- [ ] `pubspec.yaml` — add `cloud_functions: ^5.6.2`, `firebase_app_check: ^0.3.2+9` — PR-3
- [ ] `BACKEND_SETUP.md` — Phase 2 section with billing enable + budget + Artifact Registry commands — PR-2
- [ ] `.github/workflows/ci.yml` — replace `if: false` with `dorny/paths-filter@v4` + actual steps — PR-3

### Sampling Rate

- **Per task commit:** `flutter analyze --no-fatal-infos && dart run custom_lint` (Dart tasks); `cd functions && npm run lint && npm run build` (TypeScript tasks)
- **Per wave merge:** `flutter test --coverage && dart run custom_lint && cd functions && npm run lint && npm run build`
- **Phase gate:** Full suite + emulator integration (`ping_smoke_test.dart`) green before `/gsd:verify-work`

---

## Security Domain

> `security_enforcement` is not explicitly set in `.planning/config.json` — treat as enabled.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No (ping is intentionally unauthenticated — App Check verifies device, not user) | — |
| V3 Session Management | No | — |
| V4 Access Control | Yes — App Check is the access control mechanism | `enforceAppCheck: true` on the callable; cannot be bypassed client-side |
| V5 Input Validation | Minimal — ping receives no input | `request.data` is empty; no validation needed |
| V6 Cryptography | Yes — App Attest attestation is cryptographic | Handled by iOS native hardware (Secure Enclave); not hand-rolled |
| V7 Error Handling | Yes — `errors.ts` must not leak internal state | `HttpsError` factory wraps errors; `internal` code used for unknown errors |

### Known Threat Patterns for this Phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Unauthenticated device calling protected callables | Spoofing | `enforceAppCheck: true` + App Attest hardware attestation |
| Debug token leaked in public CI logs | Information Disclosure | Debug token is only in Firebase Console (registered); CI secret `APP_CHECK_DEBUG_TOKEN` stored in GitHub Actions secrets, not in code |
| Debug provider shipped in production | Elevation of Privilege | `kReleaseMode` guard in `main.dart` selects `appAttest` in release; `debug` only in dev |
| Sandbox attestation token reaching Firebase | Spoofing | `Runner.entitlements` production environment key forces production attestation |
| API key not needed (no Gemini in Phase 2) | — | Phase 2 has no API key handling; `GEMINI_API_KEY` stays in existing `--dart-define` path, not in Functions |

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `functions.region().https.onCall(handler)` (v1) | `onCall({region, enforceAppCheck}, handler)` from `firebase-functions/https` (v2) | firebase-functions v4+ (2022) | Single options object; no method chaining |
| `(data, context)` handler params (v1) | `(request: CallableRequest<T>)` single param (v2) | firebase-functions v4+ | `request.data`, `request.auth`, `request.app` |
| `functions.config()` for runtime config | `params` module or Secret Manager | firebase-functions v7 (2025) — v7 REMOVED `functions.config()` | Phase 2 uses v6 which still has it, but better to use params/Secret Manager from the start |
| Container Registry (gcr.io) | Artifact Registry | GCP (2022) | Cleanup policies only work on Artifact Registry |

**Deprecated/outdated in context of this phase:**
- `functions.config()`: Available in v6 but removed in v7. Phase 2 should use `params` or env vars from the start.
- `recommended-requiring-type-checking`: Renamed to `recommended-type-checked` in typescript-eslint v6. Both names work in v6-v8; use `recommended-type-checked`.
- `parserOptions.project: ['path']` (legacy): Replaced by `parserOptions.projectService: true` in typescript-eslint v8. Both work.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `admin.ts` initialization pattern `if (!admin.apps.length) admin.initializeApp()` | Pattern 3 | Admin SDK may require explicit initialization; low risk since Cloud Functions runtime sets FIREBASE_CONFIG automatically |
| A2 | Firebase Console App Check kill switch URL: `https://console.firebase.google.com/project/mentor-mind-aa765/appcheck` | App Check Detailed Notes | URL may have changed; user should navigate via Firebase Console sidebar → Build → App Check |
| A3 | `dorny/paths-filter@v4` is the correct action to use (confirmed v4.0.1 exists on GitHub) | Pattern 10 / CI | Confirmed via GitHub API; tag exists. Low risk. |
| A4 | App Check rejection returns HTTP 401 + error code `'unauthenticated'` | App Check Notes / Pitfall | Confirmed from multiple GitHub issues and Firebase callable protocol docs; MEDIUM confidence |
| A5 | The Artifact Registry repository for Cloud Functions is created automatically on first deploy | GCP CLI Commands | May need manual creation; document as Phase 3 follow-up since no deploy happens in Phase 2 |
| A6 | Apple Developer Program paid account is required for App Attest | Environment Availability | Not directly verified via CLI; standard Apple documentation states this; LOW risk of being wrong |

---

## Open Questions

1. **Apple Developer Program account status**
   - What we know: App Attest requires the App Attest capability, which requires a paid Apple Developer Program account.
   - What's unclear: Whether `arnobrizwan23@gmail.com` has a paid Developer account. Phase 1's device QA was deferred due to Apple Developer Portal App ID limit issues, suggesting possible free account.
   - Recommendation: If using a free account, App Attest CANNOT be enabled. Use `AppleProvider.appAttestWithDeviceCheckFallback` (falls back to DeviceCheck which works on free accounts) OR remain on `AppleProvider.debug` for all builds until a paid account is available. The CONTEXT.md locks App Attest for release — this is a blocker if the account is free.

2. **GCP billing account status**
   - What we know: `billingEnabled: false` for project `mentor-mind-aa765`.
   - What's unclear: Whether billing was intentionally disabled (cost concern) or accidentally not enabled.
   - Recommendation: PR-2 BACKEND_SETUP.md should include enabling billing as the first step. Budget alert ($10/mo) prevents runaway charges.

3. **Artifact Registry repository name**
   - What we know: The repository is created automatically on first Cloud Functions v2 deploy in a region.
   - What's unclear: The exact repository name before any deploy has happened.
   - Recommendation: The cleanup policy command in PR-2 BACKEND_SETUP.md should note that REPO_NAME must be filled in after Phase 3's first deploy. Leave it as a template.

---

## Sources

### Primary (HIGH confidence)
- `npm view firebase-functions@6.6.0` — version, engine requirements, repository, Node compatibility confirmed
- `npm view firebase-admin@13.10.0` — version and repository confirmed
- `npm view @typescript-eslint/eslint-plugin`, `@typescript-eslint/parser`, `eslint`, `prettier` — versions and repository confirmed
- `pub.dev API /packages/cloud_functions` — version 5.6.2 confirmed; `firebase_core ^3.15.2` dependency confirmed
- `pub.dev API /packages/firebase_app_check` — version 0.3.2+9 confirmed; AppleProvider enum values (4 values) confirmed
- `pub.dev API /packages/firebase_app_check 0.3.2+9` — environment SDK >=3.2.0, firebase_core ^3.15.1 confirmed
- `gcloud billing budgets create --help` — exact CLI flag syntax confirmed
- `gcloud billing projects describe mentor-mind-aa765` — billing account ID and billing status confirmed
- `gcloud functions list --help` — `--regions` and `--v2` flags confirmed
- `firebase.google.com/docs/app-check/flutter/default-providers` — `activate()` placement and AppleProvider usage
- `firebase.google.com/docs/app-check/ios/app-attest-provider` — App Attest entitlements key and value
- `typescript-eslint.io/getting-started/typed-linting/` — `.eslintrc.js` shape and parserOptions
- Phase 1 VALIDATION.md, 01-09 SUMMARY, 01-10 SUMMARY — existing emulator wiring patterns
- `lib/main.dart`, `test/_helpers/emulator_setup.dart` — existing code patterns to extend
- `lib/data/services/firebase_providers.dart`, `lib/data/repositories/users_repository.dart` — repository pattern to mirror
- `.github/workflows/ci.yml` — existing CI job structure

### Secondary (MEDIUM confidence)
- firebase.google.com/docs/functions/callable?gen=2nd — v2 `onCall` options object pattern and handler shape
- pub.dev/documentation/cloud_functions/latest — `FirebaseFunctions` class methods and `HttpsCallableResult` generic type
- pub.dev/documentation/firebase_app_check/latest/firebase_app_check/AppleProvider.html — 4 AppleProvider enum values
- firebase/flutterfire GitHub issues — App Check `'unauthenticated'` error code on enforceAppCheck rejection
- docs.cloud.google.com/artifact-registry/docs/repositories/cleanup-policy — `set-cleanup-policies` command and JSON format
- typescript-eslint.io — `recommended-type-checked` vs `recommended-requiring-type-checking` naming
- firebase/firebase-tools GitHub issue #5253 — Functions emulator does not enforce App Check

### Tertiary (LOW confidence — train knowledge, not independently verified this session)
- `admin.ts` singleton pattern `if (!admin.apps.length)` — standard firebase-admin practice, not verified against v13 docs
- Firebase Console App Check enforcement toggle URL path — conventional URL structure, not fetched
- Apple Developer Program requirement for App Attest capability — well-documented Apple requirement, not fetched from Apple docs

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all npm and pub.dev versions verified via registry APIs; `cloud_functions 5.6.2` + `firebase_core 3.15.2` compatibility matrix confirmed
- Architecture patterns: HIGH — code shapes verified against official docs and existing Phase 1 patterns
- Version constraints (cloud_functions 5.x vs 6.x): HIGH — verified via pub.dev API showing firebase_core dependency requirements
- Pitfalls: HIGH — App Attest sandbox issue and emulator App Check bypass confirmed via official docs + GitHub issues
- GCP CLI commands: HIGH — verified via `gcloud` CLI help
- CI job shape: HIGH — `dorny/paths-filter@v4` confirmed via GitHub API
- App Check rejection error code: MEDIUM — multiple consistent sources but not verified against firebase callable protocol spec
- Artifact Registry cleanup (Pitfall 4): HIGH — Firebase docs and github issues confirm `lib/` must NOT be in `.gcloudignore`

**Research date:** 2026-05-18
**Valid until:** 2026-06-17 (30 days — stable Firebase SDK ecosystem; re-verify `firebase_core` version bump before Phase 2 execution if significant time passes)
