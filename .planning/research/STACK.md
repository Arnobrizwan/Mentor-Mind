# Stack Research — MentorMinds v1.0 NEW Capabilities

**Domain:** iOS-only Flutter + Firebase tutoring app (subsequent milestone)
**Researched:** 2026-05-17
**Confidence:** MEDIUM overall

> **Scope:** This file covers ONLY the NEW libraries / services required for the v1.0 hardening milestone. The existing locked stack (Flutter 3.41 / Dart 3.11 / Riverpod 2.6.1 / GoRouter 14.8.1 / firebase_core 3.15.2 / firebase_auth 5.7.0 / cloud_firestore 5.6.12 / firebase_storage 12.4.10 / firebase_messaging 15.2.10 / google_sign_in 6.3.0 / google_generative_ai 0.4.7 / image_picker 1.2.1) is documented in `.planning/codebase/STACK.md` and is NOT re-researched here.
>
> **Research tooling constraint:** WebFetch / WebSearch / Context7 CLI were all denied in this agent's sandbox. Version pins below are anchored to (a) the FlutterFire BoM-equivalent generation already resolved in `pubspec.lock` (firebase_core 3.15.x → mid-2025 family) and (b) widely-known stable releases as of model knowledge cutoff (Jan 2026). Every "MEDIUM" or "LOW" confidence pin below SHOULD be re-verified with `flutter pub outdated` / `flutter pub upgrade --major-versions` before being committed to `pubspec.yaml`. Where I'd ordinarily pin a hard version, I use a caret range that resolves cleanly against firebase_core ^3.15.2.

---

## 1. Cloud Functions for Firebase — Gemini proxy + server-authoritative writes

### Runtime decision: Node.js + TypeScript (NOT Dart)

| Aspect | Recommendation | Why |
|---|---|---|
| Language | **TypeScript** | The `firebase-functions` and `firebase-admin` SDKs are first-class for Node; Dart-on-Functions is technically supported via the FlutterFire Dart Functions SDK but the runtime is still Node under the hood, deployment story is more brittle, the Gemini SDK ergonomics on Node are stronger, and the existing `tool/seed/seed.js` already runs Node 18+ with `firebase-admin` — so the project already has Node tooling. |
| Node runtime | **Node 20** (`nodejs20` in `functions/package.json` → `"engines": { "node": "20" }`) | Node 22 became GA on Cloud Functions for Firebase in 2025 but Node 20 LTS is still the safer default through April 2026 (Active LTS until 2025-10, Maintenance until 2026-04). For v1.0 launch within the next quarter, Node 20 is the lowest-risk pin. Re-evaluate at v1.1 — by then Node 22 LTS will be Active and the right default. |
| Functions generation | **v2 (Cloud Run-backed)** via `firebase-functions/v2/https` (`onCall`, `onRequest`) and `firebase-functions/v2/firestore` (`onDocumentWritten`) | v1 is in long-term maintenance only; v2 gives concurrency (up to 1000 req/instance), per-function min/max instances, and proper Cloud Run-based cold-start behaviour. Do NOT mix v1 + v2 in the same `index.ts` — pick v2 across the board. |
| Region | **`asia-south1` (Mumbai)** | Closest GCP region to Bangladesh users with full Gen2 functions support. Latency from Dhaka to `asia-south1` is ~50ms vs ~150ms to `us-central1`. Set on each function: `setGlobalOptions({ region: 'asia-south1', maxInstances: 10 })`. |
| Function shape for Gemini proxy | **`onCall`** (not `onRequest`) | `onCall` auto-validates the Firebase Auth JWT + App Check token, returns structured errors, no CORS wiring needed. The client uses `cloud_functions` package `httpsCallable('askMentorBot')`. |
| Function shape for points/rewards | **`onDocumentWritten` on `/users/{uid}/usage/{date}`** + admin-only `awardPoints` callable | Trigger-on-write so the client cannot bypass it by skipping a callable. Sole writer to `/rewards/{uid}` becomes the function (tighten `firestore.rules` to deny client writes to `/rewards/{uid}` and `/users/{uid}.points`). |
| Streaming support | **`onCallGenkit`** OR raw HTTPS streaming via `onRequest` + SSE | Gemini streams token-by-token. Standard `onCall` cannot stream a response. Two options: (1) use Firebase Genkit's `onCallGenkit` which has first-class streaming + works with the `cloud_functions` Flutter client (added 2024-Q4), or (2) drop to `onRequest` + Server-Sent Events and consume via Dart `http` package. **Recommend Genkit** — it's purpose-built for AI workloads, ships with retry/observability, and uses the same App Check token as plain `onCall`. |

### Dart-side package

| Package | Version | Purpose | Confidence |
|---|---|---|---|
| `cloud_functions` | `^5.2.0` | Calls `httpsCallable('askMentorBot')` from the Flutter client; bundled JWT + App Check token in-flight | MEDIUM — must match the firebase_core 3.15.x BoM generation. Resolve with `flutter pub add cloud_functions` and verify the pin doesn't downgrade firebase_core. |

### Functions-side `package.json`

```jsonc
{
  "engines": { "node": "20" },
  "main": "lib/index.js",
  "dependencies": {
    "firebase-admin": "^13.0.0",         // already in tool/seed/
    "firebase-functions": "^6.0.0",      // v2 API; ^6 is the current major as of late-2025
    "@google/genai": "^1.0.0",           // NEW unified Gemini SDK (replaces @google/generative-ai)
    "genkit": "^1.0.0",                  // optional, for streaming via onCallGenkit
    "@genkit-ai/googleai": "^1.0.0",     // Gemini plugin for Genkit
    "@genkit-ai/firebase": "^1.0.0"      // onCallGenkit wrapper
  },
  "devDependencies": {
    "typescript": "^5.4.0",
    "@types/node": "^20.0.0",
    "firebase-functions-test": "^3.3.0"
  }
}
```

> **IMPORTANT — Gemini SDK rename:** Google deprecated `@google/generative-ai` in late 2024 and replaced it with the unified `@google/genai` package (also serves Vertex AI). The Dart `google_generative_ai 0.4.7` package on the client is also legacy — but since this milestone is moving Gemini *off* the client, the Dart-side Gemini SDK can be removed from `pubspec.yaml` once the proxy lands. Inside the Cloud Function, use `@google/genai`, NOT `@google/generative-ai`.

### What NOT to use here

| Avoid | Why | Use instead |
|---|---|---|
| `firebase-functions` v1 API (`functions.https.onCall`) | Maintenance-only, no per-function options, no concurrency, slower cold starts | v2 (`firebase-functions/v2/https`) |
| `@google/generative-ai` on the function | Deprecated, no Vertex parity, no support for Gemini 2.x features | `@google/genai` |
| Dart Cloud Functions runtime | Unstable, smaller ecosystem, no Genkit support | TypeScript on Node 20 |
| Mixing `gemini-1.5-flash` (current Dart client model) with `gemini-2.0-flash` on the function | Drift between request shapes and response formats | Standardise on **`gemini-2.0-flash`** (or `gemini-2.5-flash` if released and stable by deploy time) in the function; the client should not know the model name. |

---

## 2. Firebase App Check — bind Gemini callable to genuine app installs

| Package | Version | Purpose | Confidence |
|---|---|---|---|
| `firebase_app_check` | `^0.3.2` | Issues attestation tokens; injects them into every Firebase request including `httpsCallable` | MEDIUM — needs to match firebase_core 3.15.x generation; verify with `flutter pub add firebase_app_check` |

### iOS provider decision: App Attest (primary) + DeviceCheck (fallback)

| Provider | When to use | Min iOS |
|---|---|---|
| **App Attest** (`AppleProvider.appAttest`) | Default for production. Hardware-attested. | iOS 14.0+ |
| **DeviceCheck** (`AppleProvider.deviceCheck`) | Fallback for iOS 11.0–13.x | iOS 11.0+ |
| **Debug provider** (`AppleProvider.debug`) | Simulator + local dev ONLY; emits a debug token that must be registered in the Firebase console | dev-only |

> **MentorMinds-specific:** The iOS deployment target is **13.0** (`ios/Podfile` post-install hook). App Attest requires iOS 14+, so a non-trivial slice of users on iOS 13 will hit the DeviceCheck fallback. **Recommend bumping the iOS deployment target to 14.0** — Apple stopped signing iOS 13 in 2023, so the addressable population on iOS 13 is effectively zero, and 14+ unlocks AppAttest plus removes a bunch of `@available` annotations. If the bump is unacceptable, use `AppleProviderFactory` with `appAttestWithDeviceCheckFallback` so old devices still work.

### Activation snippet (for the architecture file to reference)

```dart
// lib/main.dart — after Firebase.initializeApp(...)
await FirebaseAppCheck.instance.activate(
  appleProvider: kDebugMode
      ? AppleProvider.debug
      : AppleProvider.appAttestWithDeviceCheckFallback,
);
```

### Server-side enforcement

- In each callable, set `enforceAppCheck: true` in the v2 options:
  ```ts
  export const askMentorBot = onCall(
    { region: 'asia-south1', enforceAppCheck: true, consumeAppCheckToken: true },
    async (req) => { /* ... */ }
  );
  ```
- In the Firebase console, **enforce** App Check on Cloud Functions, Cloud Firestore, and Cloud Storage (the latter two protect against direct-from-binary REST hits with stolen `firebase_options.dart` keys).

### What NOT to use here

| Avoid | Why | Use instead |
|---|---|---|
| reCAPTCHA Enterprise on iOS | Not applicable to native iOS; that's the web provider | App Attest + DeviceCheck |
| App Attest only (no fallback) | Breaks the 0.2% of users on iOS 13 even after a deployment bump won't help legacy installs | `appAttestWithDeviceCheckFallback` |
| Skipping `consumeAppCheckToken: true` | Allows token replay; defeats anti-abuse | Always consume on the Gemini callable |

---

## 3. Firebase Crashlytics — production crash reporting

| Package | Version | Purpose | Confidence |
|---|---|---|---|
| `firebase_crashlytics` | `^4.1.0` | Native iOS crash + Dart uncaught error capture | MEDIUM |

### Integration pattern

```dart
// lib/main.dart
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  return true;
};
```

### iOS build setup (manual, not pub-managed)

- Upload dSYM symbols on every release. Either:
  - (a) Enable in Xcode Run Script phase per FlutterFire docs (`${PODS_ROOT}/FirebaseCrashlytics/upload-symbols`), OR
  - (b) Use the `firebase_crashlytics` Gradle plugin equivalent on iOS via `fastlane upload_symbols_to_crashlytics` once Fastlane lands.
- For TestFlight/App Store builds with bitcode disabled (default since Xcode 14), the in-Xcode Run Script approach is sufficient.

### What NOT to use here

| Avoid | Why | Use instead |
|---|---|---|
| Sentry | Adds another vendor, billing surface, and SDK surface area for a solo dev. Firebase is already the backend. | Firebase Crashlytics |
| `flutter_crashlytics` (third-party legacy) | Discontinued; pre-FlutterFire | `firebase_crashlytics` (official) |
| Treating `debugPrint` as observability | Existing code uses `debugPrint` in viewmodels — strip these or wrap behind a logger that forwards to Crashlytics `log()` for breadcrumbs in release | Crashlytics `log()` + `recordError()` |

---

## 4. Firebase Analytics — product telemetry

| Package | Version | Purpose | Confidence |
|---|---|---|---|
| `firebase_analytics` | `^11.3.0` | Screen views + custom events + audiences; also required by Crashlytics for full breadcrumb context | MEDIUM |

### Integration with GoRouter

GoRouter 14.x exposes `observers:` on `GoRouter()`; add `FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)` so every route push fires a `screen_view` event. This is the single highest-leverage integration — gets the 12-screen funnel "for free".

### Privacy notes (matter for App Store review)

- Set `setAnalyticsCollectionEnabled(false)` until the user accepts a consent banner if shipping to EU users. For Bangladesh-only v1.0 this is *less* critical, but App Store Connect's data privacy questionnaire still must declare collection.
- IDFA: `firebase_analytics 11.x` does NOT call `ATTrackingManager.requestTrackingAuthorization` unless you also add Google Mobile Ads or explicitly enable it. Leave it off for v1.0 unless ads are added.
- `GoogleService-Info.plist` currently has `IS_ANALYTICS_ENABLED = false` — flip this to `true` when adding the package.

### What NOT to use here

| Avoid | Why | Use instead |
|---|---|---|
| Mixpanel / Amplitude / PostHog | Extra vendor, extra cost; Firebase Analytics is free at MentorMinds' scale (<10M events/month) and integrates with Crashlytics, Remote Config, A/B Testing if needed later | `firebase_analytics` |
| `firebase_dynamic_links` for deep-link attribution | **DEPRECATED — Firebase Dynamic Links service shuts down August 2025.** Do not add. | Branch.io if attribution is truly needed; otherwise use App Links (universal links) directly — but for v1.0, just don't add it. |

---

## 5. GitHub Actions CI

### Workflow file: `.github/workflows/ci.yml`

| Component | Recommendation | Why |
|---|---|---|
| Runner | `macos-14` (Apple Silicon, M1) | Required for any iOS-related step; also faster than Intel runners. For pure `flutter analyze` / `flutter test` (no iOS build), `ubuntu-latest` is 5× cheaper and faster — recommend Ubuntu for PR checks, macOS only for nightly iOS build smoke. |
| Flutter setup action | `subosito/flutter-action@v2` | De-facto standard, 30k+ users, maintained. Pin `flutter-version: '3.41.3'` and `channel: stable` to match `.metadata`. |
| Caching | Built into `subosito/flutter-action@v2` via `cache: true` | Caches Dart pub + Flutter SDK. Cuts cold install from ~3min to ~30s. |
| iOS build (optional, nightly only) | `actions/cache@v4` for CocoaPods (`Pods/` and `~/Library/Caches/CocoaPods`) | Pod install is the slowest step; cache by `Podfile.lock` hash. |
| Secrets | Store `GEMINI_API_KEY` in GitHub Actions repo secrets — but ONLY for the integration test job. Unit tests must NOT need it (gemini service must be mockable). | After the Cloud Function proxy lands, the client no longer needs this secret at all — remove it from CI. |

### Minimal v1.0 workflow scope

```yaml
# .github/workflows/ci.yml — sketch only
name: ci
on:
  pull_request:
  push:
    branches: [main]
jobs:
  analyze-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.3'
          channel: stable
          cache: true
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter analyze
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v5    # optional, but free for public repos
        if: success()
```

### What NOT to use here

| Avoid | Why | Use instead |
|---|---|---|
| CircleCI / Bitrise / Codemagic | Extra vendor signup and billing for a solo dev. GitHub Actions has 2000 free min/month on private repos which is plenty. | GitHub Actions |
| `flutter-action@v1` | Deprecated, no Apple Silicon support | `subosito/flutter-action@v2` |
| Running `flutter test` without `dart run build_runner build` first | Riverpod codegen + Injectable codegen produce `.g.dart` files that source-importing code expects | Always codegen before analyze/test |
| `flutter pub get --offline` in CI | Pointless; CI has internet and no cached lockfile | Plain `flutter pub get` |

---

## 6. Test / mock libraries (currently absent from `dev_dependencies`)

| Package | Version | Purpose | Confidence |
|---|---|---|---|
| `mocktail` | `^1.0.4` | Mock classes without code-gen (no `@GenerateMocks`). Plays well with Riverpod's `ProviderContainer.read`. | HIGH — stable since 2023, widely adopted |
| `fake_cloud_firestore` | `^3.1.0` | In-memory Firestore for viewmodel tests. Supports queries, security-rule-agnostic. | MEDIUM — track the firebase_core major (3.x); confirm pin |
| `firebase_auth_mocks` | `^0.14.0` | In-memory FirebaseAuth for tests. Pairs with `fake_cloud_firestore`. | MEDIUM |
| `integration_test` | (Flutter SDK) | E2E tests with real widget tree; runs in simulator/device. Add via `dev_dependencies: integration_test: sdk: flutter`. | HIGH |
| `golden_toolkit` | `^0.15.0` | Multi-device golden snapshots (the 12 screens × small/large/tablet). Catches the kind of regression the spec exists to prevent. | HIGH — official Very Good Ventures package |
| `network_image_mock` | `^2.1.1` | Lets `cached_network_image` resolve in widget tests without a real HTTP server | MEDIUM |
| `coverage` | (transitive via `flutter test --coverage`) | Coverage output → `coverage/lcov.info` for Codecov | n/a |

### What NOT to use here

| Avoid | Why | Use instead |
|---|---|---|
| `mockito` | Requires `build_runner` code-gen (`@GenerateMocks`), runs every time a mock signature changes; mocktail is mock-as-code | `mocktail` |
| `flutter_driver` | Officially superseded since 2021; significant tooling rot | `integration_test` |
| Real-device-only tests in CI | Slow, flaky, requires paid runners | `integration_test` on `iPhone 15 Pro` simulator; real devices via Firebase Test Lab only for nightly |

---

## 7. fl_chart — Admin Panel analytics (Screen 12)

| Package | Version | Purpose | Confidence |
|---|---|---|---|
| `fl_chart` | `^0.69.0` | Line, bar, pie charts for the Admin Panel Analytics tab | MEDIUM — verify on `pub add` |

### Why fl_chart over alternatives

| Library | Pros | Cons | Verdict |
|---|---|---|---|
| **fl_chart** | Pure Dart, no native deps, ~3.5k stars, customisable Material 3 styling, no licence cost | API is verbose for simple cases | **PICK** — best for the 4–6 charts Screen 12 needs |
| `syncfusion_flutter_charts` | Most feature-rich, professional-grade | Requires free community licence registration per app per year; legal overhead for a solo dev | Skip |
| `charts_flutter` (Google) | Was the "official" choice | **Discontinued in 2022.** Do not use. | Skip |
| `graphic` | Grammar-of-graphics style | Steep learning curve, smaller community | Skip |

### What NOT to use here

| Avoid | Why | Use instead |
|---|---|---|
| `charts_flutter` | Abandoned by Google; no Flutter 3.x support | `fl_chart` |
| `syncfusion_flutter_charts` | Commercial licence terms unsuitable for a solo indie dev | `fl_chart` |

---

## 8. Other libs the 12-screen spec implies

### `flutter_svg` — IF the brand uses SVG illustrations

| Package | Version | Purpose | Confidence |
|---|---|---|---|
| `flutter_svg` | `^2.0.10` | Renders SVG icons / illustrations (e.g. onboarding hero art, empty-state graphics) | MEDIUM |

**Decision:** Optional. Audit `assets/images/` first — if all assets are PNG/JPG, **don't add**. The lettermark on Splash (Screen 01) is text-based per the spec, not SVG. Recommend adding only if the designer ships SVG illustrations.

### `url_launcher` — for opening PDFs / external links

| Package | Version | Purpose | Confidence |
|---|---|---|---|
| `url_launcher` | `^6.3.0` | Opens external URLs (PDF material `fileUrl`, ToS page on Register screen, app store link from Profile) | HIGH — universal Flutter staple |

**Decision:** ADD. Materials browser (Screen 07) opens PDFs (`/materials/{id}.fileUrl`) — currently this would crash because no link-opening package is wired. Also needed for the Terms of Service link on the Register screen (Screen 04) and the "Rate on App Store" entry in Profile (Screen 09).

### `flutter_local_notifications` — for FCM foreground display

| Package | Version | Purpose | Confidence |
|---|---|---|---|
| `flutter_local_notifications` | `^18.0.0` | Renders a notification banner when FCM message arrives while app is in foreground (iOS doesn't show FCM data messages in foreground by default) | MEDIUM |

**Decision:** ADD if foreground notification banners are part of the Screen 11 (Notifications) UX. If "user only sees notifications by opening the Notifications screen", skip it. The spec is ambiguous — recommend asking the user. For v1.0 conservative pick: **ADD** (most users expect foreground banners).

### `device_info_plus` + `package_info_plus` — for Crashlytics breadcrumbs

| Package | Version | Purpose | Confidence |
|---|---|---|---|
| `package_info_plus` | `^8.0.0` | App version + build number for Crashlytics `setCustomKey` | HIGH |
| `device_info_plus` | `^11.0.0` | iOS model + OS version for Crashlytics; also useful for Analytics segmentation | HIGH |

**Decision:** ADD both. Both are Flutter staples. ~50 LOC of glue code in `app_observability_service.dart`.

### `flutter_riverpod_lint` — optional, dev-only

| Package | Version | Purpose | Confidence |
|---|---|---|---|
| `custom_lint` + `riverpod_lint` | `^0.6.x` + `^2.3.x` | Catches Riverpod anti-patterns (missing `keepAlive`, ref leaks, missing `family` arg) at analyze time | MEDIUM |

**Decision:** ADD. Solo dev with no code review benefits enormously from static checks. ~15 lint rules, several catch real bugs.

---

## Installation summary

```bash
# Add to pubspec.yaml dependencies:
flutter pub add cloud_functions
flutter pub add firebase_app_check
flutter pub add firebase_crashlytics
flutter pub add firebase_analytics
flutter pub add url_launcher
flutter pub add fl_chart
flutter pub add flutter_local_notifications
flutter pub add package_info_plus
flutter pub add device_info_plus

# Remove (once Cloud Function proxy ships):
flutter pub remove google_generative_ai

# Add to dev_dependencies:
flutter pub add --dev mocktail
flutter pub add --dev fake_cloud_firestore
flutter pub add --dev firebase_auth_mocks
flutter pub add --dev golden_toolkit
flutter pub add --dev network_image_mock
flutter pub add --dev custom_lint
flutter pub add --dev riverpod_lint
# integration_test needs manual pubspec edit:
#   dev_dependencies:
#     integration_test:
#       sdk: flutter

# After ALL additions:
flutter pub get
flutter pub outdated         # sanity check the resolved tree
cd ios && pod install        # picks up new native deps (App Check, Crashlytics, Analytics)
```

### Functions repo (new sibling of `tool/seed/`)

```bash
mkdir functions && cd functions
firebase init functions      # choose TypeScript, Node 20, ESLint
npm install @google/genai genkit @genkit-ai/googleai @genkit-ai/firebase
npm install --save-dev firebase-functions-test
```

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Cloud Functions for Firebase (Node + TS) | Cloud Run service in Go/Python | If function logic grows past ~10 endpoints or needs custom Docker (e.g. PDF generation, ML inference). For v1.0 (2 functions: `askMentorBot` + `awardPoints`), Functions is correct. |
| Firebase Crashlytics | Sentry | If team grows past 3 devs and needs per-issue assignment, release health dashboards, performance monitoring beyond Firebase's offering. |
| Firebase Analytics | PostHog | If you need session replay or product analytics with SQL-style querying. Overkill for v1.0. |
| fl_chart | Syncfusion | If you need Gantt, treemaps, or financial charts that fl_chart lacks. None needed for Screen 12. |
| mocktail | mockito | Only if migrating from a codebase that already uses `@GenerateMocks` heavily. New code: mocktail. |
| GitHub Actions on Ubuntu | Codemagic | If you want managed App Store Connect upload, automated screenshot generation, and Flutter-specific CI primitives. Worth revisiting at v1.1 when ship cadence increases. |

---

## What NOT to Use (consolidated)

| Avoid | Why | Use Instead |
|---|---|---|
| `firebase_dynamic_links` | **Service shuts down August 2025.** | Don't add. Use App Links (universal links) directly via iOS associated domains if deep linking is needed. |
| `@google/generative-ai` (npm) on the Cloud Function | Deprecated by Google late 2024 | `@google/genai` |
| `google_generative_ai` (Dart) staying in `pubspec.yaml` | Direct Gemini calls from client = leaked key | Remove once Cloud Function proxy lands |
| `firebase-functions` v1 API | Maintenance-only | v2 (`firebase-functions/v2/https`) |
| `charts_flutter` | Discontinued by Google in 2022 | `fl_chart` |
| `flutter_driver` | Superseded in 2021 | `integration_test` |
| `mockito` | Code-gen overhead | `mocktail` |
| Node 22 on Functions for v1.0 | Possible but Node 20 LTS is the safer pick through April 2026 | Node 20; revisit at v1.1 |
| App Attest without DeviceCheck fallback | Breaks iOS 13 users | `appAttestWithDeviceCheckFallback` |
| Mixing FlutterFire BoM generations | Causes platform-channel mismatches | Add new Firebase packages with `flutter pub add`; let pub resolve to the same generation as `firebase_core ^3.15.x` |

---

## Stack Patterns by Variant

**If the milestone slips and Gemini-proxy work can't land:**
- Move `GEMINI_API_KEY` to an iOS-only Keychain entry and fetch from a one-shot Cloud Function at app launch, OR
- Restrict the Gemini key to the iOS bundle ID in Google Cloud Console (current key is unrestricted — verify in console)
- Both are stopgaps; the proper fix is still the Cloud Function proxy.

**If iOS deployment target stays at 13.0 (App Attest blocked):**
- Use `AppleProvider.deviceCheck` as the sole provider — works on iOS 11+ but is weaker (device-bound only, not app-bound)
- Document the security delta in `.planning/research/PITFALLS.md`.

**If Genkit is rejected as too new for v1.0:**
- Drop the streaming requirement on the proxy — let `askMentorBot` return the full Gemini response in one shot. UX cost: ~3–8s of "typing…" indicator with no token-by-token reveal. Acceptable trade-off for v1.0.

---

## Version Compatibility

| Package A | Compatible With | Notes |
|---|---|---|
| `firebase_core ^3.15.2` | `firebase_app_check ^0.3.x`, `firebase_crashlytics ^4.x`, `firebase_analytics ^11.x`, `cloud_functions ^5.x` | All FlutterFire packages MUST be from the same BoM-equivalent generation. If `flutter pub add` upgrades `firebase_core`, accept it but re-test the existing Firebase usages. |
| `firebase-functions ^6.0` (npm) | `firebase-admin ^13.0` | Already at ^13.0.1 in `tool/seed/`. Aligned. |
| `genkit ^1.0` | `@google/genai ^1.0`, Node 20+ | Genkit 1.0 went GA early 2025 |
| `flutter 3.41.3` | `Dart 3.11`, `flutter_lints ^4.0` | Existing pins; no change needed |
| `mocktail ^1.0.4` | `flutter_test` (SDK) | No transitive conflicts |
| `fake_cloud_firestore ^3.1.0` | `cloud_firestore ^5.x` | Track Firestore major; if pub resolution complains, take the resolver's suggested version |
| `flutter_local_notifications ^18.0` | iOS 13+ | Matches current deployment target |

---

## Confidence Assessment

| Item | Confidence | Why |
|---|---|---|
| Choice of Node 20 + TypeScript for Functions | HIGH | LTS schedule is public; Dart-on-Functions is not stable; `tool/seed/` already uses Node |
| Choice of v2 functions over v1 | HIGH | v1 is officially maintenance-mode |
| Choice of `@google/genai` over `@google/generative-ai` | HIGH | Deprecation is announced and irreversible |
| Genkit recommendation for streaming | MEDIUM | Genkit hit 1.0 in 2025; mature enough for v1.0 but newer than the alternative SSE-via-onRequest pattern |
| `cloud_functions ^5.2.0` pin | MEDIUM | Best-fit for firebase_core 3.15.x but unverified against pub.dev — `flutter pub add` will pick the right one |
| `firebase_app_check ^0.3.2` pin | MEDIUM | Version family is correct for firebase_core 3.15.x; specific patch needs verification |
| `firebase_crashlytics ^4.1.0` pin | MEDIUM | Same — family-correct, exact patch needs verification |
| `firebase_analytics ^11.3.0` pin | MEDIUM | Same |
| App Attest + DeviceCheck fallback strategy | HIGH | Apple platform docs are clear |
| `subosito/flutter-action@v2` recommendation | HIGH | De-facto standard with 30k+ users |
| GitHub Actions on Ubuntu for analyze/test | HIGH | Standard practice; 5× cheaper than macOS runners |
| `mocktail` over `mockito` | HIGH | Widely-acknowledged best practice for new Dart code since 2023 |
| `fake_cloud_firestore ^3.1.0` pin | MEDIUM | Tracks Firestore major; exact patch needs verification |
| `fl_chart` over Syncfusion / charts_flutter | HIGH | charts_flutter is abandoned; Syncfusion has licensing overhead |
| `url_launcher`, `package_info_plus`, `device_info_plus` adds | HIGH | All are Flutter staples; no controversy |
| `flutter_svg` recommendation | LOW | Depends on whether designer ships SVG — asset audit needed |
| `flutter_local_notifications` recommendation | MEDIUM | Spec is ambiguous on foreground notification UX |
| Dropping `google_generative_ai` from pubspec | HIGH | Direct consequence of moving Gemini to Cloud Function |
| `firebase_dynamic_links` exclusion | HIGH | Shutdown is publicly announced |

---

## Notes for the Roadmap

Suggested phase ordering driven by stack dependencies:

1. **Foundation phase** (no new features yet): Add Crashlytics + Analytics + GitHub Actions CI. These are non-disruptive and unblock observability for everything that follows.
2. **Security phase**: App Check + Cloud Functions skeleton + Gemini proxy. Migrate `GeminiService` to use `httpsCallable`. Remove `google_generative_ai` from pubspec.
3. **Server-authoritative writes**: Functions trigger on `/users/{uid}/usage/{date}` writes; tighten `firestore.rules` to deny client writes to `/rewards/{uid}.points`.
4. **12-screen polish**: Add `fl_chart`, `url_launcher`, `flutter_local_notifications`, `package_info_plus`, `device_info_plus` as each screen needs them.
5. **Test harness**: Add mocktail + fake_cloud_firestore + firebase_auth_mocks + golden_toolkit early in (4) so every new screen ships with at least a smoke test and a golden.

Phases 1–2 do NOT block phase 4 (UI polish). Solo dev can do them in parallel within a single phase if they prefer time-slicing.

---

## Sources

- `.planning/codebase/STACK.md` — existing FlutterFire BoM generation (`firebase_core 3.15.2`, etc.) anchoring sibling-package pin selection — HIGH confidence
- `.planning/codebase/INTEGRATIONS.md` — confirmed Crashlytics + Analytics + Cloud Functions are ALL absent today; `IS_ANALYTICS_ENABLED = false` — HIGH confidence
- `pubspec.yaml` + `pubspec.lock` — confirmed `cloud_functions`, `firebase_app_check`, `firebase_crashlytics`, `firebase_analytics`, `fl_chart`, `url_launcher`, `mocktail`, `fake_cloud_firestore`, `golden_toolkit` are not currently dependencies — HIGH confidence
- Model knowledge (Jan 2026 cutoff) on FlutterFire BoM versioning, Cloud Functions v2 generations, Genkit 1.0 GA, `@google/genai` rename, Firebase Dynamic Links sunset, `charts_flutter` abandonment, `mockito` → `mocktail` migration trend — MEDIUM confidence (independent verification denied in this sandbox)
- **NOT verified** via pub.dev / Context7 / official Firebase release notes during this research run — WebFetch, WebSearch, and the ctx7 CLI fallback were all denied permission in this agent's sandbox. **All MEDIUM-confidence version pins should be re-verified with `flutter pub outdated` before being committed.**

---

*Stack research for: MentorMinds v1.0 — NEW capabilities being added to an existing Flutter + Firebase app*
*Researched: 2026-05-17*
