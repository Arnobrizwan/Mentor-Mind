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

---

## Phase 2 — Cloud Functions + App Check Setup

> **IMPORTANT: Solo dev runs these commands ONCE manually post-merge.** This plan is documentation-only — no `gcloud` command is executed during plan execution. Commands are idempotent where noted; exceptions are called out explicitly.

### 1. Enable billing (prerequisite)

Project `mentor-mind-aa765` currently has billing **disabled** (RESEARCH Pitfall 7). Every subsequent step in this section — and Phase 3's first `firebase deploy --only functions` — requires billing to be active.

```bash
# PREREQUISITE: project billing is currently DISABLED.
# Enable billing on mentor-mind-aa765 against billing account 0121EC-5D572E-57FEE1.
gcloud billing projects link mentor-mind-aa765 \
  --billing-account=0121EC-5D572E-57FEE1
```

- Billing must be enabled before Phase 3's `firebase deploy --only functions` will succeed.
- Phase 2's emulator-only work is unblocked regardless — the emulator does not require billing.
- Verify: `gcloud billing projects describe mentor-mind-aa765` should show `billingEnabled: true` after this command.

### 2. Billing budget alert ($10/mo)

Prevents runaway Cloud Functions cold-deploy costs (bare `minInstances: 1` with no traffic already costs ~$25/mo).

```bash
# NOTE: this command is NOT idempotent — re-running creates a duplicate budget.
# Verify with `gcloud billing budgets list --billing-account=0121EC-5D572E-57FEE1` first.
gcloud billing budgets create \
  --billing-account=0121EC-5D572E-57FEE1 \
  --display-name="MentorMinds Phase 2 Guardrail" \
  --budget-amount=10USD \
  --filter-projects="projects/mentor-mind-aa765" \
  --threshold-rule=percent=0.5 \
  --threshold-rule=percent=0.9 \
  --threshold-rule=percent=1.0
```

**Recipient note:** Budget alerts are sent to **billing administrators** on account `0121EC-5D572E-57FEE1`. Ensure `arnobrizwan23@gmail.com` is a billing administrator: Cloud Console → Billing → Account management → IAM. If granular per-channel routing is needed, pre-create a Cloud Monitoring notification channel and add `--notifications-rule-monitoring-notification-channels=<channel-id>` — out of scope for v1.0.

### 3. Artifact Registry cleanup (keep last 3 versions)

Cloud Functions v2 pushes container images to Artifact Registry on every deploy. Without a cleanup policy, old images accumulate storage costs indefinitely.

```bash
# STEP 1 — discover the auto-created repository name after the first Phase 3 deploy:
gcloud artifacts repositories list --project=mentor-mind-aa765 --location=asia-south1

# Cloud Functions v2 creates the repo on first deploy.
# The name is typically `gcf-artifacts` or similar.
# This command ships as a template; Phase 3 SUMMARY fills in REPO_NAME.

# STEP 2 — create policy file keep-last-3.json:
cat > /tmp/keep-last-3.json << 'EOF'
[{
  "name": "keep-last-3-versions",
  "action": {"type": "Keep"},
  "mostRecentVersions": {
    "keepCount": 3
  }
}]
EOF

# STEP 3 — apply the cleanup policy (replace REPO_NAME with the actual name from STEP 1):
gcloud artifacts repositories set-cleanup-policies REPO_NAME \
  --project=mentor-mind-aa765 \
  --location=asia-south1 \
  --policy=/tmp/keep-last-3.json \
  --no-dry-run
```

> **Phase 3 follow-up:** After the first `firebase deploy --only functions`, run STEP 1 to discover the real `REPO_NAME` and re-run STEP 3 with it. Document the actual name in the Phase 3 SUMMARY.

### 4. Region pin verification

Confirm that every v2 callable deploys to `asia-south1` — non-negotiable for Bangladesh users.

```bash
# Confirm every v2 callable deploys to asia-south1.
gcloud functions list --regions=asia-south1 --v2 --project=mentor-mind-aa765
```

> **DO NOT deploy to `us-central1`** (the firebase-tools default region). Cross-region latency between Asia and us-central1 is +200 ms, which violates the "useful answer in <10 s" core value promise. The `region: 'asia-south1'` pin in `functions/src/index.ts` (Plan 02-03) is the source of truth; this verification command confirms the live state matches.

### 5. App Check kill-switch URL

If `enforceAppCheck: true` begins rejecting legitimate users in production (Phase 3+), the kill switch is a single toggle in the Firebase Console — no function redeploy required.

- Open the Firebase Console: [https://console.firebase.google.com/project/mentor-mind-aa765/appcheck](https://console.firebase.google.com/project/mentor-mind-aa765/appcheck)
- Navigate to **Build → App Check → Apps → MentorMinds iOS**.
- The **Enforcement mode** toggle per service (Cloud Functions, Cloud Firestore, etc.) is the kill switch.
- Toggling **OFF** takes effect **immediately** without a function redeploy.
- Use this if `enforceAppCheck: true` rejects legitimate users in production (Phase 3+).

### 6. Debug token registration steps

Each developer registers their own simulator's debug token once. The CI pipeline uses a single shared token.

1. Build and run a DEV iOS build:
   ```bash
   flutter run -d <iOS simulator UDID>
   # AppleProvider.debug auto-generates a token on first call (Plan 02-06 wires this).
   ```
2. Watch the **Xcode Debug console** (NOT the system log) for a line matching:
   ```
   [Firebase/AppCheck][I-FAA001001] Firebase App Check Debug Token: <UUID>
   ```
   *(Exact prefix may vary slightly across `firebase_app_check` versions; the substring `Debug App Check token` is stable.)*
3. Copy the UUID.
4. In Firebase Console, navigate to:
   **Build → App Check → Apps → MentorMinds iOS → overflow menu (⋮) → Manage debug tokens → Add debug token**
5. Paste the UUID. Give it a name like `arnob-laptop-simulator-2026-05`. Save. Token is immediately valid.
6. Confirm: on the next run of the dev simulator, calls to the **emulator** continue to work unchanged (the emulator bypasses App Check per RESEARCH Pitfall 6); calls to the **production** callable (Phase 3+) succeed with the registered token.

> **Rotation cadence (D-09):** Dev tokens never auto-expire — devs manage their own. CI token rotated **quarterly** (calendar reminder). Revocation: Firebase Console → App Check → Apps → MentorMinds iOS → Debug tokens → delete by name.

### 7. CI secret `APP_CHECK_DEBUG_TOKEN` boundary note

- **Stored at:** GitHub Actions → Settings → Secrets and Variables → Actions → `APP_CHECK_DEBUG_TOKEN`.
- **Value:** A debug token registered in Firebase Console via the same flow as §6 — name it `ci-shared-2026-Q2` or similar.
- **Phase 2 boundary:** The Phase 2 emulator smoke test (`ping_smoke_test.dart`) does **NOT** consume this secret — the Functions emulator bypasses App Check (RESEARCH Pitfall 6). The secret + env-var plumbing is shipped here so Phase 3 (when CI calls production-path enforcement) has zero CI setup overhead.
- **CI usage (Phase 3+):** `--dart-define=APP_CHECK_DEBUG_TOKEN=${{ secrets.APP_CHECK_DEBUG_TOKEN }}` in workflow steps that run against real Firebase. Plan 02-10 does NOT add this dart-define; the functions job in Phase 2 only lints + builds TypeScript.
- **Rotation:** Quarterly per D-09.
