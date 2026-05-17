import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:mentor_minds/data/services/firebase_providers.dart';

// ---------------------------------------------------------------------------
// AuthRepository — wraps FirebaseAuth + GoogleSignIn (D-01, D-04)
// Provides the seam for all auth operations. FirebaseAuthException is
// re-thrown to callers so they can map error codes to user-facing messages
// without importing firebase_auth themselves (except for the exception class).
// ---------------------------------------------------------------------------

class AuthRepository {
  AuthRepository({
    required FirebaseAuth auth,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth,
        _google = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  // -------------------------------------------------------------------------
  // authStateChanges — broadcasts FirebaseAuth user state transitions.
  // -------------------------------------------------------------------------

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  // -------------------------------------------------------------------------
  // currentUser — synchronous getter for the signed-in user.
  // -------------------------------------------------------------------------

  User? get currentUser => _auth.currentUser;

  // -------------------------------------------------------------------------
  // signInWithEmail — email + password sign-in.
  // Throws FirebaseAuthException so callers can inspect .code.
  // -------------------------------------------------------------------------

  Future<UserCredential> signInWithEmail(
    String email,
    String password,
  ) {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // -------------------------------------------------------------------------
  // registerWithEmail — creates a new email + password account.
  // Throws FirebaseAuthException so callers can inspect .code.
  // -------------------------------------------------------------------------

  Future<UserCredential> registerWithEmail(
    String email,
    String password,
  ) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // -------------------------------------------------------------------------
  // signInWithGoogle — wraps GoogleSignIn + FirebaseAuth credential flow.
  // Returns null if the user cancelled the picker (no error).
  // Throws FirebaseAuthException for auth failures.
  // -------------------------------------------------------------------------

  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _google.signIn();
    if (googleUser == null) return null; // user dismissed picker

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  // -------------------------------------------------------------------------
  // signOut — signs out of both Firebase and Google.
  // -------------------------------------------------------------------------

  Future<void> signOut() async {
    try {
      await _google.signOut();
    } catch (_) {
      // Google sign-out can fail if not signed in with Google — ignore.
    }
    await _auth.signOut();
  }

  // -------------------------------------------------------------------------
  // sendPasswordReset — sends a password reset email.
  // Throws FirebaseAuthException so callers can inspect .code.
  // -------------------------------------------------------------------------

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  // -------------------------------------------------------------------------
  // sendEmailVerification — sends a verification email to the current user.
  // Throws FirebaseAuthException so callers can inspect .code.
  // -------------------------------------------------------------------------

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No signed-in user for email verification');
    await user.sendEmailVerification();
  }

  // -------------------------------------------------------------------------
  // reload — reloads the current user's profile from Firebase Auth.
  // -------------------------------------------------------------------------

  Future<void> reload() async {
    await _auth.currentUser?.reload();
  }

  // -------------------------------------------------------------------------
  // updateDisplayName — updates the auth user's display name.
  // -------------------------------------------------------------------------

  Future<void> updateDisplayName(String displayName) async {
    await _auth.currentUser?.updateDisplayName(displayName);
  }

  // -------------------------------------------------------------------------
  // updatePhotoURL — updates the auth user's photo URL.
  // -------------------------------------------------------------------------

  Future<void> updatePhotoURL(String photoURL) async {
    await _auth.currentUser?.updatePhotoURL(photoURL);
  }

  // -------------------------------------------------------------------------
  // updatePassword — updates the auth user's password.
  // Throws FirebaseAuthException so callers can inspect .code.
  // -------------------------------------------------------------------------

  Future<void> updatePassword(String newPassword) async {
    await _auth.currentUser?.updatePassword(newPassword);
  }

  // -------------------------------------------------------------------------
  // reauthenticateWithPassword — re-authenticates the current user with
  // email + password before sensitive operations.
  // Throws FirebaseAuthException so callers can inspect .code.
  // -------------------------------------------------------------------------

  Future<UserCredential> reauthenticateWithPassword(
    String email,
    String password,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No signed-in user for reauthentication');
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    return user.reauthenticateWithCredential(credential);
  }

  // -------------------------------------------------------------------------
  // deleteAccount — deletes the current auth user account.
  // Throws FirebaseAuthException so callers can inspect .code.
  // -------------------------------------------------------------------------

  Future<void> deleteAccount() async {
    await _auth.currentUser?.delete();
    try {
      await _google.signOut();
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(auth: ref.read(firebaseAuthProvider));
});
