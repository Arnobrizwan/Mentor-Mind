---
phase: 01-foundation-refactor-ci-test-harness-ios-identity
plan: 05
type: execute
wave: 2
depends_on: ["01-04"]
files_modified:
  - lib/data/services/firebase_providers.dart
  - lib/data/repositories/users_repository.dart
  - lib/data/repositories/sessions_repository.dart
  - lib/data/repositories/materials_repository.dart
  - lib/data/repositories/notifications_repository.dart
  - lib/data/repositories/rewards_repository.dart
  - lib/data/repositories/subscriptions_repository.dart
  - lib/data/repositories/auth_repository.dart
  - lib/data/repositories/storage_repository.dart
  - lib/application/viewmodels/dashboard/dashboard_viewmodel.dart
  - lib/application/viewmodels/tutor/chat_viewmodel.dart
  - lib/application/viewmodels/notifications/notifications_viewmodel.dart
  - lib/application/viewmodels/profile/profile_viewmodel.dart
  - lib/application/viewmodels/rewards/rewards_viewmodel.dart
  - lib/application/viewmodels/rewards/gamification_viewmodel.dart
  - lib/application/viewmodels/materials/materials_viewmodel.dart
  - lib/application/viewmodels/search/search_viewmodel.dart
  - lib/application/viewmodels/auth/auth_viewmodel.dart
autonomous: true
requirements: [ARCH-03]
requirements_addressed: [ARCH-03]
tags: [repository_pattern, riverpod_providers, firebase_seams, layered_architecture, t_1_layer]

must_haves:
  truths:
    - "D-01: Repositories are organised per-collection (not per-feature) — 8 repos under `lib/data/repositories/` (users, sessions, materials, notifications, rewards, subscriptions[stub], auth, storage)"
    - "D-02: Repositories return decoded domain models (e.g. `Stream<DashboardUser>`), NEVER raw `QuerySnapshot` / `DocumentSnapshot` — cursor-pagination input params and batch handles are the only documented exceptions"
    - "D-04: Firebase SDK singletons are exposed as Riverpod providers (`firestoreProvider`, `firebaseAuthProvider`, `firebaseStorageProvider`) so tests can override them via `ProviderScope.overrides`; no `get_it`, no `injectable`"
    - "No file under `lib/application/viewmodels/**` imports `package:cloud_firestore`, `package:firebase_auth`, or `package:firebase_storage` directly"
    - "Every Firestore/Auth/Storage call previously inside a viewmodel is now mediated by a `*Repository` class under `lib/data/repositories/`"
    - "`dart run custom_lint` reports zero `layered_imports` violations after this plan (the Plan 03 baseline goes to zero per D-08's layer enforcement)"
  artifacts:
    - path: "lib/data/services/firebase_providers.dart"
      provides: "Riverpod-wrapped Firebase SDK singletons (the test override seam)"
      contains: "firestoreProvider|firebaseAuthProvider|firebaseStorageProvider"
    - path: "lib/data/repositories/users_repository.dart"
      provides: "/users/{uid} + /users/{uid}/usage/{date} reads, writes, batch helper"
      contains: "class UsersRepository"
    - path: "lib/data/repositories/rewards_repository.dart"
      provides: "/rewards/{uid} stream + awardPoints/addBadge/appendLedgerEntry"
      contains: "class RewardsRepository"
    - path: "lib/data/repositories/auth_repository.dart"
      provides: "FirebaseAuth wrapper for email + Google sign-in, password reset, currentUser stream"
      contains: "class AuthRepository"
    - path: "lib/data/repositories/storage_repository.dart"
      provides: "FirebaseStorage upload/delete helpers for image attachments + avatars"
      contains: "class StorageRepository"
  key_links:
    - from: "lib/application/viewmodels/dashboard/dashboard_viewmodel.dart"
      to: "lib/data/repositories/users_repository.dart"
      via: "ref.read(usersRepositoryProvider)"
      pattern: "usersRepositoryProvider"
    - from: "lib/data/repositories/users_repository.dart"
      to: "lib/data/services/firebase_providers.dart"
      via: "ref.read(firestoreProvider)"
      pattern: "firestoreProvider"
---

<objective>
ARCH-03 closure: Build the repository layer per D-01 (per-collection, 6+ repos) and D-02 (decoded domain models, never raw snapshots) and D-04 (Riverpod providers for SDK seams). Replace every direct `FirebaseFirestore.instance` / `FirebaseAuth.instance` / `FirebaseStorage.instance` call in every viewmodel with a `ref.read(<repo>Provider)` call. Drive the `layered_imports` violation count (Plan 03 baseline) to zero.

Purpose: This is the structural fix for the codebase's most pervasive anti-pattern (ARCHITECTURE.md Anti-pattern #3: "Direct Firebase singleton access from ViewModels"). Without this layer, every viewmodel is non-unit-testable without a real Firebase project. With it, every viewmodel is a pure consumer of injected dependencies that `ProviderScope.overrides` can swap for `FakeFirebaseFirestore` / `MockFirebaseAuth` in tests.

Output: 7 new files under `lib/data/repositories/` (users, sessions, materials, notifications, rewards, subscriptions[stub], auth, storage — 8 total including auth and storage), 1 new file under `lib/data/services/` (firebase_providers.dart), 9 viewmodel files refactored to consume repository providers, `dart run custom_lint` green, `flutter analyze --fatal-warnings` green.
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
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-PATTERNS.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md
@.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-04-model-extraction-PLAN.md
@CLAUDE.md
@firestore.rules
@storage.rules
@lib/application/viewmodels/dashboard/dashboard_viewmodel.dart
@lib/application/viewmodels/auth/auth_viewmodel.dart
@lib/application/viewmodels/profile/profile_viewmodel.dart
@lib/application/viewmodels/tutor/chat_viewmodel.dart
@lib/application/viewmodels/materials/materials_viewmodel.dart
@lib/application/viewmodels/notifications/notifications_viewmodel.dart
@lib/application/viewmodels/rewards/rewards_viewmodel.dart
@lib/application/viewmodels/rewards/gamification_viewmodel.dart
@lib/application/viewmodels/search/search_viewmodel.dart

<interfaces>
<!-- Repository surface derived from PATTERNS.md § 3 lines 262-501 (per-collection method signatures) -->
<!-- D-01: 6 explicit repos + scaffold subscriptions stub; auth + storage are added because auth_viewmodel
     and profile_viewmodel call FirebaseAuth/Storage directly and need their own seam (CONTEXT.md D-04). -->

Firebase SDK seams (lib/data/services/firebase_providers.dart) — PATTERNS.md lines 264-287:

  final firestoreProvider       = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
  final firebaseAuthProvider    = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
  final firebaseStorageProvider = Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);

Repository method signatures (derived from real call sites — PATTERNS.md § 3):

  UsersRepository (lib/data/repositories/users_repository.dart):
    Stream<DashboardUser> watchDashboardUser(String uid, String? authDisplayName);
    Stream<ProfileUser>   watchProfileUser(String uid);
    Future<DashboardUser?> getDashboardUser(String uid);
    Future<Map<String, dynamic>?> getUsageDoc(String uid, String dateKey);
    Future<void> setUsageDoc(String uid, String dateKey, Map<String, dynamic> data);
    Future<void> updateUserFields(String uid, Map<String, dynamic> fields);
    WriteBatch startBatch();   // delegates to FirebaseFirestore.instance.batch() — used by profile deletion path
    Provider: usersRepositoryProvider

  SessionsRepository (lib/data/repositories/sessions_repository.dart):
    Stream<List<SessionItem>> watchRecentSessions(String uid, {int limit = 5});
    Future<List<SessionItem>>  searchSessions(String uid, {int limit = 20});
    Future<String> saveSession(String uid, Map<String, dynamic> data);
    Future<void>   appendFeedback(String sessionId, Map<String, dynamic> feedback);  // /sessions/{sid}/feedback
    Provider: sessionsRepositoryProvider

  MaterialsRepository (lib/data/repositories/materials_repository.dart):
    Stream<List<LearningMaterial>> streamMaterials({String? subject, String? level, MaterialType? type, DocumentSnapshot? startAfter, int limit = 20});
    Stream<List<MaterialItem>>     streamDashboardMaterials({int limit = 4});  // lightweight projection for dashboard
    Future<void> incrementViewCount(String materialId);
    Provider: materialsRepositoryProvider

  NotificationsRepository (lib/data/repositories/notifications_repository.dart):
    Stream<List<AppNotification>> watchNotifications(String role, {int limit = 50});
    Future<void> markRead(String notificationId);
    Provider: notificationsRepositoryProvider

  RewardsRepository (lib/data/repositories/rewards_repository.dart):
    Stream<RewardsDoc> watchRewards(String uid);
    Future<void> awardPoints(String uid, String action, int delta);     // merge write to /rewards/{uid}
    Future<void> addBadge(String uid, String badgeId);                  // arrayUnion on /rewards/{uid}.badges
    Future<void> appendLedgerEntry(String uid, Map<String, dynamic> entry); // STUB METHOD — /rewards/{uid}/ledger lands in Phase 4
    Provider: rewardsRepositoryProvider

  SubscriptionsRepository (lib/data/repositories/subscriptions_repository.dart) — STUB ONLY, D-01:
    Future<String?> getSubscriptionType(String uid);   // returns 'free' literally until Phase 5 populates
    Future<bool>    isSubscriptionActive(String uid);  // returns false until Phase 5
    Provider: subscriptionsRepositoryProvider

  AuthRepository (lib/data/repositories/auth_repository.dart) — NEW, not in PATTERNS.md but required by
    auth_viewmodel.dart's heavy FirebaseAuth surface. Mirrors auth_viewmodel.dart's current call set:
    Stream<User?> authStateChanges();
    User? get currentUser;
    Future<UserCredential> signInWithEmail(String email, String password);
    Future<UserCredential> registerWithEmail(String email, String password);
    Future<UserCredential> signInWithGoogle();   // wraps google_sign_in + FirebaseAuth.signInWithCredential
    Future<void> signOut();                       // both Firebase + Google
    Future<void> sendPasswordReset(String email);
    Future<void> sendEmailVerification();
    Future<void> reload();
    Future<void> deleteAccount();                 // FirebaseAuth.currentUser.delete()
    Future<UserCredential> reauthenticateWithPassword(String password);
    Provider: authRepositoryProvider

  StorageRepository (lib/data/repositories/storage_repository.dart) — NEW for the same reason:
    Future<String> uploadImage({required String uid, required File file, required String suffix, String contentType = 'image/jpeg'});
    // returns download URL; path is uploads/{uid}/{ts}_{suffix} — used for chat image attachments AND avatars
    Future<void>   deleteByPath(String fullPath);   // best-effort, swallow not-found
    Provider: storageRepositoryProvider

Test override pattern (PATTERNS.md lines 405-417 — used in Plan 08 anchor tests):
  ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
      // repositories are reconstructed from these overrides automatically because they
      // read firestoreProvider / firebaseAuthProvider in their provider definition
    ],
    child: ...
  );

ViewModel refactor pattern (PATTERNS.md lines 419-442):
  - Replace `final FirebaseFirestore _firestore = FirebaseFirestore.instance;` field with a constructor
    parameter `final UsersRepository _usersRepo;`.
  - Constructor takes repos as positional `required` params.
  - Provider definition at bottom of viewmodel file passes `ref.read(<repo>Provider)` for each param.
  - Preserve the "NOT autoDispose" comment exactly for splash/profile/rewards/gamification/notifications providers
    (CONTEXT.md § code_context line 173-174 — verbatim preservation).

Pitfalls (CONTEXT.md D-14, PATTERNS.md Anti-Patterns):
  - This plan IS the body-edit plan for the viewmodels. It IS allowed to change viewmodel bodies — but ONLY
    the Firebase singleton replacements + the comment-preserving conversions. NO `withOpacity` substitutions,
    NO state-shape changes, NO method renames. The diff per viewmodel = "remove _firestore/_auth/_storage field
    + replace inline SDK calls with _repo.method() calls + add repo constructor params + update provider
    definition at file bottom". Nothing else.
  - The "NOT autoDispose" comment block (e.g. splash_viewmodel.dart:113-117) MUST be preserved verbatim. The
    `if (!mounted) return;` guards MUST stay in place. The `unawaited(...)` calls MUST stay.
  - Repositories MUST return decoded models per D-02. A repository method that returns `Stream<DocumentSnapshot>`
    is a planning violation — change it to `Stream<DashboardUser>` (decode inside the repo using the model's
    `fromDoc` factory imported from `lib/data/models/`).
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Build firebase_providers seam + 8 repository files (decoded-model surface only)</name>
  <files>lib/data/services/firebase_providers.dart, lib/data/repositories/users_repository.dart, lib/data/repositories/sessions_repository.dart, lib/data/repositories/materials_repository.dart, lib/data/repositories/notifications_repository.dart, lib/data/repositories/rewards_repository.dart, lib/data/repositories/subscriptions_repository.dart, lib/data/repositories/auth_repository.dart, lib/data/repositories/storage_repository.dart</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-PATTERNS.md (§ 3 lines 262-501 — all six repository call-site excerpts + method signatures derived from real viewmodel code)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-RESEARCH.md (Pattern 3: Repository Provider Pattern lines 371-442 — canonical firebase_providers + repo provider + test override patterns)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-CONTEXT.md (D-01 — per-collection; D-02 — decoded models never raw snapshots; D-04 — SDK singletons as providers; § Claude's Discretion — test factory naming)
    - /Users/arnobrizwan/Mentor-Mind/firestore.rules (the security boundary the repos enforce on the client side; method surface must not invent paths the rules don't allow)
    - /Users/arnobrizwan/Mentor-Mind/storage.rules (storage layer rules — informs the StorageRepository.uploadImage path validation)
    - All 9 viewmodel files listed in `files_modified` — required to confirm each repo's method surface covers every call site
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-04-model-extraction-SUMMARY.md (the "viewmodel files still importing Firebase SDKs" list from Plan 04 Task 3 — this is the exact work-set for Task 2)
  </read_first>
  <action>
    Step A — Create `lib/data/services/firebase_providers.dart`:
      Three top-level `Provider<...>` declarations exactly per PATTERNS.md lines 274-287:
      - `firestoreProvider` returns `FirebaseFirestore.instance`
      - `firebaseAuthProvider` returns `FirebaseAuth.instance`
      - `firebaseStorageProvider` returns `FirebaseStorage.instance`
      Import `package:flutter_riverpod/flutter_riverpod.dart` (D-07 added it as a direct dep in Plan 01).
      DO NOT use `hooks_riverpod` — this is a non-widget file (CLAUDE.md § Riverpod Import Convention).

    Step B — Create the 8 repository files. For each:
      1. Class name + constructor that takes Firebase SDK instances as `required` named params (e.g. `UsersRepository({required FirebaseFirestore firestore, required FirebaseAuth auth}) : _firestore = firestore, _auth = auth;`).
      2. Public method surface EXACTLY as listed in `<interfaces>` above. For methods returning streams/futures of domain models, decode inside the repo by calling the model's `fromDoc` factory (imported from `lib/data/models/<entity>.dart`). NEVER return raw `QuerySnapshot` / `DocumentSnapshot` — that violates D-02.
      3. At the bottom of the file, declare the Riverpod provider:
         `final <name>RepositoryProvider = Provider<<Name>Repository>((ref) => <Name>Repository(firestore: ref.read(firestoreProvider), auth: ref.read(firebaseAuthProvider)));`
         (only pass the SDK params the repo actually uses — e.g. `MaterialsRepository` likely only needs `firestore`; `StorageRepository` only needs `storage`).

    Step C — Per-repo specifics:

      `users_repository.dart`:
        - watchDashboardUser: pipes `/users/{uid}.snapshots()` through `DashboardUser.fromDoc(uid, data, authDisplayName)`. The `authDisplayName` parameter is the caller's `_auth.currentUser?.displayName` value, passed in from the viewmodel; the repo does NOT read FirebaseAuth itself (single-responsibility — auth lookup belongs in AuthRepository).
        - watchProfileUser: pipes `/users/{uid}.snapshots()` through `ProfileUser.fromDoc(...)`.
        - getUsageDoc / setUsageDoc: `/users/{uid}/usage/{dateKey}` document ops.
        - updateUserFields: `update(...)`.
        - startBatch: returns `_firestore.batch()`. Used by profile_viewmodel's account-deletion code path.
        - DOES NOT include `incrementPoints` — that lives in RewardsRepository (per /rewards/{uid} doc, not /users).

      `sessions_repository.dart`:
        - watchRecentSessions: `_firestore.collection('sessions').where('userId', isEqualTo: uid).orderBy('updatedAt', descending: true).limit(limit).snapshots().map((snap) => snap.docs.map(SessionItem.fromDoc).toList(growable: false))`.
        - searchSessions: same query but `.get()` not `.snapshots()`.
        - saveSession: `_firestore.collection('sessions').add(data)` returns doc id. NOTE: the actual writer (chat_viewmodel) uses `add(...)` for new sessions and `set(..., merge: true)` for updates — make this a single method taking optional `sessionId` param, OR split into `createSession` + `updateSession`. Mirror what the current chat_viewmodel does — read its session-write paths first.
        - appendFeedback: writes to `/sessions/{sid}/feedback` subcollection (used by chat_viewmodel's "rate this answer" flow if present; if absent in current code, OMIT this method — only build what's called).

      `materials_repository.dart`:
        - streamMaterials returns `Stream<List<LearningMaterial>>` (rich projection used by MaterialsScreen).
        - streamDashboardMaterials returns `Stream<List<MaterialItem>>` (lightweight projection used by DashboardScreen).
        - Both query `/materials` with `.orderBy('createdAt', descending: true)`.
        - incrementViewCount: `_firestore.collection('materials').doc(materialId).update({'views': FieldValue.increment(1)})`.
        - For the cursor pagination param `DocumentSnapshot? startAfter`: this is the ONE place we MAY leak `DocumentSnapshot` (it's a Firestore-specific cursor, not a domain concept). Acceptable — D-02 says "return decoded models", not "no Firestore types in inputs". Document this exception in the method's doc comment.

      `notifications_repository.dart`:
        - watchNotifications: queries `/notifications` with `where('recipientRole', whereIn: [role, 'all']).orderBy('timestamp', descending: true).limit(limit)`, decodes via `AppNotification.fromDoc`.
        - markRead: `_firestore.collection('notifications').doc(notificationId).update({'read': true})`.

      `rewards_repository.dart`:
        - watchRewards: `_firestore.collection('rewards').doc(uid).snapshots().map((doc) => RewardsDoc.fromDoc(doc.data() ?? {}, doc.id))`. If `RewardsDoc.fromDoc` is not present in the extracted model (PATTERNS.md doesn't show it), add a minimal `fromMap` factory inside `RewardsDoc` in `lib/data/models/rewards_doc.dart` — this is a model-layer edit; record it in Plan 04 SUMMARY's "files touched in Task 1 but back-ported to Plan 04 model files" if necessary.
        - awardPoints: `_firestore.collection('rewards').doc(uid).set({'points': FieldValue.increment(delta), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true))`.
        - addBadge: `_firestore.collection('rewards').doc(uid).set({'badges': FieldValue.arrayUnion([badgeId]), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true))`.
        - appendLedgerEntry: `_firestore.collection('rewards').doc(uid).collection('ledger').add(entry)`. STUB — flag with a doc comment "Phase 4 will replace client-side writes here with the `onSessionWrite` trigger; in Phase 1 this method exists so the repo surface is stable, but the client SHOULD NOT call it (call sites are TBD in Phase 4)." DO NOT migrate existing client-side `_firestore.collection('rewards')...` writes through this stub; instead, this Task 1 only DEFINES the method. Task 2 migrates the existing call sites to `awardPoints`/`addBadge`, NOT `appendLedgerEntry`.

      `subscriptions_repository.dart` — STUB per D-01:
        - getSubscriptionType: returns `Future.value('free')` literally (no Firestore call yet).
        - isSubscriptionActive: returns `Future.value(false)` literally.
        - Doc comment: `/// STUB — Phase 5 populates /subscriptions/{uid} and replaces these literal returns with real reads.`

      `auth_repository.dart`:
        - Wrap every `FirebaseAuth` call currently in `auth_viewmodel.dart`. Read that viewmodel first to enumerate every call site — at minimum: `signInWithEmailAndPassword`, `createUserWithEmailAndPassword`, `signOut`, `sendPasswordResetEmail`, `currentUser`, `authStateChanges`, `User.sendEmailVerification`, `User.reload`, `User.delete`, `User.reauthenticateWithCredential`, plus Google sign-in (uses both `google_sign_in.GoogleSignIn` AND `FirebaseAuth.signInWithCredential`).
        - The Google sign-in helper wraps `GoogleSignIn` + `FirebaseAuth.signInWithCredential(GoogleAuthProvider.credential(...))` inside one method. The repo OWNS the `GoogleSignIn` instance (not the viewmodel) so tests can mock it via constructor.
        - DOES NOT make the `mentor_minds/native_config` MethodChannel call — that stays in the viewmodel because it's a UI-driven probe (CONTEXT.md § code_context — `mentor_minds/native_config` MethodChannel is preserved verbatim through the bundle-id flip).

      `storage_repository.dart`:
        - uploadImage: takes `uid`, `file`, `suffix` (e.g. `'avatar.jpg'` or `'chat.jpg'`), builds path `uploads/${uid}/${DateTime.now().millisecondsSinceEpoch}_${suffix}` (matches storage.rules — see PITFALLS #7 / Plan 07 for the avatar fix), uploads with `putFile(file, SettableMetadata(contentType: contentType))`, returns `getDownloadURL()`.
        - deleteByPath: `_storage.ref(fullPath).delete()`, wrapped in try/catch returning void (best-effort).

    Step D — Sanity build:
      Run `flutter analyze --fatal-warnings` on just `lib/data/`. All 9 new files must compile. No `error -` or `warning -` lines.

    Commit each repo as its own commit OR one bulk commit "feat(data): scaffold 8 repositories + Firebase SDK providers (Phase 1 / ARCH-03)" — solo dev choice, but the commit message must reference ARCH-03.

    DO NOT touch viewmodels in this task. Task 2 handles all viewmodel edits.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f lib/data/services/firebase_providers.dart &amp;&amp; for r in users sessions materials notifications rewards subscriptions auth storage; do test -f "lib/data/repositories/${r}_repository.dart" || { echo "MISSING: ${r}_repository.dart"; exit 2; }; done</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -c 'final firestoreProvider\b\|final firebaseAuthProvider\b\|final firebaseStorageProvider\b' lib/data/services/firebase_providers.dart | xargs -I{} test {} -ge 3</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; for r in users sessions materials notifications rewards subscriptions auth storage; do grep -q "final ${r}RepositoryProvider\b" "lib/data/repositories/${r}_repository.dart" || { echo "PROVIDER MISSING in ${r}_repository.dart"; exit 3; }; done</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -RIn 'Stream<DocumentSnapshot\|Stream<QuerySnapshot\|Future<DocumentSnapshot\|Future<QuerySnapshot' lib/data/repositories/ 2>/dev/null</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --fatal-warnings lib/data/ 2>&amp;1 | tee /tmp/p1-05-t1-analyze.txt &amp;&amp; ! grep -qE '^\s*(error|warning) -' /tmp/p1-05-t1-analyze.txt</automated>
  </verify>
  <acceptance_criteria>
    - `lib/data/services/firebase_providers.dart` exists and declares exactly three SDK provider top-level finals.
    - 8 repository files exist under `lib/data/repositories/` (users, sessions, materials, notifications, rewards, subscriptions, auth, storage).
    - Each repository file declares its `<name>RepositoryProvider` at the bottom.
    - No repository method returns a raw `DocumentSnapshot` / `QuerySnapshot` / `Stream<DocumentSnapshot>` / `Stream<QuerySnapshot>` — D-02 enforced via grep (cursor-pagination input params using `DocumentSnapshot? startAfter` are allowed; outputs are not).
    - `flutter analyze --fatal-warnings lib/data/` exits 0 with no `error -` or `warning -` lines.
    - No file under `lib/data/repositories/` or `lib/data/services/` imports from `lib/presentation/` or `lib/application/` (will be enforced by Task 3's `dart run custom_lint`).
  </acceptance_criteria>
  <done>
    Repository layer + SDK seam are in place, returning decoded domain models, with Riverpod providers ready for viewmodels (Task 2) and test overrides (Plan 08). The layer is a clean graph leaf — no upward imports.
  </done>
</task>

<task type="auto">
  <name>Task 2: Refactor 9 viewmodels onto repository providers — drop direct Firebase imports</name>
  <files>lib/application/viewmodels/dashboard/dashboard_viewmodel.dart, lib/application/viewmodels/tutor/chat_viewmodel.dart, lib/application/viewmodels/notifications/notifications_viewmodel.dart, lib/application/viewmodels/profile/profile_viewmodel.dart, lib/application/viewmodels/rewards/rewards_viewmodel.dart, lib/application/viewmodels/rewards/gamification_viewmodel.dart, lib/application/viewmodels/materials/materials_viewmodel.dart, lib/application/viewmodels/search/search_viewmodel.dart, lib/application/viewmodels/auth/auth_viewmodel.dart</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-PATTERNS.md (§ 7 Viewmodel Pattern Reference lines 766-866 — the dashboard_viewmodel.dart pattern anchor: state class with copyWith(clear* = false), StateNotifier + provider declaration, `if (!mounted) return;`, NOT-autoDispose comment block at splash_viewmodel.dart:113-119)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-CONTEXT.md (§ code_context — "Provider exception list (NOT autoDispose): splashViewModelProvider, profileViewModelProvider, rewardsViewModelProvider, gamificationViewModelProvider, notificationsViewModelProvider — each documented with a comment explaining why disposal would race a pending await. Preserve these comments and the autoDispose status verbatim.")
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-04-model-extraction-SUMMARY.md (Task 3's `/tmp/p1-04-t3-vm-firebase-imports.txt` — the closed work-set of viewmodels that still directly import Firebase SDKs)
    - All 9 viewmodel files at their post-Plan-04 paths — required to see the exact current call sites to refactor
    - The 8 newly-created repository files from Task 1 — required to confirm method surface matches viewmodel needs
  </read_first>
  <action>
    For each viewmodel in `files_modified` (9 files total), perform the same mechanical refactor pattern:

    Step A — Add repository imports + remove SDK imports:
      Replace `import 'package:cloud_firestore/cloud_firestore.dart';` etc. with the matching repository imports, for example:
        `import 'package:mentor_minds/data/repositories/users_repository.dart';`
        `import 'package:mentor_minds/data/repositories/rewards_repository.dart';`
      Keep `import 'package:flutter_riverpod/flutter_riverpod.dart';` (required for `Ref`/`Provider`/`StateNotifierProvider`).
      `FieldValue` references inside the viewmodel become calls on the repo (`_rewardsRepo.awardPoints(...)` instead of `FieldValue.increment` inline); if any `FieldValue` use remains in the viewmodel, it's a missed call site — the repo should own it.

      `auth_viewmodel.dart` is the most invasive — also remove imports of `package:firebase_auth/firebase_auth.dart` and `package:google_sign_in/google_sign_in.dart`. The viewmodel keeps its import of `package:flutter/services.dart` for the MethodChannel (`mentor_minds/native_config`) — that channel is NOT moved to a repo.

    Step B — Replace SDK fields with repo fields:
      Old:
        `final FirebaseFirestore _firestore = FirebaseFirestore.instance;`
        `final FirebaseAuth _auth = FirebaseAuth.instance;`
      New:
        `final UsersRepository _usersRepo;`
        `final SessionsRepository _sessionsRepo;`
        `final AuthRepository _authRepo;`
        (etc., one final field per repo the viewmodel uses)
      Constructor: change from `DashboardViewModel() : super(DashboardState(...))` to `DashboardViewModel(this._usersRepo, this._sessionsRepo, this._materialsRepo, this._rewardsRepo, this._notificationsRepo, this._authRepo) : super(DashboardState(...))`.

      Preserve everything else verbatim:
        - `super(DashboardState(...))` initializer with `_nextMidnight(DateTime.now())` default — UNCHANGED.
        - `_init()` call in constructor body — UNCHANGED.
        - `StreamSubscription<...>` field declarations — UNCHANGED (only the generic type may change from `DocumentSnapshot<Map<String,dynamic>>` to `DashboardUser` since the stream is now decoded).
        - `if (!mounted) return;` guards after `await` — UNCHANGED.
        - `unawaited(...)` calls — UNCHANGED.
        - `@override void dispose() { _userSub?.cancel(); ... super.dispose(); }` — UNCHANGED.
        - All `state.copyWith(...)` calls — UNCHANGED.
        - State class definitions — UNCHANGED.
        - File-local enums (`MaterialType`, `MessageRole`, `AuthDestination` etc.) — UNCHANGED.

    Step C — Update Firestore/Auth/Storage call sites:
      `dashboard_viewmodel.dart` examples:
        Old (line ~390-416):
          `_userSub = _firestore.collection('users').doc(uid).snapshots().listen((doc) { final data = doc.data(); ... state = state.copyWith(user: DashboardUser.fromDoc(uid, data, authDisplayName)); });`
        New:
          `_userSub = _usersRepo.watchDashboardUser(uid, _authRepo.currentUser?.displayName).listen((user) { if (!mounted) return; state = state.copyWith(user: user); });`

      Old:
          `await _firestore.collection('rewards').doc(uid).set({'points': FieldValue.increment(delta), ...}, SetOptions(merge: true));`
        New:
          `await _rewardsRepo.awardPoints(uid, action, delta);`

      For account deletion in `profile_viewmodel.dart`:
        Old:
          `final batch = _firestore.batch(); batch.delete(_firestore.doc('users/$uid')); ...`
        New:
          `final batch = _usersRepo.startBatch(); batch.delete(/* still needs firestore.doc(...) - so users_repo.userDocRef(uid) helper exposed */); ...`
        Note: the `startBatch()` design leaks `WriteBatch` (a Firestore type) back to the viewmodel — this is intentional and documented in D-02's exception list (cursor pagination + batch handles are accepted leaks because they have no domain equivalent). If batch usage in profile_viewmodel touches more than the user doc, expose `userDocRef(uid)` / `usageDocRef(uid, date)` / `rewardsDocRef(uid)` getters on the repos that return `DocumentReference<Map<String, dynamic>>` for batch building — this is the ONLY place raw Firestore refs may surface in a viewmodel, and only for batch construction. Document each such getter with `/// Batch helper — returns the raw DocumentReference for use in WriteBatch ops only.`.

    Step D — Update provider declarations at the bottom of each viewmodel:
      Old (e.g. dashboard_viewmodel.dart):
        `final dashboardViewModelProvider = StateNotifierProvider.autoDispose<DashboardViewModel, DashboardState>((ref) => DashboardViewModel());`
      New:
        `final dashboardViewModelProvider = StateNotifierProvider.autoDispose<DashboardViewModel, DashboardState>((ref) => DashboardViewModel(ref.read(usersRepositoryProvider), ref.read(sessionsRepositoryProvider), ref.read(materialsRepositoryProvider), ref.read(rewardsRepositoryProvider), ref.read(notificationsRepositoryProvider), ref.read(authRepositoryProvider)));`

      For the 5 NOT-autoDispose providers (CONTEXT.md § code_context line 173-174):
        - `splashViewModelProvider`
        - `profileViewModelProvider`
        - `rewardsViewModelProvider`
        - `gamificationViewModelProvider`
        - `notificationsViewModelProvider`
      Preserve the documented `// Intentionally NOT autoDispose: ...` comment block VERBATIM. Only change the lambda body to pass `ref.read(...)` repo providers.

    Step E — Auth viewmodel specifics:
      `auth_viewmodel.dart` has the heaviest refactor surface. Specific call sites to redirect:
        - `_auth.signInWithEmailAndPassword(email: ..., password: ...)` → `_authRepo.signInWithEmail(email, password)`
        - `_auth.createUserWithEmailAndPassword(...)` → `_authRepo.registerWithEmail(...)`
        - `_auth.sendPasswordResetEmail(email: ...)` → `_authRepo.sendPasswordReset(email)`
        - `GoogleSignIn().signIn()` + `_auth.signInWithCredential(GoogleAuthProvider.credential(...))` → `_authRepo.signInWithGoogle()`
        - `_auth.signOut()` + `GoogleSignIn().signOut()` → `_authRepo.signOut()`
        - `_auth.currentUser?.sendEmailVerification()` → `_authRepo.sendEmailVerification()`
        - `_auth.currentUser?.reload()` → `_authRepo.reload()`
        - The Firestore writes that follow successful auth (writing the initial `/users/{uid}` doc on register, reading the doc to determine role for routing) → use `_usersRepo.updateUserFields` and `_usersRepo.getDashboardUser`.
      Keep the `MethodChannel('mentor_minds/native_config')` `googleSignInStatus` call inside the viewmodel — it's a Flutter platform-channel probe, not a Firebase concern.
      The `_mapLoginError` / `_mapRegisterError` / `_mapResetError` / `_mapVerificationError` switch-expressions still need access to `FirebaseAuthException` to switch on `.code` — either (a) the viewmodel catches `FirebaseAuthException` from the repo (the repo re-throws), or (b) the repo wraps it in a domain `AuthError` enum. Pick (a) for Phase 1 — it keeps the viewmodel's error-mapping logic identical. The viewmodel's `import` of `firebase_auth` is removed by replacing it with `import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;` so ONLY the exception class crosses the layer boundary. This is a documented exception to the no-direct-Firebase-imports rule: the `layered_imports` custom_lint rule from Plan 02 bans `package:firebase_auth` imports under `lib/presentation/` but NOT under `lib/application/` (CONTEXT.md D-08 specifies `lib/presentation/**` as the ban-source). Verify this matches Plan 02's predicate before relying on it; if the predicate also bans imports under `lib/application/**`, the `AuthError` enum approach (b) is required instead.
      RESOLUTION: Plan 02's predicate (CONTEXT.md D-08, PATTERNS.md line 553) bans Firebase SDK imports in `lib/presentation/**` ONLY. `lib/application/**` is exempt. So `show FirebaseAuthException;` is acceptable in `auth_viewmodel.dart`. Confirm against the actual predicate in `tool/lints/lib/src/layered_imports.dart` (Plan 02 Task 1) — if Plan 02 expanded the ban to `lib/application/**`, this viewmodel needs option (b).

    Step F — Run full analyze + lint sweep:
      `flutter analyze --fatal-warnings` → must exit 0.
      `dart run custom_lint` → must report ZERO `layered_imports` violations (the Plan 03 baseline goes to 0). This closes T-1-LAYER.

    Commit message: `refactor(viewmodels): consume repository providers; drop direct Firebase SDK imports (Phase 1 / ARCH-03 closure)`. Group commits per-viewmodel or single bulk — solo dev choice.

    Forbidden in this task (D-14 / CONTEXT.md § specifics):
      - No state-shape changes (no new fields on `DashboardState` etc.).
      - No method renames in viewmodels.
      - No comment cleanup.
      - No `withOpacity` → `withValues` substitution (Phase 7 territory).
      - No reordering of method definitions inside viewmodel classes.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -RIn -E "^import 'package:(cloud_firestore|firebase_auth|firebase_storage)/[^']*';\s*$" lib/application/viewmodels/ 2>/dev/null | grep -v 'show FirebaseAuthException'</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -RIn 'FirebaseFirestore\.instance\|FirebaseAuth\.instance\|FirebaseStorage\.instance' lib/application/viewmodels/ 2>/dev/null</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; for vm in dashboard chat notifications profile rewards gamification materials search auth; do f=$(find lib/application/viewmodels -name "${vm}_viewmodel.dart" 2>/dev/null | head -1); test -n "$f" || continue; grep -q 'RepositoryProvider\|_Repo\b' "$f" || { echo "NO REPO USAGE in $f"; exit 2; }; done</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; for p in splashViewModelProvider profileViewModelProvider rewardsViewModelProvider gamificationViewModelProvider notificationsViewModelProvider; do grep -B1 "^final ${p}" lib/application/viewmodels/**/*.dart 2>/dev/null | grep -q 'NOT autoDispose\|Intentionally NOT autoDispose' || { echo "MISSING autoDispose comment for $p"; exit 3; }; done</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; flutter analyze --fatal-warnings 2>&amp;1 | tee /tmp/p1-05-t2-analyze.txt &amp;&amp; ! grep -qE '^\s*(error|warning) -' /tmp/p1-05-t2-analyze.txt</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; dart run custom_lint 2>&amp;1 | tee /tmp/p1-05-t2-lint.log &amp;&amp; n=$(grep -c 'layered_imports' /tmp/p1-05-t2-lint.log || echo 0); echo "layered_imports violations: $n"; test "$n" -eq 0</automated>
  </verify>
  <acceptance_criteria>
    - No file under `lib/application/viewmodels/**` has a bare `import 'package:cloud_firestore/...'`, `import 'package:firebase_auth/...'`, or `import 'package:firebase_storage/...'` import line (the `show FirebaseAuthException` exception in `auth_viewmodel.dart` IS allowed — the regex check excludes it via `grep -v 'show FirebaseAuthException'`).
    - No file under `lib/application/viewmodels/**` references `FirebaseFirestore.instance`, `FirebaseAuth.instance`, or `FirebaseStorage.instance`.
    - Each of the 9 refactored viewmodels references at least one `RepositoryProvider` or repo field (`_Repo`).
    - All 5 NOT-autoDispose providers (`splash`, `profile`, `rewards`, `gamification`, `notifications`) still carry the `// Intentionally NOT autoDispose: ...` comment block (regex check finds the comment near each provider declaration).
    - `flutter analyze --fatal-warnings` exits 0 with no `error -` or `warning -` lines.
    - `dart run custom_lint` reports ZERO `layered_imports` violations (Plan 03 baseline → 0; T-1-LAYER closed).
  </acceptance_criteria>
  <done>
    All 9 viewmodels consume repository providers instead of Firebase SDK singletons. The `layered_imports` rule passes on the full tree. Tests in Plan 08 can override `firestoreProvider` / `firebaseAuthProvider` to inject `FakeFirebaseFirestore` / `MockFirebaseAuth` and the entire ViewModel surface becomes unit-testable. ARCH-03 is structurally closed.
  </done>
</task>

<task type="auto">
  <name>Task 3: Closure check — D-02 audit + layered_imports zero-violations + baseline doc</name>
  <files>(verification only — no edits)</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md (§ Per-Task Verification Map — row 05-repository-extraction; "Viewmodels depend on repository interfaces, not FirebaseFirestore.instance")
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-CONTEXT.md (D-02 — Repositories return decoded domain models)
    - /Users/arnobrizwan/Mentor-Mind/tool/lints/lib/src/layered_imports.dart (the rule code itself — confirm the predicate scope: `lib/presentation/**` only vs. `lib/application/**` also banned)
  </read_first>
  <action>
    Three invariant checks that prove ARCH-03 is closed and Plan 08 (test harness) can safely override the providers.

    Step A — D-02 decoded-model audit:
      `grep -RIn 'Stream<DocumentSnapshot\|Stream<QuerySnapshot\|Future<DocumentSnapshot\|Future<QuerySnapshot' lib/data/repositories/`
      Must return zero lines. If any repository method returns one of those raw types, D-02 is violated; revise that method to decode internally.

    Step B — `layered_imports` zero check (CI gate readiness):
      Run `dart run custom_lint` and confirm zero `layered_imports` lines in stdout. Compare against the Plan 03 baseline (recorded in 01-03-SUMMARY.md) — the delta should be `baseline → 0`, fully closing T-1-LAYER.

    Step C — Plan 02 lint predicate sanity:
      Read `tool/lints/lib/src/layered_imports.dart` (created by Plan 02 Task 1) and confirm:
      (1) the rule bans `package:cloud_firestore`/`package:firebase_auth`/`package:firebase_storage`/`package:firebase_messaging` imports in `lib/presentation/**`;
      (2) the rule bans `package:mentor_minds/presentation/...` imports in `lib/data/**`;
      (3) the rule does NOT yet ban Firebase imports in `lib/application/**` (this is the exemption auth_viewmodel.dart relies on for `show FirebaseAuthException`).
      If (3) does NOT hold (i.e. Plan 02 implemented the rule to also ban Firebase imports in `lib/application/**`), then Task 2's `show FirebaseAuthException` approach is invalid and the executor must (a) introduce a domain `AuthError` enum in `lib/data/models/auth_error.dart`, (b) map `FirebaseAuthException` → `AuthError` inside `AuthRepository`, (c) have `auth_viewmodel.dart` switch on `AuthError` instead. Treat this as a follow-up task within Plan 05 — DO NOT mark ARCH-03 as closed until the layered_imports rule passes regardless of the predicate's scope.

    Step D — Baseline doc for downstream plans:
      Record in SUMMARY.md:
        - Count of `lib/data/repositories/*.dart` files.
        - Count of methods on each repository (grep `^\s*(Future|Stream|void|String|bool|int)\b[^=;]*\(` per file).
        - Names of any methods that intentionally return Firestore-specific types (cursor `DocumentSnapshot`, batch helpers) and the documentation comment that explains why.
        - The exact `dart run custom_lint` zero-violations confirmation.

    Commit message for any final cleanup: `chore(arch): close ARCH-03 — zero layered_imports violations (Phase 1 closure check)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -RIn -E 'Stream<(Document|Query)Snapshot|Future<(Document|Query)Snapshot' lib/data/repositories/ 2>/dev/null</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; dart run custom_lint 2>&amp;1 | tee /tmp/p1-05-t3-lint.log &amp;&amp; n=$(grep -c 'layered_imports' /tmp/p1-05-t3-lint.log || echo 0); test "$n" -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q 'package:cloud_firestore\|package:firebase_auth\|package:firebase_storage\|package:firebase_messaging' tool/lints/lib/src/layered_imports.dart &amp;&amp; grep -q 'presentation' tool/lints/lib/src/layered_imports.dart  </verify>
  <acceptance_criteria>
    - `grep -RIn -E 'Stream<(Document|Query)Snapshot|Future<(Document|Query)Snapshot' lib/data/repositories/` returns zero lines (D-02 honored — every public method decodes to a domain model).
    - `dart run custom_lint` reports zero `layered_imports` violations (T-1-LAYER closed).
    - `tool/lints/lib/src/layered_imports.dart` contains the banned Firebase URI prefix list AND references `presentation` as the banned-source path; if it ALSO references `application` as a banned-source, Task 2's `show FirebaseAuthException` exemption is invalid and the AuthError-enum follow-up MUST be completed before this task signs off.
    - SUMMARY.md records repo file count, per-repo method count, the list of documented Firestore-type exceptions (cursor pagination + batch helpers), and the literal `dart run custom_lint` output proving zero violations.
  </acceptance_criteria>
  <done>
    ARCH-03 closed. The repository layer satisfies D-01 (per-collection), D-02 (decoded models), D-04 (Riverpod SDK providers), and the `layered_imports` rule passes on the full tree. Plan 08 (anchor tests) can override the SDK providers with `FakeFirebaseFirestore` / `MockFirebaseAuth` to unit-test any viewmodel. Plan 10 (CI workflow) can run `dart run custom_lint` as a green gate.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| viewmodel → repository | Application layer must NOT bypass the repo and reach for `FirebaseFirestore.instance` directly; the layered_imports rule + this plan's grep checks enforce |
| repository → Firebase SDK | Repository methods may use raw Firestore types internally but MUST return decoded domain models (D-02) — preventing the "leaky abstraction" anti-pattern where a query failure surfaces as a Firestore-typed exception in a screen widget |
| test boundary | `firestoreProvider` / `firebaseAuthProvider` / `firebaseStorageProvider` are the test override seams; tests in Plan 08 will substitute fakes here, not at the repository level |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-1-LAYER | Elevation of Privilege | Viewmodels bypassing repositories to call `FirebaseFirestore.instance` directly (allowing client-side queries that bypass repository-enforced query shape, e.g. omitting `where('userId', isEqualTo: uid)` and reading every session in the collection) | mitigate | Task 2 removes ALL `FirebaseFirestore.instance` / `FirebaseAuth.instance` / `FirebaseStorage.instance` references from viewmodels; Task 3 + Plan 02's `layered_imports` rule enforce zero violations going forward; Plan 10's CI workflow makes the rule a blocking gate |
| T-1-LEAK | Information Disclosure | A repository method returning a raw `QuerySnapshot` would let a viewmodel iterate `snap.docs` and access arbitrary fields not in the domain model — bypassing the model's `fromDoc` contract and potentially exposing fields like `email`/`phone` in UI surfaces that should not show them | mitigate | D-02 enforced via the grep check in Task 3 (no raw Firestore types in repo public API); the only documented exceptions are cursor pagination inputs and batch handles, both annotated with `///` doc comments explaining the leak |
| T-1-PROVIDER-RACE | Denial of Service | A test that overrides `firestoreProvider` after `usersRepositoryProvider` has been created could see the repo holding a stale reference to the un-overridden Firestore instance | accept | Riverpod evaluates `ref.read(firestoreProvider)` lazily inside `usersRepositoryProvider`'s factory; overrides established before the first `ref.read(usersRepositoryProvider)` propagate correctly. Plan 08's helper `pumpWithProviders(...)` will document this ordering. |
</threat_model>

<verification>
- `flutter analyze --fatal-warnings` exits 0 after Tasks 1, 2, and 3.
- `dart run custom_lint` reports zero `layered_imports` violations after Task 2 (T-1-LAYER closure).
- Zero viewmodel files under `lib/application/viewmodels/**` reference `FirebaseFirestore.instance`, `FirebaseAuth.instance`, or `FirebaseStorage.instance` directly.
- Zero repository public methods return raw Firestore snapshot types (D-02).
- All 5 NOT-autoDispose providers retain their documented "Intentionally NOT autoDispose" comment block.
- The 8 repository files declare their Riverpod providers and read Firebase SDK instances via `firestoreProvider`/`firebaseAuthProvider`/`firebaseStorageProvider`.
</verification>

<success_criteria>
- D-01 honored: 8 repos under `lib/data/repositories/` (users, sessions, materials, notifications, rewards, subscriptions-stub, auth, storage).
- D-02 honored: every public repo method returns a decoded domain model (with documented exceptions for cursor pagination + batch handles).
- D-04 honored: SDK singletons are exposed via `firestoreProvider`/`firebaseAuthProvider`/`firebaseStorageProvider`; tests can override.
- ARCH-03 closed: 9 viewmodels refactored onto repository providers; zero direct Firebase SDK instance access remains.
- T-1-LAYER closed: `dart run custom_lint` reports zero `layered_imports` violations.
</success_criteria>

<output>
Create `.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-05-repository-extraction-SUMMARY.md` when done. Record: the file listing for `lib/data/services/` and `lib/data/repositories/` with line counts, per-repo public method names + signatures, documented Firestore-type exceptions and their justification comments, per-viewmodel diff stats (lines added/removed), the literal `dart run custom_lint` zero-violations confirmation, and the literal output of the Plan 02 lint predicate sanity check (Task 3 Step C — confirming the rule's scope).
</output>
