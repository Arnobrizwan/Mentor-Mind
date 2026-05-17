# Phase 1: Foundation — Refactor, CI, Test Harness, iOS Identity - Pattern Map

**Mapped:** 2026-05-17
**Files analyzed:** 47 (22 moves + 20 model extractions + 6 repositories + new infrastructure + iOS edits)
**Analogs found:** 22 / 22 for moves; all model excerpts extracted directly; 0 greenfield analogs for CI / lint tool

---

## 1. Files to MOVE (22 `git mv` operations)

Each source path was confirmed to exist via `ls lib/features/**`.

### Screens (11 files)

| Source Path | Target Path | Exists |
|-------------|-------------|--------|
| `lib/features/auth/login_screen.dart` | `lib/presentation/screens/auth/login_screen.dart` | ✓ |
| `lib/features/auth/register_screen.dart` | `lib/presentation/screens/auth/register_screen.dart` | ✓ |
| `lib/features/dashboard/dashboard_screen.dart` | `lib/presentation/screens/dashboard/dashboard_screen.dart` | ✓ |
| `lib/features/materials/materials_screen.dart` | `lib/presentation/screens/materials/materials_screen.dart` | ✓ |
| `lib/features/notifications/notifications_screen.dart` | `lib/presentation/screens/notifications/notifications_screen.dart` | ✓ |
| `lib/features/onboarding/onboarding_screen.dart` | `lib/presentation/screens/onboarding/onboarding_screen.dart` | ✓ |
| `lib/features/profile/profile_screen.dart` | `lib/presentation/screens/profile/profile_screen.dart` | ✓ |
| `lib/features/rewards/rewards_screen.dart` | `lib/presentation/screens/rewards/rewards_screen.dart` | ✓ |
| `lib/features/search/search_screen.dart` | `lib/presentation/screens/search/search_screen.dart` | ✓ |
| `lib/features/splash/splash_screen.dart` | `lib/presentation/screens/splash/splash_screen.dart` | ✓ |
| `lib/features/tutor/tutor_screen.dart` | `lib/presentation/screens/tutor/tutor_screen.dart` | ✓ |

### ViewModels (13 files — two features have two each)

| Source Path | Target Path | Exists | Note |
|-------------|-------------|--------|------|
| `lib/features/auth/auth_viewmodel.dart` | `lib/application/viewmodels/auth/auth_viewmodel.dart` | ✓ | |
| `lib/features/dashboard/dashboard_viewmodel.dart` | `lib/application/viewmodels/dashboard/dashboard_viewmodel.dart` | ✓ | |
| `lib/features/materials/materials_viewmodel.dart` | `lib/application/viewmodels/materials/materials_viewmodel.dart` | ✓ | |
| `lib/features/notifications/notifications_viewmodel.dart` | `lib/application/viewmodels/notifications/notifications_viewmodel.dart` | ✓ | |
| `lib/features/onboarding/onboarding_viewmodel.dart` | `lib/application/viewmodels/onboarding/onboarding_viewmodel.dart` | ✓ | |
| `lib/features/profile/profile_viewmodel.dart` | `lib/application/viewmodels/profile/profile_viewmodel.dart` | ✓ | |
| `lib/features/rewards/rewards_viewmodel.dart` | `lib/application/viewmodels/rewards/rewards_viewmodel.dart` | ✓ | |
| `lib/features/rewards/gamification_viewmodel.dart` | `lib/application/viewmodels/rewards/gamification_viewmodel.dart` | ✓ | second rewards VM |
| `lib/features/search/search_viewmodel.dart` | `lib/application/viewmodels/search/search_viewmodel.dart` | ✓ | |
| `lib/features/splash/splash_viewmodel.dart` | `lib/application/viewmodels/splash/splash_viewmodel.dart` | ✓ | |
| `lib/features/tutor/chat_viewmodel.dart` | `lib/application/viewmodels/tutor/chat_viewmodel.dart` | ✓ | second tutor VM |

### Service (1 file — NOT moved in Phase 1; survives until Phase 3)

| Source Path | Note |
|-------------|------|
| `lib/core/services/gemini_service.dart` | Stays in `lib/core/services/`. Phase 3 deletes it when Cloud Function proxy lands. Do NOT move. |

### Critical import chain to update after `git mv`

`lib/core/routes/app_router.dart` imports all 11 screens. It is the single largest import-update job — its entire import block changes. Relative depth from `lib/presentation/screens/<feature>/` to `lib/core/` is `../../../core/` (was `../../core/` from `lib/features/<feature>/`).

---

## 2. Files to CREATE — Inline Model Extractions

All models move to `lib/data/models/` verbatim. No logic changes — only the class definition moves out, an `import` is added back to the viewmodel.

### Clean extractions (no conflict)

| Class | Source File | Source Lines | Target File |
|-------|------------|-------------|-------------|
| `DashboardUser` | `lib/features/dashboard/dashboard_viewmodel.dart` | 42–89 | `lib/data/models/dashboard_user.dart` |
| `RewardsSnapshot` | `lib/features/dashboard/dashboard_viewmodel.dart` | 91–95 | `lib/data/models/rewards_snapshot.dart` |
| `SubjectProgress` | `lib/features/dashboard/dashboard_viewmodel.dart` | 97–106 | `lib/data/models/subject_progress.dart` |
| `SessionItem` | `lib/features/dashboard/dashboard_viewmodel.dart` | 108–141 | `lib/data/models/session_item.dart` |
| `BadgeItem` | `lib/features/dashboard/dashboard_viewmodel.dart` | 172–183 | `lib/data/models/badge_item.dart` |
| `ChatMessage` | `lib/features/tutor/chat_viewmodel.dart` | 20–59 | `lib/data/models/chat_message.dart` |
| `AppNotification` | `lib/features/notifications/notifications_viewmodel.dart` | 32–81 | `lib/data/models/app_notification.dart` |
| `ProfileUser` | `lib/features/profile/profile_viewmodel.dart` | 17–86 | `lib/data/models/profile_user.dart` |
| `ProfileStats` | `lib/features/profile/profile_viewmodel.dart` | 88–99 | `lib/data/models/profile_stats.dart` |
| `RewardsDoc` | `lib/features/rewards/gamification_viewmodel.dart` | 111–125 | `lib/data/models/rewards_doc.dart` |
| `PointsHistory` | `lib/features/rewards/gamification_viewmodel.dart` | 127–147 | `lib/data/models/points_history.dart` |
| `Milestone` | `lib/features/rewards/rewards_viewmodel.dart` | 104–120 | `lib/data/models/milestone.dart` |
| `HistoryEntry` | `lib/features/rewards/rewards_viewmodel.dart` | 126–149 | `lib/data/models/history_entry.dart` |
| `EarnedBadge` | `lib/features/rewards/rewards_viewmodel.dart` | 170–179 | `lib/data/models/earned_badge.dart` |
| `LockedBadge` | `lib/features/rewards/rewards_viewmodel.dart` | 181–185 | `lib/data/models/locked_badge.dart` |
| `MaterialSearchHit` | `lib/features/search/search_viewmodel.dart` | 16–45 | `lib/data/models/material_search_hit.dart` |
| `SessionSearchHit` | `lib/features/search/search_viewmodel.dart` | 47–63 | `lib/data/models/session_search_hit.dart` |

### Key pattern excerpt — `DashboardUser.fromDoc` (dashboard_viewmodel.dart:63–88)

```dart
factory DashboardUser.fromDoc(
  String uid,
  Map<String, dynamic> data,
  String? authDisplayName,
) {
  final rawName = (data['name'] as String?)?.trim();
  final name = (rawName?.isNotEmpty ?? false)
      ? rawName!
      : (authDisplayName?.trim().isNotEmpty == true
          ? authDisplayName!.trim()
          : 'Learner');
  return DashboardUser(
    uid: uid,
    name: name,
    firstName: name.split(RegExp(r'\s+')).first,
    role: (data['role'] as String?)?.trim() ?? 'student',
    points: (data['points'] as num?)?.toInt() ?? 0,
    subjects: ((data['subjects'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(growable: false),
    level: (data['level'] as String?) ?? '',
    badgeIds: ((data['badges'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(growable: false),
  );
}
```

### Key pattern excerpt — `AppNotification.fromDoc` (notifications_viewmodel.dart:62–80)

```dart
factory AppNotification.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  final ts = data['timestamp'] ?? data['createdAt'];
  return AppNotification(
    id: doc.id,
    title: (data['title'] as String?)?.trim() ?? 'Notification',
    body: ((data['body'] as String?) ?? (data['message'] as String?) ?? '').trim(),
    type: _normalizeType(data),
    recipientRole: (data['recipientRole'] as String?)?.trim() ?? 'all',
    deeplink: (data['deeplink'] as String?)?.trim().isEmpty == true
        ? null
        : (data['deeplink'] as String?),
    timestamp: ts is Timestamp ? ts.toDate() : null,
    read: (data['read'] as bool?) ?? false,
  );
}
```

---

## DUPLICATE MODEL FLAG — Resolve Before Extraction

### `BadgeInfo` — defined in TWO files with DIFFERENT catalog entries

**Definition A — `lib/features/rewards/gamification_viewmodel.dart` lines 31–46:**
```dart
class BadgeInfo {
  final String id;
  final String emoji;
  final String name;
  final String description;
  final String unlockHint;
  final int? target;
  const BadgeInfo({
    required this.id,
    required this.emoji,
    required this.name,
    required this.description,
    required this.unlockHint,
    this.target,
  });
}
// Catalog: 7 badges: 'first_step', 'curious_learner', 'dedicated_learner',
//          'week_warrior', 'month_master', 'diagram_detective', 'subject_expert'
```

**Definition B — `lib/features/rewards/rewards_viewmodel.dart` lines 14–29:**
```dart
class BadgeInfo {
  final String id;
  final String emoji;
  final String name;
  final String description;
  final String unlockHint;
  final int? target;
  const BadgeInfo({
    required this.id,
    required this.emoji,
    required this.name,
    required this.description,
    required this.unlockHint,
    this.target,
  });
}
// Catalog: 8 badges: 'first_login', 'streak_3', 'streak_7', 'streak_30',
//          'ai_questions_10', 'ai_questions_50', 'materials_viewed_10', 'points_100'
```

**Verdict:** Class signatures are **identical** — same 6 fields, same types, same `const` constructor. The divergence is in the badge catalog constants (`_catalog` vs `_allBadges`), not the class itself. Extract one canonical `BadgeInfo` to `lib/data/models/badge_info.dart`. The two badge catalog constants (`_catalog`, `_allBadges`) stay private inside their respective viewmodel files — they are file-local constants, not part of the model class. Both viewmodels import from `badge_info.dart`.

### `LeaderboardEntry` — defined in TWO files with ONE FIELD DIFFERENCE

**Definition A — `lib/features/rewards/gamification_viewmodel.dart` lines 149–164:**
```dart
class LeaderboardEntry {
  final String uid;
  final String name;
  final String? avatarUrl;
  final int points;
  final int rank;
  final bool isCurrentUser;
  // NO subject field
}
```

**Definition B — `lib/features/rewards/rewards_viewmodel.dart` lines 151–168:**
```dart
class LeaderboardEntry {
  final String uid;
  final String name;
  final String? avatarUrl;
  final int points;
  final String? subject;   // <-- EXTRA FIELD (top subject tag)
  final int rank;
  final bool isCurrentUser;
}
```

**Verdict:** `rewards_viewmodel.dart` definition is the superset. Extract the 7-field version (with `subject`) to `lib/data/models/leaderboard_entry.dart`. Update `gamification_viewmodel.dart` to import the same model — the `subject` field will simply be unused (null) in that file's context until unification. Target: `lib/data/models/leaderboard_entry.dart`.

---

## `MaterialItem` vs `LearningMaterial` Naming Conflict

**`MaterialItem` — `lib/features/dashboard/dashboard_viewmodel.dart` lines 143–170:**
```dart
class MaterialItem {
  final String id;
  final String title;
  final String level;
  final String subject;
  final List<Color> gradient;
  // fromDoc uses QueryDocumentSnapshot
  // No fileUrl, type, views, thumbnailUrl, uploadedBy, createdAt
}
// Purpose: lightweight dashboard card model (display only)
```

**`LearningMaterial` — `lib/features/materials/materials_viewmodel.dart` lines 94–166:**
```dart
class LearningMaterial {
  final String materialId;  // note: 'materialId' not 'id'
  final String title;
  final String subject;
  final String level;
  final String fileUrl;     // extra
  final MaterialType type;  // extra
  final String? thumbnailUrl; // extra
  final String? uploadedBy;   // extra
  final int views;           // extra
  final DateTime createdAt;  // extra
  // fromDoc uses QueryDocumentSnapshot — same Firestore source
}
// Purpose: full materials-browse model with file URL, type, views
```

**Verdict:** These are NOT duplicates — they are view-tailored projections of the same `/materials` collection. `LearningMaterial` is the rich version used for browsing; `MaterialItem` is a lightweight display-only version used on the dashboard. Extract BOTH verbatim:
- `lib/data/models/material_item.dart` — from `dashboard_viewmodel.dart:143`
- `lib/data/models/learning_material.dart` — from `materials_viewmodel.dart:94`

`MaterialSearchHit.fromLearningMaterial(m)` in `search_viewmodel.dart:33` cross-references `LearningMaterial` — this import must be updated to the new model path after extraction.

---

## 3. Files to CREATE — Repositories

All repository files go under `lib/data/repositories/`. Each exposes a Riverpod `Provider<XRepository>` at the bottom of the file. SDK singletons come in via `firestoreProvider` / `firebaseAuthProvider` / `firebaseStorageProvider` from `lib/data/services/firebase_providers.dart`.

### `lib/data/services/firebase_providers.dart` (new — no codebase analog)

Canonical pattern from RESEARCH.md. No existing analog; this is greenfield.

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});
```

---

### Repository: `lib/data/repositories/users_repository.dart`

**Source call sites from `lib/features/dashboard/dashboard_viewmodel.dart`:**

Call site A (stream user doc — lines 390–416):
```dart
_userSub = _firestore
    .collection('users')
    .doc(uid)
    .snapshots()
    .listen((doc) {
  final data = doc.data();
  // ...decodes into DashboardUser.fromDoc(uid, data, ...)
});
```

Call site B (usage sub-collection read — `_awardDailyLoginIfNeeded`, ~line 568):
```dart
final usageRef = _firestore
    .collection('users')
    .doc(uid)
    .collection('usage')
    .doc(todayKey);
```

**Derived method signatures for `UsersRepository`:**
```dart
// Watch /users/{uid} — decoded as DashboardUser or ProfileUser depending on caller
Stream<Map<String, dynamic>> watchUserDoc(String uid);

// One-shot read of /users/{uid}
Future<Map<String, dynamic>?> getUserDoc(String uid);

// Read /users/{uid}/usage/{dateKey}
Future<Map<String, dynamic>?> getUsageDoc(String uid, String dateKey);

// Write /users/{uid}/usage/{dateKey}
Future<void> setUsageDoc(String uid, String dateKey, Map<String, dynamic> data);

// Update /users/{uid} fields
Future<void> updateUserFields(String uid, Map<String, dynamic> fields);

// Batch write for account deletion (used in profile_viewmodel)
WriteBatch startBatch();   // delegates to firestore.batch()

// Award points — updates /rewards/{uid}
Future<void> incrementPoints(String uid, int delta);
```

**Source:** `lib/features/dashboard/dashboard_viewmodel.dart:345–383` (init + stream setup), `lib/features/profile/profile_viewmodel.dart:148–246`.

---

### Repository: `lib/data/repositories/sessions_repository.dart`

**Source call site from `lib/features/dashboard/dashboard_viewmodel.dart` lines ~448–470:**
```dart
_sessionsSub = _firestore
    .collection('sessions')
    .where('userId', isEqualTo: uid)
    .orderBy('updatedAt', descending: true)
    .limit(5)
    .snapshots()
    .listen((snap) {
  final sessions = snap.docs
      .map(SessionItem.fromDoc)
      .toList(growable: false);
  state = state.copyWith(recentSessions: sessions);
});
```

**Source call site from `lib/features/search/search_viewmodel.dart` lines ~300–325:**
```dart
final sessionSnap = await _firestore
    .collection('sessions')
    .where('userId', isEqualTo: uid)
    .orderBy('updatedAt', descending: true)
    .limit(20)
    .get();
```

**Derived method signatures for `SessionsRepository`:**
```dart
// Stream recent sessions for a user
Stream<List<SessionItem>> watchRecentSessions(String uid, {int limit = 5});

// One-shot search query
Future<List<SessionItem>> searchSessions(String uid, {int limit = 20});

// Create/update a session document
Future<String> saveSession(String uid, Map<String, dynamic> data);
```

---

### Repository: `lib/data/repositories/materials_repository.dart`

**Source call site from `lib/features/materials/materials_viewmodel.dart` lines ~295–320:**
```dart
_firestore
    .collection('materials')
    .orderBy('createdAt', descending: true)
    .limit(20)
    .snapshots()
    .map((snap) => snap.docs.map(LearningMaterial.fromDoc).toList(growable: false));
```

**Source call site (view count increment):**
```dart
_firestore.collection('materials').doc(id).update({
  'views': FieldValue.increment(1),
});
```

**Derived method signatures for `MaterialsRepository`:**
```dart
// Stream materials with optional filters
Stream<List<LearningMaterial>> streamMaterials({
  String? subject,
  String? level,
  MaterialType? type,
  DocumentSnapshot? startAfter,  // cursor pagination
  int limit = 20,
});

// Increment view count
Future<void> incrementViewCount(String materialId);
```

---

### Repository: `lib/data/repositories/notifications_repository.dart`

**Source call site from `lib/features/notifications/notifications_viewmodel.dart` lines ~185–210:**
```dart
_firestore
    .collection('notifications')
    .where('recipientRole', whereIn: [role, 'all'])
    .orderBy('timestamp', descending: true)
    .limit(50)
    .snapshots()
    .listen((snap) {
  final items = snap.docs
      .map(AppNotification.fromDoc)
      .toList(growable: false);
  state = state.copyWith(notifications: items);
});
```

**Derived method signatures for `NotificationsRepository`:**
```dart
// Stream notifications for a given role
Stream<List<AppNotification>> watchNotifications(String role, {int limit = 50});

// Mark as read
Future<void> markRead(String notificationId);
```

---

### Repository: `lib/data/repositories/rewards_repository.dart`

**Source call site from `lib/features/rewards/gamification_viewmodel.dart` lines ~225–260:**
```dart
_firestore
    .collection('rewards')
    .doc(uid)
    .snapshots()
    .listen((doc) {
  final data = doc.data() ?? {};
  // ...decodes into RewardsDoc
});
```

**Source call site (award points — from `chat_viewmodel.dart` / `dashboard_viewmodel.dart`):**
```dart
await _firestore.collection('rewards').doc(uid).set({
  'points': FieldValue.increment(delta),
  'updatedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));
```

**Derived method signatures for `RewardsRepository`:**
```dart
// Stream /rewards/{uid}
Stream<RewardsDoc> watchRewards(String uid);

// Award points (merge write)
Future<void> awardPoints(String uid, String action, int delta);

// Add badge id to /rewards/{uid}.badges array
Future<void> addBadge(String uid, String badgeId);

// Add to /rewards/{uid}/ledger (Phase 4 subcollection — stub now)
Future<void> appendLedgerEntry(String uid, Map<String, dynamic> entry);
```

---

### Repository: `lib/data/repositories/subscriptions_repository.dart`

**Status: stub only in Phase 1.** No `/subscriptions` collection is populated until Phase 5.

**Stub method signatures (scaffold only, all unimplemented):**
```dart
// Read subscription for a user
Future<String?> getSubscriptionType(String uid);  // returns 'free' | 'premium'

// Check if subscription is active
Future<bool> isSubscriptionActive(String uid);
```

---

## 4. Files to CREATE — New Infrastructure (Greenfield, No Codebase Analog)

### `tool/lints/` — custom_lint rule package

**No analog exists** in the codebase. This is a standalone Dart package living outside `lib/`. Closest public reference: https://pub.dev/packages/custom_lint_builder.

**Package structure:**
```
tool/lints/
├── pubspec.yaml
└── lib/
    └── mentormind_lints.dart
```

**`tool/lints/pubspec.yaml`:**
```yaml
name: mentormind_lints
version: 0.0.1
publish_to: none

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  custom_lint_builder: ^0.7.0
  analyzer: ^7.0.0
```

**Wire into host `pubspec.yaml` dev_dependencies:**
```yaml
dev_dependencies:
  custom_lint: ^0.7.7
  riverpod_lint: ^2.6.5
  mentormind_lints:
    path: tool/lints
```

**Wire into `analysis_options.yaml`:**
```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  plugins:
    - custom_lint
```

**Rule file:** `tool/lints/lib/mentormind_lints.dart`
- Rule id: `layered_imports`
- Bans `package:cloud_firestore`, `package:firebase_auth`, `package:firebase_storage`, `package:firebase_messaging` imports from files whose path contains `lib/presentation/`
- Bans imports of `lib/presentation/` from files whose path contains `lib/data/`
- Exempts `lib/core/` and `abstract final class` namespaces

**Planner note:** No existing Dart file in this repo demonstrates a `PluginBase` / `DartLintRule` implementation. The planner must reference the `custom_lint_builder` README directly for the boilerplate — there is no in-repo pattern to copy.

---

### `.github/workflows/ci.yml` — GitHub Actions CI

**No `.github/` directory exists in the repo.** This is greenfield.

**Canonical workflow from RESEARCH.md (verified against official actions):**
```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  flutter:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: '3.41.3'
          cache: true
      - run: flutter pub get
      - run: flutter analyze --fatal-warnings
      - run: dart run custom_lint
      - run: flutter test --coverage
      - uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage/lcov.info

  functions:
    runs-on: ubuntu-latest
    if: contains(github.event.head_commit.modified, 'functions/')
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: echo "Functions CI stub — no-op until Phase 2"
```

**Critical note:** `dart run custom_lint` and `flutter analyze` are SEPARATE steps. `flutter analyze` does not run custom_lint plugins as a CI command (only the IDE picks them up from `analysis_options.yaml`).

---

### `firebase.json` — emulators block

**Current `firebase.json` content (entire file, one line):**
```json
{
  "firestore": {"rules": "firestore.rules", "indexes": "firestore.indexes.json"},
  "storage": {"rules": "storage.rules"},
  "flutter": {
    "platforms": {
      "ios": {
        "default": {
          "projectId": "mentor-mind-aa765",
          "appId": "1:722452556351:ios:823964b9f46ebc2f97e68a",
          "uploadDebugSymbols": false,
          "fileOutput": "ios/Runner/GoogleService-Info.plist"
        }
      },
      "dart": {
        "lib/firebase_options.dart": {
          "projectId": "mentor-mind-aa765",
          "configurations": {
            "ios": "1:722452556351:ios:823964b9f46ebc2f97e68a",
            "macos": "1:722452556351:ios:823964b9f46ebc2f97e68a"
          }
        }
      }
    }
  }
}
```

**Emulators block to ADD (merge into the JSON above):**
```json
"emulators": {
  "auth":      {"port": 9099},
  "firestore": {"port": 8080},
  "storage":   {"port": 9199},
  "ui":        {"enabled": true, "port": 4000}
}
```

**No `functions` emulator entry in Phase 1** — functions emulator is Phase 2.

---

## 5. iOS File Edits — Bundle ID + Deployment Target

### Current state (confirmed by direct file reads)

| File | Key | Current Value | Target Value |
|------|-----|--------------|-------------|
| `ios/Podfile` line 2 | `# platform :ios, '13.0'` | commented out | uncomment → `platform :ios, '14.2'` |
| `ios/Podfile` lines 50–51 | `if current < 13.0` / `= '13.0'` | `13.0` threshold | change both to `14.2` |
| `ios/Runner.xcodeproj/project.pbxproj` line 483 | `IPHONEOS_DEPLOYMENT_TARGET` | `13.0` (Profile config) | `14.2` |
| `ios/Runner.xcodeproj/project.pbxproj` line 617 | `IPHONEOS_DEPLOYMENT_TARGET` | `13.0` (Debug config) | `14.2` |
| `ios/Runner.xcodeproj/project.pbxproj` line 668 | `IPHONEOS_DEPLOYMENT_TARGET` | `13.0` (Release config) | `14.2` |
| `ios/Runner.xcodeproj/project.pbxproj` line 507 | `PRODUCT_BUNDLE_IDENTIFIER` | `com.arnobrizwan.mentorminds` (Profile) | `com.mentorminds.mentorMinds` |
| `ios/Runner.xcodeproj/project.pbxproj` line 694 | `PRODUCT_BUNDLE_IDENTIFIER` | `com.arnobrizwan.mentorminds` (Debug) | `com.mentorminds.mentorMinds` |
| `ios/Runner.xcodeproj/project.pbxproj` line 718 | `PRODUCT_BUNDLE_IDENTIFIER` | `com.arnobrizwan.mentorminds` (Release) | `com.mentorminds.mentorMinds` |
| `ios/Runner/Runner.entitlements` line 7 | `keychain-access-groups` | `$(AppIdentifierPrefix)com.arnobrizwan.mentorminds` | `$(AppIdentifierPrefix)com.mentorminds.mentorMinds` |
| `ios/Runner/Info.plist` | `CFBundleURLTypes` | **absent** | add `REVERSED_CLIENT_ID` URL scheme entry |

### Podfile current state (lines 39–63, confirmed read):

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      # Bump deployment target for pods whose default is below iOS 13
      current = config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f
      if current < 13.0
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      end
    end
  end
  # ...
end
```

**Required Podfile changes:**
1. Line 2: uncomment and change to `platform :ios, '14.2'`
2. `if current < 13.0` → `if current < 14.2`
3. `= '13.0'` → `= '14.2'`

### `Info.plist` — missing `CFBundleURLTypes` entry

Current `Info.plist` has no `CFBundleURLTypes` key (confirmed: only `NSPhotoLibraryUsageDescription`, `NSCameraUsageDescription`, `CFBundleIdentifier` present). After downloading the new `GoogleService-Info.plist` with `REVERSED_CLIENT_ID` populated, add:

```xml
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

**`YOUR_CLIENT_NUMBER` comes from the new `GoogleService-Info.plist` `REVERSED_CLIENT_ID` field.** This value is not yet available — it requires the Firebase Console checklist in `BACKEND_SETUP.md` to be completed first (register new iOS app, download new plist).

---

## 6. Avatar Upload Edit Sites

### Edit site 1 — `lib/features/profile/profile_viewmodel.dart` line 232

**Current (broken — path not allowed by `storage.rules`):**
```dart
      if (avatarFile != null) {
        state = state.copyWith(uploadingAvatar: true);
        final ref = _storage.ref('avatars/${user.uid}.jpg');   // ← LINE 232: BROKEN
        await ref.putFile(
          File(avatarFile.path),
          SettableMetadata(contentType: 'image/jpeg'),
        );
        final url = await ref.getDownloadURL();
        updates['avatarUrl'] = url;
```

**Fixed (matches `storage.rules` pattern `uploads/{uid}/{allPaths=**}`):**
```dart
        final ref = _storage.ref(
          'uploads/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_avatar.jpg',
        );
```

### Edit site 2 — `lib/features/profile/profile_viewmodel.dart` line 429

**Current (broken — same wrong path, in account deletion cleanup):**
```dart
      // 2. Delete avatar from Storage (best-effort — not all users have one).
      try {
        await _storage.ref('avatars/$uid.jpg').delete();  // ← LINE 429: BROKEN
      } catch (_) {}
```

**Fixed:**
```dart
      try {
        // Best-effort: only succeeds if avatar was previously uploaded.
        // Path must match the fixed upload path from updateProfile.
        // Cannot know the exact timestamp; delete by listing or skip.
        // Simplest safe option: no-op here — file will be orphaned.
        // If cleanup is required, use Storage list API in Phase 4+.
      } catch (_) {}
```

**Note:** The delete at line 429 cannot be trivially fixed with a static path because the new upload path includes a millisecond timestamp. The safest Phase 1 fix is to make the delete a no-op (comment it out) and defer orphan cleanup. The planner should reflect this trade-off. The `storage.rules` already catches `avatars/` writes — the broken upload at line 232 is the critical fix; line 429 is best-effort and harmless to leave as a no-op.

---

## 7. ViewModel Pattern Reference (Anchor for "read_first")

**Best analog: `lib/features/dashboard/dashboard_viewmodel.dart`** — the most complete viewmodel in the codebase, covering streams, state guards, disposal, and `autoDispose`.

### State class with `copyWith(clear* = false)` pattern (lines 252–282):

```dart
DashboardState copyWith({
  bool? isLoading,
  String? error,
  DashboardUser? user,
  List<SessionItem>? recentSessions,
  List<MaterialItem>? materials,
  RewardsSnapshot? rewards,
  int? streak,
  int? notificationCount,
  DateTime? dailyChallengeResetsAt,
  bool? justAwardedDailyPoints,
  int? dailyAwardAmount,
  bool clearError = false,   // explicit bool — not a nullable parameter
  bool clearUser = false,
}) {
  return DashboardState(
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
    user: clearUser ? null : (user ?? this.user),
    recentSessions: recentSessions ?? this.recentSessions,
    // ...
  );
}
```

**Why this pattern exists:** Standard `copyWith(error: null)` cannot distinguish "set to null" from "leave unchanged" when the field is nullable. `clearError: true` is the explicit signal.

### StateNotifier class + provider (lines 337–672):

```dart
class DashboardViewModel extends StateNotifier<DashboardState> {
  DashboardViewModel()
      : super(DashboardState(
          dailyChallengeResetsAt: _nextMidnight(DateTime.now()),
        )) {
    _init();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  // ... additional subscriptions

  @override
  void dispose() {
    _userSub?.cancel();
    _sessionsSub?.cancel();
    _materialsSub?.cancel();
    _notifSub?.cancel();
    super.dispose();  // always call super
  }
}

// Bottom of file — provider declaration
final dashboardViewModelProvider =
    StateNotifierProvider.autoDispose<DashboardViewModel, DashboardState>(
  (ref) => DashboardViewModel(),
);
```

### `if (!mounted) return;` post-await guard (line 554):

```dart
      if (!mounted) return;
      state = state.copyWith(streak: streak);
```

**Every `async` method that writes `state` after an `await` must include this guard.** Without it, writing to a disposed `StateNotifier` throws.

### NOT autoDispose — provider exception with required comment (splash_viewmodel.dart:113–119):

```dart
// Intentionally NOT autoDispose: the splash screen uses ref.read (not watch),
// so an autoDispose provider gets disposed during the await inside
// resolveDestination(), causing a "used after dispose" throw on the next
// state = ... that then hangs the splash sequence.
final splashViewModelProvider =
    StateNotifierProvider<SplashViewModel, SplashState>(
  (ref) => SplashViewModel(),
);
```

**Apply this comment pattern to all 5 non-autoDispose providers** (`splashViewModelProvider`, `profileViewModelProvider`, `rewardsViewModelProvider`, `gamificationViewModelProvider`, `notificationsViewModelProvider`) — preserve verbatim through the `git mv`.

### Import convention for new viewmodel files:

```dart
// Viewmodel file — use flutter_riverpod (NOT hooks_riverpod)
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Screen file — use hooks_riverpod (re-exports everything from flutter_riverpod)
import 'package:hooks_riverpod/hooks_riverpod.dart';
```

### `unawaited()` fire-and-forget pattern (dashboard_viewmodel.dart:382–383):

```dart
// One-shot background work — intentionally fire-and-forget.
unawaited(_fetchStreak(uid));
unawaited(_awardDailyLoginIfNeeded(uid));
```

Import: `import 'dart:async';` — required for `unawaited()`.

---

## Shared Patterns

### Auth — no middleware, no decorators

All auth checks are imperative inside viewmodel init methods:
```dart
// Pattern: check currentUser at top of init, bail early with state.error
final user = _auth.currentUser;
if (user == null) {
  state = state.copyWith(isLoading: false, error: 'You are not signed in.');
  return;
}
final uid = user.uid;
```

**Source:** `lib/features/dashboard/dashboard_viewmodel.dart:366–373`. Copy this pattern to all repository-accepting viewmodels in PR-2.

### Error handling — non-fatal stream errors

```dart
// Non-fatal — leave streak at previous value.
} catch (_) {}
```

**Source:** `lib/features/dashboard/dashboard_viewmodel.dart:556–558`. Dashboard swallows stream errors with a comment. Repositories should propagate errors; viewmodels decide whether to surface or swallow.

### `growable: false` on all immutable list results

```dart
.toList(growable: false)
```

Apply to every `.map(...).toList()` call that produces a list stored in state or returned from a repository. Source: codebase-wide convention documented in CLAUDE.md.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `tool/lints/lib/mentormind_lints.dart` | lint plugin | static analysis | No custom_lint plugin exists in repo; greenfield |
| `.github/workflows/ci.yml` | CI config | batch | No `.github/` directory exists |
| `lib/data/repositories/subscriptions_repository.dart` | repository | CRUD | No `/subscriptions` collection exists yet; stub only |
| `lib/data/services/firebase_providers.dart` | provider | — | Pattern exists conceptually (see `geminiServiceProvider`) but no SDK-seam provider file exists |
| `test/_support/factories/*.dart` | test factories | — | No test files exist in the repo (`test/` directory is empty) |
| `test/_helpers/*.dart` | test helpers | — | Same — zero existing tests |
| `integration_test/login_smoke_test.dart` | integration test | — | Same |

---

## Metadata

**Analog search scope:** `lib/features/`, `ios/`, `firebase.json`, `ios/Runner.xcodeproj/project.pbxproj`, `ios/Podfile`, `ios/Runner/Info.plist`, `ios/Runner/Runner.entitlements`
**Files read:** 18 source files + 5 iOS/config files
**Pattern extraction date:** 2026-05-17
