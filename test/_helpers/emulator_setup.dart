import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

// ---------------------------------------------------------------------------
// emulator_setup.dart — Configure Firebase SDKs to talk to the Local Emulator
// Suite instead of the production project.
//
// Call configureEmulators() in integration-test setUpAll, AFTER
// Firebase.initializeApp and BEFORE any Auth / Firestore / Storage operation.
//
// Ports must match firebase.json emulators block:
//   auth:      localhost:9099
//   firestore: localhost:8080
//   storage:   localhost:9199
//
// The USE_EMULATOR dart-define is also read by lib/main.dart to wire
// the same redirects when running the full app under emulators.
// ---------------------------------------------------------------------------

// kUseEmulator is a compile-time const so the check is free at runtime.
const bool kUseEmulator =
    String.fromEnvironment('USE_EMULATOR', defaultValue: 'false') == 'true';

// Redirects all Auth, Firestore and Storage SDK calls to localhost emulator
// ports. No-op when USE_EMULATOR is false or absent.
Future<void> configureEmulators() async {
  if (!kUseEmulator) return;
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
}
