import 'package:firebase_auth/firebase_auth.dart';

/// AUTH-02 — true when email/password user must verify before tutor features.
bool requiresEmailVerification(User? user) {
  if (user == null || user.emailVerified) return false;
  return user.providerData.any((p) => p.providerId == 'password');
}
