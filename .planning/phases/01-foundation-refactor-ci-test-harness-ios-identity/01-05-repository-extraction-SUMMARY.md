---
phase: "01"
plan: "05"
subsystem: "data-layer"
tags: ["repository-pattern", "firestore", "refactor", "layered-imports", "arch-03"]
dependency_graph:
  requires: ["01-01", "01-02", "01-03", "01-04"]
  provides: ["repository-layer", "firebase-providers", "d-02-compliance"]
  affects: ["all-viewmodels", "notifications-screen"]
tech_stack:
  added:
    - "lib/data/repositories/* (8 repos: users, sessions, materials, notifications, rewards, subscriptions, auth, storage)"
    - "lib/data/services/firebase_providers.dart (SDK singleton providers)"
  patterns:
    - "Repository pattern: per-collection, injected via Riverpod providers"
    - "D-02 cursor-pagination exception: DocumentSnapshot as paginator input only"
    - "D-02 batch exception: WriteBatch/DocumentReference for atomic multi-doc writes"
    - "D-02 restricted imports: show FirebaseAuthException/FirebaseException only in viewmodels"
key_files:
  created:
    - "lib/data/services/firebase_providers.dart"
    - "lib/data/repositories/auth_repository.dart"
    - "lib/data/repositories/users_repository.dart"
    - "lib/data/repositories/sessions_repository.dart"
    - "lib/data/repositories/materials_repository.dart"
    - "lib/data/repositories/notifications_repository.dart"
    - "lib/data/repositories/rewards_repository.dart"
    - "lib/data/repositories/storage_repository.dart"
    - "lib/data/repositories/subscriptions_repository.dart"
  modified:
    - "lib/application/viewmodels/splash/splash_viewmodel.dart"
    - "lib/application/viewmodels/auth/auth_viewmodel.dart"
    - "lib/application/viewmodels/dashboard/dashboard_viewmodel.dart"
    - "lib/application/viewmodels/tutor/chat_viewmodel.dart"
    - "lib/application/viewmodels/profile/profile_viewmodel.dart"
    - "lib/application/viewmodels/rewards/rewards_viewmodel.dart"
    - "lib/application/viewmodels/rewards/gamification_viewmodel.dart"
    - "lib/application/viewmodels/materials/materials_viewmodel.dart"
    - "lib/application/viewmodels/search/search_viewmodel.dart"
    - "lib/application/viewmodels/notifications/notifications_viewmodel.dart"
    - "lib/presentation/screens/notifications/notifications_screen.dart"
decisions:
  - "DocumentSnapshot stored only in MaterialsViewModel as D-02 cursor exception (not surfaced to UI)"
  - "watchRewardsRaw returns Map<String,dynamic> with Timestamps already decoded to DateTime so RewardsViewModel never imports cloud_firestore"
  - "markAllAsReadForCurrentUser added to NotificationsViewModel so notifications_screen needs zero Firebase imports"
  - "SubscriptionsRepository is a stub returning 'free' until Phase 5"
metrics:
  duration: "~4 hours across 2 sessions"
  completed: "2026-05-17T14:20:33Z"
  tasks_completed: 3
  files_created: 9
  files_modified: 11
---

# Phase 01 Plan 05: Repository Extraction Summary

Extracted all Firebase SDK access into a typed repository layer under `lib/data/repositories/`. All 9 viewmodels now consume injected repository providers — zero direct `FirebaseFirestore.instance` / `FirebaseAuth.instance` / `FirebaseStorage.instance` calls remain in `lib/application/`. Closed ARCH-03: `layered_imports` violations driven from 2 to 0. `dart run custom_lint` reports "No issues found."

## Tasks Completed

| # | Task | Commit | Outcome |
|---|------|--------|---------|
| 1 | Build firebase_providers.dart + 8 repository files | 106fc7e | All 8 repos created, analyze clean |
| 2 | Refactor 9 viewmodels to repository layer | c0001e2 | Zero Firebase singletons in application/; ARCH-03 closed |
| 3 | Closure checks: D-02 audit, custom_lint, lint predicate | (Task 3) | 0 errors, 0 custom_lint violations, rule validated |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical methods] watchRewardsRaw, watchUserDocRaw, getLeaderboard added to repos**
- **Found during:** Task 2 (rewards_viewmodel refactor)
- **Issue:** `rewards_viewmodel.dart` needed raw map access to `/rewards/{uid}` with Timestamps decoded, a raw user doc stream for fallback points, and a multi-query leaderboard method
- **Fix:** Added `watchRewardsRaw()` to `RewardsRepository` (decodes Timestamps to DateTime in repo), `watchUserDocRaw()` to `UsersRepository`, and `getLeaderboard()` encapsulating the top-N + current-user-rank query
- **Files modified:** `lib/data/repositories/rewards_repository.dart`, `lib/data/repositories/users_repository.dart`

**2. [Rule 2 - Missing critical functionality] markAllAsReadForCurrentUser added to NotificationsViewModel**
- **Found during:** Task 2 (notifications_screen ARCH-03 fix)
- **Issue:** `notifications_screen.dart` called `FirebaseAuth.instance.currentUser?.uid` and `FirebaseFirestore.instance.collection('users').doc(uid).get()` in `_resolveRole()` to obtain uid+role for `markAllAsRead`. Removing these would break the Mark-all-read button.
- **Fix:** Added `markAllAsReadForCurrentUser()` to `NotificationsViewModel` that resolves uid from `_authRepo` and role from `_usersRepo.getUserDocRaw()` — screen now calls one method with no Firebase access
- **Files modified:** `lib/application/viewmodels/notifications/notifications_viewmodel.dart`, `lib/presentation/screens/notifications/notifications_screen.dart`

**3. [Rule 2 - Missing functionality] searchMaterialDocs enhanced with case-variant and subject-match support**
- **Found during:** Task 2 (search_viewmodel refactor)
- **Issue:** `MaterialsRepository.searchMaterialDocs` only ran a single title-prefix query. The original `SearchViewModel._searchMaterials` ran both original-case and title-case variants plus subject exact-match — necessary for search quality
- **Fix:** Enhanced `searchMaterialDocs(query, {knownSubjects})` to accept a `knownSubjects` list and run case-variant + subject queries, matching the original multi-query behavior
- **Files modified:** `lib/data/repositories/materials_repository.dart`

**4. [Rule 1 - Bug] Removed unused _usersRepo dependency from SearchViewModel**
- **Found during:** Task 2 (search_viewmodel analyze)
- **Issue:** Initial draft included `UsersRepository` dep that was unused (premium check moved to SubscriptionsRepository)
- **Fix:** Removed `_usersRepo` field and import

## D-02 Compliance Audit Results

| Check | Result |
|-------|--------|
| `FirebaseFirestore.instance` in `lib/application/` | 0 occurrences |
| `FirebaseAuth.instance` in `lib/application/` | 0 occurrences |
| `FirebaseStorage.instance` in `lib/application/` | 0 occurrences |
| `FieldValue` in `lib/application/` | 0 occurrences |
| `SetOptions` in `lib/application/` | 0 occurrences |
| `Timestamp.now()` / `Timestamp.fromDate()` in `lib/application/` | 0 occurrences |
| Firebase imports in `lib/presentation/` | 0 occurrences |
| `dart run custom_lint` violations | 0 |

### Documented D-02 Exceptions

- `lib/application/viewmodels/materials/materials_viewmodel.dart`: `import 'package:cloud_firestore/cloud_firestore.dart' show DocumentSnapshot;` — D-02 cursor-pagination exception; `DocumentSnapshot` is stored only in the viewmodel and passed back to `MaterialsRepository.getMaterials(startAfter:)` for Firestore cursor pagination. Never surfaced to the UI layer.
- `lib/application/viewmodels/auth/auth_viewmodel.dart`: `show FirebaseAuthException, FirebaseException, User` — error-code mapping and auth state typing require these types
- `lib/application/viewmodels/profile/profile_viewmodel.dart`: `show FirebaseAuthException, FirebaseException` — reauth error handling
- `lib/application/viewmodels/notifications/notifications_viewmodel.dart`: `show FirebaseException` — error handling in markAsRead/deleteNotification
- `lib/application/viewmodels/splash/splash_viewmodel.dart`: `show FirebaseException` — error handling in splash flow

## ARCH-03 Closure

- **Before:** 2 `layered_imports` violations in `lib/presentation/screens/notifications/notifications_screen.dart` (`firebase_auth`, `cloud_firestore`)
- **After:** 0 violations
- **Verification:** `dart run custom_lint` — "No issues found!"

## Known Stubs

| Stub | File | Reason |
|------|------|--------|
| `getSubscriptionType()` returns `'free'` | `lib/data/repositories/subscriptions_repository.dart` | Phase 5 will populate `/subscriptions/{uid}` with real data |
| `isSubscriptionActive()` returns `false` | `lib/data/repositories/subscriptions_repository.dart` | Phase 5 stub |
| `appendLedgerEntry()` writes to unused sub-collection | `lib/data/repositories/rewards_repository.dart` | Phase 4 will replace with Cloud Function trigger |

## Self-Check: PASSED

- [x] `lib/data/services/firebase_providers.dart` — exists
- [x] `lib/data/repositories/auth_repository.dart` — exists
- [x] `lib/data/repositories/users_repository.dart` — exists
- [x] `lib/data/repositories/sessions_repository.dart` — exists
- [x] `lib/data/repositories/materials_repository.dart` — exists
- [x] `lib/data/repositories/notifications_repository.dart` — exists
- [x] `lib/data/repositories/rewards_repository.dart` — exists
- [x] `lib/data/repositories/storage_repository.dart` — exists
- [x] `lib/data/repositories/subscriptions_repository.dart` — exists
- [x] Task 1 commit: `106fc7e`
- [x] Task 2 commit: `c0001e2`
- [x] `flutter analyze lib/` — 0 errors
- [x] `dart run custom_lint` — 0 violations
- [x] `lib/presentation/screens/notifications/notifications_screen.dart` — 0 Firebase imports
