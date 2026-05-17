# Phase 1: Foundation — Refactor, CI, Test Harness, iOS Identity - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-17
**Phase:** 1-Foundation — Refactor, CI, Test Harness, iOS Identity
**Areas discussed:** Repository abstraction shape (ARCH-03), Riverpod codegen + unused DI packages (QUAL-06), Test scaffolding depth in P1 (CI-04, CI-05), Refactor PR sequencing

User-added context: "focus on ios 26 14-2" — interpreted and confirmed as iOS 26 SDK + iOS 14.2 minimum deployment target.

---

## Repository abstraction shape (ARCH-03)

### How should repositories be organized under lib/data/repositories/?

| Option | Description | Selected |
|--------|-------------|----------|
| Per-collection | UsersRepository, SessionsRepository, MaterialsRepository, NotificationsRepository, RewardsRepository, SubscriptionsRepository. ~6 repos. 1:1 with Firestore collections + firestore.rules. | ✓ |
| Per-feature | DashboardRepository, ChatRepository, ProfileRepository, etc. ~10 repos. Same collection read from multiple repos → query duplication. | |
| Hybrid | Collection repos for CRUD + per-feature services compose them. More flexibility, more layers. | |

**User's choice:** Per-collection.

### What do repositories return — raw Firestore types or decoded domain models?

| Option | Description | Selected |
|--------|-------------|----------|
| Decoded domain models | Stream<List<MaterialItem>>; repo owns fromDoc/toMap; viewmodels never touch Firestore types. | ✓ |
| Raw Firestore snapshots | Stream<QuerySnapshot>; viewmodels call fromDoc themselves. Leaks Firestore into application layer. | |
| Both | Two methods per query. | |

**User's choice:** Decoded domain models.

### Where do extracted models live under lib/data/models/?

| Option | Description | Selected |
|--------|-------------|----------|
| Flat — one file per entity | lib/data/models/chat_message.dart, etc. ~10 files. No nesting. | ✓ |
| Grouped by collection | lib/data/models/users/..., lib/data/models/sessions/..., etc. | |
| Single barrel file | lib/data/models/models.dart with everything. Breaks no-barrel convention. | |

**User's choice:** Flat — one file per entity.

### How are repositories wired into viewmodels?

| Option | Description | Selected |
|--------|-------------|----------|
| Riverpod Provider per repo | usersRepositoryProvider; firestoreProvider/firebaseAuthProvider/storageProvider expose SDK singletons for ProviderScope.overrides; no get_it/injectable. | ✓ |
| Repo constructor takes SDK instances explicitly (no provider for SDK) | Less test-friendly. | |
| Implicit SDK access inside repo | Same testability problem as today. | |

**User's choice:** Riverpod Provider per repo (with SDK provider seams).

---

## Riverpod codegen + unused DI packages (QUAL-06)

### Riverpod codegen direction — migrate to @riverpod now, or stay vanilla?

| Option | Description | Selected |
|--------|-------------|----------|
| Stay vanilla in P1 — defer codegen entirely | Keep StateNotifier pattern. Drop riverpod_annotation/riverpod_generator/build_runner. Migration bundled with Riverpod 2→3 in v1.1. | ✓ |
| Migrate to @riverpod codegen this phase | Modern API; rewrites 12 viewmodels inside the refactor PR; breaks diff hygiene. | |
| Codegen only for new files | Mixed style; inconsistency cost. | |

**User's choice:** Stay vanilla; defer codegen.

### Which unused codegen + DI packages get deleted from pubspec.yaml in P1?

| Option | Description | Selected |
|--------|-------------|----------|
| riverpod_annotation (dep) | unused | ✓ |
| riverpod_generator (dev_dep) | unused | ✓ |
| injectable (dep) | unused; DI via Riverpod instead | ✓ |
| injectable_generator (dev_dep) + get_it (dep) | all unused | ✓ |

**User's choice:** Delete all four (effectively all five packages — get_it bundled with injectable_generator option).

### What about build_runner?

| Option | Description | Selected |
|--------|-------------|----------|
| Drop now | Nothing uses codegen; cleanest pubspec. | ✓ |
| Keep build_runner | Might want it later for freezed/json_serializable. YAGNI. | |

**User's choice:** Drop build_runner.

### flutter_riverpod fix (QUAL-03 — currently mapped to Phase 7)

| Option | Description | Selected |
|--------|-------------|----------|
| Fix now in P1 | Add flutter_riverpod to dependencies. Clears 12 info hits. Removes latent v3 break. | ✓ |
| Defer to Phase 7 | Honors traceability but keeps the latent break. | |

**User's choice:** Fix now in P1. Scope adjustment — QUAL-03 pulled forward from P7.

### custom_lint setup (QUAL-04) — what enforces the layer rule?

| Option | Description | Selected |
|--------|-------------|----------|
| custom_lint + riverpod_lint + project-local rule | Layered-import enforcement + riverpod_lint hints; runs via 'dart run custom_lint' in CI. | ✓ |
| Custom rule only — skip riverpod_lint | Misses Riverpod-specific hints. | |
| Defer custom rule — use grep in CI | Doesn't satisfy QUAL-04's 'custom_lint passes' requirement. | |

**User's choice:** custom_lint + riverpod_lint + project-local rule.

---

## Test scaffolding depth in P1 (CI-04, CI-05)

### How deep does the test surface go in Phase 1 vs deferred to Phase 7?

| Option | Description | Selected |
|--------|-------------|----------|
| Harness + anchor tests + Validators/models | Install 6 deps. ~5 anchor tests (Validators, OnboardingVM, AuthVM, DashboardScreen widget, login smoke integration). | ✓ |
| Full coverage in P1 | 12 widget tests + 12 viewmodel test suites. ~50+ tests; P1 becomes huge. | |
| Harness-only | Install deps + trivial test per category. No real assertions. | |

**User's choice:** Harness + anchor tests.

### Firebase Local Emulator Suite scope (CI-06)

| Option | Description | Selected |
|--------|-------------|----------|
| Auth + Firestore + Storage only | 3 SDKs we use today; Functions emulator in P2. | ✓ |
| Auth + Firestore + Storage + Functions placeholder | All four; pre-positions P2 work but adds Node toolchain to P1. | |
| Skip emulator entirely | Mocks only; doesn't satisfy CI-06. | |

**User's choice:** Auth + Firestore + Storage only.

### Test directory layout

| Option | Description | Selected |
|--------|-------------|----------|
| Mirror lib/ structure | test/presentation/, test/application/, test/data/, test/core/, integration_test/, plus _support/ and _helpers/. | ✓ |
| Flat by type | test/unit/, test/widget/, test/golden/, integration_test/. | |
| Mirror only by layer, not file | test/presentation/, test/application/, test/data/; freeform file names. | |

**User's choice:** Mirror lib/ structure.

### Golden tests in P1

| Option | Description | Selected |
|--------|-------------|----------|
| Defer goldens to Phase 7 | Install golden_toolkit (CI-07 requires) but write none. | ✓ |
| Write goldens for theme + 3-5 stable widgets in P1 | Lock down theme regressions for P2-P6. May need rewrite in P7. | |

**User's choice:** Defer goldens to P7.

### GitHub Actions CI gates (CI-01, CI-02)

| Option | Description | Selected |
|--------|-------------|----------|
| analyze (errors+warnings) + test + coverage upload | --fatal-warnings (not --fatal-infos); test --coverage; lcov.info artifact; no coverage threshold. | ✓ |
| Same + custom_lint check | Adds 'dart run custom_lint' to the gate. (Effectively folded into the chosen option via D-13.) | |
| Strict --fatal-infos | Would require fixing all 167 lints in P1; out of scope per ROADMAP. | |

**User's choice:** analyze (errors+warnings only) + test + coverage upload. Note: D-13 in CONTEXT.md also includes the `dart run custom_lint` gate based on the QUAL-04 decision in the Codegen+DI area — both checks land in the same CI workflow.

---

## Refactor PR sequencing

### How is Phase 1 sequenced into PRs?

| Option | Description | Selected |
|--------|-------------|----------|
| 3 grouped PRs | PR-1 refactor+extract, PR-2 repos+lint+cleanup, PR-3 CI+tests+iOS identity. Balanced. | ✓ |
| 6 sequential PRs | Max review hygiene; solo-dev overhead. | |
| 1 atomic PR | Smaller process overhead; hard to review, impossible to bisect. | |

**User's choice:** 3 grouped PRs.

### iOS identity flip ordering inside PR-3

| Option | Description | Selected |
|--------|-------------|----------|
| Last step of PR-3, behind manual checklist | BACKEND_SETUP.md updated FIRST with Firebase Console + APNs steps; code changes follow. | ✓ |
| Separate pre-phase prep PR | Bundle ID flip in its own tiny PR before P1 starts. | |
| First step of PR-3 | Identity before tests; risk of stale simulator state during testing. | |

**User's choice:** Last step of PR-3 behind manual checklist.

### iOS toolchain confirmation ("ios 26 14-2")

| Option | Description | Selected |
|--------|-------------|----------|
| iOS 26 SDK + iOS 14.2 min deployment | Latest Xcode 26.x; deployment bumped to 14.2 (above the originally planned 14.0). | ✓ |
| iOS 26 only — keep 14.0 | Wider device support; original plan. | |
| Something else | Open clarification. | |

**User's choice:** iOS 26 SDK + iOS 14.2 minimum deployment target.

### Avatar upload path fix (ARCH-06)

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse uploads/{uid}/{ts}.jpg | Already-allowed path; no storage.rules change. Lazy backfill of old avatarUrl values. | ✓ |
| Add separate avatars/{uid}.jpg rule | New surface in storage.rules; more for rules-unit-testing in P4. | |
| Move to /users/{uid}/avatar.jpg | More structured; requires new rule. | |

**User's choice:** Reuse uploads/{uid}/{ts}.jpg.

---

## Claude's Discretion

- Internal file/rule naming for the project-local custom_lint package (e.g. `tool/lints/`, rule id `layered_imports`).
- Test factory naming under `test/_support/factories/` and helper naming under `test/_helpers/`.
- Branch + PR title style (solo dev — use conventional commits per existing git log).
- Whether `analysis_options.yaml` `analyzer.plugins` wiring is the standard `custom_lint` install or a custom variant.
- Exact import-statement style and ordering rules inside the layer-enforcement custom_lint rule.

## Deferred Ideas

- Riverpod 2 → 3 upgrade + `@riverpod` codegen migration → v1.1 milestone.
- `freezed` / `json_serializable` for `lib/data/models/` → revisit if hand-rolled mapping becomes painful.
- Full per-screen smoke widget tests + per-viewmodel happy/error path coverage → Phase 7 (polish).
- Golden tests → Phase 7 (after UI polish stabilises AppTheme + screens).
- `functions/` Node toolchain + Functions emulator wiring → Phase 2.
- Coverage thresholds → revisit at end of Phase 7.
- Sentry/Datadog and additional crash-reporting → out of scope (REQUIREMENTS.md).
