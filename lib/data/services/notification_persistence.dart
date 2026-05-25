import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ---------------------------------------------------------------------------
// Persist FCM payloads to /notifications (NOTF-02).
// Uses notificationId from data when present (admin broadcast dedupe).
// ---------------------------------------------------------------------------

Future<void> persistRemoteMessage(
  FirebaseFirestore firestore,
  RemoteMessage message,
) async {
  final data = message.data;
  final title = message.notification?.title ??
      data['title'] ??
      'MentorMinds';
  final body = message.notification?.body ?? data['body'] ?? '';
  if (body.toString().isEmpty && title.toString().isEmpty) return;

  final id = (data['notificationId'] as String?)?.trim();
  final ref = id != null && id.isNotEmpty
      ? firestore.collection('notifications').doc(id)
      : firestore.collection('notifications').doc();

  final snap = await ref.get();
  if (snap.exists) return;

  await ref.set({
    'title': title,
    'body': body,
    'type': (data['type'] as String?) ?? 'announcement',
    'recipientRole': (data['recipientRole'] as String?) ?? 'all',
    'deeplink': data['deeplink'],
    'read': false,
    'timestamp': FieldValue.serverTimestamp(),
    'source': 'fcm_client',
  });
}
