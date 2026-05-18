# Phase 2: Cloud Functions Scaffolding + App Check — Pattern Map

**Mapped:** 2026-05-18
**Files analyzed:** 22 (new or modified)
**Analogs found:** 14 / 22 (8 TypeScript/config files have no in-repo analog — canonical skeletons provided from RESEARCH.md)

---

## File Classification

| New / Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------------|------|-----------|----------------|---------------|
| `lib/data/services/firebase_functions_provider.dart` | service | request-response | `lib/data/services/firebase_providers.dart` | exact |
| `lib/data/repositories/ping_repository.dart` | repository | request-response | `lib/data/repositories/users_repository.dart` | exact |
| `lib/data/models/ping_response.dart` | model | transform | `lib/data/models/chat_message.dart` | role-match |
| `lib/main.dart` (modify) | entrypoint | request-response | self (existing emulator block) | self-modify |
| `test/_helpers/emulator_setup.dart` (modify) | utility | request-response | self (existing configureEmulators body) | self-modify |
| `integration_test/ping_smoke_test.dart` | test | request-response | `integration_test/login_smoke_test.dart` | exact |
| `ios/Runner/Runner.entitlements` (modify) | config | — | self (existing keychain key) | self-modify |
| `pubspec.yaml` (modify) | config | — | self (existing firebase deps block) | self-modify |
| `firebase.json` (modify) | config | — | self (existing emulators block) | self-modify |
| `.github/workflows/ci.yml` (modify) | CI | — | self (existing `functions:` stub job) | self-modify |
| `functions/package.json` | config | — | none (new TS monorepo) | no analog — RESEARCH skeleton |
| `functions/tsconfig.json` | config | — | none | no analog — RESEARCH skeleton |
| `functions/.eslintrc.js` | config | — | none | no analog — RESEARCH skeleton |
| `functions/.prettierrc` | config | — | none | no analog — defaults |
| `functions/.gitignore` | config | — | none | no analog — literal |
| `functions/src/index.ts` | controller | request-response | none | no analog — RESEARCH Pattern 1 |
| `functions/src/lib/admin.ts` | service | request-response | none | no analog — RESEARCH Pattern 3 |
| `functions/src/lib/errors.ts` | utility | transform | none | no analog — RESEARCH Pattern 2 |
| `functions/src/lib/gemini.ts` | service stub | — | none | no analog — stub only |
| `functions/src/lib/rate_limit.ts` | service stub | — | none | no analog — stub only |
| `functions/src/lib/claims.ts` | service stub | — | none | no analog — stub only |
| `BACKEND_SETUP.md` (modify) | docs | — | self (existing headings) | self-modify |

---

## Pattern Assignments

### Group 1: Dart Services

---

#### `lib/data/services/firebase_functions_provider.dart` (service, request-response)

**Analog:** `lib/data/services/firebase_providers.dart` (lines 1–24)

**Full analog — copy structure verbatim, substitute SDK:**

```dart
// EXISTING (firebase_providers.dart lines 1-24)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Firebase SDK singleton providers — the test override seam (D-04).
// Replace FirebaseFirestore.instance / FirebaseAuth.instance /
// FirebaseStorage.instance everywhere in the app by reading from these
// providers. Tests can inject FakeFirebaseFirestore / MockFirebaseAuth via
// ProviderScope.overrides before any repository provider is first read.

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});
```

**Substitution rule:** Copy the file header comment block + `Provider<T>((ref) => ...)` structure verbatim. Replace the import with `package:cloud_functions/cloud_functions.dart` and `package:flutter_riverpod/flutter_riverpod.dart`. Replace the singleton body with `FirebaseFunctions.instanceFor(region: 'asia-south1')`. The new file declares exactly one provider: `firebaseFunctionsProvider`. Keep the banner comment explaining it is the test override seam.

**layered_imports compliance:** `cloud_functions` import is permitted in `lib/data/services/` (data layer). No presentation or application layer imports.

---

### Group 2: Dart Repositories

---

#### `lib/data/repositories/ping_repository.dart` (repository, request-response)

**Analog:** `lib/data/repositories/users_repository.dart` (lines 1–24, 61–66, 371–376)

**Imports pattern** (analog lines 1–9):

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/data/models/dashboard_user.dart';
import 'package:mentor_minds/data/services/firebase_providers.dart';
```

**Constructor pattern** (analog lines 15–24):

```dart
class UsersRepository {
  UsersRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
```

**Provider declaration pattern** (analog lines 371–376):

```dart
final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(
    firestore: ref.read(firestoreProvider),
    auth: ref.read(firebaseAuthProvider),
  );
});
```

**Substitution rule:** Copy the class header + constructor + provider declaration pattern. Replace import of `cloud_firestore`/`firebase_auth` with `cloud_functions/cloud_functions.dart`. Replace import of `firebase_providers.dart` with `firebase_functions_provider.dart`. Replace import of `dashboard_user.dart` with `ping_response.dart`. The single method `ping()` calls `_functions.httpsCallable('ping').call<dynamic>()`, casts `result.data` from `Map<Object?, Object?>` to `Map<String, dynamic>`, and returns `PingResponse.fromMap(data)`. Provider construction uses `ref.read(firebaseFunctionsProvider)` as the single argument.

**Critical detail from RESEARCH Pattern 8** — the cast is non-obvious:

```dart
// The callable returns Map<Object?, Object?> at runtime, not Map<String, dynamic>
final data = (result.data as Map<Object?, Object?>).cast<String, dynamic>();
```

**layered_imports compliance:** `cloud_functions` import is permitted at repository layer (`lib/data/repositories/`). Viewmodels may NOT import `cloud_functions` directly — they go through `pingRepositoryProvider`.

---

### Group 3: Dart Models

---

#### `lib/data/models/ping_response.dart` (model, transform)

**Analog:** `lib/data/models/chat_message.dart` (lines 64–84) — demonstrates the `static X fromMap(Map<String, dynamic> m)` pattern with safe-cast field extraction.

**fromMap pattern** (analog lines 64–75):

```dart
static ChatMessage fromMap(Map<String, dynamic> m) {
  return ChatMessage(
    id: (m['id'] as String?) ??
        'm_${DateTime.now().microsecondsSinceEpoch}',
    role: MessageRole.values.firstWhere(
      (r) => r.name == (m['role'] as String?),
      orElse: () => MessageRole.user,
    ),
    content: (m['content'] as String?) ?? '',
    timestamp:
        (m['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
```

**Alternative analog:** `lib/data/models/dashboard_user.dart` (lines 28–53) for a simpler `factory X.fromDoc(...)` + safe-cast primitive extraction without enums.

**Substitution rule:** Copy the `const` constructor + `factory X.fromMap(Map<String, dynamic> map)` factory shape. Use `as T? ?? default` safe-cast pattern for every field: `map['ok'] as bool? ?? false`, `(map['timestamp'] as num?)?.toInt() ?? 0`, `map['region'] as String? ?? ''`. No Firestore imports needed — `PingResponse` decodes from a plain Dart `Map` (not a Firestore snapshot). Use `factory` (not `static`) to align with the existing model convention in this codebase.

---

### Group 4: Dart Entrypoint / Test Wiring

---

#### `lib/main.dart` (modify — add App Check activation + Functions emulator)

**Self-modify.** Two extension points in the existing file.

**Extension point A — App Check activation** (insert after line 31, before line 48):

```dart
// EXISTING context (main.dart lines 26-48):
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

  // NEW: insert FirebaseAppCheck.instance.activate(...) here
  // BEFORE the USE_EMULATOR block and BEFORE runApp.

  const bool useEmulator =
      bool.fromEnvironment('USE_EMULATOR', defaultValue: false);
  if (useEmulator) {
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
```

**Extension point B — Functions emulator** (inside the existing `if (useEmulator)` block, lines 42–46):

```dart
  if (useEmulator) {
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
    // NEW: add FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
  }
```

**Substitution rule:** Add `import 'package:firebase_app_check/firebase_app_check.dart'` and `import 'package:flutter/foundation.dart'` (for `kReleaseMode`) to the imports block (after existing Firebase imports, alphabetically). Add `import 'package:cloud_functions/cloud_functions.dart'` for the emulator wiring. Insert `await FirebaseAppCheck.instance.activate(appleProvider: kReleaseMode ? AppleProvider.appAttest : AppleProvider.debug)` immediately after the `try/catch` Firebase init block. Append `FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001)` as the fourth line inside the `if (useEmulator)` block. The file MUST NOT import anything from `test/`.

---

#### `test/_helpers/emulator_setup.dart` (modify — add Functions emulator)

**Self-modify.** Existing file (lines 1–32) — add one line inside `configureEmulators()`.

**Existing body to extend** (lines 27–32):

```dart
Future<void> configureEmulators() async {
  if (!kUseEmulator) return;
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
  // NEW: FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
}
```

**Substitution rule:** Add `import 'package:cloud_functions/cloud_functions.dart'` to the imports block (after the existing three Firebase imports). Append `FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001)` as the last line inside the `if (!kUseEmulator) return;` guard (i.e., after the Storage line). Note: this call does NOT need `await` — it is synchronous.

---

#### `integration_test/ping_smoke_test.dart` (new)

**Analog:** `integration_test/login_smoke_test.dart` (lines 1–50)

**Full scaffold pattern** (lines 20–50):

```dart
@Tags(<String>['emulator', 'integration'])
library;

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
    // login_smoke_test adds user seeding here — not needed for ping
  });

  testWidgets('sign-in smoke — emulator → dashboard', (tester) async {
    // ... assertions
  });
}
```

**Substitution rule:** Copy the `@Tags`, `library;`, `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`, `setUpAll` with `Firebase.initializeApp` + `configureEmulators()` scaffold verbatim. Remove the user-seeding block (not needed for ping). Replace the `testWidgets` body: add `import 'package:cloud_functions/cloud_functions.dart'`, invoke `FirebaseFunctions.instance.httpsCallable('ping').call<dynamic>()`, cast `result.data` as `Map<Object?, Object?>` → `.cast<String, dynamic>()`, assert `data['ok'] == true`, `data['timestamp']` is `isA<int>()`, and `data['region'] == 'asia-south1'`. Wrap the call in a `Stopwatch` and assert `elapsedMilliseconds < 1000`. Do NOT import `mentor_minds/main.dart` — this test calls the callable directly, not through the app widget.

---

### Group 5: iOS Native Config

---

#### `ios/Runner/Runner.entitlements` (modify — add App Attest environment)

**Self-modify.** Existing plist (lines 1–10):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
  <key>keychain-access-groups</key>
  <array>
    <string>$(AppIdentifierPrefix)com.mentorminds.mentorMinds</string>
  </array>
</dict>
</plist>
```

**Substitution rule:** Insert the following key-value pair inside the `<dict>` element, after the existing `keychain-access-groups` array and before the closing `</dict>`:

```xml
  <key>com.apple.developer.devicecheck.appattest.environment</key>
  <string>production</string>
```

This forces App Attest to use production mode on all builds (preventing sandbox token rejection by Firebase App Check). The App Attest Xcode capability must also be added via Xcode → Signing & Capabilities → `+` → App Attest — this is a manual step that modifies the `.xcodeproj` entitlements linkage and cannot be done by editing the plist alone.

---

### Group 6: Flutter Config

---

#### `pubspec.yaml` (modify — add cloud_functions + firebase_app_check)

**Self-modify.** Existing Firebase deps block (lines 27–33):

```yaml
  # Firebase
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.4.3
  firebase_storage: ^12.3.2
  firebase_messaging: ^15.1.3
  google_sign_in: ^6.2.1
```

**Substitution rule:** Append two lines to the Firebase deps block, after `google_sign_in`:

```yaml
  cloud_functions: ^5.6.2
  firebase_app_check: ^0.3.2+9
```

**Version constraint is safety-critical:** `cloud_functions ^6.x` requires `firebase_core ^4.x` and will break pub resolution against the existing `firebase_core 3.15.2`. Same for `firebase_app_check ^0.4.x`. These exact constraints (`^5.6.2` / `^0.3.2+9`) are the only versions verified compatible with `firebase_core 3.15.2`. Run `flutter pub get` after editing and confirm it resolves without conflict.

---

#### `firebase.json` (modify — add functions emulator port)

**Self-modify.** Existing emulators block (single-line JSON):

```json
{
  "emulators": {
    "auth": {"port": 9099},
    "firestore": {"port": 8080},
    "storage": {"port": 9199},
    "ui": {"enabled": true, "port": 4000}
  }
}
```

**Substitution rule:** Insert `"functions": {"port": 5001}` between `"storage"` and `"ui"` in the emulators object. The maintained order is: `auth → firestore → storage → functions → ui`. Port 5001 is the Firebase default for the Functions emulator — matches every Firebase CLI example and the `useFunctionsEmulator('localhost', 5001)` calls in `emulator_setup.dart` and `lib/main.dart`.

---

### Group 7: CI

---

#### `.github/workflows/ci.yml` (modify — lift the functions job stub)

**Self-modify.** Existing stub (lines 99–115):

```yaml
  functions:
    name: Cloud Functions lint + build (stub until Phase 2)
    runs-on: ubuntu-latest
    timeout-minutes: 10
    if: false  # Phase 1: functions/ does not exist; replaced in Phase 2

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - name: Functions CI stub
        run: echo "Functions CI stub — no-op until Phase 2"
        # Phase 2 will replace this with:
        #   cd functions && npm ci && npm run lint && npm run build
```

**Substitution rule:** Remove the `if: false` line. Replace the `name` value with `Cloud Functions lint + build (CI-03)`. Remove the `Functions CI stub` step and its echo. Add a `dorny/paths-filter@v4` step as the second step (after `actions/checkout@v4`) to gate subsequent steps on `functions/**` path changes. Conditionalize the `setup-node`, install, and build steps with `if: steps.filter.outputs.functions == 'true'`. The final shape follows RESEARCH Pattern 10:

```yaml
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

---

### Group 8: TypeScript Monorepo (no in-repo analogs — RESEARCH skeletons)

---

#### `functions/package.json` (new — no analog)

**Source:** RESEARCH §Standard Stack + `firebase init functions` convention for v2.

**Canonical skeleton (25 lines):**

```json
{
  "name": "mentor-minds-functions",
  "description": "MentorMinds Cloud Functions (v2, asia-south1)",
  "version": "1.0.0",
  "private": true,
  "engines": {
    "node": "20"
  },
  "main": "lib/index.js",
  "scripts": {
    "build": "tsc",
    "build:watch": "tsc --watch",
    "lint": "eslint --ext .ts src/",
    "serve": "npm run build && firebase emulators:start --only functions"
  },
  "dependencies": {
    "firebase-admin": "^13.10.0",
    "firebase-functions": "^6.6.0"
  },
  "devDependencies": {
    "@typescript-eslint/eslint-plugin": "^8.59.3",
    "@typescript-eslint/parser": "^8.59.3",
    "eslint": "^10.4.0",
    "prettier": "^3.8.3",
    "typescript": "^5.8.3"
  }
}
```

**Substitution rule:** Use this skeleton verbatim. `"node": "20"` is non-negotiable (firebase-functions v6 minimum). `"main": "lib/index.js"` must point to the compiled output dir. No `jest` devDep in Phase 2 (defer per CONTEXT.md discretion — if a trivial errors.test.ts is added, `jest` + `ts-jest` + `@types/jest` can be added then). `functions/package-lock.json` must be committed after `npm install` (CI uses `npm ci`).

---

#### `functions/tsconfig.json` (new — no analog)

**Source:** RESEARCH Pattern 4.

**Canonical skeleton:**

```json
{
  "compilerOptions": {
    "module": "commonjs",
    "noImplicitReturns": true,
    "noUnusedLocals": true,
    "outDir": "lib",
    "rootDir": "src",
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

**Substitution rule:** Use verbatim. `"rootDir": "src"` is required so `tsc` does not traverse parent directories. `"noUncheckedIndexedAccess": true` causes array index access to return `T | undefined` — any code touching `request.data` as an array must null-check. This is intentional per CONTEXT.md discretion.

---

#### `functions/.eslintrc.js` (new — no analog)

**Source:** RESEARCH Pattern 5.

**Canonical skeleton:**

```javascript
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
  ignorePatterns: ["/lib/**/*", "/generated/**/*"],
  plugins: ["@typescript-eslint"],
  rules: {},
};
```

**Substitution rule:** Use verbatim. The `project: true` shorthand (typescript-eslint v6+) lets the parser auto-discover `tsconfig.json` in the same directory. `ignorePatterns: ["/lib/**/*"]` prevents linting compiled output. The extends array order matters: `recommended` rules first, then `recommended-type-checked` (type-aware superset).

---

#### `functions/.prettierrc` (new — no analog)

**Canonical content:** `{}`

**Substitution rule:** An empty object `{}` means "use prettier's built-in defaults": `singleQuote: false` (double quotes), `semi: true`, `trailingComma: "all"`. This is what `firebase init functions` would write. The file must exist so prettier-aware editors and `prettier --check` find the config.

---

#### `functions/.gitignore` (new — no analog)

**Canonical content:**

```
lib/
node_modules/
```

**Substitution rule:** `lib/` is the TypeScript compiled output — must be gitignored (do NOT add to `.gcloudignore`; Firebase deploy reads it from disk). `node_modules/` is standard. No other entries needed in Phase 2.

---

#### `functions/src/index.ts` (new — no analog)

**Source:** RESEARCH Pattern 1 (firebase-functions v2 `onCall` with region + enforceAppCheck).

**Canonical skeleton:**

```typescript
import { onCall } from "firebase-functions/https";

export const ping = onCall(
  {
    region: "asia-south1",
    enforceAppCheck: true,
  },
  (_request) => {
    return {
      ok: true,
      timestamp: Date.now(),
      region: "asia-south1",
    };
  }
);
```

**Substitution rule:** Use verbatim. Import from `"firebase-functions/https"` (not `"firebase-functions/v2/https"` — the v6 package re-exports from the root `https` path). The handler parameter is `_request` (prefixed underscore) because `noUnusedLocals: true` would fail if it were `request` and unused. `enforceAppCheck: true` is set server-side here; the Functions emulator ignores it, which is expected behavior per RESEARCH Pitfall 6. Do NOT import `admin.ts` — the `ping` function does not touch Firestore or Auth.

---

#### `functions/src/lib/admin.ts` (new — no analog)

**Source:** RESEARCH Pattern 3.

**Canonical skeleton:**

```typescript
import * as admin from "firebase-admin";

// Singleton: initializeApp() uses FIREBASE_CONFIG env var set by the runtime.
// Guard prevents re-initialization when the module is hot-reloaded in emulator.
if (!admin.apps.length) {
  admin.initializeApp();
}

export const db = admin.firestore();
export const auth = admin.auth();
export default admin;
```

**Substitution rule:** Use verbatim. The `if (!admin.apps.length)` guard is mandatory — without it, calling `initializeApp()` twice (e.g., in emulator hot-reload) throws. Export named `db` and `auth` helpers so callables never call `admin.firestore()` / `admin.auth()` inline (avoids re-creating instances). The default export of `admin` is for edge cases that need the full SDK.

---

#### `functions/src/lib/errors.ts` (new — no analog)

**Source:** RESEARCH Pattern 2.

**Canonical skeleton:**

```typescript
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

export function invalidArgument(message: string): HttpsError {
  return new HttpsError("invalid-argument", message);
}

export function internal(message: string): HttpsError {
  return new HttpsError("internal", message);
}

export function mapKnownError(error: unknown): HttpsError {
  if (error instanceof HttpsError) return error;
  const msg = error instanceof Error ? error.message : "Unknown error";
  return new HttpsError("internal", msg);
}
```

**Substitution rule:** Use verbatim. These are the five factory functions specified in CONTEXT.md D-05 plus `mapKnownError`. Import from `"firebase-functions/https"` (same path as `onCall`). The `mapKnownError` function is the target of the trivial unit test in `functions/src/__tests__/errors.test.ts` (CONTEXT.md discretion item).

---

#### `functions/src/lib/gemini.ts` (new — stub only)

**Canonical skeleton:**

```typescript
// Phase 3 interface — stub only. Do NOT implement in Phase 2.

export interface GeminiCallOptions {
  maxOutputTokens?: number;
  temperature?: number;
}

export interface GeminiResponse {
  text: string;
  finishReason?: string;
}

export async function callGemini(
  prompt: string,
  _opts?: GeminiCallOptions
): Promise<GeminiResponse> {
  throw new Error("not implemented — see Phase 3");
}
```

**Substitution rule:** Implement as a pure TypeScript interface stub with a `throw new Error('not implemented — see Phase 3')` body. No `@google/generative-ai` SDK import (D-20: NO Gemini code in Phase 2). The interface shape stabilizes the import contract so Phase 3 only needs to fill in the body without changing callers.

---

#### `functions/src/lib/rate_limit.ts` (new — stub only)

**Canonical skeleton:**

```typescript
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
```

**Substitution rule:** Stub only — `throw new Error('not implemented — see Phase 3')`. Parameters prefixed with `_` to satisfy `noUnusedLocals`. The `resetAt` field is documented as "midnight UTC+6" for the Phase 3 implementer.

---

#### `functions/src/lib/claims.ts` (new — stub only)

**Canonical skeleton:**

```typescript
// Phase 5 interface — stub only. Do NOT implement in Phase 2.

export type UserRole = "student" | "teacher" | "admin";

export async function setPremium(
  _uid: string,
  _isPremium: boolean
): Promise<void> {
  throw new Error("not implemented — see Phase 5");
}

export async function getRole(_uid: string): Promise<UserRole> {
  throw new Error("not implemented — see Phase 5");
}
```

**Substitution rule:** Stub only — `throw new Error('not implemented — see Phase 5')`. The `UserRole` union type matches the three roles used across the Dart codebase (CLAUDE.md conventions). Parameters prefixed with `_` for `noUnusedLocals`.

---

### Group 9: Docs

---

#### `BACKEND_SETUP.md` (modify — add Phase 2 section)

**Self-modify.** Existing structure (first 60 lines shows sections 1–5). The new Phase 2 section appends after the existing content.

**Existing headings pattern:**

```markdown
## 1. Prerequisites
## 2. Create the Firebase project
## 3. Enable the products the app uses
## 4. Wire the app
## 5. Deploy security rules + indexes
```

**Substitution rule:** Append a new top-level section `## Phase 2 — Cloud Functions + App Check Setup` with these subsections:

1. **Enable billing** — `gcloud billing projects link mentor-mind-aa765 --billing-account=0121EC-5D572E-57FEE1` (prerequisite before any Functions deploy or budget creation)
2. **Billing budget ($10/mo)** — the exact `gcloud billing budgets create` command from RESEARCH §GCP CLI Commands, with note that the command is NOT idempotent (check with `list` before re-running), and that `arnobrizwan23@gmail.com` must be a billing admin on account `0121EC-5D572E-57FEE1`
3. **Artifact Registry cleanup (last 3 versions)** — the three-step command from RESEARCH §FUNC-05 (list repos → create keep-last-3.json → set-cleanup-policies); leave `REPO_NAME` as a template placeholder because the repository is auto-created on first Phase 3 deploy
4. **Region pin verification** — `gcloud functions list --regions=asia-south1 --gen2` and the "DO NOT" warning against `us-central1`
5. **App Check kill-switch URL** — Firebase Console direct URL pattern: `https://console.firebase.google.com/project/mentor-mind-aa765/appcheck` with note that the "Enforce" toggle per-app controls the kill switch
6. **Debug token registration steps** — (a) run `flutter run -d <simulator>` on a dev build; (b) copy the auto-generated debug token from the Xcode console log line `[Firebase/AppCheck][I-FAC...] Debug App Attest token: <token>`; (c) Firebase Console → App Check → Apps → MentorMinds iOS → Debug tokens → Add debug token; (d) confirm emulator test is unaffected (emulator bypasses App Check); (e) confirm production callable (Phase 3+) accepts the token
7. **CI secret `APP_CHECK_DEBUG_TOKEN`** — document that the secret is stored in GitHub Actions → Settings → Secrets and Variables → Actions → `APP_CHECK_DEBUG_TOKEN`; note that Phase 2's emulator integration test does NOT use this secret (emulator bypasses App Check); the secret is reserved for Phase 3+ when CI calls production-path enforcement

---

## Shared Patterns

### SDK singleton provider
**Source:** `lib/data/services/firebase_providers.dart` (lines 14–24)
**Apply to:** `lib/data/services/firebase_functions_provider.dart`

```dart
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});
```

Pattern: one `Provider<T>((ref) => SDK.instance)` per SDK type. Test override seam via `ProviderScope.overrides`. No `autoDispose` (SDK singletons live for the app lifetime).

---

### Repository constructor injection
**Source:** `lib/data/repositories/users_repository.dart` (lines 15–23, 371–376)
**Apply to:** `lib/data/repositories/ping_repository.dart`

```dart
class UsersRepository {
  UsersRepository({required FirebaseFirestore firestore, ...})
      : _firestore = firestore, ...;
  final FirebaseFirestore _firestore;
}

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(firestore: ref.read(firestoreProvider), ...);
});
```

Pattern: named required constructor parameter → private final field. Provider at bottom of file uses `ref.read` (not `ref.watch`) for SDK instances (they never change). No `autoDispose` — repositories are stateless and cheap to keep alive.

---

### Safe-cast fromMap factory
**Source:** `lib/data/models/chat_message.dart` (lines 64–75) and `lib/data/models/dashboard_user.dart` (lines 28–53)
**Apply to:** `lib/data/models/ping_response.dart`

```dart
factory DashboardUser.fromDoc(String uid, Map<String, dynamic> data, ...) {
  return DashboardUser(
    role: (data['role'] as String?)?.trim() ?? 'student',
    points: (data['points'] as num?)?.toInt() ?? 0,
    ...
  );
}
```

Pattern: every field extraction uses `as T? ?? default` — never bare `data['key'] as T` which throws on null or type mismatch. Use `(data['key'] as num?)?.toInt()` for integer fields to handle both `int` and `double` from the wire.

---

### Integration test scaffold
**Source:** `integration_test/login_smoke_test.dart` (lines 20–50)
**Apply to:** `integration_test/ping_smoke_test.dart`

```dart
@Tags(<String>['emulator', 'integration'])
library;

// ... imports

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await configureEmulators();
  });
  testWidgets('...', (tester) async { ... });
}
```

Pattern: library-level `@Tags` + `library;` (not `library name;`) for tag-based test selection via `dart_test.yaml`. Always `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` first in `main()`. `setUpAll` runs `Firebase.initializeApp` + `configureEmulators()` in that order.

---

### Emulator block (lib/main.dart)
**Source:** `lib/main.dart` (lines 40–46)
**Apply to:** `lib/main.dart` (extend the existing block) + `test/_helpers/emulator_setup.dart`

```dart
const bool useEmulator =
    bool.fromEnvironment('USE_EMULATOR', defaultValue: false);
if (useEmulator) {
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
  // pattern: append new SDK emulator wiring as a new line here
}
```

Pattern: `bool.fromEnvironment` compile-time const gates emulator wiring. Each SDK's `use*Emulator` call is one line. Order: Firestore (sync) → Auth (async, awaited) → Storage (async, awaited) → Functions (sync, no await needed). The `lib/` block and the `test/` block are intentionally duplicated — lib MUST NOT import test.

---

## No Analog Found

Files with no close in-repo match (planner uses RESEARCH.md pattern skeletons):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `functions/package.json` | config | — | No Node.js/npm project exists in repo; use RESEARCH §Standard Stack skeleton |
| `functions/tsconfig.json` | config | — | No TypeScript project exists in repo; use RESEARCH Pattern 4 |
| `functions/.eslintrc.js` | config | — | No ESLint config in repo; use RESEARCH Pattern 5 |
| `functions/.prettierrc` | config | — | No prettier config in repo; use `{}` defaults |
| `functions/.gitignore` | config | — | No functions-level .gitignore; use `lib/\nnode_modules/` |
| `functions/src/index.ts` | controller | request-response | No TypeScript callables in repo; use RESEARCH Pattern 1 |
| `functions/src/lib/admin.ts` | service | request-response | No Admin SDK wrappers in repo; use RESEARCH Pattern 3 |
| `functions/src/lib/errors.ts` | utility | transform | No HttpsError factories in repo; use RESEARCH Pattern 2 |

---

## Metadata

**Analog search scope:** `lib/data/services/`, `lib/data/repositories/`, `lib/data/models/`, `lib/main.dart`, `test/_helpers/`, `integration_test/`, `ios/Runner/`, `pubspec.yaml`, `firebase.json`, `.github/workflows/`
**Files scanned (analog reads):** 12 existing files
**Pattern extraction date:** 2026-05-18

---

## PATTERN MAPPING COMPLETE

**Phase:** 02 — Cloud Functions Scaffolding + App Check
**Files classified:** 22
**Analogs found:** 14 / 22

### Coverage
- Files with exact analog: 2 (`firebase_functions_provider.dart` → `firebase_providers.dart`; `ping_smoke_test.dart` → `login_smoke_test.dart`)
- Files with role-match analog: 2 (`ping_repository.dart` → `users_repository.dart`; `ping_response.dart` → `chat_message.dart`)
- Files that are self-modifications (extend existing): 8 (`main.dart`, `emulator_setup.dart`, `Runner.entitlements`, `pubspec.yaml`, `firebase.json`, `ci.yml`, `BACKEND_SETUP.md`, and the existing `users_repository.dart` provider pattern re-used)
- Files with no in-repo analog (RESEARCH skeleton): 8 (all `functions/` directory files)

### Key Patterns Identified
- All Dart service providers follow `Provider<T>((ref) => SDK.instance)` declared at the bottom of the file — `firebase_functions_provider.dart` copies exactly
- All repositories take SDK dependencies as named required constructor params and declare a bottom-of-file `Provider` using `ref.read` — `ping_repository.dart` copies exactly
- All model `fromMap` factories use `as T? ?? default` safe-cast extraction, never bare casts — `ping_response.dart` copies exactly
- The `HttpsCallableResult.data` cast from `Map<Object?, Object?>` to `Map<String, dynamic>` is the one non-obvious addition (no Firestore analog) — extracted from RESEARCH Pattern 8
- All integration tests share: `@Tags` + `library;` + `IntegrationTestWidgetsFlutterBinding` + `setUpAll(Firebase.initializeApp + configureEmulators)` scaffold
- `layered_imports` custom_lint rule gates: `cloud_functions` imports are restricted to `lib/data/` — viewmodels MUST NOT import the SDK directly

### File Created
`/Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-PATTERNS.md`

### Ready for Planning
Pattern mapping complete. Planner can now reference analog patterns in PLAN.md files for all 10 planned plan slugs (02-01 through 02-10 per VALIDATION.md Per-Plan Verification Map).
