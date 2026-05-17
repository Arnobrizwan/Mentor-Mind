---
phase: 01-foundation-refactor-ci-test-harness-ios-identity
plan: 01
type: execute
wave: 0
depends_on: []
files_modified:
  - pubspec.yaml
  - firebase.json
  - .gitignore
  - tool/seed/.gitignore
  - tool/emulator-data/.gitkeep
autonomous: true
requirements: [CI-06, CI-07, QUAL-06]
requirements_addressed: [CI-06, CI-07, QUAL-06]
tags: [flutter, firebase, emulator, dependencies, gitignore]

must_haves:
  truths:
    - "D-05: Viewmodels stay on vanilla `StateNotifier` + `StateNotifierProvider` in Phase 1 — no `@riverpod` codegen is introduced; the migration is bundled with the future Riverpod 2 → 3 upgrade (v1.1)"
    - "D-06: `riverpod_annotation`, `riverpod_generator`, `injectable`, `injectable_generator`, `build_runner`, and `get_it` are deleted from `pubspec.yaml`"
    - "D-07: `flutter_riverpod: ^2.6.1` is added to `dependencies` (no longer transitive-only via `hooks_riverpod`), clearing the 12 `depend_on_referenced_packages` info hits"
    - "D-10: Firebase Local Emulator Suite scope is Auth + Firestore + Storage only — no Functions emulator in Phase 1 (Functions emulator lands in Phase 2 when `functions/` exists)"
    - "flutter pub get resolves with the new test-harness dev_dependencies and without the deleted codegen packages"
    - "firebase emulators:start --only auth,firestore,storage boots Auth (9099), Firestore (8080), Storage (9199) and UI (4000)"
    - "tool/seed/service-account.json is gitignored and git check-ignore confirms it"
  artifacts:
    - path: "pubspec.yaml"
      provides: "Updated dev_dependencies + removed codegen deps"
      contains: "mocktail|fake_cloud_firestore|firebase_auth_mocks|golden_toolkit|network_image_mock|integration_test"
    - path: "firebase.json"
      provides: "Local Emulator Suite configuration"
      contains: "emulators"
    - path: "tool/emulator-data/.gitkeep"
      provides: "Committed seed directory placeholder for emulator export/import"
  key_links:
    - from: "pubspec.yaml"
      to: "test-harness dev_dependencies"
      via: "pub get resolution"
      pattern: "fake_cloud_firestore: \\^3\\.1"
    - from: "firebase.json"
      to: "Firebase Local Emulator Suite"
      via: "firebase emulators:start"
      pattern: "\"emulators\""
---

<objective>
Wave 0 plumbing: install the six test-harness dev_dependencies pinned to versions compatible with our Firebase ^5.x stack (per RESEARCH § Standard Stack), delete the unused codegen + DI packages (D-06), add `flutter_riverpod` as a direct dependency (D-07), wire the Firebase Local Emulator Suite config block (D-10), and close T-1-SECRET by confirming `tool/seed/service-account.json` is gitignored before any source-control work begins.

Purpose: Every later plan in this phase (lints, refactor, anchor tests, CI) depends on this dependency surface being correct. If `flutter pub get` fails after this plan, nothing downstream compiles.

Output: A `pubspec.yaml` that resolves cleanly with `flutter pub get`, a `firebase.json` whose `emulators:start --only auth,firestore,storage` boots, and a verified-gitignored `service-account.json`.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-CONTEXT.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-PATTERNS.md
@CLAUDE.md
@pubspec.yaml
@firebase.json

<interfaces>
<!-- Locked package versions (RESEARCH § Standard Stack, lines 156-175) -->

Test harness dev_dependencies (compatibility-pinned for Firebase ^5.x):
- mocktail: ^1.0.5
- fake_cloud_firestore: ^3.1.0     (NOT ^4.x — that requires cloud_firestore ^6.x)
- firebase_auth_mocks: ^0.14.2     (NOT ^0.15.x — that requires firebase_auth ^6.x)
- golden_toolkit: ^0.15.0
- network_image_mock: ^2.1.1
- integration_test: { sdk: flutter }

Direct dependency to ADD (D-07 / QUAL-03 pulled forward):
- flutter_riverpod: ^2.6.1

Packages to REMOVE entirely (D-06, QUAL-06 vanilla decision):
- dependencies:     riverpod_annotation, injectable, get_it
- dev_dependencies: riverpod_generator, injectable_generator, build_runner

Firebase emulator port assignments (RESEARCH Pattern 6 + VALIDATION lines 47-49):
- auth      : 9099
- firestore : 8080
- storage   : 9199
- ui        : 4000 (enabled)
- functions : NOT included in Phase 1 (added by Phase 2 per D-10)
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Verify-versions + secret-gitignore preflight</name>
  <files>.gitignore, tool/seed/.gitignore</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md (§ Standard Stack lines 127-184; § Pre-planning verification items lines 1078-1083)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md (§ Validation Sign-Off lines 100-108 — `flutter pub outdated` + `git check-ignore` gates)
    - /Users/arnobrizwan/Mentor-Mind/pubspec.yaml (current dependency state — required to confirm what is being removed)
    - /Users/arnobrizwan/Mentor-Mind/.gitignore (current ignore rules)
    - /Users/arnobrizwan/Mentor-Mind/tool/seed/.gitignore (existing seed-tool ignore rules)
  </read_first>
  <action>
    Two preflight checks before touching pubspec.yaml.

    (A) Run `flutter pub outdated --no-dev-dependencies` and inspect the output for `cloud_firestore`, `firebase_auth`, and `firebase_storage`. If any of these have moved off the `^5.x` major (e.g. resolved version starts with `6.`), STOP and surface the version drift — the pinned test-harness versions in Task 2 only work against Firebase Flutter SDK v5. If all three remain on `^5.x`, proceed.

    (B) Verify T-1-SECRET mitigation: run `git check-ignore -v tool/seed/service-account.json` (the file may or may not exist on disk — `check-ignore` works on paths regardless). The command must return a non-zero exit code with NO output meaning "not ignored", OR a zero exit code with the ignore rule line meaning "ignored". If the file is NOT ignored, add the line `service-account.json` to `tool/seed/.gitignore` and also add the line `tool/seed/service-account.json` to the top-level `.gitignore`. Re-run `git check-ignore -v tool/seed/service-account.json` and confirm it now prints an ignore rule. Do NOT commit `service-account.json` itself; only the .gitignore edits.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && flutter pub outdated --no-dev-dependencies 2>&amp;1 | grep -E '^(cloud_firestore|firebase_auth|firebase_storage)\b' | awk '{print $1, $2}' | tee /tmp/p1-outdated.txt && ! grep -E '\b6\.' /tmp/p1-outdated.txt</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && git check-ignore -v tool/seed/service-account.json</automated>
  </verify>
  <acceptance_criteria>
    - `flutter pub outdated --no-dev-dependencies` shows `cloud_firestore`, `firebase_auth`, `firebase_storage` resolved to versions whose major is `5` (the regex `\b6\.` does NOT match in those rows).
    - `git check-ignore -v tool/seed/service-account.json` exits with status 0 and prints an ignore rule referencing either `.gitignore` or `tool/seed/.gitignore`.
    - No edits are made to `pubspec.yaml`, `firebase.json`, or the emulator data directory in this task.
  </acceptance_criteria>
  <done>
    Firebase SDK majors confirmed at v5; service-account key is verifiably gitignored; we have written confirmation in the task log that T-1-SECRET is mitigated before any subsequent source-tree changes.
  </done>
</task>

<task type="auto">
  <name>Task 2: pubspec.yaml — remove codegen deps, add flutter_riverpod + test harness</name>
  <files>pubspec.yaml</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/pubspec.yaml (current state — must see what is removed vs. added)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-CONTEXT.md (D-06, D-07, D-08, D-09 — locked package decisions)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md (§ Standard Stack — Compatible Versions; § Package Legitimacy Audit lines 187-203)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-PATTERNS.md (§ tool/lints — pubspec.yaml dev_dependencies wiring lines 533-540 — note `mentormind_lints` path dep is wired by Plan 02, NOT here)
  </read_first>
  <action>
    Edit `pubspec.yaml` to align with D-06, D-07 and CI-07. Three coordinated edits in the same file (one commit at task end).

    Under `dependencies:`:
    1. Add `flutter_riverpod: ^2.6.1` (D-07 / QUAL-03 pulled forward — closes 12 `depend_on_referenced_packages` info hits).
    2. Remove `riverpod_annotation` (currently `^2.3.5`).
    3. Remove `injectable` (currently `^2.4.4`).
    4. Remove `get_it` (currently `^7.7.0`).

    Under `dev_dependencies:`, ADD all six test-harness entries (CI-07) at the pinned versions from RESEARCH § Standard Stack:
    - `mocktail: ^1.0.5`
    - `fake_cloud_firestore: ^3.1.0` — DO NOT pin `^4.x`; it requires cloud_firestore ^6.x and breaks our SDK
    - `firebase_auth_mocks: ^0.14.2` — DO NOT pin `^0.15.x`; same Firebase SDK v6 incompatibility
    - `golden_toolkit: ^0.15.0`
    - `network_image_mock: ^2.1.1`
    - `integration_test:\n    sdk: flutter` (multi-line entry for SDK-bundled package)

    Under `dev_dependencies:`, REMOVE three codegen entries:
    - `riverpod_generator` (`^2.4.3`)
    - `injectable_generator` (`^2.6.2`)
    - `build_runner` (`^2.4.12`)

    DO NOT add `custom_lint`, `riverpod_lint`, or `mentormind_lints` in this plan — those are wired by Plan 02 to keep the lint surface independently rollbackable.

    After saving, run `flutter pub get` and confirm it exits 0 with no version-conflict messages. Commit with message:
    `chore(pubspec): pin v1.0 test harness, drop codegen + DI deps, add flutter_riverpod direct dep (Phase 1 / D-06, D-07, CI-07)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && flutter pub get 2>&amp;1 | tee /tmp/p1-pubget.txt &amp;&amp; ! grep -Ei 'version solving failed|conflict' /tmp/p1-pubget.txt</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -cE '^\s*(mocktail|fake_cloud_firestore|firebase_auth_mocks|golden_toolkit|network_image_mock|integration_test|flutter_riverpod):' pubspec.yaml | xargs -I{} test {} -ge 7</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -E '^\s*(riverpod_annotation|riverpod_generator|injectable|injectable_generator|get_it|build_runner):' pubspec.yaml</automated>
  </verify>
  <acceptance_criteria>
    - `flutter pub get` exits 0 and its output does not contain the strings "version solving failed" or "conflict" (case-insensitive).
    - `grep -E '^\s*(mocktail|fake_cloud_firestore|firebase_auth_mocks|golden_toolkit|network_image_mock|integration_test|flutter_riverpod):' pubspec.yaml` matches at least 7 lines (the six new dev_deps plus `flutter_riverpod` under dependencies).
    - `grep -E '^\s*(riverpod_annotation|riverpod_generator|injectable|injectable_generator|get_it|build_runner):' pubspec.yaml` returns ZERO matches (all six codegen/DI packages removed).
    - `pubspec.lock` is updated (timestamp newer than this task started) and contains entries for `fake_cloud_firestore` and `firebase_auth_mocks`.
  </acceptance_criteria>
  <done>
    `pubspec.yaml` is at the locked Phase 1 state per D-06 + D-07 + CI-07; `flutter pub get` resolves cleanly; codegen packages are excised; test harness packages are installed at versions compatible with our Firebase ^5.x stack.
  </done>
</task>

<task type="auto">
  <name>Task 3: firebase.json — add emulators block + commit seed directory</name>
  <files>firebase.json, tool/emulator-data/.gitkeep</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/firebase.json (current state — must merge, not overwrite the flutter/platforms block)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-PATTERNS.md (§ firebase.json — emulators block, lines 611-650; current file content shown verbatim)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md (Pattern 6: Firebase Local Emulator Suite, lines 564-616 — Java + Firebase CLI prerequisites confirmed)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-CONTEXT.md (D-10: Auth + Firestore + Storage only; Functions emulator added in Phase 2)
  </read_first>
  <action>
    Edit `firebase.json` to ADD (merge into the existing top-level object — do NOT overwrite the `firestore`, `storage`, or `flutter` keys) a new top-level `emulators` key with the exact structure from PATTERNS.md lines 641-648:

    - `auth`: port 9099
    - `firestore`: port 8080
    - `storage`: port 9199
    - `ui`: { enabled: true, port: 4000 }

    Explicitly OMIT the `functions` emulator entry (per D-10 — Phase 2 adds it). Do not add `singleProjectMode`, `database`, or `hosting` entries.

    Create the empty directory `tool/emulator-data/` with a `.gitkeep` file inside (zero bytes) so the directory is committed. This directory will be the target of future `firebase emulators:export tool/emulator-data` runs to seed deterministic state for the integration smoke test in Plan 09. Do NOT run `emulators:export` yet — that comes in Plan 09 after the anchor tests exist.

    After saving `firebase.json`, run `firebase emulators:start --only auth,firestore,storage --inspect-functions 0` in a background shell for ~10 seconds, capture its stdout to a temp file, then stop it (Ctrl-C / SIGTERM). Inspect the captured log for the three expected lines.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; node -e "const j=require('./firebase.json'); if(!j.emulators) {process.exit(2)}; const p=j.emulators; if(p.auth.port!==9099||p.firestore.port!==8080||p.storage.port!==9199||!p.ui.enabled||p.ui.port!==4000){process.exit(3)}; if(p.functions){process.exit(4)}; console.log('ok')"</automated>
    <automated>test -f /Users/arnobrizwan/Mentor-Mind/tool/emulator-data/.gitkeep</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ( firebase emulators:start --only auth,firestore,storage > /tmp/p1-emu.log 2>&amp;1 &amp; PID=$!; sleep 12; kill $PID 2>/dev/null; wait $PID 2>/dev/null; true ) &amp;&amp; grep -q 'Auth Emulator' /tmp/p1-emu.log &amp;&amp; grep -q 'Firestore Emulator' /tmp/p1-emu.log &amp;&amp; grep -q 'Storage Emulator' /tmp/p1-emu.log</automated>
  </verify>
  <acceptance_criteria>
    - `firebase.json` parses as valid JSON (Node.js `require('./firebase.json')` succeeds).
    - `firebase.json` top-level `emulators` object has exactly four keys (`auth`, `firestore`, `storage`, `ui`) with the exact port values above; `functions` key is NOT present.
    - `tool/emulator-data/.gitkeep` is committed (file exists; `git ls-files tool/emulator-data/.gitkeep` returns the path).
    - A 12-second `firebase emulators:start --only auth,firestore,storage` boot writes the three expected emulator-ready lines to its log before being terminated.
    - The existing `flutter` / `firestore` / `storage` top-level keys in `firebase.json` are unchanged (verified by diffing only the new `emulators` block).
  </acceptance_criteria>
  <done>
    `firebase.json` has the emulators block per D-10; the Local Emulator Suite (Auth + Firestore + Storage + UI only) boots locally with the configured ports; the seed directory placeholder is committed for Plan 09 to populate.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| repo → public git remote | Anything committed becomes world-readable; `tool/seed/service-account.json` would be a credential leak |
| dev workstation → Firebase project `mentor-mind-aa765` | `pub get` pulls third-party packages whose code runs at test/build time |
| dev workstation ⇄ Firebase Local Emulator | Bound to localhost; not reachable from network unless ports explicitly forwarded |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-1-SECRET | Information Disclosure | `tool/seed/service-account.json` | mitigate | Task 1 runs `git check-ignore -v` and amends `.gitignore` if needed BEFORE any other source-tree changes |
| T-1-W0 | Information Disclosure | New test harness deps (`firebase_auth_mocks`, `fake_cloud_firestore`) | mitigate | All tests will use mocks or `useAuthEmulator(host, port)` — never real Firebase project credentials; this plan only INSTALLS deps, the no-real-credentials rule is enforced in Plan 08 |
| T-1-PKG | Tampering (supply chain) | Six newly added dev_deps | accept | All packages verified against pub.dev in RESEARCH § Package Legitimacy Audit (lines 187-203); pinned to exact major versions; no `[ASSUMED]`/`[SUS]` packages in the install set so no blocking-human checkpoint required |
| T-1-EMU | Spoofing | Localhost emulator ports (9099/8080/9199/4000) | accept | Bound to localhost only; dev-machine-only exposure; ports do not run in production |
</threat_model>

<verification>
- `flutter pub get` resolves with zero version conflicts (Task 2 automated check).
- `firebase emulators:start --only auth,firestore,storage` boots within 12 seconds and writes the three expected lines (Task 3 automated check).
- `git check-ignore -v tool/seed/service-account.json` returns a matching ignore rule (Task 1 automated check).
- No file outside `files_modified` is touched.
</verification>

<success_criteria>
- `pubspec.yaml` matches D-06 (six packages removed) and D-07 (`flutter_riverpod` added as direct dep) and CI-07 (six test-harness dev_deps installed) without any version conflict.
- `firebase.json` has the emulators block per D-10; Functions emulator deliberately omitted until Phase 2.
- `tool/seed/service-account.json` is verifiably gitignored (T-1-SECRET closed).
- `tool/emulator-data/.gitkeep` is committed for Plan 09 to populate.
</success_criteria>

<output>
Create `.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-01-deps-and-emulators-SUMMARY.md` when done. Record: pre-edit `flutter pub outdated` output for Firebase SDK rows, final `pubspec.yaml` diff (lines added/removed counts only), `firebase.json` diff, the literal output of `git check-ignore -v tool/seed/service-account.json`, and the emulator boot log lines proving each emulator started.
</output>
