# MentorMinds — Backend Setup

The Flutter client is fully wired to Firebase. These steps connect it to your actual Firebase project.

---

## 1. Prerequisites

```bash
# Firebase CLI
npm install -g firebase-tools
firebase login

# FlutterFire CLI (for generating firebase_options.dart)
dart pub global activate flutterfire_cli
# Make sure pub bin is on your PATH (add to ~/.zshrc):
#   export PATH="$PATH":"$HOME/.pub-cache/bin"
```

## 2. Create the Firebase project

1. Go to https://console.firebase.google.com → **Add project**.
2. Name it (e.g. `mentorminds-prod` or `mentorminds-dev`).
3. In the project settings, register both **iOS** and **Android** apps if you plan to build for both. Bundle ID: `com.mentorminds.mentorMinds` (Android: same). You can adjust these in `ios/Runner.xcodeproj` and `android/app/build.gradle` if needed.

## 3. Enable the products the app uses

Inside the Firebase console:

- **Authentication** → **Sign-in method** → enable:
  - Email/Password
  - Google
- **Cloud Firestore** → **Create database** → start in **production mode** (we ship rules below; don't use test mode).
- **Cloud Storage** → **Get started** → use default region. Start in production mode.
- **Cloud Messaging** → nothing to configure yet; SDK is installed for future push notifications.

## 4. Wire the app

From the project root:

```bash
flutterfire configure
```

This writes `lib/firebase_options.dart` and the platform config files
(`ios/Runner/GoogleService-Info.plist`, `android/app/google-services.json`).

Then uncomment the two lines in `lib/main.dart`:

```dart
import 'firebase_options.dart';
// ...
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

(Leave the `try/catch` — it's harmless once config exists.)

## 5. Deploy security rules + indexes

```bash
# Point the Firebase CLI at your project (one-time)
firebase use --add     # pick the project you just created

# Deploy Firestore rules + indexes and Storage rules
firebase deploy --only firestore:rules,firestore:indexes,storage
```

What each file does:

| File | Purpose |
|---|---|
| `firestore.rules` | Per-collection access control — users, sessions, rewards, materials, notifications, per-day usage. |
| `firestore.indexes.json` | Composite indexes the dashboard + chat queries need (sessions by user+updatedAt, materials by subject+createdAt, notifications by role+read). |
| `storage.rules` | Restricts `uploads/{uid}/…` to the owning user, images only, 5MB cap. |
| `firebase.json` | Tells `firebase deploy` where those files live. |

## 6. Seed an admin account

Admin role grants elevated access in the rules. Create your first admin manually:

1. Register a normal account through the app.
2. In Firestore console, open `/users/{your-uid}` and change `role` to `"admin"`.
3. (Optional) Also set `isApproved: true` on your first teacher account for testing the teacher flow.

Subsequent admin/teacher approvals should happen through an admin UI — out of scope for now.

## 7. Run with the Gemini API key

The AI tutor calls Google's Gemini API. Without a key it shows a clear
"not configured" message instead of real answers.

```bash
# Get a key: https://aistudio.google.com/apikey

flutter run --dart-define=GEMINI_API_KEY=<your-key>
```

For everyday dev, drop this into a launch config:

- **VS Code** — `.vscode/launch.json` → `"toolArgs": ["--dart-define=GEMINI_API_KEY=..."]`
- **Android Studio** — Run → Edit Configurations → Additional run args

> Don't commit the key. Use `--dart-define` or a CI secret.

---

## Schema reference

| Collection | Document shape | Who writes |
|---|---|---|
| `/users/{uid}` | `uid, name, email, role, subscriptionType, points, badges[], subjects[], level, isApproved, emailVerified, createdAt` | Self on register/profile edit; admin for role/approval |
| `/users/{uid}/usage/{YYYY-MM-DD}` | `date, messageCount, loginRewarded, loginRewardedAt, lastMessageAt` | Self (chat + daily login) |
| `/rewards/{uid}` | `userId, points, badges[], history[]` | Self (client-side for MVP) |
| `/sessions/{id}` | `userId, subject, level, title, lastQuestion, messageCount, messages[], createdAt, updatedAt` | Session owner |
| `/sessions/{id}/messages/{mid}` | `role, content, timestamp, imagePath?` | Session owner (legacy path; new code writes to `/sessions/{id}.messages[]` inline) |
| `/materials/{id}` | `subject, level, title, createdAt, …` | Approved teacher or admin |
| `/notifications/{id}` | `recipientRole, read, …` | Admin |

## Known MVP trade-offs

- Points are incremented client-side (daily login reward, session-complete award). A user with dev tools open could inflate their own points. When Cloud Functions ship, move these to functions and tighten the `/users` + `/rewards` write rules.
- `/notifications` currently requires admin to create. A "system" notification (e.g. weekly streak reminder) should also be sent by a scheduled Cloud Function — not covered here.
- No password-reset templating; Firebase uses its default email for now. Customize in the Auth console.

---

## Phase 1 — iOS Identity Migration Checklist

Run these 4 manual steps BEFORE resuming the executor (which will run `flutterfire configure` and `flutter build ios --no-codesign`).

- [ ] **(1) Register new iOS app in Firebase Console**
      Visit: https://console.firebase.google.com/project/mentor-mind-aa765/settings/general
      Click "Add app" → iOS.
      Bundle ID: `com.mentorminds.mentorMinds`  (exact case: capital M in mentorMinds)
      App nickname: `MentorMinds iOS (v1.0)` (optional)
      App Store ID: leave blank for now
      Click "Register app".

- [ ] **(2) Download replacement GoogleService-Info.plist**
      On the same page after registration, click "Download GoogleService-Info.plist".
      Verify the downloaded file contains both `<key>CLIENT_ID</key>` and `<key>REVERSED_CLIENT_ID</key>` entries.
      Move/copy the file to `ios/Runner/GoogleService-Info.plist`, OVERWRITING the existing file.
      Verify with: `grep -c 'CLIENT_ID\|REVERSED_CLIENT_ID' ios/Runner/GoogleService-Info.plist` → expected 2 or more.

- [ ] **(3) Re-associate APNs auth key (.p8) with the new iOS app**
      Visit: https://console.firebase.google.com/project/mentor-mind-aa765/settings/cloudmessaging
      Under "Apple app configuration" select the NEW iOS app (com.mentorminds.mentorMinds).
      Under "APNs Authentication Key" click "Upload".
      Upload the SAME .p8 file already associated with the old app — Apple .p8 keys are per-Team, not per-bundle-id, so no new key generation is required.
      Confirm "Key ID" and "Team ID" populate after upload.

- [ ] **(4) Confirm Apple Developer Portal App ID exists**
      Visit: https://developer.apple.com/account/resources/identifiers
      Confirm that `com.mentorminds.mentorMinds` either (a) appears explicitly as an Identifier, or (b) is covered by a wildcard provisioning profile your Apple Team uses for development builds.
      If neither (a) nor (b): create an explicit App ID for `com.mentorminds.mentorMinds` with default capabilities. For Phase 1 (development builds only), default auto-provisioning is sufficient — explicit App ID with Push capability is required at Phase 6 (FCM).

Once all 4 boxes are checked AND the new GoogleService-Info.plist is in place at `ios/Runner/GoogleService-Info.plist`, run these CLI verification checks:

```bash
# Check 1 — new plist has the Google Sign-In keys (expected: 2 or more)
grep -c 'CLIENT_ID\|REVERSED_CLIENT_ID' ios/Runner/GoogleService-Info.plist

# Check 2 — plist BUNDLE_ID matches the new id (expected: 1 match)
grep -A1 'BUNDLE_ID' ios/Runner/GoogleService-Info.plist | grep 'com.mentorminds.mentorMinds'

# Check 3 — BACKEND_SETUP.md has 4 checked boxes (expected: 4 or more)
grep -c '^\s*- \[x\]' BACKEND_SETUP.md
```

Then type "approved" in the chat to resume the executor (which will run `flutterfire configure`, `pod install`, and `flutter build ios --no-codesign`).

---

## Troubleshooting

**"Missing or insufficient permissions"** — rule denied the write. In the console, open **Firestore → Rules Playground**, paste the exact path + action, and trace which rule dropped it.

**"The query requires an index"** — Firestore will log a URL. Click it to auto-create. Add that index to `firestore.indexes.json` so it's reproducible.

**iOS: `Firebase app has not been configured`** — `firebase_options.dart` wasn't generated or the import in `main.dart` is still commented out.

**Android: `google-services.json missing`** — run `flutterfire configure` again, then delete the Android build cache: `cd android && ./gradlew clean`.

**Image picker "no image" on iOS** — you revoked Photo Library permission. Reset via simulator menu: **Device → Erase All Content and Settings**.
