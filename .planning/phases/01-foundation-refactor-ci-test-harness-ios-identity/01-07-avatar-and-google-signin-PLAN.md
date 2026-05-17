---
phase: 01-foundation-refactor-ci-test-harness-ios-identity
plan: 07
type: execute
wave: 2
depends_on: ["01-03", "01-06"]
files_modified:
  - lib/application/viewmodels/profile/profile_viewmodel.dart
  - lib/data/repositories/storage_repository.dart
  - ios/Runner/Info.plist
autonomous: false
requirements: [ARCH-06, ARCH-07]
requirements_addressed: [ARCH-06, ARCH-07]
tags: [avatar, google_signin, storage_rules, info_plist, t_1_storage, t_1_ident]

must_haves:
  truths:
    - "D-16: Avatar fix lives in PR-3 and reuses the already-permitted `uploads/{uid}/{ts}.jpg` Storage path — no `storage.rules` change required; backfill is lazy on next save. Avatar upload writes to `uploads/{uid}/{ts}_avatar.jpg` — matching the deployed `storage.rules` wildcard pattern `uploads/{uid}/{allPaths=**}`"
    - "Old broken delete at profile_viewmodel.dart:429 is converted to a documented no-op (or guarded best-effort) — cannot delete by static path without knowing the timestamp suffix"
    - "`ios/Runner/Info.plist` contains a `CFBundleURLTypes` entry whose `CFBundleURLSchemes` array includes the `REVERSED_CLIENT_ID` value from the new `GoogleService-Info.plist`"
    - "On-device Google Sign-In status check via the existing `mentor_minds/native_config` MethodChannel returns `configured: true` (was `false` because REVERSED_CLIENT_ID URL scheme was missing)"
    - "End-to-end avatar upload manual test on simulator with Firebase emulator Storage produces a downloadable image URL"
  artifacts:
    - path: "lib/application/viewmodels/profile/profile_viewmodel.dart"
      provides: "Profile viewmodel writing avatar to uploads/{uid}/{ts}_avatar.jpg via StorageRepository"
      contains: "uploads/"
    - path: "lib/data/repositories/storage_repository.dart"
      provides: "uploadImage helper with the corrected uploads/{uid}/{ts}_{suffix} path"
      contains: "uploads/"
    - path: "ios/Runner/Info.plist"
      provides: "CFBundleURLTypes with REVERSED_CLIENT_ID URL scheme for Google Sign-In OAuth callback"
      contains: "CFBundleURLTypes|com.googleusercontent.apps"
  key_links:
    - from: "lib/application/viewmodels/profile/profile_viewmodel.dart"
      to: "lib/data/repositories/storage_repository.dart"
      via: "ref.read(storageRepositoryProvider).uploadImage(...)"
      pattern: "uploadImage"
    - from: "ios/Runner/Info.plist"
      to: "ios/Runner/GoogleService-Info.plist"
      via: "Google Sign-In OAuth URL scheme (REVERSED_CLIENT_ID copied between files)"
      pattern: "com\\.googleusercontent\\.apps\\."
---

<objective>
Close ARCH-06 (avatar upload path mismatch) and ARCH-07 (iOS Google Sign-In native config) in one plan because both are user-visible iOS surface fixes that the user will manually QA together on a real device after Phase 1 closes. Plan 06 staged the prerequisite (new `GoogleService-Info.plist` with `REVERSED_CLIENT_ID`); this plan wires it into `Info.plist` and fixes the avatar upload one-liner.

Purpose: Avatar uploads currently fail silently with `permission-denied` because `profile_viewmodel.dart:232` writes to `avatars/${uid}.jpg` but `storage.rules` only allows `uploads/{uid}/{allPaths=**}` (PITFALLS #7). Google Sign-In on iOS currently exits with `googleSignInStatus(): configured: false, reason: "Add REVERSED_CLIENT_ID URL scheme to Info.plist"` because the URL scheme was never added (PITFALLS #8). Both are gated on Plan 06's new GoogleService-Info.plist (which has the `REVERSED_CLIENT_ID` to copy into Info.plist) AND on Plan 03's repo-extracted profile_viewmodel (which now uses `StorageRepository` instead of direct FirebaseStorage calls).

Output: profile_viewmodel writes through StorageRepository at the correct path; the `_storage.ref('avatars/...').delete()` at line 429 becomes a no-op with a documented rationale; Info.plist has the CFBundleURLTypes entry with the REVERSED_CLIENT_ID; on-device Google Sign-In test passes.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-CONTEXT.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-PATTERNS.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md
@CLAUDE.md
@storage.rules
@ios/Runner/Info.plist
@ios/Runner/GoogleService-Info.plist
@ios/Runner/AppDelegate.swift
@lib/application/viewmodels/profile/profile_viewmodel.dart
@lib/data/repositories/storage_repository.dart

<interfaces>
<!-- ARCH-06 source-of-truth (PATTERNS.md § 6 Avatar Upload Edit Sites lines 716-762) -->

Current broken state (post-Plan-03 path; the file moved from lib/features/profile/ to lib/application/viewmodels/profile/):

  Edit site 1 — profile_viewmodel.dart:~232 (line number may have shifted from the historical "232" because Plan 05's refactor changed the surrounding code; locate by content):
    BROKEN: `final ref = _storage.ref('avatars/${user.uid}.jpg');`
    CORRECT: `await ref.read(storageRepositoryProvider).uploadImage(uid: user.uid, file: File(avatarFile.path), suffix: 'avatar.jpg', contentType: 'image/jpeg');`
    The repo internally builds path `uploads/${uid}/${DateTime.now().millisecondsSinceEpoch}_avatar.jpg` which matches `storage.rules` `match /uploads/{uid}/{allPaths=**}`.

  Edit site 2 — profile_viewmodel.dart:~429 (same caveat on line number):
    BROKEN: `await _storage.ref('avatars/$uid.jpg').delete();`
    Cannot be statically corrected because the new upload path includes a `millisecondsSinceEpoch` timestamp — viewmodel does not know the exact path to delete.
    RESOLUTION (RESEARCH § Code Examples lines 844-853): no-op the delete with a documented comment. Orphan storage objects on account deletion accepted as a Phase 1 limitation; the user's account row goes away, the storage object becomes inaccessible but takes up <100KB. Phase 4+ may add a Storage list-and-delete sweep using a Cloud Function.

<!-- ARCH-07 source-of-truth (PATTERNS.md § 5 lines 695-713 + RESEARCH § Common Pitfalls Pitfall 8 lines 807-824) -->

Current Info.plist state (confirmed by direct file read in research):
  - Contains: NSPhotoLibraryUsageDescription, NSCameraUsageDescription, CFBundleIdentifier (and standard keys).
  - Missing: CFBundleURLTypes entirely.

Required addition (PATTERNS.md lines 700-712):
```
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.YOUR_CLIENT_NUMBER</string>
    </array>
  </dict>
</array>
```

YOUR_CLIENT_NUMBER is the segment after `com.googleusercontent.apps.` in the `REVERSED_CLIENT_ID` field of the new `ios/Runner/GoogleService-Info.plist`. Read it from the plist (Plan 06's new download) at execution time — do NOT hard-code from research.

Native verification path (RESEARCH § code_context lines 174-178 + CLAUDE.md):
  The Dart `AuthViewModel.checkGoogleSignInConfigured()` (or equivalent) calls `MethodChannel('mentor_minds/native_config').invokeMethod('googleSignInStatus')`. Swift side (`ios/Runner/AppDelegate.swift` — unchanged) reads `GoogleService-Info.plist.CLIENT_ID` AND scans `Info.plist.CFBundleURLTypes` for a scheme starting with `com.googleusercontent.apps.`. Returns `{configured: true|false, reason: "..."}`.

  After Plan 06 (new plist) + this plan (Info.plist edit), the Swift probe MUST return `configured: true`.

Storage rules (read-only context — confirms uploads/{uid}/** is the allowed pattern):
  `match /uploads/{uid}/{allPaths=**} { allow read, write: if request.auth.uid == uid; }`
  Therefore: any file path starting `uploads/{uid}/` is permitted; any other path under root is denied.

Pitfalls to avoid (RESEARCH § Common Pitfalls 7 + 8):
  - Don't write `uploads/${uid}_avatar.jpg` (flat path doesn't match the `{uid}/{allPaths=**}` wildcard).
  - Don't put REVERSED_CLIENT_ID in only one of the two files — both `GoogleService-Info.plist` AND `Info.plist` need it.
  - Don't add a NEW URL scheme prefix — the value MUST be the literal `com.googleusercontent.apps.<NUMBER>` reverse-domain form (NOT `https://`, NOT a custom scheme).

Plan 06 prerequisite check:
  Before this plan starts, verify `grep -c 'REVERSED_CLIENT_ID' ios/Runner/GoogleService-Info.plist` returns ≥1. If 0, Plan 06's Task 0 manual checklist was not completed and this plan cannot proceed.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Avatar path fix — profile_viewmodel via StorageRepository</name>
  <files>lib/application/viewmodels/profile/profile_viewmodel.dart, lib/data/repositories/storage_repository.dart</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/lib/application/viewmodels/profile/profile_viewmodel.dart (current state — post-Plan-05; the `_storage` field is gone, replaced by `_storageRepo` from Plan 05; the `avatars/...` string may still be present in the upload call site that Plan 05 routed through `_storageRepo` because Plan 05 only swapped the SDK call, not the path)
    - /Users/arnobrizwan/Mentor-Mind/lib/data/repositories/storage_repository.dart (Plan 05's storage repo — confirm its `uploadImage` method signature uses `suffix` and builds `uploads/{uid}/{ts}_{suffix}`)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-PATTERNS.md (§ 6 Avatar Upload Edit Sites lines 716-762 — both edit sites + the resolution for line 429)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md (§ Common Pitfalls — Pitfall 7: storage.rules match pattern lines 802-805; § Code Examples — Avatar Fix lines 830-855)
    - /Users/arnobrizwan/Mentor-Mind/storage.rules (the deployed rules — confirms `uploads/{uid}/{allPaths=**}` is the only allow-write match)
  </read_first>
  <action>
    Two edits in profile_viewmodel.dart; one defensive sanity-check in storage_repository.dart.

    Step A — Locate the upload site:
      Use grep to find every literal `avatars/` string in `lib/application/viewmodels/profile/profile_viewmodel.dart`:
        `grep -n "avatars/" lib/application/viewmodels/profile/profile_viewmodel.dart`
      Expected count: 2 lines (the upload call + the delete call). If 0: Plan 05 may have already fixed the path during the SDK→repo swap — re-read the file to confirm.

    Step B — Upload site fix:
      Replace the upload-site call (in `updateProfile` method, the part inside `if (avatarFile != null) { ... }`):
        Old (post-Plan-05 — Plan 05 already swapped FirebaseStorage to _storageRepo; the avatar string may have been preserved verbatim through that swap):
          `final url = await _storageRepo.uploadImage(uid: user.uid, file: File(avatarFile.path), suffix: 'avatars/${user.uid}.jpg', ...);`  // wrong suffix
          OR
          `final ref = _storage.ref('avatars/${user.uid}.jpg'); ... final url = await ref.getDownloadURL();`  // if Plan 05 missed this site
        New:
          `final url = await _storageRepo.uploadImage(uid: user.uid, file: File(avatarFile.path), suffix: 'avatar.jpg', contentType: 'image/jpeg');`
      The `suffix` param is the string AFTER the `${ts}_` portion. The repo builds the final path `uploads/${uid}/${DateTime.now().millisecondsSinceEpoch}_avatar.jpg`. The viewmodel does not see the timestamp; it gets back the download URL and proceeds.

    Step C — Delete site no-op (former line ~429):
      Replace the delete call (in the account-deletion path):
        Old: `try { await _storage.ref('avatars/$uid.jpg').delete(); } catch (_) {}` OR `try { await _storageRepo.deleteByPath('avatars/$uid.jpg'); } catch (_) {}`
        New: A documented no-op block — write a multi-line comment explaining WHY the delete is skipped. Suggested text:
        ```
        // ARCH-06 / Plan 07: avatar storage delete is intentionally skipped on account deletion.
        // The upload path is `uploads/{uid}/{ts}_avatar.jpg` where the timestamp is opaque to the
        // viewmodel. A reliable client-side delete would require either (a) recording the upload
        // path on `/users/{uid}.avatarStoragePath`, or (b) a Storage list-and-delete sweep.
        // Both are deferred to Phase 4+. Orphan objects are <100KB each and rate-limited by the
        // user's own delete-account frequency (typically once per account in the user's lifetime).
        ```
      No `_storage.ref(...).delete()` and no `_storageRepo.deleteByPath(...)` call replaces it — the line is fully removed.

    Step D — StorageRepository sanity check (defensive — Plan 05 already implemented this method):
      Read `lib/data/repositories/storage_repository.dart`. Confirm `uploadImage` builds the path as `uploads/${uid}/${DateTime.now().millisecondsSinceEpoch}_${suffix}` (NOT `uploads/${uid}/${suffix}` — the timestamp prefix is what allows multiple uploads to coexist).
      If Plan 05's implementation differs from this, FIX it here and document the change in SUMMARY.md. The repo path-build logic is the single chokepoint that determines whether the path matches storage.rules.

    Step E — Run analyze + spot-check storage.rules compatibility:
      `flutter analyze --fatal-warnings` exits 0.
      `grep -c "avatars/" lib/application/viewmodels/profile/profile_viewmodel.dart` → 0 (both occurrences removed).
      `grep -c "uploads/" lib/data/repositories/storage_repository.dart` → ≥1 (path built inside the repo).

    Commit message: `fix(profile): avatar upload writes to uploads/{uid}/{ts}_avatar.jpg per storage.rules (Phase 1 / ARCH-06; PITFALLS #7)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; n=$(grep -c "avatars/" lib/application/viewmodels/profile/profile_viewmodel.dart); test "$n" -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "uploadImage" lib/application/viewmodels/profile/profile_viewmodel.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "uploads/" lib/data/repositories/storage_repository.dart &amp;&amp; grep -q 'millisecondsSinceEpoch\|DateTime.now()' lib/data/repositories/storage_repository.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --fatal-warnings 2>&amp;1 | tee /tmp/p1-07-t1-analyze.txt &amp;&amp; ! grep -qE '^\s*(error|warning) -' /tmp/p1-07-t1-analyze.txt</automated>
  </verify>
  <acceptance_criteria>
    - Zero occurrences of the literal string `avatars/` anywhere in `lib/application/viewmodels/profile/profile_viewmodel.dart` (both upload + delete sites cleansed).
    - profile_viewmodel.dart references `uploadImage` (the StorageRepository method).
    - `lib/data/repositories/storage_repository.dart` contains `uploads/` AND `millisecondsSinceEpoch` (or `DateTime.now()`) — the timestamped path-build is in place.
    - `flutter analyze --fatal-warnings` exits 0.
    - The delete-site replacement is a multi-line comment block (not a silent removal) explaining the no-op rationale.
  </acceptance_criteria>
  <done>
    ARCH-06 is structurally closed: avatar uploads write to a path the deployed `storage.rules` allow, and the account-deletion no-op is documented. The manual end-to-end QA check (upload an avatar on a simulator) happens in Task 3.
  </done>
</task>

<task type="auto">
  <name>Task 2: Info.plist — add CFBundleURLTypes with REVERSED_CLIENT_ID URL scheme</name>
  <files>ios/Runner/Info.plist</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/ios/Runner/Info.plist (current state — confirm CFBundleURLTypes is absent)
    - /Users/arnobrizwan/Mentor-Mind/ios/Runner/GoogleService-Info.plist (Plan 06's new download — read REVERSED_CLIENT_ID value)
    - /Users/arnobrizwan/Mentor-Mind/ios/Runner/AppDelegate.swift (defines `mentor_minds/native_config` MethodChannel + `googleSignInStatus` implementation — confirm what the Swift code expects to find in Info.plist)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-PATTERNS.md (§ Info.plist — missing CFBundleURLTypes entry lines 695-713)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md (§ Common Pitfalls — Pitfall 8 lines 807-824)
  </read_first>
  <action>
    Step A — Confirm Plan 06 prerequisite:
      `grep -c 'REVERSED_CLIENT_ID' ios/Runner/GoogleService-Info.plist` must return ≥1. If 0, STOP — Plan 06's Task 0 (the Firebase Console download) was not completed; surface this as a blocking issue and DO NOT proceed.

    Step B — Read REVERSED_CLIENT_ID value:
      `grep -A1 'REVERSED_CLIENT_ID' ios/Runner/GoogleService-Info.plist` returns 2 lines; the value line looks like `<string>com.googleusercontent.apps.722452556351-XXXXXXX</string>`. Extract the exact `com.googleusercontent.apps.NUMBER-HASH` string — that is the URL scheme to register.

    Step C — Insert the CFBundleURLTypes block:
      Open `ios/Runner/Info.plist`. Add (BEFORE the closing `</dict>` / `</plist>` of the root dict, idiomatically AFTER existing keys like `NSCameraUsageDescription`):

      ```xml
      <key>CFBundleURLTypes</key>
      <array>
        <dict>
          <key>CFBundleTypeRole</key>
          <string>Editor</string>
          <key>CFBundleURLSchemes</key>
          <array>
            <string>com.googleusercontent.apps.PASTE_THE_EXACT_NUMBER_HASH_HERE</string>
          </array>
        </dict>
      </array>
      ```

      Replace `PASTE_THE_EXACT_NUMBER_HASH_HERE` with the literal value extracted in Step B (including the `com.googleusercontent.apps.` prefix copied from the plist). The string MUST match exactly — case-sensitive.

      DO NOT add any other URL scheme. DO NOT add CFBundleTypeRole = "Viewer". DO NOT remove existing keys. The Info.plist XML must validate (Apple plistutil); a malformed plist breaks the iOS build.

    Step D — Validate Info.plist:
      Run `plutil -lint ios/Runner/Info.plist` (built-in macOS tool). Must exit 0 with "OK".
      Or, if `plutil` is not available, run `python3 -c "import plistlib; plistlib.load(open('ios/Runner/Info.plist','rb'))"` — must not raise.

      Run `grep -c 'com.googleusercontent.apps\.' ios/Runner/Info.plist` → must return 1.
      Run `grep -c 'CFBundleURLTypes' ios/Runner/Info.plist` → must return 1.

    Step E — Light build smoke (without flutter run on device):
      Run `flutter build ios --no-codesign 2>&1 | tee /tmp/p1-07-t2-build.log`. Confirm exit 0.

    Commit message: `feat(ios): wire Google Sign-In REVERSED_CLIENT_ID URL scheme in Info.plist (Phase 1 / ARCH-07; PITFALLS #8)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; n=$(grep -c 'REVERSED_CLIENT_ID' ios/Runner/GoogleService-Info.plist); test "$n" -ge 1</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; n=$(grep -c 'CFBundleURLTypes' ios/Runner/Info.plist); test "$n" -eq 1</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; n=$(grep -c 'com\.googleusercontent\.apps\.' ios/Runner/Info.plist); test "$n" -ge 1</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ( plutil -lint ios/Runner/Info.plist 2>&amp;1 || python3 -c "import plistlib; plistlib.load(open('ios/Runner/Info.plist','rb'))" 2>&amp;1 ) | tee /tmp/p1-07-t2-plist.log &amp;&amp; ( grep -q 'OK$' /tmp/p1-07-t2-plist.log || test -s /tmp/p1-07-t2-plist.log = "" )</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter build ios --no-codesign 2>&amp;1 | tee /tmp/p1-07-t2-build.log; test $? -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; reversed=$(grep -A1 'REVERSED_CLIENT_ID' ios/Runner/GoogleService-Info.plist | grep -oE 'com\.googleusercontent\.apps\.[A-Za-z0-9_-]+' | head -1); test -n "$reversed" &amp;&amp; grep -q "$reversed" ios/Runner/Info.plist</automated>
  </verify>
  <acceptance_criteria>
    - `ios/Runner/Info.plist` contains exactly one `CFBundleURLTypes` key.
    - The Info.plist contains at least one URL scheme starting with `com.googleusercontent.apps.`.
    - The REVERSED_CLIENT_ID value in `GoogleService-Info.plist` is byte-identical to the URL scheme string in `Info.plist` (last automated check extracts from plist A and greps in plist B).
    - `plutil -lint` (or plistlib parse fallback) confirms the plist is valid XML.
    - `flutter build ios --no-codesign` exits 0.
  </acceptance_criteria>
  <done>
    Info.plist has the OAuth callback URL scheme. The native Swift probe in `googleSignInStatus` (via `mentor_minds/native_config` MethodChannel) should now return `configured: true` instead of `configured: false`. Task 3 verifies this on a real device.
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 3 (CHECKPOINT): Manual QA — avatar upload + Google Sign-In on simulator + device</name>
  <files>(no edits — verification only)</files>
  <what-built>
    - Avatar upload now writes to `uploads/{uid}/{ts}_avatar.jpg` instead of `avatars/{uid}.jpg`.
    - `ios/Runner/Info.plist` has the `CFBundleURLTypes` entry with the REVERSED_CLIENT_ID URL scheme.
    - The existing `mentor_minds/native_config` MethodChannel `googleSignInStatus` probe should now return `configured: true`.
  </what-built>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md (§ Manual-Only Verifications — rows for ARCH-06 + ARCH-07)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md (§ Code Examples — Avatar Fix verification line 856)
    - /Users/arnobrizwan/Mentor-Mind/ios/Runner/AppDelegate.swift (`googleSignInStatus` implementation — confirms what counts as "configured: true")
  </read_first>
  <how-to-verify>
    Two manual verifications. Both must pass before resuming.

    **Verification A — Avatar upload (ARCH-06):**
    1. Start the Firebase Local Emulator Suite from Plan 01: `firebase emulators:start --only auth,firestore,storage --import=tool/emulator-data`. Leave it running in one terminal.
    2. In another terminal, run: `flutter run --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY --dart-define=USE_EMULATOR=true -d "iPhone 15 Simulator"` (or whatever simulator id `flutter devices` shows).
    3. Register a new test user via the Register screen (any email/password — the emulator Auth accepts anything).
    4. Navigate to Profile screen.
    5. Tap the avatar / "Change photo" button.
    6. Pick an image from the simulator's Photos app (drag-and-drop an image to the simulator window if Photos is empty).
    7. Save the profile.
    8. Expected outcome: NO `permission-denied` error in the Xcode debug console; the new avatar renders on the Profile screen after the save completes.
    9. To prove the upload landed at the correct path, open the Emulator UI at http://localhost:4000 → Storage tab → confirm a file appears under `uploads/{uid}/{timestamp}_avatar.jpg` (NOT under `avatars/`).
    10. Type "avatar-ok" if all 9 steps succeed; describe the failure mode otherwise.

    **Verification B — Google Sign-In configured (ARCH-07):**
    1. On a PHYSICAL iOS 14.2+ device (or iOS 14.2+ simulator if the Apple ID has Google Sign-In test credentials — simulator is acceptable for the "configured: true" probe even if the actual OAuth flow needs a real device).
    2. Run: `flutter run -d <device-id>` (no --dart-define needed; production Firebase project is fine for the configured-check).
    3. Navigate to the Login screen.
    4. Confirm: the "Sign in with Google" button is VISIBLE (it is hidden when `googleSignInStatus` returns `configured: false`). Visibility of the button is the success criterion for the configured-check.
    5. (OPTIONAL — full E2E) Tap the button. If on a real device with a Google account configured in Apple Settings, the OAuth flow opens. Complete it. Confirm the app routes to /dashboard after the handshake.
    6. (OPTIONAL — fallback diagnostic) Run from the Dart side a one-off `MethodChannel('mentor_minds/native_config').invokeMethod('googleSignInStatus')` and log the response — must contain `{configured: true}`.
    7. Type "google-signin-configured" if step 4 succeeded; describe issues otherwise.

    Both verifications must succeed. If verification A fails with a non-permission-denied error (e.g. emulator storage offline, image_picker permission denied), document it in SUMMARY.md as an unrelated infra issue — the ARCH-06 closure is still valid if path is correct.

    Type "approved" once both succeed, OR describe issues.
  </how-to-verify>
  <resume-signal>Type "approved" or describe issues</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| client → Firebase Storage | `storage.rules` enforce path-based ACL: only `uploads/{uid}/{anything}` writes are accepted; any other path is denied at the rules layer |
| Info.plist CFBundleURLTypes ⇄ Google OAuth callback | The URL scheme registers iOS to handle the `com.googleusercontent.apps.X` callback from Google's OAuth consent screen; without it, the auth flow returns to a black screen |
| GoogleService-Info.plist (Firebase-managed) ⇄ Info.plist (Xcode-managed) | The two plists must agree on the REVERSED_CLIENT_ID value; the value in GSI-plist is the source of truth and gets copied to Info.plist |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-1-STORAGE | Tampering / Information Disclosure | A path like `avatars/{uid}.jpg` (the previous broken path) attempts to write outside the `uploads/{uid}/**` allowed pattern; if the user has any other allow-write rule for arbitrary paths (they don't, per storage.rules), it could land in an unintended location | mitigate | Task 1 routes ALL avatar writes through `StorageRepository.uploadImage` which hard-codes the `uploads/{uid}/...` prefix; the suffix is a caller-supplied filename component (`avatar.jpg`) but the path prefix is not callable from outside the repo |
| T-1-ORPHAN | Repudiation | Orphan storage objects accumulating after account deletion (we no-op the delete) | accept | Documented in code comment + SUMMARY.md; objects are <100KB each, rate-limited by account-deletion frequency; Phase 4+ may add a Cloud Function sweep |
| T-1-OAUTH-MISCONFIG | Spoofing | A wrong / mismatched URL scheme in Info.plist could either (a) silently fail OAuth (button hides; users can't sign in), or (b) accept a callback meant for a different OAuth client (worst case) | mitigate | Task 2 extracts REVERSED_CLIENT_ID directly from the plist Plan 06 downloaded from Firebase Console; the automated check at the end of Task 2 confirms byte-identical strings between the two plists (no copy-paste typos) |
| T-1-IDENT (cross-ref) | Spoofing | Plan 06's bundle id flip + this plan's URL scheme together prevent the old `com.arnobrizwan.mentorminds` bundle from receiving OAuth callbacks meant for `com.mentorminds.mentorMinds` | mitigate | Plan 06 unregistered the old iOS app in Firebase Console; this plan registers the new URL scheme; the OAuth issuer (Google) only accepts callbacks from URL schemes registered with the project's iOS OAuth client |
</threat_model>

<verification>
- Task 1: zero `avatars/` strings in profile_viewmodel.dart; `uploadImage` call present; storage_repository.dart builds `uploads/{uid}/{ts}_{suffix}`.
- Task 2: Info.plist has exactly one CFBundleURLTypes block with the URL scheme byte-identical to the REVERSED_CLIENT_ID value in GoogleService-Info.plist.
- Task 3 (manual): avatar upload succeeds end-to-end against emulator Storage; storage object appears at `uploads/{uid}/{ts}_avatar.jpg`; Google Sign-In button is visible (proves `googleSignInStatus → configured: true`).
- `flutter analyze --fatal-warnings` exits 0.
- `flutter build ios --no-codesign` exits 0.
- `plutil -lint ios/Runner/Info.plist` exits 0.
</verification>

<success_criteria>
- ARCH-06 closed: avatar uploads write to a `storage.rules`-permitted path; end-to-end manual verification passes.
- ARCH-07 closed: REVERSED_CLIENT_ID URL scheme is in Info.plist; native `googleSignInStatus` probe returns `configured: true`; Google Sign-In button is visible on the Login screen.
- T-1-STORAGE and T-1-OAUTH-MISCONFIG closed.
- T-1-ORPHAN accepted with documented rationale (Phase 4+ sweep).
</success_criteria>

<output>
Create `.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-07-avatar-and-google-signin-SUMMARY.md` when done. Record: the profile_viewmodel.dart diff (before/after for both edit sites), the Info.plist diff (the CFBundleURLTypes block added), the REVERSED_CLIENT_ID value extracted from GoogleService-Info.plist (redacted to last 4 chars if treated as sensitive — but per Firebase docs the client id is public), the literal output of the avatar manual verification (Emulator UI screenshot reference or path observation), and the Google Sign-In button visibility + (if attempted) OAuth handshake result.
</output>
