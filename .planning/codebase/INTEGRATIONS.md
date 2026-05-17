# External Integrations

**Analysis Date:** 2026-05-17

MentorMinds is a Firebase-backed Flutter app with one third-party AI provider (Google Gemini). All persistence, auth, file storage, and (planned) push notifications run on a single Firebase project; the AI tutor talks to Gemini directly from the device using a build-time API key.

## APIs & External Services

### Google Gemini (AI tutor)

- **Service:** Google Generative AI — Gemini API
- **SDK:** `google_generative_ai: ^0.4.6` (resolved `0.4.7`)
- **Wrapper:** `lib/core/services/gemini_service.dart`
- **Model:** `gemini-1.5-flash` (hard-coded as `_kModelName`)
- **Auth:** Build-time API key via `--dart-define=GEMINI_API_KEY=<key>`, read as `String.fromEnvironment('GEMINI_API_KEY')`:

  ```dart
  // lib/core/services/gemini_service.dart
  const String _kApiKey = String.fromEnvironment('GEMINI_API_KEY');
  const String _kModelName = 'gemini-1.5-flash';
  ```
- **Run command:** `flutter run --dart-define=GEMINI_API_KEY=<your-key>` (documented in `BACKEND_SETUP.md` §7)
- **Capabilities used:**
  - Streaming text (`generateContentStream`) → `GeminiService.sendMessage` — drives token-by-token tutor responses in `lib/features/tutor/chat_viewmodel.dart` (`sendMessage`)
  - Multimodal one-shot (`generateContent` with `DataPart('image/...', bytes)`) → `GeminiService.analyzeImage` — used only when `state.isPremium` for image attach flow
- **System prompt:** Defined in `_kSystemPrompt` inside `lib/core/services/gemini_service.dart`; instructs the model to act as "MentorBot" for Bangladeshi O/A Level students with markdown formatting and Socratic guidance.
- **Transcript / context:** Held in-memory in `GeminiService._history` (a `List<Content>`); reset on new chat via `GeminiService.resetSession()`. Not persisted server-side.
- **Failure mode:** When the key is missing, `GeminiService.isAvailable == false` and any call yields the literal string `'AI tutor is not configured. Pass GEMINI_API_KEY via --dart-define=GEMINI_API_KEY=<key> when you run the app.'` (no crash at import).

### Google Sign-In (OAuth)

- **SDK:** `google_sign_in: ^6.2.1` (resolved `6.3.0`)
- **Call site:** `lib/features/auth/auth_viewmodel.dart` → `loginWithGoogle()` calls `GoogleSignIn().signIn()` and then `FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(...))`
- **iOS native bridge:** Before the Google picker opens, Dart calls a method-channel pre-flight:

  ```dart
  // lib/features/auth/auth_viewmodel.dart
  static const MethodChannel _nativeConfigChannel =
      MethodChannel('mentor_minds/native_config');

  Future<String?> _googleSignInConfigurationError() async {
    // ... invokes 'googleSignInStatus'
  }
  ```
  Handled in `ios/Runner/AppDelegate.swift` `googleSignInStatus()`, which validates that `GoogleService-Info.plist` contains both `CLIENT_ID` and `REVERSED_CLIENT_ID` AND that `REVERSED_CLIENT_ID` is registered as a `CFBundleURLSchemes` entry in `Info.plist`.
- **Current configuration status — NOT WIRED:** `ios/Runner/GoogleService-Info.plist` currently contains only `API_KEY`, `GCM_SENDER_ID`, `BUNDLE_ID`, `PROJECT_ID`, `STORAGE_BUCKET`, `GOOGLE_APP_ID`, and the `IS_*_ENABLED` flags. There is **no `CLIENT_ID`** and **no `REVERSED_CLIENT_ID`**, and `ios/Runner/Info.plist` has **no `CFBundleURLTypes`** entry. The pre-flight will return `{"configured": false, reason: "Add GoogleService-Info.plist ... missing CLIENT_ID"}` and the Dart layer will surface "Google Sign-In is not configured for iOS yet." Email/password auth still works.

## Firebase Project

- **Project ID:** `mentor-mind-aa765`
- **iOS App ID:** `1:722452556351:ios:823964b9f46ebc2f97e68a`
- **iOS Bundle ID:** `com.arnobrizwan.mentorminds`
- **Messaging Sender ID:** `722452556351`
- **Storage bucket:** `mentor-mind-aa765.firebasestorage.app`
- **iOS API key (committed in `lib/firebase_options.dart` and `ios/Runner/GoogleService-Info.plist`):** `AIzaSyB9xmghvdBhWrKRzEDnGiu7vyPvuHWIS10`
  - This is a client-side Firebase API key — not a secret per Firebase docs, but it MUST be restricted in Google Cloud Console to the iOS bundle id `com.arnobrizwan.mentorminds`.
- **Project config files:**
  - `firebase.json` — points the Firebase CLI at `firestore.rules`, `firestore.indexes.json`, `storage.rules`; declares the iOS Flutter app under `flutter.platforms.ios.default`
  - `lib/firebase_options.dart` — generated platform-specific `FirebaseOptions`; selected at runtime via `DefaultFirebaseOptions.currentPlatform` in `lib/main.dart`
  - `ios/Runner/GoogleService-Info.plist` — iOS-side native Firebase config

**Initialization** (`lib/main.dart`):
```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```
Wrapped in try/catch that only logs (`debugPrint`) on failure — the app continues to launch even if Firebase init fails.

## Firebase Products in Use

| Product | SDK | Used? | Where |
|---|---|---|---|
| Firebase Auth | `firebase_auth 5.7.0` | YES | `lib/features/auth/auth_viewmodel.dart`, `lib/features/profile/profile_viewmodel.dart`, `lib/features/tutor/chat_viewmodel.dart`, every other viewmodel via `FirebaseAuth.instance.currentUser` |
| Cloud Firestore | `cloud_firestore 5.6.12` | YES | Every feature viewmodel (`auth`, `dashboard`, `tutor`, `materials`, `profile`, `rewards`, `notifications`, `search`) |
| Cloud Storage | `firebase_storage 12.4.10` | YES | `lib/features/tutor/chat_viewmodel.dart` (`_uploadImage` → `uploads/{uid}/{ts}_{rnd}.jpg`); `lib/features/profile/profile_viewmodel.dart` (avatar upload) |
| Firebase Cloud Messaging | `firebase_messaging 15.2.10` | NO (SDK only) | `grep -r firebase_messaging\|FirebaseMessaging lib/` returns zero hits. SDK is installed and `IS_GCM_ENABLED = true` in `GoogleService-Info.plist`, but no token registration, foreground handler, or background handler exists yet. `BACKEND_SETUP.md` §3 calls this out as "nothing to configure yet". |
| Firebase Analytics | — | NO | Not installed; `IS_ANALYTICS_ENABLED = false` in `GoogleService-Info.plist`. |
| Cloud Functions | — | NO | None deployed. `firestore.rules` explicitly notes "When Cloud Functions land, move point mutations server-side and tighten /users and /rewards writes accordingly." |
| Firebase Hosting | — | NO | Not configured. |

### Firebase Auth — Sign-in methods enabled

(Per `BACKEND_SETUP.md` §3, these must be enabled in the Firebase console for the wired flows to work.)

- **Email / Password** — used by `loginWithEmail`, `registerWithEmail`, `resetPassword`, `resendEmailVerification` in `lib/features/auth/auth_viewmodel.dart`
- **Google** — wired in code via `google_sign_in`, but iOS native config is missing (see above)

Sign-out triggers both `_google.signOut()` and `_auth.signOut()` (`AuthViewModel.signOut`).

## Data Storage

### Firestore schema (per `firestore.rules`, `firestore.indexes.json`, `DATA.md`, `BACKEND_SETUP.md`)

**Collections:**

| Path | Owner | Read | Write | Notes |
|---|---|---|---|---|
| `/users/{uid}` | self / admin | owner or admin | owner (cannot change `role` or `isApproved`) / admin | Created on register in `lib/features/auth/auth_viewmodel.dart` (batch with `/rewards/{uid}`). Teacher accounts start with `isApproved: false`. |
| `/users/{uid}/usage/{YYYY-MM-DD}` | self | owner / admin | owner / admin | Per-day usage doc updated on every chat turn (`chat_viewmodel.dart._incrementUsage`); used for free-tier 10/day rate limit |
| `/rewards/{uid}` | self | owner / admin | owner / admin (delete: admin only) | Points + badges ledger, mirrors `/users.points`; client-side increments today (MVP trade-off documented in `firestore.rules`) |
| `/sessions/{sid}` | session owner | owner only (`resource.data.userId == request.auth.uid`) | owner only | Chat sessions; written by `chat_viewmodel.dart._saveSession` |
| `/sessions/{sid}/messages/{mid}` | session owner (legacy) | parent owner | parent owner | Legacy path — new code embeds messages inline as `messages: []` on the parent doc |
| `/materials/{id}` | teachers/admin | any signed-in | approved teacher (`userDoc().role == 'teacher' && isApproved == true`) or admin | Seeded by `tool/seed/seed.js` (15 docs) |
| `/notifications/{id}` | admin | any signed-in | create: admin only; update: any signed-in but only field `read` (and must set to `true`); delete: any signed-in | Seeded by `tool/seed/seed.js` (5 docs). Known trade-off in rules: any user delete removes the doc for everyone. |

**Document shapes (from `BACKEND_SETUP.md` and observed writes):**

- `/users/{uid}`: `{ uid, name, email, displayName, role: 'student'|'teacher'|'admin', subscriptionType: 'free'|'premium', points, badges[], subjects[], level: 'O Level'|'A Level', isApproved, emailVerified, createdAt, avatarUrl?, photoUrl?, notificationsEnabled? }`
- `/users/{uid}/usage/{YYYY-MM-DD}`: `{ date, messageCount, loginRewarded, loginRewardedAt, lastMessageAt }`
- `/rewards/{uid}`: `{ userId, points, badges[], history: [{ type, points, at }] }`
- `/sessions/{sid}`: `{ userId, subject, level, title, lastQuestion, messageCount, messages: [{ id, role, content, timestamp, imageUrl?, feedback?, isError? }], createdAt, updatedAt }`
- `/materials/{id}`: `{ title, subject, level, type: 'pdf'|'video'|'note', fileUrl, thumbnailUrl, uploadedBy, views, createdAt, uploadedAt }`
- `/notifications/{id}`: `{ title, body, recipientRole: 'all'|'student'|'teacher'|'admin', read, deeplink, createdAt, timestamp, type }`

**Composite indexes deployed (`firestore.indexes.json`):**
- `sessions`: `userId ASC, updatedAt DESC` (dashboard recent sessions, top-3)
- `notifications`: `recipientRole ASC, read ASC` (unread badge count)
- `materials`: 7 indexes covering combinations of `subject`, `level`, `type` × `createdAt DESC` (materials browser filters)

**Security-rule helpers (`firestore.rules`):**
- `isSignedIn()`, `isOwner(uid)`
- `userDoc()` — fetches `/users/{request.auth.uid}`
- `isAdmin()` — checks `role == 'admin'`
- `isApprovedTeacher()` — checks `role == 'teacher' && isApproved == true`

### Cloud Storage rules (`storage.rules`)

- Only `uploads/{uid}/**` is writable, and only by the owning user
- Image MIME types only (`request.resource.contentType.matches('image/.*')`)
- 5 MB cap (`request.resource.size < 5 * 1024 * 1024`)
- All other paths default-deny
- Path is exercised by `chat_viewmodel.dart._uploadImage`:

  ```dart
  final ref = _storage.ref().child('uploads').child(uid).child(name);
  await ref.putFile(file);
  return ref.getDownloadURL();
  ```

### File storage

- **Cloud Storage bucket:** `mentor-mind-aa765.firebasestorage.app` — used for user image attaches in the AI tutor (premium only) and profile avatars
- **Local filesystem:** `image_picker` writes temp files; `chat_viewmodel.dart` reads them as `Uint8List` via `imageFile.readAsBytes()` before sending to Gemini

### Caching

- No remote caching layer (Redis, etc.). Firestore offline persistence is the default Firebase client behaviour on iOS.
- `cached_network_image` caches material thumbnails / avatars on-device.
- `shared_preferences` caches onboarding selection (`onboarding_level`, `onboarding_subjects` keys read in `AuthViewModel._readOnboardingSelection`).

## Authentication & Identity

- **Primary provider:** Firebase Authentication
- **Methods:**
  - Email / password (verified email required; `sendEmailVerification` called post-register)
  - Google OAuth via `google_sign_in` + `GoogleAuthProvider.credential`
- **Role model:** `role` field on `/users/{uid}` — `student`, `teacher`, `admin` (plus legacy `premium_student` mapped to student dashboard in `_resolveRoleDestination`)
- **Teacher approval gate:** Teachers register with `isApproved: false`; admin must manually flip the flag in Firestore (or via a future admin UI)
- **Premium gate:** `subscriptionType: 'premium'` on `/users/{uid}` — unlocks unlimited chat (no 10/day cap) and image attach in the tutor (`chat_viewmodel.dart`)
- **Session keychain:** iOS keychain access group `$(AppIdentifierPrefix)com.arnobrizwan.mentorminds` declared in `ios/Runner/Runner.entitlements` (used by Firebase Auth to persist refresh tokens across reinstalls)

## Monitoring & Observability

- **Error tracking:** None. No Sentry, Crashlytics, or Firebase Crashlytics dependency in `pubspec.yaml`.
- **Analytics:** None. `firebase_analytics` is not installed; `IS_ANALYTICS_ENABLED = false` in `GoogleService-Info.plist`.
- **Logs:** `debugPrint(...)` and `print(...)` calls scattered through viewmodels (e.g. `AuthViewModel` logs `FirebaseAuthException` codes). No structured logging library.
- **Cloud Functions logs:** N/A — no Functions deployed.

## CI/CD & Deployment

- **CI pipeline:** None. No `.github/`, `.gitlab-ci.yml`, `bitrise.yml`, `fastlane/`, or similar in the repo.
- **Build automation:** Manual `flutter build ios` from a developer Mac.
- **Deployment for Firebase artifacts:** Manual via Firebase CLI (`firebase deploy --only firestore:rules,firestore:indexes,storage`), documented in `BACKEND_SETUP.md` §5.
- **App distribution:** Manual via Xcode → App Store Connect (no TestFlight automation configured).

## Webhooks & Callbacks

- **Incoming webhooks:** None. There is no HTTP server in this repo — Firebase Functions are not deployed and there is no separate backend.
- **Outgoing webhooks:** None.
- **Push notification callbacks:** Not wired — `firebase_messaging` is installed but not registered, so APNs callbacks fall through to the default `FlutterAppDelegate` implementation.

## Environment Configuration

**Build-time `--dart-define` flags (read via `String.fromEnvironment`):**
| Var | Required? | Used in | Failure mode |
|---|---|---|---|
| `GEMINI_API_KEY` | YES (for AI tutor) | `lib/core/services/gemini_service.dart` | App still launches; tutor returns the "AI tutor is not configured" message |

**Files containing committed config (NOT secrets):**
- `lib/firebase_options.dart` — Firebase iOS / Android / macOS options (client API key is here)
- `ios/Runner/GoogleService-Info.plist` — Firebase iOS native config
- `firebase.json`, `firestore.rules`, `firestore.indexes.json`, `storage.rules` — Firebase project config + rules

**Files containing real secrets (NOT committed):**
- `tool/seed/service-account.json` — Firebase Admin SDK service account; gitignored via `tool/seed/.gitignore`

**Where secrets live in practice:**
- Gemini API key: developer's local launch config (VS Code `.vscode/launch.json` `toolArgs`, Android Studio "Additional run args"), or CI secret store if/when CI lands
- Service account JSON: developer's local `tool/seed/` directory

**`.env` files:** None present.

## Third-Party SDKs Summary

| Category | SDK | Purpose |
|---|---|---|
| AI | `google_generative_ai` | Gemini-1.5-flash text + vision via direct HTTPS to `generativelanguage.googleapis.com` |
| Auth | `google_sign_in` | Google OAuth token retrieval feeding `FirebaseAuth.signInWithCredential` |
| Backend | `firebase_core` + `firebase_auth` + `cloud_firestore` + `firebase_storage` + `firebase_messaging` | All hosted on Google Cloud project `mentor-mind-aa765` |
| Media | `image_picker`, `cached_network_image` | Camera/photo library access; remote image caching |
| Native | `connectivity_plus`, `shared_preferences` | Reachability and key-value cache (per-platform plugins under the hood) |

No payment SDK (Stripe, Apple In-App Purchase), no analytics SDK, no maps, no map/SMS provider. The "premium" tier is currently a manually-flipped Firestore flag — there is no monetization integration wired yet.

---

*Integration audit: 2026-05-17*
