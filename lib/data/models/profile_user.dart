import 'package:firebase_auth/firebase_auth.dart';

// ---------------------------------------------------------------------------
// ProfileUser — full user projection used by the profile screen.
// Decoded from /users/{uid}. Includes email, subscriptionType, avatar URL.
// Lightweight dashboard projection: DashboardUser (lib/data/models/dashboard_user.dart)
// ---------------------------------------------------------------------------

class ProfileUser {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String subscriptionType;
  final List<String> subjects;
  final String level;
  final int points;
  final String? avatarUrl;
  final bool notificationsEnabled;
  final bool isApproved;

  const ProfileUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.subscriptionType,
    required this.subjects,
    required this.level,
    required this.points,
    required this.avatarUrl,
    required this.notificationsEnabled,
    required this.isApproved,
  });

  bool get isPremium => subscriptionType == 'premium';

  ProfileUser copyWith({
    String? subscriptionType,
    bool? isApproved,
  }) =>
      ProfileUser(
        uid: uid,
        name: name,
        email: email,
        role: role,
        subscriptionType: subscriptionType ?? this.subscriptionType,
        subjects: subjects,
        level: level,
        points: points,
        avatarUrl: avatarUrl,
        notificationsEnabled: notificationsEnabled,
        isApproved: isApproved ?? this.isApproved,
      );

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return email.isNotEmpty ? email[0].toUpperCase() : '?';
    }
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory ProfileUser.fromDoc(
    String uid,
    Map<String, dynamic> data,
    User? authUser,
  ) {
    final rawName = (data['name'] as String?)?.trim();
    final name = (rawName?.isNotEmpty ?? false)
        ? rawName!
        : (authUser?.displayName?.trim().isNotEmpty == true
            ? authUser!.displayName!.trim()
            : 'Learner');

    // Read avatarUrl (new field) with fallback to photoUrl (auth_viewmodel
    // seeds this for Google sign-in users). Empty strings count as null.
    String? avatar = (data['avatarUrl'] as String?)?.trim();
    if (avatar == null || avatar.isEmpty) {
      avatar = (data['photoUrl'] as String?)?.trim();
    }
    return ProfileUser(
      uid: uid,
      name: name,
      email: (data['email'] as String?)?.trim() ?? authUser?.email ?? '',
      role: (data['role'] as String?)?.trim() ?? 'student',
      subscriptionType: (data['subscriptionType'] as String?)?.trim() ?? 'free',
      subjects: ((data['subjects'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      level: (data['level'] as String?) ?? '',
      points: (data['points'] as num?)?.toInt() ?? 0,
      avatarUrl: (avatar?.isEmpty ?? true) ? null : avatar,
      notificationsEnabled: (data['notificationsEnabled'] as bool?) ?? true,
      isApproved: (data['isApproved'] as bool?) ?? true,
    );
  }
}
