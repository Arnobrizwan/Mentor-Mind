// ---------------------------------------------------------------------------
// DashboardUser — lightweight user projection used by the dashboard screen.
// Decoded from /users/{uid}. Does NOT include email, subscriptionType, or
// avatar; those are in ProfileUser (lib/data/models/profile_user.dart).
// ---------------------------------------------------------------------------

class DashboardUser {
  final String uid;
  final String name;
  final String firstName;
  final String role;
  final int points;
  final List<String> subjects;
  final String level;
  final List<String> badgeIds;

  const DashboardUser({
    required this.uid,
    required this.name,
    required this.firstName,
    required this.role,
    required this.points,
    required this.subjects,
    required this.level,
    required this.badgeIds,
  });

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
}
