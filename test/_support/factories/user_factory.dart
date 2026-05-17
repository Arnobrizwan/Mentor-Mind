import 'package:mentor_minds/data/models/dashboard_user.dart';
import 'package:mentor_minds/data/models/profile_user.dart';

// ---------------------------------------------------------------------------
// user_factory.dart — Test data builders for DashboardUser and ProfileUser.
// All parameters have sensible defaults so callers only override what matters.
// Consistent uid/name defaults across factories aid cross-test assertions.
// ---------------------------------------------------------------------------

DashboardUser buildDashboardUser({
  String uid = 'test-uid',
  String name = 'Test Learner',
  String firstName = 'Test',
  String role = 'student',
  int points = 0,
  List<String> subjects = const ['Mathematics', 'Physics'],
  String level = 'O Level',
  List<String> badgeIds = const [],
}) {
  return DashboardUser(
    uid: uid,
    name: name,
    firstName: firstName,
    role: role,
    points: points,
    subjects: subjects,
    level: level,
    badgeIds: badgeIds,
  );
}

ProfileUser buildProfileUser({
  String uid = 'test-uid',
  String name = 'Test Learner',
  String email = 'test@example.com',
  String role = 'student',
  String subscriptionType = 'free',
  List<String> subjects = const ['Mathematics', 'Physics'],
  String level = 'O Level',
  int points = 0,
  String? avatarUrl,
  bool notificationsEnabled = true,
}) {
  return ProfileUser(
    uid: uid,
    name: name,
    email: email,
    role: role,
    subscriptionType: subscriptionType,
    subjects: subjects,
    level: level,
    points: points,
    avatarUrl: avatarUrl,
    notificationsEnabled: notificationsEnabled,
  );
}
