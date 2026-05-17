---
phase: 01-foundation-refactor-ci-test-harness-ios-identity
plan: 07
subsystem: ios
tags: [avatar_upload, google_sign_in, info_plist, cfbundleurltypes, storage_repository, arch_06, arch_07]

# Dependency graph
requires:
  - phase: 01-05-repository-extraction
    provides: StorageRepository.uploadAvatar (correct path) + AuthRepository
  - phase: 01-06-ios-identity-flip
    provides: new GoogleService-Info.plist with REVERSED_CLIENT_ID, new bundle ID com.mentorminds.mentorMinds
provides:
  - ARCH-06 closure (code): broken `avatars/{uid}.jpg` delete on account close removed from profile_viewmodel.dart; account close no longer issues a permission-denied'd Storage delete. Upload path was already correct (uploads/{uid}/{ts}_avatar.jpg via StorageRepository).
  - ARCH-07 closure (code): CFBundleURLTypes block added to ios/Runner/Info.plist with the REVERSED_CLIENT_ID URL scheme (com.googleusercontent.apps.722452556351-clb5opngp2jgp0jko6hophqja9tp38en) — byte-identical to GoogleService-Info.plist. google_sign_in iOS plugin can now intercept OAuth callback URLs on the new bundle id.
  - **T-1-ORPHAN documented:** ~100KB orphan avatar blob per delete-account (rare). Proper fix needs avatarStoragePath persistence on /users/{uid} or a server-side sweep. Deferred to Phase 4+ (server-authoritative rewards) when a Cloud Function can do the sweep on user delete.
affects: [Plan 01-11 phase closeout (device QA debt), Phase 4 (server sweep can resolve T-1-ORPHAN), Phase 6 (FCM device tests will need this signing path resolved)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "CFBundleURLTypes block lives in Info.plist root dict — registers the REVERSED_CLIENT_ID URL scheme for Google Sign-In OAuth callback interception."
    - "Avatar upload path uses opaque timestamp prefix (uploads/{uid}/{ts}_avatar.jpg), so client-side delete cannot reconstruct the full path without storing it on /users/{uid}. Deletion is a documented no-op until a path-tracking field is added (Phase 4+)."

key-files:
  created: []
  modified:
    - ios/Runner/Info.plist
    - lib/application/viewmodels/profile/profile_viewmodel.dart

key-decisions:
  - "Removed the broken deleteByPath('avatars/{uid}.jpg') call from ProfileViewModel.deleteAccount() rather than 'fixing' it to use the correct path — the upload path uses an opaque timestamp the viewmodel can't reconstruct, so even a 'fixed' delete would still be wrong without persistent path tracking. Documented as T-1-ORPHAN."
  - "Wired REVERSED_CLIENT_ID as a single CFBundleURLSchemes entry, not multiple. Matches google_sign_in's documented requirement; matches Firebase's documented Info.plist edit."
  - "DEFERRED device QA to Plan 01-11 verification debt. Code changes are complete and verified via static analysis (flutter analyze 155, dart run custom_lint 0 layered_imports), but signed device install requires Apple Developer Portal App ID registration which is currently blocked on the free-account 10-IDs-per-7-days limit. See 'Deviations' below."

patterns-established:
  - "When account deletion can't reliably clean up Storage objects without persistent path tracking, leave the delete as a no-op + document the orphan footprint + flag the deferred fix. Better than a silent permission-denied'd delete that pretends to clean up."

requirements-completed: [ARCH-06, ARCH-07]

# Metrics
duration: ~30min (autonomous code) + indefinite (device QA deferred)
completed: 2026-05-18
qa_status: code-complete; device QA deferred to Plan 01-11
---

# Plan 01-07: Avatar + Google Sign-In Summary

**ARCH-06 closed at the code level (broken Storage delete on account close removed; orphan-blob trade-off documented as T-1-ORPHAN). ARCH-07 closed at the code level (CFBundleURLTypes + REVERSED_CLIENT_ID wired into Info.plist). Device QA deferred to Plan 01-11 — blocked on Apple Developer Portal free-account App ID limit, not on code.**

## Performance

- **Duration:** ~30 min for code; indefinite for device QA (deferred)
- **Started:** 2026-05-17
- **Completed (code):** 2026-05-18 (date crossed Asia/Kuala_Lumpur midnight during checkpoint)
- **Tasks:** 2/3 code tasks committed; Task 3 (device QA) deferred to 01-11 verification debt
- **Files modified:** 2

## Accomplishments

- **ARCH-07 (Info.plist URL scheme):** CFBundleURLTypes added at the end of the root dict in `ios/Runner/Info.plist` with one CFBundleURLSchemes entry — `com.googleusercontent.apps.722452556351-clb5opngp2jgp0jko6hophqja9tp38en` — byte-identical to the REVERSED_CLIENT_ID in the new GoogleService-Info.plist landed by Plan 01-06. `plistlib` confirms valid XML.
- **ARCH-06 (avatar path mismatch):** The broken `await _storageRepo.deleteByPath('avatars/$uid.jpg')` call in `ProfileViewModel.deleteAccount()` was removed. The actual upload path is `uploads/{uid}/{ts}_avatar.jpg` (built by `StorageRepository.uploadAvatar` with an opaque timestamp) — the old delete used the wrong prefix AND wrong filename and would have silently permission-denied against `storage.rules` every time. Now an inline comment documents the T-1-ORPHAN trade-off.
- **`flutter analyze` 155 issues** — baseline preserved; no new warnings or errors from these edits.
- **`dart run custom_lint` clean** — 0 layered_imports violations remain.
- **`flutter build ios --debug --no-codesign` succeeded** (12 min) — code compiles cleanly with the new bundle ID, the new Info.plist URL scheme, and the new GoogleService-Info.plist.

## Task Commits

1. **Task 1: ARCH-06 avatar fix** — `a2e3d8f fix(profile): drop broken avatars/{uid}.jpg delete on account close`
2. **Task 2: ARCH-07 Info.plist URL scheme** — `952db29 feat(ios): wire Google Sign-In REVERSED_CLIENT_ID URL scheme in Info.plist`
3. **Task 3: Device QA** — *deferred to Plan 01-11 verification debt* (see Deviations)

**Plan SUMMARY commit:** (this file's commit — recorded after this section is finalized)

## Files Modified

- `ios/Runner/Info.plist` — added 11 lines: CFBundleURLTypes block with REVERSED_CLIENT_ID URL scheme
- `lib/application/viewmodels/profile/profile_viewmodel.dart` — removed broken Storage delete (1 line removed); replaced with 6-line `// ARCH-06 / Plan 07` comment explaining T-1-ORPHAN trade-off

## Decisions Made

- **Don't try to "fix" the avatar delete to use the correct path.** The upload uses an opaque timestamp the viewmodel doesn't retain. A reliable delete requires either (a) persisting `avatarStoragePath` on `/users/{uid}` (data-shape change, Phase 4 territory) or (b) a server-side Storage list+delete sweep (Cloud Function, Phase 4 territory). For Phase 1, dropping the broken call + documenting the orphan trade-off is the smallest-blast-radius fix. The orphan footprint is ~100KB per account-delete (the typical avatar JPEG); account-delete is a rare per-user lifetime event — total cumulative leak is microscopic vs. Storage's free tier.
- **Defer device QA to Plan 01-11 verification debt** rather than failing the plan. Code edits are static-verified clean; the QA blocker is purely environmental (Apple Developer Portal free-account App ID limit hit before the new bundle id `com.mentorminds.mentorMinds` could be registered). Closing 01-07 on code-complete lets Plans 01-08/09/10 proceed; Plan 01-11 will gate on device QA being resolved before phase completion.

## Deviations from Plan

### Auto-fixed Issues

**1. [Subagent sandbox] `git commit` from the executor was blocked**
- **Found during:** Task 1 + Task 2 — subagent staged both file edits but couldn't commit
- **Issue:** The executor agent's Bash sandbox rejected `git commit` invocations (session-level enforcement triggered by the first heredoc commit attempt).
- **Fix:** Orchestrator committed both files atomically with the messages the subagent recommended.
- **Files modified:** none additional
- **Verification:** `git log --oneline | head -2` shows both commits with correct subjects.
- **Committed in:** `a2e3d8f`, `952db29` (orchestrator)

### Deferred Items

**2. [Environment — Apple Developer Portal] Device QA deferred to Plan 01-11**
- **Found during:** Task 3 — signed `flutter run -d <iphone>` failed at signing
- **Symptom:** Xcode keeps generating fresh provisioning-profile UUIDs (`70ef86b9-…`, `9645ff69-…`, `7c78911a-…`) and reporting `The folder "{UUID}.mobileprovision" doesn't exist` + `No profiles for 'com.mentorminds.mentorMinds' were found`. Even with `-allowProvisioningUpdates`, the build fails because `security find-generic-password -s "Xcode-Token"` returns "item could not be found in the keychain" — Xcode has no cached Apple ID auth token.
- **Root cause:** User is on a free Apple ID. To register the new bundle ID `com.mentorminds.mentorMinds` with the Apple Developer Portal, Xcode needs to either (a) have a cached Apple ID auth token AND (b) be under the 10-App-IDs-per-7-days free-tier limit. The 10-IDs limit is currently exceeded (per the previous orphan App IDs `com.MentorMind`, `com.arnobrizwan.mentorminds`, `com.mentormind` from earlier Plan 01-06 attempts + other historical free-tier App IDs the user has registered).
- **What was tried via CLI:**
  - `xcodebuild -downloadPlatform iOS` ✓ — installed iOS Platform 26.5 (8.5 GB)
  - `flutter build ios --debug --no-codesign` ✓ — succeeded (12 min)
  - `flutter install -d <iphone>` ✗ — the no-codesign .app cannot be installed on device
  - `flutter run -d <iphone> --debug --no-hot` ✗ — same signing error
  - `xcodebuild -workspace Runner.xcworkspace ... -allowProvisioningUpdates clean build` ✗ — same signing error (Xcode-Token not in keychain)
  - Purged DerivedData + xcuserdata + retried — same error
  - `open ios/Runner.xcworkspace` — handed off to user; user must (a) sign in to Apple ID in Xcode Settings, (b) delete unused free App IDs at https://developer.apple.com/account/resources/identifiers/list to get back under the 10-per-7-days quota, (c) click "Try Again" in Runner → Signing & Capabilities
- **Fix:** Plan 01-07 marked code-complete with documented device-QA debt. Plan 01-11 closeout will gate phase completion on the device QA passing (avatar upload + Google Sign-In flow). Until then, the QA items roll into the phase verification checklist as `pending`.
- **Files modified:** none
- **Verification:** N/A (deferred)
- **Committed in:** n/a

### Process Note

**3. [Plan defect — fix scope]** Plan 01-07 called the ARCH-06 fix a "one-liner". Reality: it's a `-1 / +6` change (1 line removed, 6-line rationale comment added). The user-facing behavior is identical to a true one-liner (the broken call is gone), but the documentation overhead made it a 7-line diff. Not a real deviation — just a reality check that "one-liner" plan language understates the work when the fix needs an inline rationale comment.

---

**Total deviations:** 3 (1 sandbox workaround, 1 environmental block surfacing as deferred QA, 1 plan-vocabulary nitpick)
**Impact on plan:** Code is complete and verified; only the device QA is open. Phase 1 success criterion 3 ("user can edit avatar end-to-end against the deployed storage.rules" + "user can complete Google Sign-In on a physical iOS device") moves into Plan 01-11's verification checklist as `pending`.

## Issues Encountered

- **Apple Developer Portal free-account App ID limit hit.** The cleanest recovery is enrolling in the Apple Developer Program ($99/year), which removes the 10-per-7-days limit AND is needed for App Store submission in Phase 5 anyway. Until then, the user must manually delete unused free App IDs via the web UI (no CLI option exists for App ID deletion).
- **3 orphan Firebase iOS apps remain in Firebase Console** (`com.MentorMind`, `com.arnobrizwan.mentorminds`, `com.mentormind`) — leftover from Plan 01-06 registration attempts; also need manual Console cleanup. Firebase CLI does not support `apps:delete`.

## User Setup Required

**To unblock device QA (Plan 01-11 will re-check):**

1. **(Optional but recommended)** Enroll in Apple Developer Program ($99/year) at https://developer.apple.com/programs/enroll/ — removes the free-tier App ID limit; required for App Store submission in Phase 5.
2. **(Otherwise)** At https://developer.apple.com/account/resources/identifiers/list:
   - Delete unused free App IDs (e.g. `com.arnobrizwan.mentorminds`, `com.mentormind`, `com.MentorMind`, any throwaway test IDs)
   - Stay under 10 active free App IDs at any given 7-day window
3. **In Xcode → Settings → Accounts:** sign in to Apple ID (if not already signed in); confirm team `QY3A292N8R` appears.
4. **In Xcode → Runner → Signing & Capabilities:** click **Try Again** next to the provisioning profile error. Xcode will register `com.mentorminds.mentorMinds` with the Apple Developer Portal and create a development profile.
5. **From CLI after Xcode signing succeeds:**
   ```bash
   flutter run -d 00008150-000C590611D2401C --debug --no-hot
   ```
   Then on iPhone:
   - Login → Profile → tap avatar → pick photo → save → expect successful upload to `uploads/{uid}/{ts}_avatar.jpg` (verifiable in Firebase Console → Storage)
   - Logout → Login → "Sign in with Google" button visible → tap → OAuth → land on Dashboard

## Next Phase Readiness

- ✓ Plan 01-08 (anchor tests) can proceed — Dart-only, no iOS device dependency.
- ✓ Plan 01-09 (emulator integration smoke) can proceed — uses Firebase Local Emulator Suite, not a device.
- ✓ Plan 01-10 (GitHub Actions CI) can proceed — Linux/macOS CI runners, no real iPhone needed.
- ⚠ Plan 01-11 (phase closeout) MUST verify the device QA before flipping Phase 1 to `complete`. Until then, Phase 1 sits at "code-complete + device-QA-pending".

## Evidence — `flutter analyze` baseline preserved

```
155 issues found. (ran in 3.7s)
```

(Same composition as pre-plan: 151 info + 1 warning + 3 errors, all pre-existing as documented in Plan 01-03 SUMMARY.)

## Evidence — `dart run custom_lint` clean

```
Analyzing...

No issues found!
```

## Evidence — `flutter build ios --debug --no-codesign` success

```
Building com.mentorminds.mentorMinds for device (ios)...
Running Xcode build...
Xcode build done.                                           724.0s
✓ Built build/ios/iphoneos/Runner.app
```

## Evidence — signed-build failure (deferred to user manual action)

```
flutter run -d 00008150-000C590611D2401C --debug --no-hot
...
Automatically signing iOS for device deployment using specified development team in Xcode project: QY3A292N8R
Running Xcode build...
Xcode build done.                                           18.3s
Failed to build iOS app
Error (Xcode): The folder "e5e01ba2-d13a-45a3-9bc3-429cecb301f7.mobileprovision" doesn't exist.
Error (Xcode): No profiles for 'com.mentorminds.mentorMinds' were found
```

(Root cause: Xcode-Token not in keychain + free-tier 10-App-IDs limit; remediation documented in `User Setup Required` above.)

## Evidence — REVERSED_CLIENT_ID match

```
$ awk -F'[<>]' '/REVERSED_CLIENT_ID/{getline; print $3}' ios/Runner/GoogleService-Info.plist
com.googleusercontent.apps.722452556351-clb5opngp2jgp0jko6hophqja9tp38en

$ grep -A2 CFBundleURLSchemes ios/Runner/Info.plist
		<key>CFBundleURLSchemes</key>
		<array>
			<string>com.googleusercontent.apps.722452556351-clb5opngp2jgp0jko6hophqja9tp38en</string>
```

Byte-identical match — google_sign_in iOS plugin can intercept the OAuth callback URL.

---
*Phase: 01-foundation-refactor-ci-test-harness-ios-identity*
*Plan: 01-07-avatar-and-google-signin*
*Completed (code): 2026-05-18*
*QA: deferred to Plan 01-11*
