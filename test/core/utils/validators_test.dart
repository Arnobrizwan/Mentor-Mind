// Anchor 1 — Pure unit test for Validators.
// No Firebase, no Riverpod, no SharedPreferences.
// Proves `flutter test` runs cleanly after Phase 1 restructuring.

import 'package:flutter_test/flutter_test.dart';
import 'package:mentor_minds/core/utils/validators.dart';

@Tags(['unit'])

void main() {
  group('Validators', () {
    // -----------------------------------------------------------------------
    // email
    // -----------------------------------------------------------------------
    group('email', () {
      test('returns null for valid email', () {
        expect(Validators.email('test@example.com'), isNull);
      });
      test('returns error for missing @', () {
        expect(Validators.email('notanemail'), isNotNull);
      });
      test('returns error for no-dot domain', () {
        expect(Validators.email('no-at.com'), isNotNull);
      });
      test('returns error for empty string', () {
        expect(Validators.email(''), isNotNull);
      });
      test('returns error for null', () {
        expect(Validators.email(null), isNotNull);
      });
    });

    // -----------------------------------------------------------------------
    // name
    // -----------------------------------------------------------------------
    group('name', () {
      test('returns null for valid full name', () {
        expect(Validators.name('Test Learner'), isNull);
      });
      test('returns error for empty string', () {
        expect(Validators.name(''), isNotNull);
      });
      test('returns error for null', () {
        expect(Validators.name(null), isNotNull);
      });
      test('returns error for single-character name', () {
        // Rule: length < 2 → 'Name is too short'
        expect(Validators.name('A'), isNotNull);
      });
    });

    // -----------------------------------------------------------------------
    // password (registration — strong: 8+ chars, 1 uppercase, 1 number)
    // -----------------------------------------------------------------------
    group('password', () {
      test('returns null for strong password', () {
        expect(Validators.password('Password1'), isNull);
      });
      test('returns error for too-short password', () {
        expect(Validators.password('Abc1'), isNotNull);
      });
      test('returns error for no uppercase', () {
        expect(Validators.password('password1'), isNotNull);
      });
      test('returns error for no digit', () {
        expect(Validators.password('Password'), isNotNull);
      });
      test('returns error for empty string', () {
        expect(Validators.password(''), isNotNull);
      });
      test('returns error for null', () {
        expect(Validators.password(null), isNotNull);
      });
    });

    // -----------------------------------------------------------------------
    // loginPassword (lighter: non-empty only — never reveal password policy)
    // -----------------------------------------------------------------------
    group('loginPassword', () {
      test('returns null for any non-empty password', () {
        expect(Validators.loginPassword('abc'), isNull);
      });
      test('returns null for weak password that passes login check', () {
        expect(Validators.loginPassword('a'), isNull);
      });
      test('returns error for empty string', () {
        expect(Validators.loginPassword(''), isNotNull);
      });
      test('returns error for null', () {
        expect(Validators.loginPassword(null), isNotNull);
      });
    });

    // -----------------------------------------------------------------------
    // confirmPassword
    // -----------------------------------------------------------------------
    group('confirmPassword', () {
      test('returns null when passwords match', () {
        expect(Validators.confirmPassword('Password1', 'Password1'), isNull);
      });
      test('returns error when passwords differ', () {
        expect(Validators.confirmPassword('Password1', 'Password2'), isNotNull);
      });
      test('returns error for empty confirm', () {
        expect(Validators.confirmPassword('', 'Password1'), isNotNull);
      });
      test('returns error for null confirm', () {
        expect(Validators.confirmPassword(null, 'Password1'), isNotNull);
      });
    });

    // -----------------------------------------------------------------------
    // role — accepts 'student' | 'teacher'; rejects everything else
    // -----------------------------------------------------------------------
    group('role', () {
      test('returns null for student', () {
        expect(Validators.role('student'), isNull);
      });
      test('returns null for teacher', () {
        expect(Validators.role('teacher'), isNull);
      });
      test('returns error for admin (not a valid registration role)', () {
        expect(Validators.role('admin'), isNotNull);
      });
      test('returns error for empty string', () {
        expect(Validators.role(''), isNotNull);
      });
      test('returns error for null', () {
        expect(Validators.role(null), isNotNull);
      });
    });
  });
}
