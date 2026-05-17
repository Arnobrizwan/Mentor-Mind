---
phase: 01-foundation-refactor-ci-test-harness-ios-identity
plan: 11
type: execute
wave: 3
depends_on: ["01-04", "01-05", "01-06", "01-07", "01-08", "01-09", "01-10"]
files_modified:
  - .planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md
autonomous: true
requirements: []
requirements_addressed: []
tags: [phase_closeout, validation, nyquist, verification_sweep]

must_haves:
  truths:
    - "`flutter pub outdated` confirms Firebase ^5.x SDKs are still on v5 (unchanged from Plan 01's preflight)"
    - "`git log --follow` continuity is verified on 3 representative renamed files (one screen, one viewmodel, one extracted model)"
    - "`flutter analyze --fatal-warnings` exits 0 across the full tree"
    - "`dart run custom_lint` reports zero `layered_imports` violations"
    - "`flutter test --coverage` exits 0; all anchor tests pass"
    - "Emulator integration smoke test passes (when run locally with the emulator suite up)"
    - "All ✅-able rows in 01-VALIDATION.md § Per-Task Verification Map are flipped to ✅"
    - "`nyquist_compliant: true` is set in 01-VALIDATION.md frontmatter"
    - "All 16 Phase 1 requirement IDs (ARCH-01..07, CI-01..07, QUAL-04, QUAL-06) trace to at least one ✅ row"
  artifacts:
    - path: ".planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md"
      provides: "Phase 1 validation status, all rows ✅, nyquist_compliant: true"
      contains: "nyquist_compliant: true"
  key_links:
    - from: "01-VALIDATION.md frontmatter"
      to: "All 10 prior plans' SUMMARY.md files"
      via: "Status references — each row's ✅ corresponds to a SUMMARY proving the requirement is closed"
      pattern: "nyquist_compliant: true"
---

<objective>
Phase 1 closeout — a verification-only plan that runs the full sweep across all 10 prior plans, flips every row in `01-VALIDATION.md` to ✅, sets `nyquist_compliant: true`, and produces a Phase-1-closed SUMMARY that proves all 16 requirement IDs (ARCH-01..07, CI-01..07, QUAL-04, QUAL-06) trace to verifiable green gates. This plan introduces NO code changes — its job is to assert that the cumulative work of Plans 01-10 actually delivers Phase 1's success criteria as written in ROADMAP.md.

Purpose: Without an explicit closeout plan, the phase ends in an ambiguous "probably done" state — individual plans show green but cross-plan invariants (e.g. "VALIDATION.md is in sync with the SUMMARY collection", "git log --follow is preserved end-to-end") may have drifted. This plan is the integration test for the planning system itself.

Output: Updated 01-VALIDATION.md with all rows ✅ and `nyquist_compliant: true`; a closeout SUMMARY documenting the cross-plan invariant checks and pointing forward to Phase 2's entry conditions.
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
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-01-deps-and-emulators-PLAN.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-02-custom-lint-plugin-PLAN.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-03-pure-git-mv-refactor-PLAN.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-04-model-extraction-PLAN.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-05-repository-extraction-PLAN.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-06-ios-identity-flip-PLAN.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-07-avatar-and-google-signin-PLAN.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-08-test-harness-anchors-PLAN.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-09-emulator-integration-smoke-PLAN.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-10-github-actions-ci-PLAN.md
@CLAUDE.md

<interfaces>
<!-- Cross-plan invariants this plan asserts -->

ROADMAP Phase 1 success criteria (5 truths to verify):
  1. lib/ is split into lib/presentation/screens/, lib/application/viewmodels/, lib/data/{repositories,services,models}/ and a hard one-way import rule (presentation → application → data) is enforced by custom_lint running in CI.
     → Verifiable by: directory existence + `dart run custom_lint` zero `layered_imports` + .github/workflows/ci.yml has `dart run custom_lint` step.

  2. Every PR against `main` runs `flutter analyze`, `flutter test`, and (when functions/** changes) the TypeScript lint+build — all three gate merge; coverage artifact is uploaded.
     → Verifiable by: .github/workflows/ci.yml has all four steps; functions job has path-filter or `if:` guard; upload-artifact step references coverage/lcov.info.

  3. User can edit their avatar in Profile and the upload succeeds end-to-end against the deployed storage.rules, and user can complete Google Sign-In on a physical iOS device.
     → Verifiable by: Plan 07 Task 3's manual checkpoint sign-off (avatar manual test + Google Sign-In button visibility); SUMMARY.md from Plan 07 documents the closure.

  4. App builds, signs, and runs on iOS 14+ device under bundle ID com.mentorminds.mentorMinds with Firebase iOS app registration + APNs association both matching; BACKEND_SETUP.md and Xcode agree.
     → Verifiable by: 3-of-each PRODUCT_BUNDLE_IDENTIFIER + IPHONEOS_DEPLOYMENT_TARGET in pbxproj; Plan 06 SUMMARY documents the Firebase Console + APNs steps; BACKEND_SETUP.md exists at repo root.

  5. Firebase Local Emulator Suite (Auth + Firestore + Storage + Functions) boots locally and is the default target for `flutter test integration_test/`; the new dev_dependencies (mocktail, fake_cloud_firestore, firebase_auth_mocks, golden_toolkit, network_image_mock, integration_test) all resolve and have at least one smoke test exercising them.
     → CAVEAT: Functions emulator is deferred to Phase 2 per D-10. Phase 1 ships Auth + Firestore + Storage only. This is a documented scope adjustment, not a regression. Verifiable by: firebase.json emulators block has auth+firestore+storage+ui (not functions); pubspec.yaml has all 6 test deps; each dep is exercised by at least one anchor test (Plan 08) or the integration smoke (Plan 09).

Full requirement → plan map (16 IDs, all covered by ≥1 plan):

  ARCH-01 → Plan 02 (rule + scaffold) + Plan 03 (refactor) + Plan 05 (rule passes on full tree)
  ARCH-02 → Plan 04 (model extraction)
  ARCH-03 → Plan 05 (repository extraction)
  ARCH-04 → Plan 06 (bundle ID flip)
  ARCH-05 → Plan 06 (iOS 14.2 deployment target)
  ARCH-06 → Plan 07 (avatar path fix)
  ARCH-07 → Plan 07 (Google Sign-In wiring)
  CI-01   → Plan 10 (CI workflow — analyze step)
  CI-02   → Plan 10 (CI workflow — test --coverage + upload-artifact)
  CI-03   → Plan 10 (CI workflow — functions job stub)
  CI-04   → Plan 08 (dashboard widget anchor test — partial; Phase 7 finishes)
  CI-05   → Plan 08 (auth + onboarding viewmodel anchors — partial; Phase 7 finishes)
  CI-06   → Plan 09 (emulator integration smoke)
  CI-07   → Plan 01 (test deps installed) + Plan 08 (each dep exercised)
  QUAL-04 → Plan 02 (custom_lint + riverpod_lint installed + rule lands) + Plan 10 (CI runs it)
  QUAL-06 → Plan 01 (codegen + DI packages removed)

VALIDATION.md row → closing plan map (read from 01-VALIDATION.md § Per-Task Verification Map):
  01-w0-deps-and-emulators        → Plan 01
  01-w0-emulator-config           → Plan 09 (and Plan 01 for the firebase.json block)
  01-w0-anchor-tests              → Plan 08 + Plan 09
  02-refactor-pure-git-mv         → Plan 03
  03-layer-lint-rule              → Plan 02 + Plan 05 (zero violations achieved by Plan 05)
  04-model-extraction             → Plan 04
  05-repository-extraction        → Plan 05
  06-bundle-id-flip               → Plan 06 (manual rows; Task 0 + Task 1)
  07-ios-deployment-target        → Plan 06 (Task 1 + Task 2)
  08-avatar-upload-fix            → Plan 07 (manual rows; Task 1 + Task 3 checkpoint)
  09-google-sign-in               → Plan 07 (manual rows; Task 2 + Task 3 checkpoint)
  10-ci-workflow                  → Plan 10
  11-codegen-decision-doc         → Plan 01 (D-06 deletions confirmed by grep)

Note: VALIDATION.md has slightly different plan-slug naming than the actual filenames (e.g. it uses `02-refactor-pure-git-mv` while the filename is `01-03-pure-git-mv-refactor-PLAN.md`). The verifier-to-plan map is correct semantically — flip each row's `Status` column to ✅ regardless of slug naming drift.

Final SUMMARY format (template for the SUMMARY.md this plan writes):

```markdown
# Phase 1 — Closeout SUMMARY

**Completed:** <date>
**nyquist_compliant:** true

## Cross-Plan Invariants

| Invariant | Check | Status |
|-----------|-------|--------|
| `git log --follow` continuity | `git log --follow ...` returns ≥2 commits for {3 spot files} | ✅ |
| `flutter analyze --fatal-warnings` | Exits 0 | ✅ |
| `dart run custom_lint` | Zero `layered_imports` | ✅ |
| `flutter test --coverage` | Exits 0; lcov.info produced | ✅ |
| Emulator integration smoke | Local run passes | ✅ |
| Bundle ID consistency | 3/3 in pbxproj, entitlements match | ✅ |
| iOS deployment target | 3/3 in pbxproj + Podfile | ✅ |
| Firebase SDK version drift | Still on ^5.x | ✅ |
| T-1-SECRET | No credentials in CI workflow | ✅ |

## Requirement Trace Table

| ID | Closing Plan(s) | Evidence |
|----|-----------------|----------|
| ARCH-01 | 02 + 03 + 05 | `dart run custom_lint` zero violations |
| ARCH-02 | 04           | 21 models extracted; zero duplicates |
| ARCH-03 | 05           | Zero `FirebaseFirestore.instance` in viewmodels |
| ARCH-04 | 06           | 3/3 PRODUCT_BUNDLE_IDENTIFIER lines correct |
| ARCH-05 | 06           | 3/3 IPHONEOS_DEPLOYMENT_TARGET = 14.2 |
| ARCH-06 | 07           | profile_viewmodel uses uploads/{uid}/{ts}_avatar.jpg |
| ARCH-07 | 07           | Info.plist CFBundleURLTypes references REVERSED_CLIENT_ID |
| CI-01   | 10           | .github/workflows/ci.yml has analyze step |
| CI-02   | 10           | .github/workflows/ci.yml has test --coverage + upload-artifact |
| CI-03   | 10           | .github/workflows/ci.yml has functions job |
| CI-04   | 08 (partial) | 1 of 12 smoke tests; Phase 7 finishes |
| CI-05   | 08 (partial) | 2 of ~12 vm tests; Phase 7 finishes |
| CI-06   | 09           | integration_test/login_smoke_test.dart green |
| CI-07   | 01 + 08      | 6 deps installed + exercised |
| QUAL-04 | 02 + 10      | custom_lint passes; CI runs it |
| QUAL-06 | 01           | 6 codegen/DI packages removed from pubspec |

## Phase 2 Entry Conditions

- All 16 requirement IDs traced to ✅ above.
- Plan 6's BACKEND_SETUP.md ready for Phase 2 to extend with App Check + Functions setup checklist.
- functions/ directory does NOT exist yet — Phase 2 creates it.

## Known Carry-Forward Items (NOT regressions)

- 167 info-level analyzer warnings remain (`withOpacity`, etc.) — Phase 7 burndown territory.
- CI-04 / CI-05 are partially satisfied (4 anchor tests; full coverage in Phase 7).
- D-12: golden_toolkit is installed but no goldens written; Phase 7 writes them after AppTheme stabilizes.
- Functions emulator is NOT in firebase.json — added in Phase 2 per D-10.
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Cross-plan invariant sweep — re-run every gate one final time</name>
  <files>(no edits — verification only)</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-CONTEXT.md (the locked decisions list — every D-XX is the executor's contract)
    - /Users/arnobrizwan/Mentor-Mind/.planning/ROADMAP.md (Phase 1 entry — the 5 success criteria are the closeout target)
    - The 10 prior plan files (Plans 01-10) — confirm each exists and has a matching SUMMARY.md committed
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md (the row-by-row status target)
  </read_first>
  <action>
    Run a sequence of 8 invariant checks, one per ROADMAP success criterion + cross-cutting concerns. None of these edit code; they all assert prior plans' work persisted.

    Check 1 — Firebase SDK still on ^5.x (Plan 01 baseline holds):
      `flutter pub outdated --no-dev-dependencies 2>&1 | grep -E '^(cloud_firestore|firebase_auth|firebase_storage)\b'`
      The resolved versions must start with `5.` for all three rows. Any `6.x` resolution means a transitive bump happened — record it and surface (the test-harness pins from Plan 01 are ^5-only-compatible).

    Check 2 — `flutter analyze --fatal-warnings` green:
      `flutter analyze --fatal-warnings 2>&1 | tee /tmp/p1-11-analyze.log`
      Exit 0; no `error -` or `warning -` lines.

    Check 3 — `dart run custom_lint` zero `layered_imports`:
      `dart run custom_lint 2>&1 | tee /tmp/p1-11-lint.log`
      Zero lines containing `layered_imports`.

    Check 4 — `flutter test --coverage` green:
      `rm -f coverage/lcov.info; flutter test --coverage 2>&1 | tee /tmp/p1-11-test.log`
      Exit 0; `coverage/lcov.info` non-empty.

    Check 5 — `git log --follow` continuity on 3 representative renamed files (Plan 03's anchor proof):
      For each of these 3 files, run `git log --follow --oneline -- <path> | wc -l` and assert ≥2:
        - `lib/presentation/screens/dashboard/dashboard_screen.dart` (screen)
        - `lib/application/viewmodels/auth/auth_viewmodel.dart` (viewmodel)
        - `lib/data/models/dashboard_user.dart` (Plan-04-extracted model — its history should follow `git log --follow` back to its original definition site inside `dashboard_viewmodel.dart`, which was further `git mv`d from `lib/features/dashboard/dashboard_viewmodel.dart`. NOTE: `git log --follow` for extracted classes is best-effort — git only tracks rename of whole files, not class extractions. Acceptable if this third row shows just 1 commit (the creation of the extracted file). Record the actual count.)

    Check 6 — iOS identity coherence (3/3 in pbxproj):
      `grep -c 'PRODUCT_BUNDLE_IDENTIFIER = com.mentorminds.mentorMinds;' ios/Runner.xcodeproj/project.pbxproj` → 3
      `grep -c 'PRODUCT_BUNDLE_IDENTIFIER = com.arnobrizwan' ios/Runner.xcodeproj/project.pbxproj` → 0
      `grep -c 'IPHONEOS_DEPLOYMENT_TARGET = 14.2;' ios/Runner.xcodeproj/project.pbxproj` → 3
      `grep -c 'IPHONEOS_DEPLOYMENT_TARGET = 13.0;' ios/Runner.xcodeproj/project.pbxproj` → 0

    Check 7 — CI workflow exists + valid + uncompromised:
      `test -f .github/workflows/ci.yml`
      `grep -q 'flutter analyze --fatal-warnings' .github/workflows/ci.yml`
      `grep -q 'dart run custom_lint' .github/workflows/ci.yml`
      `grep -q 'flutter test --coverage' .github/workflows/ci.yml`
      `grep -q 'upload-artifact' .github/workflows/ci.yml`
      `! grep -E 'service-account|GOOGLE_APPLICATION_CREDENTIALS|FIREBASE_TOKEN' .github/workflows/ci.yml`

    Check 8 — All 10 prior plans have a SUMMARY.md:
      For N in 01..10, `test -f .planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-${N}-*-SUMMARY.md || record missing`.
      All 10 SUMMARY files MUST exist. If any are missing, the corresponding plan was not properly closed by the executor; surface the gap.

    Emulator integration test (Check 9 — local-only):
      This is intentionally OPTIONAL in this automated task because it requires a running iOS simulator + the emulator suite up. If the developer is running this plan from a Mac with both, also run:
        `firebase emulators:start --only auth,firestore,storage --import=tool/emulator-data &`
        `flutter test integration_test/login_smoke_test.dart --dart-define=USE_EMULATOR=true -d <simulator>`
      Confirm exit 0. If skipped (e.g. running on CI-like Linux), record "skipped — local-only check" in SUMMARY.

    If ANY check fails:
      Do NOT proceed to Task 2. Surface the failure, identify which prior plan owns the failing invariant, and recommend re-running the corresponding plan's verification tasks.

    Record all 8 (or 9) check outcomes verbatim for inclusion in the closeout SUMMARY.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter pub outdated --no-dev-dependencies 2>&amp;1 | grep -E '^(cloud_firestore|firebase_auth|firebase_storage)\b' | awk '{print $1, $2}' | tee /tmp/p1-11-c1.log &amp;&amp; ! grep -E '\s6\.' /tmp/p1-11-c1.log</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --fatal-warnings 2>&amp;1 | tee /tmp/p1-11-c2.log &amp;&amp; ! grep -qE '^\s*(error|warning) -' /tmp/p1-11-c2.log</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; dart run custom_lint 2>&amp;1 | tee /tmp/p1-11-c3.log &amp;&amp; ! grep -q 'layered_imports' /tmp/p1-11-c3.log</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; rm -f coverage/lcov.info; flutter test --coverage 2>&amp;1 | tee /tmp/p1-11-c4.log &amp;&amp; test -s coverage/lcov.info</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; for f in lib/presentation/screens/dashboard/dashboard_screen.dart lib/application/viewmodels/auth/auth_viewmodel.dart; do n=$(git log --follow --oneline -- "$f" 2>/dev/null | wc -l | tr -d ' '); test "$n" -ge 2 || { echo "FAIL --follow on $f returned $n"; exit 2; }; done; n=$(git log --follow --oneline -- lib/data/models/dashboard_user.dart 2>/dev/null | wc -l | tr -d ' '); echo "data model --follow count: $n (1 is acceptable — extraction not rename)"</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test $(grep -c 'PRODUCT_BUNDLE_IDENTIFIER = com.mentorminds.mentorMinds;' ios/Runner.xcodeproj/project.pbxproj) -eq 3 &amp;&amp; test $(grep -c 'IPHONEOS_DEPLOYMENT_TARGET = 14.2;' ios/Runner.xcodeproj/project.pbxproj) -eq 3 &amp;&amp; ! grep -q 'com.arnobrizwan' ios/Runner.xcodeproj/project.pbxproj &amp;&amp; ! grep -q 'IPHONEOS_DEPLOYMENT_TARGET = 13.0;' ios/Runner.xcodeproj/project.pbxproj</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f .github/workflows/ci.yml &amp;&amp; grep -q 'flutter analyze --fatal-warnings' .github/workflows/ci.yml &amp;&amp; grep -q 'dart run custom_lint' .github/workflows/ci.yml &amp;&amp; grep -q 'flutter test --coverage' .github/workflows/ci.yml &amp;&amp; grep -q 'upload-artifact' .github/workflows/ci.yml &amp;&amp; ! grep -qE 'service-account|GOOGLE_APPLICATION_CREDENTIALS|FIREBASE_TOKEN' .github/workflows/ci.yml</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; n=$(ls .planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-*-SUMMARY.md 2>/dev/null | wc -l | tr -d ' '); test "$n" -ge 10 || { echo "MISSING SUMMARY files: only $n of expected ≥10"; exit 3; }</automated>
  </verify>
  <acceptance_criteria>
    - Check 1: Firebase SDKs still on ^5.x.
    - Check 2: `flutter analyze --fatal-warnings` exits 0; no errors/warnings.
    - Check 3: `dart run custom_lint` reports zero `layered_imports` violations.
    - Check 4: `flutter test --coverage` exits 0; `coverage/lcov.info` non-empty.
    - Check 5: `git log --follow` on the screen + viewmodel files returns ≥2 commits each (the third — extracted model — may return 1 commit; that's acceptable since extraction is not a rename).
    - Check 6: pbxproj has exactly 3 occurrences of the new bundle id + 3 of 14.2; zero of the old bundle id + zero of 13.0.
    - Check 7: CI workflow exists with all four gate steps and no credential references.
    - Check 8: At least 10 SUMMARY.md files exist under the phase directory.
  </acceptance_criteria>
  <done>
    All 8 cross-plan invariants are green. Phase 1's structural + verification surface is intact. Task 2 can flip VALIDATION.md rows.
  </done>
</task>

<task type="auto">
  <name>Task 2: Update 01-VALIDATION.md — flip all rows to ✅ + set nyquist_compliant: true</name>
  <files>.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md (current state — frontmatter has `nyquist_compliant: false`; the Per-Task Verification Map has ⬜ pending status on every row)
    - The literal output captured in Task 1 for all 8 invariant checks
  </read_first>
  <action>
    Two edits to 01-VALIDATION.md.

    Step A — Frontmatter update:
      Change `nyquist_compliant: false` → `nyquist_compliant: true`.
      Change `status: draft` → `status: closed` (if the `status:` field exists; otherwise leave alone).
      Update `wave_0_complete: false` → `wave_0_complete: true` if that field exists.

    Step B — Per-Task Verification Map table — flip Status column to ✅ for every row:
      Read the table (lines 45-60 of 01-VALIDATION.md, the rows with the `⬜ pending` markers). For each row whose closing plan has been completed (per the closing-plan map in `<interfaces>`), flip `⬜ pending` to `✅ green`.

      For the manual-verification rows (`06-bundle-id-flip`, `07-ios-deployment-target`, `08-avatar-upload-fix`, `09-google-sign-in`), confirm that Plan 06 Task 0 + Plan 07 Task 3 checkpoints were approved (the developer signed off on the BACKEND_SETUP.md checklist + the avatar + Google Sign-In manual QA). If any of those checkpoints were SKIPPED rather than approved, flip those rows to ⚠️ flaky with a note in the closeout SUMMARY explaining the gap (not blocking, but Phase 2 should re-verify on a real device).

      Update the row for `01-w0-emulator-config` (Plan 09 closed this — Task 3 was supposed to flip the row already; this is the safety net in case Plan 09 missed it).

    Step C — Optional: Update Validation Sign-Off section:
      The `## Validation Sign-Off` section (lines 99-109) has 8 checkboxes. For each: confirm the underlying check passed in Task 1 of THIS plan; mark `[x]` (using `[X]` is also acceptable).
      Confirm `nyquist_compliant: true set` is the LAST checkbox; toggle it after the others.
      Change `**Approval:** pending` → `**Approval:** Phase 1 closed <YYYY-MM-DD>`.

    Step D — Commit:
      Single commit: `docs(phase-1): close validation — nyquist_compliant: true; all rows ✅ (Phase 1 closeout)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q '^nyquist_compliant:\s*true' .planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; pending=$(grep -c '⬜ pending' .planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md 2>/dev/null || echo 0); test "$pending" -eq 0 || { echo "still pending rows: $pending"; exit 2; }</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; greens=$(grep -c '✅ green\|✅' .planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md 2>/dev/null || echo 0); test "$greens" -ge 13</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -q 'Approval:\*\* pending' .planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md</automated>
  </verify>
  <acceptance_criteria>
    - `nyquist_compliant: true` is set in 01-VALIDATION.md frontmatter.
    - Zero `⬜ pending` rows remain in the Per-Task Verification Map.
    - At least 13 ✅ markers exist in the file (12 Map rows + at least 1 in Sign-Off + others as needed).
    - The `**Approval:** pending` line is gone — replaced with "Phase 1 closed <date>" or equivalent.
    - The 5 ROADMAP success criteria are referenced or summarized in the closeout SUMMARY (Task 3).
  </acceptance_criteria>
  <done>
    01-VALIDATION.md reflects the closed state of Phase 1: nyquist_compliant: true, all rows ✅, sign-off complete. The phase is structurally + procedurally closed.
  </done>
</task>

<task type="auto">
  <name>Task 3: Write closeout SUMMARY.md + commit</name>
  <files>.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-11-phase-closeout-SUMMARY.md</files>
  <read_first>
    - The 8 invariant-check outcomes from Task 1
    - The flipped VALIDATION.md from Task 2
    - All 10 prior plans' SUMMARY.md files — extract one-line takeaways for the trace table
    - /Users/arnobrizwan/Mentor-Mind/.planning/ROADMAP.md (Phase 1's 5 success criteria — must be quoted in the SUMMARY)
  </read_first>
  <action>
    Write `.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-11-phase-closeout-SUMMARY.md` following the template in `<interfaces>` above. Sections:

    1. **Header** with date + `nyquist_compliant: true` callout.
    2. **Cross-Plan Invariants** — table with 8 rows from Task 1 + Status ✅.
    3. **Requirement Trace Table** — 16 rows from the requirement-to-plan map in `<interfaces>`.
    4. **ROADMAP Phase 1 Success Criteria Verification** — quote each of the 5 criteria from ROADMAP and mark each with the plan(s) that closed it. Specifically address criterion #5's caveat (Functions emulator deferred to Phase 2 per D-10 — NOT a regression).
    5. **Phase 2 Entry Conditions** — what Phase 2 should expect to find: BACKEND_SETUP.md with iOS identity section ready to extend, layered tree under `lib/{presentation,application,data}/`, CI workflow in place ready to add a Functions job, custom_lint plugin in place ready to add new rules.
    6. **Known Carry-Forward Items** — explicitly call out the items in `<interfaces>` last section. These are NOT regressions but Phase 7 / Phase 2+ work:
       - 167 info-level analyzer warnings (Phase 7).
       - CI-04 / CI-05 partial closure (Phase 7).
       - No goldens written despite golden_toolkit installed (D-12; Phase 7).
       - Functions emulator absent from firebase.json (Phase 2).
       - Orphan avatar storage objects on account deletion (Phase 4+ sweep).
    7. **Final Test Run** — paste the literal final-line output of `flutter test --coverage` and `dart run custom_lint`.

    Commit message: `docs(phase-1): closeout SUMMARY — Phase 1 nyquist_compliant`.

    After committing, the Phase 1 entry in ROADMAP.md may be flipped from `- [ ]` to `- [x]` by the developer (NOT by this plan — ROADMAP edits are out of scope; the developer flips it after reviewing this SUMMARY).
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f .planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-11-phase-closeout-SUMMARY.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'nyquist_compliant' .planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-11-phase-closeout-SUMMARY.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; for ID in ARCH-01 ARCH-02 ARCH-03 ARCH-04 ARCH-05 ARCH-06 ARCH-07 CI-01 CI-02 CI-03 CI-04 CI-05 CI-06 CI-07 QUAL-04 QUAL-06; do grep -q "\b${ID}\b" .planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-11-phase-closeout-SUMMARY.md || { echo "MISSING requirement ID in SUMMARY: $ID"; exit 2; }; done</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'Phase 2 Entry Conditions\|Phase 2' .planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-11-phase-closeout-SUMMARY.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'Known Carry-Forward\|carry-forward\|Carry Forward' .planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-11-phase-closeout-SUMMARY.md</automated>
  </verify>
  <acceptance_criteria>
    - `01-11-phase-closeout-SUMMARY.md` exists.
    - All 16 requirement IDs (ARCH-01..07, CI-01..07, QUAL-04, QUAL-06) are referenced in the SUMMARY.
    - A "Phase 2 Entry Conditions" or equivalent section exists.
    - A "Known Carry-Forward Items" section explicitly enumerates the non-regression deferrals (167 info warnings, partial CI-04/CI-05, deferred goldens, deferred Functions emulator, deferred orphan storage cleanup).
    - The SUMMARY references the literal final-line output of `flutter test --coverage` and `dart run custom_lint` from Task 1.
  </acceptance_criteria>
  <done>
    Phase 1 is structurally + procedurally + documentationally closed. The SUMMARY traces every requirement ID to its closing plan, asserts the cross-plan invariants, and hands off cleanly to Phase 2. The developer flips ROADMAP.md's Phase 1 entry from `- [ ]` to `- [x]` as the final manual step.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| 10 prior plans ⇄ closeout assertion | This plan's invariant checks must EXERCISE the closed state, not just assume it from the SUMMARY files; a SUMMARY that lies cannot fool `grep -c` |
| VALIDATION.md ⇄ ground truth | Flipping rows to ✅ without re-running the underlying check would silently regress |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-1-CLOSEOUT-LIE | Repudiation | A closeout that marks rows ✅ without re-verifying the underlying check would let regressions slip into Phase 2's baseline | mitigate | Task 1 RE-RUNS every gate (`flutter analyze`, `dart run custom_lint`, `flutter test --coverage`, grep on pbxproj, grep on CI workflow); Task 2 only flips rows after Task 1's checks pass; if Task 1 fails any check, Task 2 is gated and does not run |
| T-1-MANUAL-SKIP | Repudiation | The manual QA rows (avatar upload + Google Sign-In on device) rely on the developer's earlier checkpoint approval — a developer who clicked "approved" without actually running the test would close those rows fraudulently | accept | Phase 2 will re-encounter these on the first real-device build; if the avatar path is wrong or the URL scheme is missing, Firebase Auth / Storage will fail on the first run; the cost of "lie about manual closure" is bounded to one Phase 2 day of debugging |
| T-1-VALIDATION-DRIFT | Tampering | If 01-VALIDATION.md is hand-edited between Plan 09's Task 3 (which flips the emulator row) and Plan 11's Task 2 (which flips the remaining rows), Plan 11 could overwrite Plan 09's progress | accept | Solo dev workflow; the only edits between plans are this plan's; git history records every edit |
</threat_model>

<verification>
- All 8 cross-plan invariants from Task 1 are green.
- 01-VALIDATION.md frontmatter has `nyquist_compliant: true`.
- Zero `⬜ pending` rows remain in 01-VALIDATION.md.
- Closeout SUMMARY references all 16 requirement IDs.
- Phase 2 Entry Conditions + Known Carry-Forward sections present in SUMMARY.
- All 10 prior plans have a SUMMARY.md file committed.
</verification>

<success_criteria>
- Phase 1 ROADMAP success criteria (#1-#5) are each traced to a closing plan + evidence.
- All 16 requirement IDs ✅ in the closeout trace table.
- `nyquist_compliant: true` set in 01-VALIDATION.md.
- A subsequent /gsd:verify-work invocation on this phase would find no failing gate.
- Phase 2 planning can begin with a stable baseline: layered tree, repo seams, CI gate, custom_lint rule, anchor tests, emulator config — all in place.
</success_criteria>

<output>
Create `.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-11-phase-closeout-SUMMARY.md` (this is Task 3's output). Record: the 8 cross-plan invariant check outcomes verbatim, the 16-row requirement trace table, the 5 ROADMAP success criteria quoted + closed-by attribution, the Phase 2 entry conditions, the known carry-forward items, and the final `flutter test --coverage` + `dart run custom_lint` output lines.
</output>
