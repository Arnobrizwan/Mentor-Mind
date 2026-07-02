import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

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
//   functions: localhost:5001
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
  // Android emulator reaches the host via 10.0.2.2; iOS Simulator/desktop use
  // localhost (the device loopback == host loopback there).
  final String host =
      defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  await FirebaseStorage.instance.useStorageEmulator(host, 9199);
  FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
  // Callables are pinned to region asia-south1; redirect that instance too.
  FirebaseFunctions.instanceFor(region: 'asia-south1')
      .useFunctionsEmulator(host, 5001);
}
