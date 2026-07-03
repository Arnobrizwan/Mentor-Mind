import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/data/services/notification_persistence.dart';
import 'package:mentor_minds/data/services/firebase_providers.dart';
import 'package:mentor_minds/firebase_messaging_background.dart';

// ---------------------------------------------------------------------------
// MessagingService — NOTF-01..04 FCM iOS wiring
// ---------------------------------------------------------------------------

abstract final class FcmTopics {
  static const all = 'role_all';
  static const student = 'role_student';
  static const premiumStudent = 'role_premium_student';
  static const teacher = 'role_teacher';
  static const admin = 'role_admin';
}

class MessagingService {
  MessagingService({
    required FirebaseMessaging messaging,
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _messaging = messaging,
        _firestore = firestore,
        _auth = auth;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;

  static const _prefRationaleDone = 'fcm_rationale_done';

  /// Call once from main() before runApp.
  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _initLocalNotifications();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen(_onTokenRefresh);
    _foregroundSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleOpenedMessage,
    );
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _pendingOpen = initial;
    }
  }

  RemoteMessage? _pendingOpen;

  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundSub?.cancel();
    _openedSub?.cancel();
  }

  /// Shows rationale once, then requests permission and subscribes to topics.
  Future<void> ensureRegistered({
    required BuildContext context,
    required String role,
    required bool isPremium,
  }) async {
    if (!Platform.isIOS) {
      await _registerTopics(role: role, isPremium: isPremium);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(_prefRationaleDone) ?? false;
    if (!done && context.mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Stay on track'),
          content: const Text(
            'MentorMinds sends helpful reminders — daily challenges, '
            'new study materials, and achievement alerts. You can change '
            'this anytime in Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      await prefs.setBool(_prefRationaleDone, true);
      if (proceed != true) return;
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final allowed = settings.authorizationStatus ==
            AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!allowed) return;

    await _registerTopics(role: role, isPremium: isPremium);
  }

  /// Handle notification tap navigation (NOTF-08) — call from dashboard mount.
  void handlePendingNavigation(BuildContext context) {
    final msg = _pendingOpen;
    if (msg == null) return;
    _pendingOpen = null;
    _navigateForMessage(context, msg);
  }

  List<String> topicsForRole(String role, bool isPremium) {
    final topics = <String>[FcmTopics.all];
    switch (role) {
      case 'admin':
        topics.add(FcmTopics.admin);
        break;
      case 'teacher':
        topics.add(FcmTopics.teacher);
        break;
      default:
        topics.add(
          isPremium ? FcmTopics.premiumStudent : FcmTopics.student,
        );
    }
    return topics;
  }

  Future<void> _registerTopics({
    required String role,
    required bool isPremium,
  }) async {
    final fcmToken = await _messaging.getToken();
    if (fcmToken == null) return;

    if (Platform.isIOS) {
      final apns = await _waitForApnsToken();
      if (apns == null) {
        debugPrint('FCM: APNs token not ready after 10s — deferring topics');
        return;
      }
    }

    final topics = topicsForRole(role, isPremium);
    for (final topic in topics) {
      await _messaging.subscribeToTopic(topic);
    }

    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _firestore.collection('users').doc(uid).set(
        {
          'fcmToken': fcmToken,
          'fcmTopics': topics,
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
  }

  Future<String?> _waitForApnsToken() async {
    for (var i = 0; i < 20; i++) {
      final apns = await _messaging.getAPNSToken();
      if (apns != null) return apns;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  Future<void> _onTokenRefresh(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final snap = await _firestore.collection('users').doc(uid).get();
    final data = snap.data() ?? {};
    final role = (data['role'] as String?) ?? 'student';
    final isPremium =
        (data['subscriptionType'] as String?) == 'premium' ||
        (_auth.currentUser != null &&
            (await _auth.currentUser!.getIdTokenResult())
                    .claims?['premium'] ==
                true);
    await _firestore.collection('users').doc(uid).set(
      {'fcmToken': token, 'fcmUpdatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    await _registerTopics(role: role, isPremium: isPremium);
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    await persistRemoteMessage(_firestore, message);
    final title = message.notification?.title ??
        message.data['title'] ??
        'MentorMinds';
    final body =
        message.notification?.body ?? message.data['body'] ?? '';
    await _local.show(
      message.hashCode,
      title.toString(),
      body.toString(),
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  void _handleOpenedMessage(RemoteMessage message) {
    _pendingOpen = message;
  }

  void _navigateForMessage(BuildContext context, RemoteMessage message) {
    final type = (message.data['type'] as String?) ?? 'announcement';
    switch (type) {
      case 'new_material':
        context.goNamed(AppRoutes.materials);
        break;
      case 'achievement':
        context.goNamed(AppRoutes.rewards);
        break;
      case 'daily_challenge':
        context.goNamed(AppRoutes.tutor);
        break;
      default:
        context.goNamed(AppRoutes.notifications);
    }
  }

  Future<void> _initLocalNotifications() async {
    const ios = DarwinInitializationSettings();
    // Android requires an explicit init settings block (defaults to the app
    // launcher icon for the small-icon slot); omitting it throws
    // "Android settings must be set when targeting Android platform".
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(iOS: ios, android: android);
    await _local.initialize(
      init,
      onDidReceiveNotificationResponse: (response) {
        // Tap handled via onMessageOpenedApp / getInitialMessage for FCM.
      },
    );
  }
}

/// Widget tests override to `false` to skip FCM registration.
final fcmRegistrationEnabledProvider = Provider<bool>((ref) => true);

final messagingServiceProvider = Provider<MessagingService>((ref) {
  final svc = MessagingService(
    messaging: FirebaseMessaging.instance,
    firestore: ref.read(firestoreProvider),
    auth: ref.read(firebaseAuthProvider),
  );
  ref.onDispose(svc.dispose);
  return svc;
});
