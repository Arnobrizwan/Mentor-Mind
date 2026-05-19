---
phase: 03-gemini-proxy-server-side-rate-limiting
plan: 12
type: execute
wave: 6
depends_on: ["03-09", "03-11"]
files_modified:
  - lib/application/viewmodels/tutor/chat_viewmodel.dart
  - lib/core/services/gemini_service.dart
  - pubspec.yaml
  - pubspec.lock
  - README.md
  - BACKEND_SETUP.md
  - .github/workflows/ci.yml
  - .vscode/launch.json
autonomous: true
requirements: [AI-02, AI-03, AI-10]
pr_group: PR-3
tags: [chat_viewmodel_swap, gemini_service_delete, google_generative_ai_remove, dart_define_scrub, ios_binary_rebuild, ai_02, ai_03, ai_10, t_3_layer_breach, t_3_key_leak]

must_haves:
  truths:
    - "AI-02 honored: `--dart-define=GEMINI_API_KEY` removed from EVERY build config — `.github/workflows/ci.yml`, `README.md`, `BACKEND_SETUP.md` run instructions, `.vscode/launch.json` (if exists). The compiled iOS binary no longer carries the leaked key after `flutter build ios` reruns"
    - "AI-03 honored: `google_generative_ai: ^0.4.6` REMOVED from `pubspec.yaml` dependencies; `pubspec.lock` regenerated; the SDK is no longer linked into the binary"
    - "AI-10 honored: `chat_viewmodel.dart` no longer has `async*` / `await for` over Gemini chunks — non-streaming v1.0; the typing-indicator UX is preserved via the `isStreaming` flag which now means 'awaiting the Future' (RESEARCH §Anti-Patterns)"
    - "Path correction honored: this plan edits `lib/application/viewmodels/tutor/chat_viewmodel.dart` (the Phase 1 D-02 refactored path) — confirmed at repo state by `find lib -name chat_viewmodel.dart` returning ONLY this single path; NO file at `lib/features/tutor/chat_viewmodel.dart`"
    - "lib/core/services/gemini_service.dart DELETED in this commit — its SYSTEM_PROMPT text was preserved verbatim by plan 03-03 (functions/src/lib/gemini.ts SYSTEM_PROMPT const) so no information loss"
    - "Repository swap: `_geminiService` field replaced by `_mentorBotRepository`; `_history` in-memory state removed (server-side persistence in /sessions/{sid}/messages/ takes over per plan 03-06 D-08); `geminiServiceProvider` declaration removed"
    - "clientRequestId generation honored: `const Uuid().v4()` generated ONCE per user-initiated send and persisted onto the in-flight ChatMessage so a network flap retries with the same id (server-side idempotency dedupe — plan 03-06)"
    - "sessionId generation honored: `state.sessionId ?? const Uuid().v4()` — first message of a new chat generates a UUID; subsequent messages reuse it"
    - "dhakaDateKey honored: the inline `_todayKey()` helper at chat_viewmodel.dart:~461 REPLACED by `dhakaDateKey(DateTime.now())` from `lib/core/constants/quota.dart` (plan 03-10)"
    - "T-3-LAYER-BREACH closed (other side): chat_viewmodel.dart MUST NOT import cloud_functions — only the repository does; custom_lint `layered_imports` rule enforces this"
    - "T-3-KEY-LEAK closed: the iOS binary rebuild after this swap removes the literal GEMINI_API_KEY string from the compiled artifact; plan 03-08 BACKEND_SETUP §5 manual rotation is the companion gate"
    - "D-23 honored: NO migration script; NO data wipe; in-memory _history vanishes on app restart (existing behavior — preserved); first new session after PR-3 lands in the new server-persisted schema"
    - "flutter analyze --no-fatal-infos, dart run custom_lint (zero violations), flutter build ios --no-codesign ALL exit 0"
  artifacts:
    - path: "lib/application/viewmodels/tutor/chat_viewmodel.dart"
      provides: "MODIFIED — _geminiService swapped for _mentorBotRepository; _history removed; streaming code path removed; chatViewModelProvider updated"
      contains: "_mentorBotRepository"
    - path: "lib/core/services/gemini_service.dart"
      provides: "DELETED — git rm; SYSTEM_PROMPT preserved server-side"
      contains: ""
    - path: "pubspec.yaml"
      provides: "MODIFIED — google_generative_ai line REMOVED"
      contains: "uuid:"
    - path: "README.md"
      provides: "MODIFIED — removes --dart-define=GEMINI_API_KEY block; adds note pointing to BACKEND_SETUP.md §Phase 3"
      contains: ""
    - path: ".github/workflows/ci.yml"
      provides: "MODIFIED — removes --dart-define=GEMINI_API_KEY from flutter: job (if present)"
      contains: ""
    - path: "BACKEND_SETUP.md"
      provides: "MODIFIED — removes any --dart-define=GEMINI_API_KEY run-instruction holdover"
      contains: ""
    - path: ".vscode/launch.json"
      provides: "MODIFIED (if file exists) — removes --dart-define=GEMINI_API_KEY arg"
      contains: ""
  key_links:
    - from: "lib/application/viewmodels/tutor/chat_viewmodel.dart"
      to: "lib/data/repositories/mentor_bot_repository.dart (plan 03-11)"
      via: "imports MentorBotRepository + mentorBotRepositoryProvider"
      pattern: "mentorBotRepositoryProvider"
    - from: "lib/application/viewmodels/tutor/chat_viewmodel.dart"
      to: "lib/core/constants/quota.dart (plan 03-10)"
      via: "imports dhakaDateKey for display quota counter"
      pattern: "dhakaDateKey"
    - from: "lib/application/viewmodels/tutor/chat_viewmodel.dart"
      to: "package:uuid (plan 03-10)"
      via: "Uuid().v4() generates clientRequestId + sessionId"
      pattern: "Uuid\\(\\)\\.v4"
---

<objective>
Atomically swap `lib/application/viewmodels/tutor/chat_viewmodel.dart` from `GeminiService` to `MentorBotRepository`. Specifically: (1) replace the `_gemini` / `_geminiService` field with `_mentorBotRepository`; (2) replace the `async*` / `await for` streaming block in `sendMessage` with a `Future<MentorBotResponse>` call (isStreaming flag preserved as a typing-indicator signal); (3) replace the inline `_todayKey()` and `_genId()` helpers with `dhakaDateKey(...)` + `const Uuid().v4()`; (4) update `chatViewModelProvider` to inject `mentorBotRepositoryProvider` instead of `geminiServiceProvider`. Then: DELETE `lib/core/services/gemini_service.dart`. Then: REMOVE `google_generative_ai: ^0.4.6` from `pubspec.yaml` + regenerate `pubspec.lock`. Then: REMOVE every `--dart-define=GEMINI_API_KEY` reference from `README.md`, `BACKEND_SETUP.md`, `.github/workflows/ci.yml`, `.vscode/launch.json` (if it exists).

Purpose: This is the AI-02 + AI-03 + AI-10 atomic landing — the Phase 3 PR-3 stays a SINGLE PR (D-18 / D-20) so the system is never in a half-state where the Dart side has the new repository but the binary still links the old SDK with the leaked key. After this plan + plan 03-08 §5 (manual Studio key revoke), the leaked key is dead AND the binary no longer carries it.

Output: 8 files modified/deleted. One or more commits (CONTEXT D-18 lists 5 sub-steps that can be 1 or 5 commits — keep them logically ordered: (a) repository swap, (b) delete gemini_service.dart, (c) pubspec edit + pub get, (d) build config scrub, (e) verify). `flutter analyze --no-fatal-infos`, `dart run custom_lint`, `flutter build ios --no-codesign` ALL exit 0.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-CONTEXT.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-RESEARCH.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-PATTERNS.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-11-mentor-bot-repository-PLAN.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-10-uuid-and-quota-dart-PLAN.md
@lib/application/viewmodels/tutor/chat_viewmodel.dart
@lib/core/services/gemini_service.dart
@pubspec.yaml
@README.md
@BACKEND_SETUP.md
@.github/workflows/ci.yml
@CLAUDE.md

<unresolved_questions>
**Model-fallback decision:** Plan 03-04's checkpoint may have resolved to `gemini-2.5-pro` (plan 03-03 default stands) OR upgraded to `gemini-3.1-pro` OR downgraded to `gemini-1.5-pro`. This plan does NOT depend on which one — the Dart side does not name the model — but the SUMMARY of plan 03-12 records which model was resolved so PR-3's description references it.

If Plan 03-04 ended in path `(d)` (no model resolved), this plan is BLOCKED — PR-3 cannot merge until a model is pinned. Surface this to the user before starting Task 1.
</unresolved_questions>

<interfaces>
<!-- Patterns from 03-PATTERNS.md §lib/application/viewmodels/tutor/chat_viewmodel.dart lines 779-859 + §lib/core/services/gemini_service.dart §DELETE rule + §pubspec.yaml diff -->

chat_viewmodel.dart — DELTAS (full list — 8 distinct edits):

DELTA 1 — Imports (top of file):
  REMOVE:
    `import 'package:mentor_minds/core/services/gemini_service.dart';`
  ADD (alphabetical):
    `import 'package:mentor_minds/core/constants/quota.dart';`
    `import 'package:mentor_minds/data/models/mentor_bot_response.dart';`
    `import 'package:mentor_minds/data/repositories/mentor_bot_repository.dart';`
    `import 'package:uuid/uuid.dart';`

DELTA 2 — Field declaration (in `class ChatViewModel extends StateNotifier<ChatState>`):
  REMOVE:
    `final GeminiService _gemini;`  (or `final GeminiService _geminiService;` — confirm exact name at read-time)
  ADD:
    `final MentorBotRepository _mentorBotRepository;`

DELTA 3 — Constructor parameter list:
  REMOVE the `GeminiService` parameter (e.g. `this._gemini` or `required GeminiService gemini, ... : _gemini = gemini`).
  ADD `required MentorBotRepository mentorBotRepository` and `_mentorBotRepository = mentorBotRepository` in the initializer list.
  Preserve all OTHER parameters (authRepository, usersRepository, sessionsRepository, storageRepository).

DELTA 4 — `sendMessage` body — streaming block REPLACEMENT:
  Look for the existing `async*` / `await for (final chunk in _gemini.sendMessage(...))` block (RESEARCH §Anti-Patterns confirms it lives at approximately chat_viewmodel.dart:286-296 in the current state).
  REMOVE the entire streaming block:
    ```dart
    final buffer = StringBuffer();
    await for (final chunk in _gemini.sendMessage(
      text: trimmed,
      subject: state.selectedSubject,
      level: state.selectedLevel,
    )) {
      buffer.write(chunk);
      _updateMessage(aiPlaceholder.id, content: buffer.toString());
    }
    finalText = buffer.toString();
    _updateMessage(aiPlaceholder.id, isStreaming: false);
    ```
  REPLACE with:
    ```dart
    // Phase 3 AI-10: non-streaming Future call. isStreaming flag stays in
    // ChatState — drives the typing indicator — but now means "awaiting the
    // Future" instead of "consuming a Stream". Same UX.
    final response = await _mentorBotRepository.sendMessage(
      sessionId: state.sessionId ?? const Uuid().v4(),
      clientRequestId: clientRequestId,
      message: trimmed,
      subject: state.selectedSubject,
      level: state.selectedLevel,
    );
    finalText = response.text;
    _updateMessage(aiPlaceholder.id, content: finalText, isStreaming: false);
    ```

DELTA 5 — `sendMessage` body — image-attached branch:
  If the current code has a separate `_gemini.analyzeImage(...)` await block (RESEARCH confirms lines ~275-283), REPLACE it with a `_mentorBotRepository.sendMessage(...)` call that PASSES `imageUrl: <storage path>`. The mentorBotChat handler (plan 03-06) routes image vs text via the presence of `imageUrl`. Concrete shape:
    ```dart
    final response = await _mentorBotRepository.sendMessage(
      sessionId: state.sessionId ?? const Uuid().v4(),
      clientRequestId: clientRequestId,
      message: trimmed,
      imageUrl: uploadedImageUrl,  // gs:// or download URL from storage upload
      subject: state.selectedSubject,
      level: state.selectedLevel,
    );
    finalText = response.text;
    _updateMessage(aiPlaceholder.id, content: finalText, isStreaming: false);
    ```

DELTA 6 — clientRequestId generation:
  ADD ONE line at the TOP of the sendMessage body (BEFORE any state mutation, BEFORE the message is appended to the in-flight list):
    `final clientRequestId = const Uuid().v4();`
  Persist clientRequestId onto the in-flight ChatMessage for both user and ai placeholder docs (so a retry uses the SAME id). If the existing ChatMessage model doesn't have a `clientRequestId` field, leave a TODO comment and confirm the model shape at read time — the in-flight retry-with-same-id behavior is a Phase 3 polish that can ship in this plan or carry to plan 03-13 smoke-test exercises (the smoke test exercises the wire-level retry).

DELTA 7 — `newChat()` + `loadSession()`:
  REMOVE the `_gemini.resetSession()` call from `newChat()` (~line 194) — no in-memory chat history to reset.
  REMOVE the `_gemini.resetSession()` call from `loadSession()` (~line 392) — same.

DELTA 8 — Helper-function replacements:
  REMOVE the `_todayKey()` static helper (~lines 461-465) — replace every call site with `dhakaDateKey(DateTime.now())` imported from `lib/core/constants/quota.dart`.
  REMOVE the `_genId()` helper (~lines 467-470) — replace every call site with `const Uuid().v4()`.

DELTA 9 — Provider declaration block (bottom of file):
  REMOVE the existing `geminiServiceProvider` declaration:
    ```dart
    final geminiServiceProvider = Provider<GeminiService>((ref) {
      final svc = GeminiService();
      ref.onDispose(svc.resetSession);
      return svc;
    });
    ```
  REPLACE `chatViewModelProvider` to inject MentorBotRepository instead of GeminiService:
    ```dart
    final chatViewModelProvider =
        StateNotifierProvider.autoDispose<ChatViewModel, ChatState>((ref) {
      return ChatViewModel(
        mentorBotRepository: ref.read(mentorBotRepositoryProvider),
        authRepository: ref.read(authRepositoryProvider),
        usersRepository: ref.read(usersRepositoryProvider),
        sessionsRepository: ref.read(sessionsRepositoryProvider),
        storageRepository: ref.read(storageRepositoryProvider),
      );
    });
    ```
  Adapt the constructor-call style to match the existing pattern (positional vs named — if the existing constructor uses positional, keep positional with the new parameter in the same slot the old GeminiService was).

lib/core/services/gemini_service.dart — DELETE:
  `git rm /Users/arnobrizwan/Mentor-Mind/lib/core/services/gemini_service.dart`
  No replacement file. SYSTEM_PROMPT is preserved server-side (plan 03-03 functions/src/lib/gemini.ts).

pubspec.yaml — DELTA:
  REMOVE the line `  google_generative_ai: ^0.4.6` from `dependencies:`.
  `flutter pub get` regenerates `pubspec.lock` WITHOUT the google_generative_ai block.

README.md — DELTA:
  Find any line containing `--dart-define=GEMINI_API_KEY` (likely a `flutter run` example).
  REMOVE the `--dart-define=GEMINI_API_KEY=<your-key>` argument from the command line.
  ADD a note pointing to BACKEND_SETUP.md §Phase 3 (where the proxy setup lives).
  Example:
    Before: `flutter run --dart-define=GEMINI_API_KEY=AIzaXXXX`
    After:  `flutter run  # No API key needed — Gemini calls proxied via Cloud Functions. See BACKEND_SETUP.md §Phase 3.`

BACKEND_SETUP.md — DELTA:
  Find any line containing `--dart-define=GEMINI_API_KEY` in the run-instructions sections (could be in the Phase 1 / Phase 2 quickstart blocks — NOT the new §Phase 3 section, which already avoids it).
  REMOVE the argument.

.github/workflows/ci.yml — DELTA:
  Search for `--dart-define=GEMINI_API_KEY` anywhere in the workflow. If present (likely in the `flutter:` job's `flutter test` step), REMOVE the argument.
  Verify the workflow still parses after the edit.

.vscode/launch.json — DELTA:
  If this file exists (it currently does NOT per RESEARCH §Files-not-yet-present), and contains any `--dart-define=GEMINI_API_KEY` arg in any `args` array, REMOVE that single string.
  If the file doesn't exist, skip — no-op.

Verification command set (must ALL pass — copy the commands into the verify block):
```bash
# 1. gemini_service.dart deleted
test ! -f lib/core/services/gemini_service.dart

# 2. google_generative_ai removed from pubspec
! grep -q "google_generative_ai" pubspec.yaml
! grep -q "google_generative_ai" pubspec.lock

# 3. GEMINI_API_KEY scrubbed everywhere
! grep -rE 'GEMINI_API_KEY' .vscode/launch.json .github/workflows/ci.yml README.md BACKEND_SETUP.md 2>/dev/null

# 4. chat_viewmodel.dart no longer imports gemini_service
! grep -q "core/services/gemini_service" lib/application/viewmodels/tutor/chat_viewmodel.dart

# 5. chat_viewmodel.dart uses MentorBotRepository
grep -q "MentorBotRepository" lib/application/viewmodels/tutor/chat_viewmodel.dart
grep -q "_mentorBotRepository" lib/application/viewmodels/tutor/chat_viewmodel.dart

# 6. AI-10: no streaming code path
! grep -E 'generateContentStream|async\*|await for' lib/application/viewmodels/tutor/chat_viewmodel.dart

# 7. dhakaDateKey + Uuid imports
grep -q "package:mentor_minds/core/constants/quota.dart" lib/application/viewmodels/tutor/chat_viewmodel.dart
grep -q "package:uuid/uuid.dart" lib/application/viewmodels/tutor/chat_viewmodel.dart

# 8. T-3-LAYER-BREACH: no cloud_functions import in viewmodel
! grep -E "import 'package:cloud_functions" lib/application/viewmodels/tutor/chat_viewmodel.dart

# 9. Build chain green
flutter analyze --no-fatal-infos
dart run custom_lint
flutter build ios --no-codesign
```

What this plan does NOT do:
  - Does NOT delete the existing `lib/data/models/chat_message.dart` — Phase 1 D-02 model stays; the viewmodel still uses ChatMessage for the in-flight UI list.
  - Does NOT modify any unrelated viewmodel (auth, dashboard, profile, etc).
  - Does NOT change the iOS build configuration beyond the launch.json scrub (entitlements, Info.plist, Podfile all unchanged).
  - Does NOT add a streaming endpoint (AI-10 — non-streaming v1.0 — explicit).
  - Does NOT call `firebase deploy` — production deploys happen via the PR-3 merge process, documented in plan 03-15 closeout.
  - Does NOT remove the existing `_awardPoints('complete_session')` client-side call (Q-2 in VALIDATION — DEFERRED to Phase 4 per REWD-04 ownership).
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Atomic swap — chat_viewmodel.dart from GeminiService → MentorBotRepository; delete gemini_service.dart; remove google_generative_ai from pubspec; scrub GEMINI_API_KEY from all build configs; verify analyze + custom_lint + build all green</name>
  <files>lib/application/viewmodels/tutor/chat_viewmodel.dart, lib/core/services/gemini_service.dart, pubspec.yaml, pubspec.lock, README.md, BACKEND_SETUP.md, .github/workflows/ci.yml, .vscode/launch.json</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/lib/application/viewmodels/tutor/chat_viewmodel.dart (CURRENT — full file; capture the exact field name `_gemini` vs `_geminiService`, the constructor signature shape (named vs positional), the streaming block line range, the helper function line ranges)
    - /Users/arnobrizwan/Mentor-Mind/lib/core/services/gemini_service.dart (confirm shape; this file is DELETED in this plan but read first to confirm no public symbols are referenced elsewhere)
    - /Users/arnobrizwan/Mentor-Mind/lib/data/repositories/mentor_bot_repository.dart (plan 03-11 — confirm `MentorBotRepository.sendMessage` signature + `mentorBotRepositoryProvider`)
    - /Users/arnobrizwan/Mentor-Mind/lib/core/constants/quota.dart (plan 03-10 — confirm `dhakaDateKey(DateTime)` export)
    - /Users/arnobrizwan/Mentor-Mind/pubspec.yaml (CURRENT — confirm `google_generative_ai: ^0.4.6` is still present from Phase 1)
    - /Users/arnobrizwan/Mentor-Mind/README.md (CURRENT — find any `--dart-define=GEMINI_API_KEY` line)
    - /Users/arnobrizwan/Mentor-Mind/BACKEND_SETUP.md (CURRENT — find any `--dart-define=GEMINI_API_KEY` line in Phase 1 / Phase 2 quickstart blocks)
    - /Users/arnobrizwan/Mentor-Mind/.github/workflows/ci.yml (CURRENT — find any `--dart-define=GEMINI_API_KEY` line)
    - /Users/arnobrizwan/Mentor-Mind/.vscode/launch.json (CURRENT — may not exist; skip if absent)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-PATTERNS.md (§lib/application/viewmodels/tutor/chat_viewmodel.dart lines 779-859 — substitution rules)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md (row `03-12-chat-viewmodel-swap` line 65)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-CONTEXT.md (D-18 PR-3 sequencing; D-23 no migration; AI-02/AI-03/AI-10)
  </read_first>
  <action>
    Step 0 — PRE-FLIGHT: Confirm Plan 03-04 resolved a model (otherwise PR-3 is blocked):
      ```bash
      ls /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-04-model-availability-checkpoint-SUMMARY.md
      # If absent OR records path (d): STOP and surface to user.
      ```

    Step A — Read `lib/application/viewmodels/tutor/chat_viewmodel.dart` in full. Capture:
      - The exact field name (`_gemini` or `_geminiService`).
      - Whether the constructor uses positional or named parameters.
      - The exact line range of the streaming block (`async*` / `await for`).
      - The exact line range of `_todayKey()` and `_genId()` helpers.
      - The exact provider block at the bottom (the existing `geminiServiceProvider` + the existing `chatViewModelProvider` shape).
      - The ChatMessage model: does it have a `clientRequestId` field? (If not, the persistence of clientRequestId onto the in-flight model is a follow-up; the network-level retry-with-same-id is exercised by plan 03-13 smoke test.)

    Step B — Apply DELTAs 1-9 from the `<interfaces>` section to `chat_viewmodel.dart`. Order:
      1. Imports — REMOVE gemini_service; ADD quota.dart + mentor_bot_response.dart + mentor_bot_repository.dart + uuid.
      2. Field declaration — `final MentorBotRepository _mentorBotRepository;`.
      3. Constructor — REPLACE GeminiService parameter with MentorBotRepository parameter.
      4. `sendMessage` body — REPLACE the streaming block (text branch).
      5. `sendMessage` body — REPLACE the image branch (if present) with the `imageUrl:` payload variant.
      6. `sendMessage` body — ADD `final clientRequestId = const Uuid().v4();` at the top of the method.
      7. `newChat()` + `loadSession()` — REMOVE `_gemini.resetSession()` calls.
      8. Helper functions — DELETE `_todayKey()` + `_genId()`; replace call sites with `dhakaDateKey(DateTime.now())` + `const Uuid().v4()`.
      9. Provider block — REMOVE `geminiServiceProvider`; UPDATE `chatViewModelProvider` to read `mentorBotRepositoryProvider`.

    Step C — Delete the gemini_service.dart file:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      git rm lib/core/services/gemini_service.dart
      ```

    Step D — Edit pubspec.yaml:
      Remove the line `  google_generative_ai: ^0.4.6`. Do NOT remove `uuid: ^4.5.3` (plan 03-10 added it). Do NOT remove `intl: ^0.19.0` (still needed by lib/core/constants/quota.dart).

    Step E — Regenerate pubspec.lock:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      flutter pub get 2>&amp;1 | tail -10
      # Expect: exit 0. The line `- google_generative_ai 0.4.6` (or similar)
      # should appear in the output indicating removal.
      ```

    Step F — Scrub `--dart-define=GEMINI_API_KEY` from all build configs:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      # Find every file with the pattern (informational; the edits follow):
      grep -rEn 'GEMINI_API_KEY|--dart-define=GEMINI_API_KEY' \
        README.md BACKEND_SETUP.md .github/workflows/ci.yml .vscode/launch.json 2>/dev/null \
        | tee /tmp/p3-12-found-keys.log

      # For each file in the grep output, remove the offending arg / line.
      ```

      Targeted edits:
        - **README.md**: find `flutter run --dart-define=GEMINI_API_KEY=...` lines; remove the `--dart-define=...` arg; replace with `flutter run  # See BACKEND_SETUP.md §Phase 3 for setup`.
        - **BACKEND_SETUP.md**: find any holdover `--dart-define=GEMINI_API_KEY` in §Phase 1 / Phase 2 quickstart blocks (the new §Phase 3 added by plan 03-08 already avoids it); remove.
        - **.github/workflows/ci.yml**: find any `--dart-define=GEMINI_API_KEY` in `flutter test` or `flutter build` step args; remove.
        - **.vscode/launch.json** (only if file exists): find any `"--dart-define=GEMINI_API_KEY=..."` string in any `"args"` array; remove that one string.

    Step G — Verify each build config is clean:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      ! grep -rE 'GEMINI_API_KEY' README.md BACKEND_SETUP.md .github/workflows/ci.yml .vscode/launch.json 2>/dev/null
      # Expect: zero matches.
      ```

    Step H — Build chain verification:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind

      # 1. Static analysis
      flutter analyze --no-fatal-infos 2>&amp;1 | tee /tmp/p3-12-analyze.log
      test $? -eq 0

      # 2. custom_lint (Phase 1 D-CONTEXT layered_imports rule)
      dart run custom_lint 2>&amp;1 | tee /tmp/p3-12-customlint.log
      # Expect: no `layered_imports` violations on chat_viewmodel.dart
      ! grep -E 'chat_viewmodel\.dart.*layered_imports' /tmp/p3-12-customlint.log

      # 3. iOS build (the SCRUB validation — the rebuilt binary no longer
      #    contains the literal GEMINI_API_KEY string)
      flutter build ios --no-codesign 2>&amp;1 | tee /tmp/p3-12-build-ios.log
      test $? -eq 0

      # 4. Optional belt-and-suspenders: verify no GEMINI_API_KEY string in the
      #    compiled binary (defends against any --dart-define holdover):
      if [ -f build/ios/iphoneos/Runner.app/Runner ]; then
        ! strings build/ios/iphoneos/Runner.app/Runner 2>/dev/null | grep -q "GEMINI_API_KEY"
      fi
      ```

    Step I — Required-content greps:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind

      # chat_viewmodel.dart edits
      ! grep -q "core/services/gemini_service" lib/application/viewmodels/tutor/chat_viewmodel.dart
      grep -q "MentorBotRepository" lib/application/viewmodels/tutor/chat_viewmodel.dart
      grep -q "_mentorBotRepository" lib/application/viewmodels/tutor/chat_viewmodel.dart
      grep -q "package:uuid/uuid.dart" lib/application/viewmodels/tutor/chat_viewmodel.dart
      grep -q "package:mentor_minds/core/constants/quota.dart" lib/application/viewmodels/tutor/chat_viewmodel.dart
      grep -q "dhakaDateKey" lib/application/viewmodels/tutor/chat_viewmodel.dart
      grep -q "Uuid().v4()" lib/application/viewmodels/tutor/chat_viewmodel.dart
      grep -q "mentorBotRepositoryProvider" lib/application/viewmodels/tutor/chat_viewmodel.dart
      # Old gemini_service references gone
      ! grep -q "geminiServiceProvider" lib/application/viewmodels/tutor/chat_viewmodel.dart
      ! grep -q "GeminiService" lib/application/viewmodels/tutor/chat_viewmodel.dart
      # AI-10: no streaming
      ! grep -E 'generateContentStream|async\*|await for.*chunk' lib/application/viewmodels/tutor/chat_viewmodel.dart
      # T-3-LAYER-BREACH: no cloud_functions import in viewmodel
      ! grep -E "import 'package:cloud_functions" lib/application/viewmodels/tutor/chat_viewmodel.dart

      # gemini_service deleted
      test ! -f lib/core/services/gemini_service.dart

      # pubspec scrubbed
      ! grep -q "google_generative_ai" pubspec.yaml
      ! grep -q "google_generative_ai" pubspec.lock
      ```

    Step J — Commit (one atomic commit per D-18 / D-20 — easier to revert):
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      git add lib/application/viewmodels/tutor/chat_viewmodel.dart \
              lib/core/services/gemini_service.dart \
              pubspec.yaml pubspec.lock \
              README.md BACKEND_SETUP.md \
              .github/workflows/ci.yml
      # Add launch.json only if it exists and was modified
      [ -f .vscode/launch.json ] &amp;&amp; git add .vscode/launch.json
      git commit -m "refactor(chat): swap GeminiService → MentorBotRepository; delete gemini_service.dart; remove google_generative_ai + GEMINI_API_KEY everywhere (Phase 3 PR-3; AI-02/AI-03/AI-10; D-18/D-20)"
      ```
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test ! -f lib/core/services/gemini_service.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -q "google_generative_ai" pubspec.yaml &amp;&amp; ! grep -q "google_generative_ai" pubspec.lock</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -rE 'GEMINI_API_KEY' README.md BACKEND_SETUP.md .github/workflows/ci.yml 2>/dev/null</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; [ ! -f .vscode/launch.json ] || ! grep -q "GEMINI_API_KEY" .vscode/launch.json</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -q "core/services/gemini_service" lib/application/viewmodels/tutor/chat_viewmodel.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "MentorBotRepository" lib/application/viewmodels/tutor/chat_viewmodel.dart &amp;&amp; grep -q "_mentorBotRepository" lib/application/viewmodels/tutor/chat_viewmodel.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "package:uuid/uuid.dart" lib/application/viewmodels/tutor/chat_viewmodel.dart &amp;&amp; grep -q "package:mentor_minds/core/constants/quota.dart" lib/application/viewmodels/tutor/chat_viewmodel.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "mentorBotRepositoryProvider" lib/application/viewmodels/tutor/chat_viewmodel.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -E 'generateContentStream|async\*|await for.*chunk' lib/application/viewmodels/tutor/chat_viewmodel.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -E "import 'package:cloud_functions" lib/application/viewmodels/tutor/chat_viewmodel.dart</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --no-fatal-infos 2>&amp;1 | tail -5; test $? -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; dart run custom_lint 2>&amp;1 | tee /tmp/p3-12-v-customlint.log; ! grep -E 'chat_viewmodel\.dart.*layered_imports' /tmp/p3-12-v-customlint.log</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter build ios --no-codesign 2>&amp;1 | tail -10; test $? -eq 0</automated>
  </verify>
  <acceptance_criteria>
    - `lib/core/services/gemini_service.dart` DELETED.
    - `lib/application/viewmodels/tutor/chat_viewmodel.dart` no longer imports `core/services/gemini_service.dart`; imports the four new packages (quota, mentor_bot_response, mentor_bot_repository, uuid).
    - Field renamed: `_mentorBotRepository` (NOT `_gemini` / `_geminiService`).
    - `chatViewModelProvider` injects `mentorBotRepositoryProvider`.
    - `Uuid().v4()` used for clientRequestId + sessionId generation.
    - `dhakaDateKey(DateTime.now())` used in place of the old `_todayKey()` helper.
    - No `async*` / `await for chunk` block (AI-10 — non-streaming).
    - No `import 'package:cloud_functions'` in chat_viewmodel.dart (T-3-LAYER-BREACH closed).
    - `pubspec.yaml` does NOT contain `google_generative_ai`; `pubspec.lock` regenerated.
    - Zero `GEMINI_API_KEY` references in `README.md`, `BACKEND_SETUP.md`, `.github/workflows/ci.yml`, `.vscode/launch.json`.
    - `flutter analyze --no-fatal-infos` exits 0.
    - `dart run custom_lint` reports no `layered_imports` violations on chat_viewmodel.dart.
    - `flutter build ios --no-codesign` exits 0.
    - Compiled iOS Runner binary does NOT contain the literal string `GEMINI_API_KEY` (best-effort `strings` check).
  </acceptance_criteria>
  <done>
    The atomic swap landed. The iOS binary is rebuilt without the leaked key + without `google_generative_ai`. Plan 03-08 §5 manual revoke (solo dev clicks https://aistudio.google.com/apikey) is the companion gate. Plan 03-13 emulator smoke test exercises the new path end-to-end. Plan 03-15 closeout's blocking human checkpoint reconfirms the key revoke before flipping nyquist_compliant.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| iOS binary ⇄ leaked Google AI Studio key | Pre-swap: the binary linked `google_generative_ai` and was compiled with `--dart-define=GEMINI_API_KEY=...` baking the key into the artifact. Post-swap: the SDK is gone; the env-var is gone; the binary is rebuilt; the key is no longer in the artifact. |
| chat_viewmodel.dart ⇄ MentorBotRepository | New layer boundary: viewmodel calls repository (NOT cloud_functions directly). custom_lint enforces. |
| In-memory _history ⇄ persisted /sessions/{sid}/messages/ | Old: in-memory only, vanished on restart. New: server-side persistence per plan 03-06; client reads from Firestore stream for history loading (handled in `loadSession`, not changed here). |
| pubspec.yaml ⇄ supply chain | google_generative_ai removed; uuid stays (vetted in plan 03-10). |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-3-KEY-LEAK | Information Disclosure | (continuing T-3-KEY-LEAK closure) The leaked key persists in old iOS binary builds; the new build rebuilds without the key, but rotation in Studio is the authoritative fix | mitigate | This plan removes the key from the new build path; plan 03-08 §5 + plan 03-15 closeout checkpoint enforce the manual Studio revoke. T-3-KEY-LEAK is FULLY closed only when both edits land. |
| T-3-LAYER-BREACH | Tampering | Viewmodel imports cloud_functions directly, bypassing the repository | mitigate | custom_lint `layered_imports` rule + this plan's verify gate `! grep "import 'package:cloud_functions" chat_viewmodel.dart`. Phase 1 D-CONTEXT enforced; Phase 3 carries forward. |
| T-3-12-HISTORY-LOSS | Repudiation | Removing in-memory _history loses unsaved chat content on swap-day | accept | D-23 explicit: in-memory transcripts vanish on app restart in current behavior anyway; PR-3 doesn't worsen the contract. First new session post-PR-3 lands in the new schema. |
| T-3-12-IOS-BUILD-FAIL | Denial of Service | `flutter build ios --no-codesign` fails after the swap due to a missed import or type error | mitigate | Step H runs the build BEFORE the commit. CI's flutter: job (Phase 1) does the same on PR push. |
| T-3-12-CONFIG-DRIFT | Tampering | A future developer re-introduces `--dart-define=GEMINI_API_KEY` in launch.json or CI | mitigate | Plan 03-15 closeout re-runs the scrub greps. Adding a pre-commit hook is a Phase 7 polish item. |
| T-3-12-RETRY-SAME-ID-MISSING | Tampering | Network flap during sendMessage; the client retries; the new attempt generates a NEW clientRequestId; server deduplication fails; user is double-charged quota | partial-mitigate | The clientRequestId is generated ONCE at the top of sendMessage (DELTA 6). If the ChatMessage model carries it, retries reuse. If not (model is untouched in this plan), the retry-with-same-id behavior is exercised by plan 03-13 smoke test at the wire level. Accept the gap for v1.0; document in plan 03-13 SUMMARY. |
| T-3-12-PROVIDER-CYCLE | Denial of Service | The new mentorBotRepositoryProvider creates a dependency cycle with auth/sessions providers | accept | Phase 1's repository providers + Phase 3's new MentorBotRepository each have a single dependency (firebaseFunctionsProvider for the new one); no cycle possible. custom_lint catches structural import cycles. |
</threat_model>

<verification>
- lib/application/viewmodels/tutor/chat_viewmodel.dart swapped to MentorBotRepository.
- lib/core/services/gemini_service.dart deleted.
- google_generative_ai removed from pubspec + lock.
- GEMINI_API_KEY scrubbed from README, BACKEND_SETUP, ci.yml, launch.json.
- No streaming code path in chat_viewmodel.
- No cloud_functions import in chat_viewmodel.
- Uuid().v4() + dhakaDateKey wired.
- flutter analyze, dart run custom_lint, flutter build ios all green.
- Compiled binary has no GEMINI_API_KEY string.
</verification>

<success_criteria>
- AI-02: leaked-key build path removed.
- AI-03: SDK removed from binary.
- AI-10: non-streaming Future call.
- D-18 / D-20 atomic PR-3 swap landed.
- Plan 03-13 emulator smoke test has a working repository wired into chat_viewmodel.
- Plan 03-15 closeout's manual revoke checkpoint can verify Studio rotation.
</success_criteria>

<output>
Create `.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-12-chat-viewmodel-swap-SUMMARY.md` when done. Record:
1. The diff of lib/application/viewmodels/tutor/chat_viewmodel.dart (full before/after — this is the core artifact of the plan).
2. Confirmation that lib/core/services/gemini_service.dart was deleted (git status output).
3. The pubspec.yaml diff (google_generative_ai line removed).
4. The list of files that had GEMINI_API_KEY references + each diff.
5. flutter analyze output (0 errors).
6. dart run custom_lint output (no layered_imports violations on chat_viewmodel.dart).
7. flutter build ios --no-codesign exit code (must be 0).
8. (If attempted) the `strings build/ios/iphoneos/Runner.app/Runner | grep -c GEMINI_API_KEY` result (expect 0).
9. Commit SHA.
10. The model resolution recorded by plan 03-04 SUMMARY (referenced for PR-3 description).
11. Forward-pointer: plan 03-13 emulator smoke test exercises the swap end-to-end; plan 03-15 closeout checkpoint verifies leaked-key revoke.
</output>
</content>
