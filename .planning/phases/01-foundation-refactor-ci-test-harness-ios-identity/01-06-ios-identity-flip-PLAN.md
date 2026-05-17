---
phase: 01-foundation-refactor-ci-test-harness-ios-identity
plan: 06
type: execute
wave: 1
depends_on: ["01-01"]
files_modified:
  - ios/Podfile
  - ios/Runner.xcodeproj/project.pbxproj
  - ios/Runner/Runner.entitlements
  - ios/Runner/GoogleService-Info.plist
  - lib/firebase_options.dart
  - BACKEND_SETUP.md
autonomous: false
requirements: [ARCH-04, ARCH-05]
requirements_addressed: [ARCH-04, ARCH-05]
tags: [ios, bundle_id, deployment_target, firebase_console, apns, human_in_the_loop]

user_setup:
  - service: firebase_console
    why: "Register a new iOS app under bundle id com.mentorminds.mentorMinds and re-associate APNs auth key"
    dashboard_config:
      - task: "Register new iOS app with bundle id `com.mentorminds.mentorMinds`"
        location: "Firebase Console → Project Settings → Your apps → Add app → iOS"
      - task: "Download replacement GoogleService-Info.plist (must contain CLIENT_ID and REVERSED_CLIENT_ID)"
        location: "Firebase Console → Project Settings → iOS apps → mentor-mind-aa765 → GoogleService-Info.plist"
      - task: "Re-upload existing APNs .p8 auth key to the NEW iOS app (Apple .p8 keys are per Apple Team, not per bundle id — same .p8 can be re-associated)"
        location: "Firebase Console → Project Settings → Cloud Messaging → Apple app configuration → APNs Authentication Key → Upload"
  - service: apple_developer_portal
    why: "Update Xcode signing identity to match the new bundle id"
    dashboard_config:
      - task: "Confirm App ID exists for com.mentorminds.mentorMinds (auto-provisioning is typically enabled for development; for release, explicit App ID may be needed)"
        location: "Apple Developer → Certificates, Identifiers & Profiles → Identifiers"

must_haves:
  truths:
    - "`PRODUCT_BUNDLE_IDENTIFIER` is `com.mentorminds.mentorMinds` in ALL THREE xcodeproj build configurations (Debug, Release, Profile)"
    - "D-15: iOS toolchain builds against iOS 26 SDK (Xcode 26.x) with minimum deployment target `14.2` (one notch above 14.0 — captures App Attest stability fixes); `IPHONEOS_DEPLOYMENT_TARGET` is `14.2` in ALL THREE xcodeproj build configurations AND in `ios/Podfile` AND in the Podfile `post_install` threshold"
    - "`ios/Runner/Runner.entitlements` `keychain-access-groups` uses the new bundle id prefix `$(AppIdentifierPrefix)com.mentorminds.mentorMinds`"
    - "`ios/Runner/GoogleService-Info.plist` contains `CLIENT_ID` AND `REVERSED_CLIENT_ID` keys (the OLD plist has neither — confirms a fresh download)"
    - "`lib/firebase_options.dart` has been regenerated via `flutterfire configure` for the new bundle id (Firestore App ID in the file matches the new Firebase Console iOS app registration)"
    - "`flutter build ios --no-codesign` exits 0 (proves Xcode toolchain accepts the new identity + deployment target)"
    - "`BACKEND_SETUP.md` documents the human-in-the-loop checklist with check-able items"
  artifacts:
    - path: "ios/Podfile"
      provides: "iOS 14.2 minimum deployment target locked"
      contains: "platform :ios, '14.2'"
    - path: "ios/Runner.xcodeproj/project.pbxproj"
      provides: "Bundle ID + deployment target in all 3 build configs"
      contains: "com.mentorminds.mentorMinds"
    - path: "BACKEND_SETUP.md"
      provides: "Human-in-the-loop checklist for Firebase Console + Apple Developer Portal steps"
      contains: "Bundle ID|APNs|GoogleService-Info"
  key_links:
    - from: "ios/Runner.xcodeproj/project.pbxproj"
      to: "ios/Runner/GoogleService-Info.plist"
      via: "build phase 'Copy Bundle Resources'"
      pattern: "GoogleService-Info\\.plist"
    - from: "ios/Runner/Info.plist"
      to: "ios/Runner/GoogleService-Info.plist"
      via: "REVERSED_CLIENT_ID URL scheme (wired in Plan 07)"
      pattern: "REVERSED_CLIENT_ID"
---

<objective>
PR-3 iOS identity portion. Flip the iOS bundle identifier from `com.arnobrizwan.mentorminds` to `com.mentorminds.mentorMinds` in all three Xcode build configurations + entitlements (ARCH-04), bump the iOS minimum deployment target from 13.0 to 14.2 in all three xcodeproj configs + Podfile + post_install hook (ARCH-05, unlocks App Attest as the primary App Check provider in Phase 2), swap in the freshly-downloaded `GoogleService-Info.plist` (which now contains `CLIENT_ID` + `REVERSED_CLIENT_ID` — the OLD plist had neither), regenerate `lib/firebase_options.dart` via `flutterfire configure`, and prove the build still compiles on Xcode 26 / CocoaPods 1.16.

Purpose: This is the highest-blast-radius plan in Phase 1 — it touches Firebase Console (human-in-the-loop), Apple Developer Portal (signing), Xcode project files, Pods, and the generated firebase_options.dart. The work CAN run in parallel with Plan 03's pure git mv (Wave 1) because the file sets are completely disjoint — Plan 03 only touches `lib/`, this plan only touches `ios/`, `lib/firebase_options.dart` (regenerated), and `BACKEND_SETUP.md`. Lumping in `lib/firebase_options.dart` is safe because the file is auto-generated and not edited by any other Phase 1 plan.

Output: New bundle id active across all build configs, deployment target at 14.2, pods recompiled at the new floor, new `GoogleService-Info.plist` in place with `CLIENT_ID`/`REVERSED_CLIENT_ID` populated, regenerated firebase_options.dart, BACKEND_SETUP.md with the documented checklist, and proof of clean `flutter build ios --no-codesign`.
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
@ios/Podfile
@ios/Runner.xcodeproj/project.pbxproj
@ios/Runner/Runner.entitlements
@ios/Runner/Info.plist
@ios/Runner/GoogleService-Info.plist
@firebase.json

<interfaces>
<!-- All target values from PATTERNS.md § 5 (lines 654-713) — confirmed by direct file reads in research -->

Bundle ID change (ARCH-04):
  OLD: com.arnobrizwan.mentorminds
  NEW: com.mentorminds.mentorMinds   (note capital M in mentorMinds — locked per CONTEXT.md spec)

Deployment target change (ARCH-05):
  OLD: 13.0
  NEW: 14.2

Files to edit (exact line numbers from PATTERNS.md § 5 lines 657-668 — confirmed by direct file read):

  ios/Podfile
    Line  2: `# platform :ios, '13.0'` → `platform :ios, '14.2'` (uncomment and bump)
    Line ~50: `if current < 13.0` → `if current < 14.2`
    Line ~51: `= '13.0'` → `= '14.2'`

  ios/Runner.xcodeproj/project.pbxproj  (FOUND VIA `grep -n` since line numbers may shift; PATTERNS.md gave these as of research date 2026-05-17)
    Line 483: `IPHONEOS_DEPLOYMENT_TARGET = 13.0;` (Profile config) → `IPHONEOS_DEPLOYMENT_TARGET = 14.2;`
    Line 617: `IPHONEOS_DEPLOYMENT_TARGET = 13.0;` (Debug config)   → `IPHONEOS_DEPLOYMENT_TARGET = 14.2;`
    Line 668: `IPHONEOS_DEPLOYMENT_TARGET = 13.0;` (Release config) → `IPHONEOS_DEPLOYMENT_TARGET = 14.2;`
    Line 507: `PRODUCT_BUNDLE_IDENTIFIER = com.arnobrizwan.mentorminds;` (Profile) → `... com.mentorminds.mentorMinds;`
    Line 694: `PRODUCT_BUNDLE_IDENTIFIER = com.arnobrizwan.mentorminds;` (Debug)   → `... com.mentorminds.mentorMinds;`
    Line 718: `PRODUCT_BUNDLE_IDENTIFIER = com.arnobrizwan.mentorminds;` (Release) → `... com.mentorminds.mentorMinds;`
    NOTE: line numbers are advisory. Use `grep -n 'PRODUCT_BUNDLE_IDENTIFIER\|IPHONEOS_DEPLOYMENT_TARGET' ios/Runner.xcodeproj/project.pbxproj` to find the actual lines at execution time. Count of matches MUST be 3 for each before AND after editing.

  ios/Runner/Runner.entitlements
    Line ~7: `<string>$(AppIdentifierPrefix)com.arnobrizwan.mentorminds</string>` → `<string>$(AppIdentifierPrefix)com.mentorminds.mentorMinds</string>`

  ios/Runner/GoogleService-Info.plist
    REPLACE the entire file with the freshly downloaded copy from Firebase Console. The new copy MUST contain:
      - <key>CLIENT_ID</key>          (currently absent — verified by PATTERNS.md line 697 "Current `Info.plist` has no `CFBundleURLTypes`" and RESEARCH § Local grep "confirmed no `CLIENT_ID` in `GoogleService-Info.plist`")
      - <key>REVERSED_CLIENT_ID</key> (currently absent)
      - <key>BUNDLE_ID</key> = com.mentorminds.mentorMinds
      - <key>PROJECT_ID</key> = mentor-mind-aa765 (unchanged — same Firebase project, new iOS app registration within it)

  lib/firebase_options.dart  (auto-generated)
    REGENERATED via `cd <repo> && flutterfire configure --project=mentor-mind-aa765 --platforms=ios` after the new iOS app exists in Firebase Console. The resulting file's `DefaultFirebaseOptions.ios` block will reference the new App ID issued by Firebase Console (a string of the form `1:722452556351:ios:NEW_HEX`).

  BACKEND_SETUP.md  (NEW FILE)
    Documents the human-in-the-loop checklist (see Task 0 / Step A). Lives at repo root per CONTEXT.md § canonical_refs line 145.

Current Podfile excerpt (PATTERNS.md lines 673-688, confirmed by file read):

  platform_target_line: "# platform :ios, '13.0'"  (line 2, currently commented out)

  post_install do |installer|
    installer.pods_project.targets.each do |target|
      flutter_additional_ios_build_settings(target)
      target.build_configurations.each do |config|
        config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
        current = config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f
        if current < 13.0
          config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
        end
      end
    end
  end

  REQUIRED edits: line 2 uncomment + change to '14.2'; lines ~50-51 bump threshold 13.0 → 14.2.

Apple .p8 key re-association (PATTERNS.md Open Question 2 — RESOLUTION lines 935-938):
  - Apple .p8 keys are per Apple Team, NOT per bundle id.
  - The existing .p8 key CAN be re-uploaded to the new Firebase iOS app registration without generating a new key from Apple Developer Portal.
  - Document this in BACKEND_SETUP.md so the user doesn't request a redundant key.

Pitfalls (PATTERNS.md / RESEARCH § Common Pitfalls 5, 6, 8):
  - Pitfall 5: Bumping iOS deployment target in Podfile but NOT in project.pbxproj → Xcode signs with the lower target. Must edit ALL FIVE locations atomically (1 Podfile platform_target + 2 Podfile threshold + 3 project.pbxproj).
  - Pitfall 6: Flipping the bundle id in code without registering the new iOS app in Firebase Console → app launches but Firebase Auth fails silently. This plan is `autonomous: false` precisely because the Firebase Console step has no API equivalent.
  - Pitfall 8: The REVERSED_CLIENT_ID needs to land in BOTH the new GoogleService-Info.plist AND the Info.plist CFBundleURLTypes — but the Info.plist edit is DEFERRED to Plan 07 (ARCH-07 / Google Sign-In wiring). This plan's GoogleService-Info.plist swap is a PREREQUISITE for Plan 07.

Out of scope for this plan (delegated):
  - Info.plist CFBundleURLTypes edit → Plan 07 (it depends on the REVERSED_CLIENT_ID value that lands here, plus the avatar-path fix in the same Plan 07)
  - Avatar path fix → Plan 07 (ARCH-06)
  - Google Sign-In handshake test on real device → Plan 07 (ARCH-07 closure manual check)
</interfaces>
</context>

<tasks>

<task type="checkpoint:human-action" gate="blocking">
  <name>Task 0 (CHECKPOINT): Human-in-the-loop — Firebase Console + Apple Developer Portal steps</name>
  <files>BACKEND_SETUP.md, ios/Runner/GoogleService-Info.plist (new download)</files>
  <what-built>
    A new BACKEND_SETUP.md file at repo root that documents the manual steps the user must perform in the Firebase Console and Apple Developer Portal before any Xcode/Podfile/firebase_options.dart edits land. The downloaded replacement GoogleService-Info.plist is staged at ios/Runner/GoogleService-Info.plist BUT not yet committed — Task 2 commits it together with the Xcode + Podfile edits to keep the bundle-id-flip atomic.
  </what-built>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-CONTEXT.md (D-14 PR-3 lines 88-99 — the exact 4-step Firebase Console checklist)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md (§ Common Pitfalls — Pitfall 6 + Pitfall 8; § Open Questions item 2 — APNs .p8 re-usability)
  </read_first>
  <how-to-verify>
    BEFORE this checkpoint resumes, complete the following 4 steps manually. EACH step must be checked off in BACKEND_SETUP.md (add the file at repo root if it does not exist; if it already exists, append a new Phase 1 section).

    BACKEND_SETUP.md required section (template):
    ```
    ## Phase 1 — iOS Identity Migration Checklist

    Run these 4 manual steps BEFORE the executor edits ios/ or runs `flutterfire configure`.

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
          Do NOT commit yet — Task 2 commits it alongside the project.pbxproj + Podfile edits.

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

    Once all 4 boxes are checked AND the new GoogleService-Info.plist is in place on disk at `ios/Runner/GoogleService-Info.plist`, type "approved" to resume.
    ```

    After running the 4 steps, run these CLI checks to confirm:

    Check 1 — new plist has the Google Sign-In keys:
      `grep -c 'CLIENT_ID\|REVERSED_CLIENT_ID' ios/Runner/GoogleService-Info.plist`
      Expected: 2 or more matches (the OLD plist returns 0).

    Check 2 — plist's BUNDLE_ID matches the new id:
      `grep -A1 'BUNDLE_ID' ios/Runner/GoogleService-Info.plist | grep 'com.mentorminds.mentorMinds'`
      Expected: 1 match.

    Check 3 — BACKEND_SETUP.md exists with the Phase 1 section and all 4 boxes checked:
      `grep -c '^\s*- \[x\]' BACKEND_SETUP.md`
      Expected: 4 or more.
  </how-to-verify>
  <resume-signal>Type "approved" or describe issues</resume-signal>
</task>

<task type="auto">
  <name>Task 1: Xcode project edits — bundle id (3 configs) + deployment target (3 configs) + entitlements</name>
  <files>ios/Runner.xcodeproj/project.pbxproj, ios/Runner/Runner.entitlements</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/ios/Runner.xcodeproj/project.pbxproj (current state — confirm exact line numbers of PRODUCT_BUNDLE_IDENTIFIER and IPHONEOS_DEPLOYMENT_TARGET entries; PATTERNS.md gave 483/507/617/668/694/718 as of research date, but pbxproj line numbers shift if any other edit happened in between)
    - /Users/arnobrizwan/Mentor-Mind/ios/Runner/Runner.entitlements (current state — line 7 has the keychain-access-groups string)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-PATTERNS.md (§ 5 lines 654-712 — full target value table; § iOS Podfile current state lines 671-688)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md (§ Common Pitfalls — Pitfall 5: all 5 locations must change atomically)
  </read_first>
  <action>
    Edit two files. Both edits MUST land in a single commit per the bundle-id-flip atomicity rule (PITFALL 5 + 6 + 8: any partial state leaves the build in a half-flipped state where Firebase Auth silently fails on the OLD bundle id but Xcode signs with the NEW one).

    Step A — `ios/Runner.xcodeproj/project.pbxproj`:
      Use `grep -n` (not hard-coded line numbers) to locate all 3 occurrences each of:
        - `PRODUCT_BUNDLE_IDENTIFIER = com.arnobrizwan.mentorminds;`
        - `IPHONEOS_DEPLOYMENT_TARGET = 13.0;`
      Count must be exactly 3 for each. If the count is anything other than 3, STOP — the file may have been edited by another tool or new build configs added; investigate before proceeding.

      Replace every occurrence:
        `PRODUCT_BUNDLE_IDENTIFIER = com.arnobrizwan.mentorminds;` → `PRODUCT_BUNDLE_IDENTIFIER = com.mentorminds.mentorMinds;`
        `IPHONEOS_DEPLOYMENT_TARGET = 13.0;`                       → `IPHONEOS_DEPLOYMENT_TARGET = 14.2;`

      Verify post-edit:
        `grep -c 'PRODUCT_BUNDLE_IDENTIFIER = com.mentorminds.mentorMinds;' ios/Runner.xcodeproj/project.pbxproj` → 3
        `grep -c 'PRODUCT_BUNDLE_IDENTIFIER = com.arnobrizwan.mentorminds;' ios/Runner.xcodeproj/project.pbxproj` → 0
        `grep -c 'IPHONEOS_DEPLOYMENT_TARGET = 14.2;' ios/Runner.xcodeproj/project.pbxproj` → 3
        `grep -c 'IPHONEOS_DEPLOYMENT_TARGET = 13.0;' ios/Runner.xcodeproj/project.pbxproj` → 0

      DO NOT touch any other line. The pbxproj is a fragile Xcode-managed file — extra edits risk corrupting it.

    Step B — `ios/Runner/Runner.entitlements`:
      Replace the single occurrence (line ~7) of:
        `<string>$(AppIdentifierPrefix)com.arnobrizwan.mentorminds</string>`
      with:
        `<string>$(AppIdentifierPrefix)com.mentorminds.mentorMinds</string>`

      Verify post-edit:
        `grep -c 'com.mentorminds.mentorMinds' ios/Runner/Runner.entitlements` → 1
        `grep -c 'com.arnobrizwan.mentorminds' ios/Runner/Runner.entitlements` → 0

    Step C — DO NOT yet run `pod install` or `flutter build ios`. Task 2 edits the Podfile and then runs both.

    Commit (combine with Task 2 if convenient — single atomic commit is preferred):
      `chore(ios): flip bundle id to com.mentorminds.mentorMinds + iOS 14.2 deployment target (3 configs each) (Phase 1 / ARCH-04, ARCH-05)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; n=$(grep -c 'PRODUCT_BUNDLE_IDENTIFIER = com.mentorminds.mentorMinds;' ios/Runner.xcodeproj/project.pbxproj); test "$n" -eq 3</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; n=$(grep -c 'PRODUCT_BUNDLE_IDENTIFIER = com.arnobrizwan.mentorminds;' ios/Runner.xcodeproj/project.pbxproj); test "$n" -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; n=$(grep -c 'IPHONEOS_DEPLOYMENT_TARGET = 14.2;' ios/Runner.xcodeproj/project.pbxproj); test "$n" -eq 3</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; n=$(grep -c 'IPHONEOS_DEPLOYMENT_TARGET = 13.0;' ios/Runner.xcodeproj/project.pbxproj); test "$n" -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q '\$(AppIdentifierPrefix)com.mentorminds.mentorMinds' ios/Runner/Runner.entitlements &amp;&amp; ! grep -q 'com.arnobrizwan' ios/Runner/Runner.entitlements</automated>
  </verify>
  <acceptance_criteria>
    - `ios/Runner.xcodeproj/project.pbxproj` has exactly 3 occurrences of `PRODUCT_BUNDLE_IDENTIFIER = com.mentorminds.mentorMinds;` and ZERO occurrences of `com.arnobrizwan.mentorminds` (entire file).
    - `ios/Runner.xcodeproj/project.pbxproj` has exactly 3 occurrences of `IPHONEOS_DEPLOYMENT_TARGET = 14.2;` and ZERO occurrences of `IPHONEOS_DEPLOYMENT_TARGET = 13.0;`.
    - `ios/Runner/Runner.entitlements` contains the new keychain-access-groups string and contains ZERO occurrences of the old bundle id.
    - The pbxproj file is still valid Xcode XML (Xcode opens the workspace without errors — verified manually if needed, but not required for the automated checks).
  </acceptance_criteria>
  <done>
    Bundle id and deployment target are correct in all three Xcode build configurations; keychain-access-groups entitlement matches the new bundle id prefix. The Podfile + pod install side lands in Task 2; this task only handles the Xcode-managed files.
  </done>
</task>

<task type="auto">
  <name>Task 2: Podfile bump + pod install + flutterfire configure + flutter build smoke</name>
  <files>ios/Podfile, lib/firebase_options.dart, ios/Pods/** (regenerated by pod install — not tracked in git but Podfile.lock is), ios/Podfile.lock</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/ios/Podfile (current state — line 2 commented out, post_install lines ~39-63 per PATTERNS.md line 671-688)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-PATTERNS.md (§ Required Podfile changes lines 690-694)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md (§ iOS Deployment Target Update — Podfile lines 873-895; § Environment Availability — Xcode 26.5, CocoaPods 1.16.2 confirmed)
    - /Users/arnobrizwan/Mentor-Mind/firebase.json (confirms `lib/firebase_options.dart` is the target output of `flutterfire configure --platforms=ios`)
  </read_first>
  <action>
    Three sequential sub-tasks. All in one commit at the end.

    Step A — Edit `ios/Podfile`:
      Line 2: change `# platform :ios, '13.0'` → `platform :ios, '14.2'` (uncomment AND bump).
      Post-install hook: replace `if current < 13.0` → `if current < 14.2` AND replace the assignment `'13.0'` → `'14.2'` on the line directly below.

      Verify post-edit:
        `grep -c "^\s*platform :ios, '14.2'" ios/Podfile` → 1
        `grep -c "if current < 14\.2" ios/Podfile` → 1
        `grep -c "IPHONEOS_DEPLOYMENT_TARGET'\] = '14.2'" ios/Podfile` → 1
        `grep -c "13\.0" ios/Podfile` → 0

    Step B — Pod deintegrate + install:
      Run `cd ios && pod deintegrate && pod install`. Capture stdout to `/tmp/p1-06-pod-install.log`.
      Expected outcome: pods recompile at the new floor; no "Minimum deployment target should be >= ..." warnings; `Podfile.lock` is updated.
      If any pod fails because it requires a higher minimum (e.g. 15.0+), DOCUMENT it in SUMMARY.md and surface to the user — this is the contingency in CONTEXT.md D-15 ("if any pod requires bumping, do it inside PR-3"). For Firebase ^5.x + google_sign_in ^6.x + connectivity_plus ^6.x + image_picker ^1.x, all confirmed compatible with 14.2 per RESEARCH § Assumptions A2.

    Step C — Regenerate `lib/firebase_options.dart`:
      Run `flutterfire configure --project=mentor-mind-aa765 --platforms=ios --yes` from the repo root.
      Confirm `lib/firebase_options.dart` was rewritten — the `DefaultFirebaseOptions.ios` block's `appId` will now reference the NEW iOS app registered in Task 0 (a different `1:722452556351:ios:NEW_HEX` string from the old one).
      Confirm `firebase.json` was NOT mutated by `flutterfire configure` in a way that drops the existing emulator config (Plan 01 added the `emulators` block; flutterfire configure may overwrite the `flutter.platforms` block but should not touch siblings — verify by diff).
      If `firebase.json` lost the emulators block, restore it from `git show HEAD:firebase.json` and re-merge the platforms update.

    Step D — Build smoke test (no codesign, no real device required):
      Run `flutter clean && flutter pub get && flutter build ios --no-codesign 2>&1 | tee /tmp/p1-06-build.log`.
      Capture exit code. Confirm:
        - Exit code 0.
        - No "Minimum deployment target should be >= ..." warnings (greedy regex over the log).
        - No "PROVISIONING_PROFILE_SPECIFIER" errors (the --no-codesign flag should suppress signing entirely — if signing errors persist, the auto-provisioning profile in Apple Developer is not configured; this is acceptable for Phase 1 and is documented as a follow-up in BACKEND_SETUP.md Step 4).

      If --no-codesign still fails on signing for any reason, fall back to `flutter build ios --no-codesign --simulator` which targets the iOS Simulator and never requires signing. Document the fallback in SUMMARY.md.

    Commit message: `chore(ios): bump deployment target to iOS 14.2, regenerate firebase_options for new bundle id (Phase 1 / ARCH-04, ARCH-05)`. Include `ios/Podfile`, `ios/Podfile.lock`, `lib/firebase_options.dart`, `ios/Runner/GoogleService-Info.plist` (staged from Task 0) in the same commit.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -c "^\s*platform :ios, '14\.2'" ios/Podfile | xargs -I{} test {} -ge 1 &amp;&amp; grep -c "if current < 14\.2" ios/Podfile | xargs -I{} test {} -ge 1 &amp;&amp; ! grep -q "13\.0" ios/Podfile</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -c '1:722452556351:ios:' lib/firebase_options.dart | xargs -I{} test {} -ge 1</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; node -e "const j=require('./firebase.json'); if(!j.emulators){process.exit(2)}; if(j.emulators.auth.port!==9099){process.exit(3)}; console.log('emulators block intact')"</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ( flutter clean &amp;&amp; flutter pub get &amp;&amp; flutter build ios --no-codesign 2>&amp;1 | tee /tmp/p1-06-build.log ); ec=$?; ! grep -qE 'Minimum deployment target should be' /tmp/p1-06-build.log; ec2=$?; test $ec -eq 0 -a $ec2 -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -c 'CLIENT_ID\|REVERSED_CLIENT_ID' ios/Runner/GoogleService-Info.plist | xargs -I{} test {} -ge 2</automated>
  </verify>
  <acceptance_criteria>
    - `ios/Podfile` declares `platform :ios, '14.2'` (uncommented), the post_install threshold is `if current < 14.2`, and ZERO occurrences of `13.0` remain in the file.
    - `lib/firebase_options.dart` contains the Firebase iOS App ID prefix `1:722452556351:ios:` (project mentor-mind-aa765 unchanged; only the iOS app sub-id rotates).
    - `firebase.json` still has the `emulators` block with Auth on port 9099 (Plan 01's config survived `flutterfire configure`).
    - `flutter build ios --no-codesign` exits 0 with no "Minimum deployment target" warnings; fallback to `--simulator` flag is allowed and documented if signing failures are unrelated to deployment target.
    - The new `GoogleService-Info.plist` contains both `CLIENT_ID` and `REVERSED_CLIENT_ID` keys (verified — Plan 07 depends on this).
  </acceptance_criteria>
  <done>
    Podfile + Pods + firebase_options.dart all aligned to bundle id `com.mentorminds.mentorMinds` and iOS 14.2 minimum deployment target. `flutter build ios --no-codesign` succeeds. The new `GoogleService-Info.plist` is committed at `ios/Runner/`. Plan 07 can now wire the `REVERSED_CLIENT_ID` into `Info.plist` and fix the avatar path.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Xcode build identity ⇄ Firebase backend | The bundle id is the join key between the Xcode-signed binary and the Firebase iOS app registration; a mismatch silently fails Firebase Auth/FCM/etc. (PITFALLS #6) |
| Apple `.p8` auth key ⇄ APNs ⇄ Firebase Console | The .p8 must be re-associated with the new iOS app; if skipped, FCM in Phase 6 fails |
| GoogleService-Info.plist content ⇄ Google Sign-In OAuth flow | The plist's REVERSED_CLIENT_ID becomes the iOS URL scheme; absent from current plist (verified by grep), present in the new download (verified by Task 0 check) |
| firebase_options.dart auto-generated content | Touching this file by hand would be reverted by the next `flutterfire configure`; this plan deliberately routes the change through the CLI |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-1-IDENT | Spoofing / Elevation of Privilege | An app signed under the new bundle id but pointing at a Firebase iOS app registered under the OLD bundle id would silently accept Auth callbacks meant for a different app (or fail open) | mitigate | Task 0 (human-in-the-loop) requires Firebase Console re-registration BEFORE Task 1/2 land; Task 2 regenerates firebase_options.dart via flutterfire configure which fails fast if the new iOS app does not exist; the build smoke test exits non-zero if firebase_options.dart's appId does not match a real Firebase iOS app under the project |
| T-1-PARTIAL-FLIP | Tampering | Editing pbxproj but skipping Podfile (or vice versa) leaves the build in a half-flipped state where Xcode signs at 14.2 but pods compile at 13.0 (PITFALLS #5) | mitigate | Task 1 + Task 2 commit together as a single atomic change; verify checks count exact occurrences (3 of each in pbxproj, 0 of '13.0' anywhere in Podfile or pbxproj); commit fails review if any check fails |
| T-1-APNS-DRIFT | Denial of Service | New iOS app registered but .p8 key NOT re-associated → FCM push token registration in Phase 6 fails silently | mitigate | Task 0 Step 3 explicitly re-associates the .p8 with the new iOS app; BACKEND_SETUP.md documents that .p8 keys are per-Team (not per-bundle) so the same key works for both |
| T-1-CONSOLE-LOG-LEAK | Information Disclosure | A misconfigured Firebase iOS app could log fully-qualified user identifiers (uid + email) to Xcode console via the Auth SDK's debug verbose logging | accept | Firebase Auth's debug logging is OFF by default in release builds; Phase 1 does not enable verbose logging anywhere; Phase 2 adds App Check which further restricts unauthorized client access |
</threat_model>

<verification>
- Task 0 BACKEND_SETUP.md checklist has 4 `- [x]` items, the new GoogleService-Info.plist contains CLIENT_ID + REVERSED_CLIENT_ID, and BUNDLE_ID = com.mentorminds.mentorMinds.
- Task 1 pbxproj has exactly 3 occurrences of the new bundle id and 3 occurrences of 14.2; zero occurrences of the old bundle id and zero occurrences of 13.0 in the same file.
- Task 1 Runner.entitlements references the new bundle id only.
- Task 2 Podfile has `platform :ios, '14.2'` uncommented, post_install threshold at 14.2, zero `13.0` references; lib/firebase_options.dart regenerated; firebase.json emulators block survived; `flutter build ios --no-codesign` exits 0.
</verification>

<success_criteria>
- ARCH-04 closed: bundle id `com.mentorminds.mentorMinds` is consistent across Xcode (3 build configs), entitlements, Firebase Console iOS app registration, APNs association, and `BACKEND_SETUP.md`.
- ARCH-05 closed: iOS minimum deployment target is 14.2 across Xcode (3 build configs), Podfile platform line, and Podfile post_install threshold.
- `flutter build ios --no-codesign` exits 0 (toolchain accepts the new identity + target).
- New `GoogleService-Info.plist` is in place with `CLIENT_ID`/`REVERSED_CLIENT_ID` (Plan 07 depends on this).
- Plan 01's `firebase.json` emulators block survives `flutterfire configure`.
</success_criteria>

<output>
Create `.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-06-ios-identity-flip-SUMMARY.md` when done. Record: the 4 BACKEND_SETUP.md checklist items + their completion timestamps, the exact grep counts on pbxproj (before + after), the Podfile diff, the literal output of `pod install` (filtered to deployment-target lines), the diff of `lib/firebase_options.dart` (old appId → new appId), the `flutter build ios --no-codesign` final line of output (`Built ... [release] ...` or equivalent), confirmation that the `firebase.json` emulators block is intact, and the resolution if any pod required a higher floor than 14.2 (per RESEARCH Assumption A2).
</output>
