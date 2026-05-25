import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:mentor_minds/data/services/notification_persistence.dart';
import 'package:mentor_minds/firebase_options.dart';

/// NOTF-02 — top-level background handler (must not be inside a class).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await persistRemoteMessage(FirebaseFirestore.instance, message);
}
