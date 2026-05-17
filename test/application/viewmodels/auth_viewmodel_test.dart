// Anchor 3 — AuthViewModel unit test with Firebase mocks.
// Exercises: firebase_auth_mocks + fake_cloud_firestore (CI-07).
// Uses ProviderScope override pattern against firebaseAuthProvider +
// firestoreProvider (D-04 seam — no real Firebase project touched; T-1-W0).

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentor_minds/application/viewmodels/auth/auth_viewmodel.dart';
import 'package:mentor_minds/data/services/firebase_providers.dart';
import '../../_helpers/provider_scope_helpers.dart';

void main() {
  group('AuthViewModel', () {
    // -----------------------------------------------------------------------
    // Anchor 3a — invalid email short-circuits before hitting Firebase
    // -----------------------------------------------------------------------
    test('loginWithEmail with invalid email returns null + sets error', () async {
      final container = makeContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
          firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
        ],
      );

      final vm = container.read(authViewModelProvider.notifier);
      final result = await vm.loginWithEmail('not-an-email', 'password');

      expect(result, isNull);
      expect(container.read(authViewModelProvider).error, isNotNull);
    });

    // -----------------------------------------------------------------------
    // Anchor 3b — valid credentials with a pre-seeded user document succeed
    //
    // MockFirebaseAuth with signedIn: false is the default; passing mockUser
    // makes signInWithEmailAndPassword succeed immediately (no network call).
    // FakeFirebaseFirestore is pre-seeded with /users/{uid} role:'student'
    // so _resolveRoleDestination returns AuthDestination.studentDashboard.
    // -----------------------------------------------------------------------
    test('loginWithEmail with valid credentials returns studentDashboard', () async {
      const testUid = 'test-uid';
      const testEmail = 'test@example.com';

      final fakeFirestore = FakeFirebaseFirestore();
      await fakeFirestore.collection('users').doc(testUid).set({
        'uid': testUid,
        'email': testEmail,
        'name': 'Test Learner',
        'role': 'student',
        'subscriptionType': 'free',
        'points': 0,
        'subjects': <String>[],
        'level': 'O Level',
        'badges': <String>[],
      });

      final container = makeContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(
            MockFirebaseAuth(
              mockUser: MockUser(uid: testUid, email: testEmail),
            ),
          ),
          firestoreProvider.overrideWithValue(fakeFirestore),
        ],
      );

      final vm = container.read(authViewModelProvider.notifier);
      final result = await vm.loginWithEmail(testEmail, 'password123');

      expect(result, AuthDestination.studentDashboard);
    });
  });
}
