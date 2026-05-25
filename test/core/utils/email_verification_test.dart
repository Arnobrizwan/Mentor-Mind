import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentor_minds/core/utils/email_verification.dart';

void main() {
  group('requiresEmailVerification', () {
    test('returns false for null user', () {
      expect(requiresEmailVerification(null), isFalse);
    });

    test('returns false when email is verified', () {
      final user = _FakeUser(emailVerified: true, providers: ['password']);
      expect(requiresEmailVerification(user), isFalse);
    });

    test('returns true for unverified email/password user', () {
      final user = _FakeUser(emailVerified: false, providers: ['password']);
      expect(requiresEmailVerification(user), isTrue);
    });

    test('returns false for unverified Google-only user', () {
      final user = _FakeUser(emailVerified: false, providers: ['google.com']);
      expect(requiresEmailVerification(user), isFalse);
    });
  });
}

class _FakeUser implements User {
  _FakeUser({required this.emailVerified, required this.providers});

  @override
  final bool emailVerified;

  final List<String> providers;

  @override
  List<UserInfo> get providerData =>
      providers.map((id) => _FakeUserInfo(id)).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserInfo implements UserInfo {
  _FakeUserInfo(this.providerId);

  @override
  final String providerId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
