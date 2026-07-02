import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException, FirebaseException, User;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mentor_minds/core/utils/validators.dart';
import 'package:mentor_minds/data/repositories/auth_repository.dart';
import 'package:mentor_minds/data/repositories/users_repository.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum AuthErrorField { email, password, name, generic }

class AuthState {
  final bool isLoading;
  final String? error;
  final AuthErrorField? errorField;
  final User? user;

  const AuthState({
    this.isLoading = false,
    this.error,
    this.errorField,
    this.user,
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    AuthErrorField? errorField,
    User? user,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      errorField: clearError ? null : (errorField ?? this.errorField),
      user: clearUser ? null : (user ?? this.user),
    );
  }
}

// ---------------------------------------------------------------------------
// Destination — mirrors SplashDestination; screen handles the actual navigation
// ---------------------------------------------------------------------------

enum AuthDestination {
  studentDashboard,
  teacherDashboard,
  admin,
}

// ---------------------------------------------------------------------------
// ViewModel
// ---------------------------------------------------------------------------

class AuthViewModel extends StateNotifier<AuthState> {
  AuthViewModel(this._authRepo, this._usersRepo) : super(const AuthState());

  final AuthRepository _authRepo;
  final UsersRepository _usersRepo;

  static const MethodChannel _nativeConfigChannel =
      MethodChannel('mentor_minds/native_config');

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<AuthDestination?> loginWithEmail(
    String email,
    String password,
  ) async {
    final e = email.trim();
    if (e.isEmpty || !_emailRegex.hasMatch(e)) {
      state = state.copyWith(
        isLoading: false,
        error: 'Please enter a valid email address',
      );
      return null;
    }
    if (password.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'Please enter your password',
      );
      return null;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final cred = await _authRepo.signInWithEmail(e, password);
      final user = cred.user;
      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Login failed. Please try again.',
        );
        return null;
      }

      final destination = await _resolveRoleDestination(user.uid);
      state = AuthState(user: user);
      return destination;
    } on FirebaseAuthException catch (ex) {
      debugPrint(
          'loginWithEmail FirebaseAuthException: ${ex.code} — ${ex.message}');
      state = state.copyWith(
        isLoading: false,
        error: _mapLoginError(ex.code),
      );
      return null;
    } catch (e, st) {
      debugPrint('loginWithEmail unknown: $e\n$st');
      state = state.copyWith(
        isLoading: false,
        error: 'Login failed: $e',
      );
      return null;
    }
  }

  Future<AuthDestination?> loginWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final configError = await _googleSignInConfigurationError();
      if (configError != null) {
        state = state.copyWith(
          isLoading: false,
          error: configError,
        );
        return null;
      }

      final cred = await _authRepo.signInWithGoogle();
      if (cred == null) {
        // User dismissed the picker — silent return to idle
        state = state.copyWith(isLoading: false);
        return null;
      }

      final user = cred.user;
      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Google sign-in failed. Please try again.',
        );
        return null;
      }

      await _ensureUserDoc(user);

      final destination = await _resolveRoleDestination(user.uid);
      state = AuthState(user: user);
      return destination;
    } on FirebaseAuthException catch (ex) {
      state = state.copyWith(
        isLoading: false,
        error: _mapLoginError(ex.code),
      );
      return null;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Google sign-in failed. Please try again.',
      );
      return null;
    }
  }

  Future<String?> _googleSignInConfigurationError() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }

    try {
      final status =
          await _nativeConfigChannel.invokeMapMethod<String, dynamic>(
        'googleSignInStatus',
      );
      if (status?['configured'] == true) {
        return null;
      }
      return status?['reason'] as String? ??
          'Google Sign-In is not configured for iOS yet.';
    } on PlatformException {
      return 'Google Sign-In is not configured for iOS yet.';
    }
  }

  Future<AuthDestination?> registerWithEmail({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
    required String role,
    required bool termsAccepted,
  }) async {
    final nameErr = Validators.name(name);
    if (nameErr != null) {
      state = state.copyWith(
        isLoading: false,
        error: nameErr,
        errorField: AuthErrorField.name,
      );
      return null;
    }
    final emailErr = Validators.email(email);
    if (emailErr != null) {
      state = state.copyWith(
        isLoading: false,
        error: emailErr,
        errorField: AuthErrorField.email,
      );
      return null;
    }
    final passErr = Validators.password(password);
    if (passErr != null) {
      state = state.copyWith(
        isLoading: false,
        error: passErr,
        errorField: AuthErrorField.password,
      );
      return null;
    }
    final confirmErr = Validators.confirmPassword(confirmPassword, password);
    if (confirmErr != null) {
      state = state.copyWith(
        isLoading: false,
        error: confirmErr,
        errorField: AuthErrorField.password,
      );
      return null;
    }
    if (!termsAccepted) {
      state = state.copyWith(
        isLoading: false,
        error: 'Please accept the Terms of Service and Privacy Policy',
        errorField: AuthErrorField.generic,
      );
      return null;
    }
    final roleErr = Validators.role(role);
    if (roleErr != null) {
      state = state.copyWith(
        isLoading: false,
        error: roleErr,
        errorField: AuthErrorField.generic,
      );
      return null;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    final trimmedName = name.trim();
    final trimmedEmail = email.trim();

    try {
      final cred = await _authRepo.registerWithEmail(trimmedEmail, password);
      final user = cred.user;
      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Registration failed. Please try again.',
          errorField: AuthErrorField.generic,
        );
        return null;
      }

      await _authRepo.updateDisplayName(trimmedName);

      final (level, subjects) = await _readOnboardingSelection();

      // Write user doc and rewards doc atomically via batch.
      // userDocRef / rewardsDocRef are batch-helper getters on UsersRepository
      // per D-02 documented batch exception.
      final batch = _usersRepo.startBatch();
      final userRef = _usersRepo.userDocRef(user.uid);
      final rewardsRef = _usersRepo.rewardsDocRef(user.uid);

      batch.set(userRef, {
        'uid': user.uid,
        'name': trimmedName,
        'email': trimmedEmail,
        'displayName': trimmedName,
        'role': role,
        'subscriptionType': 'free',
        'points': 0,
        'badges': <String>[],
        'subjects': subjects,
        'level': level,
        // Teachers require admin approval before gaining teacher features
        'isApproved': role != 'teacher',
        'emailVerified': false,
      });
      batch.set(rewardsRef, {
        'userId': user.uid,
        'points': 0,
        'badges': <String>[],
        'history': <Map<String, dynamic>>[],
      });

      await batch.commit();
      await _authRepo.sendEmailVerification();

      state = AuthState(user: user);
      return AuthDestination.studentDashboard;
    } on FirebaseAuthException catch (ex) {
      debugPrint(
          'registerWithEmail FirebaseAuthException: ${ex.code} — ${ex.message}');
      state = state.copyWith(
        isLoading: false,
        error: _mapRegisterError(ex.code),
        errorField: ex.code == 'email-already-in-use'
            ? AuthErrorField.email
            : AuthErrorField.generic,
      );
      return null;
    } on FirebaseException catch (ex) {
      // Firestore / Storage failure (most likely: rules denied the write).
      debugPrint(
          'registerWithEmail FirebaseException: [${ex.plugin}/${ex.code}] ${ex.message}');
      final msg = ex.code == 'permission-denied'
          ? 'We created your account but couldn\'t save your profile '
              '(permission denied). Check Firestore rules.'
          : 'Registration hit a server error: ${ex.message ?? ex.code}';
      state = state.copyWith(
        isLoading: false,
        error: msg,
        errorField: AuthErrorField.generic,
      );
      return null;
    } catch (e, st) {
      debugPrint('registerWithEmail unknown: $e\n$st');
      state = state.copyWith(
        isLoading: false,
        error: 'Registration failed: $e',
        errorField: AuthErrorField.generic,
      );
      return null;
    }
  }

  // Older builds stored 'o_level'/'a_level' in prefs; the canonical format
  // used by /users docs, materials filters, and the tutor callable is
  // 'O Level'/'A Level'. Normalize on read so legacy installs self-heal.
  static String _normalizeLevel(String level) => switch (level) {
        'o_level' => 'O Level',
        'a_level' => 'A Level',
        _ => level,
      };

  Future<(String, List<String>)> _readOnboardingSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final level = _normalizeLevel(prefs.getString('onboarding_level') ?? '');
      final raw = prefs.getString('onboarding_subjects');
      if (raw == null || raw.isEmpty) return (level, const <String>[]);
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return (level, decoded.map((e) => e.toString()).toList());
      }
      return (level, const <String>[]);
    } catch (_) {
      return ('', const <String>[]);
    }
  }

  Future<bool> resendEmailVerification() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _authRepo.sendEmailVerification();
      state = state.copyWith(isLoading: false);
      return true;
    } on FirebaseAuthException catch (ex) {
      state = state.copyWith(
        isLoading: false,
        error: _mapVerificationError(ex.code),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not resend verification email. Please try again.',
      );
      return false;
    }
  }

  Future<void> signOut() async {
    await _authRepo.signOut();
    state = const AuthState();
  }

  Future<bool> resetPassword(String email) async {
    final e = email.trim();
    if (e.isEmpty || !_emailRegex.hasMatch(e)) {
      state = state.copyWith(
        isLoading: false,
        error: 'Please enter a valid email address',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _authRepo.sendPasswordReset(e);
      state = state.copyWith(isLoading: false);
      return true;
    } on FirebaseAuthException catch (ex) {
      state = state.copyWith(
        isLoading: false,
        error: _mapResetError(ex.code),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not send reset email. Please try again.',
      );
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  Future<void> _ensureUserDoc(User user) async {
    final existing = await _usersRepo.getUserDocRaw(user.uid);
    if (existing != null) return;

    await _usersRepo.setUserFields(user.uid, {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoUrl': user.photoURL,
      'role': 'student',
      'subscriptionType': 'free',
    });
  }

  Future<AuthDestination> _resolveRoleDestination(String uid) async {
    try {
      final data = await _usersRepo.getUserDocRaw(uid);
      final role = (data?['role'] as String?)?.trim() ?? 'student';
      return switch (role) {
        'admin' => AuthDestination.admin,
        'teacher' => AuthDestination.teacherDashboard,
        'student' => AuthDestination.studentDashboard,
        'premium_student' => AuthDestination.studentDashboard,
        _ => AuthDestination.studentDashboard,
      };
    } on FirebaseException {
      // Auth succeeded but profile read failed — land on student dashboard
      // rather than blocking the user behind a Firestore hiccup.
      return AuthDestination.studentDashboard;
    }
  }

  String _mapLoginError(String code) => switch (code) {
        'user-not-found' => 'No account found with this email',
        'wrong-password' => 'Incorrect password',
        'invalid-email' => 'Invalid email address',
        'user-disabled' => 'This account has been disabled',
        'too-many-requests' => 'Too many attempts. Try again later.',
        'invalid-credential' => 'Incorrect email or password',
        'network-request-failed' =>
          'Network error. Check your connection and try again.',
        _ => 'Login failed. Please try again.',
      };

  String _mapResetError(String code) => switch (code) {
        'user-not-found' => 'No account found with this email',
        'invalid-email' => 'Invalid email address',
        'network-request-failed' =>
          'Network error. Check your connection and try again.',
        _ => 'Could not send reset email. Please try again.',
      };

  String _mapRegisterError(String code) => switch (code) {
        'email-already-in-use' => 'An account with this email already exists',
        'invalid-email' => 'Invalid email address',
        'weak-password' => 'Password is too weak',
        'operation-not-allowed' => 'Email sign-up is currently disabled',
        'network-request-failed' =>
          'Network error. Check your connection and try again.',
        _ => 'Registration failed. Please try again.',
      };

  String _mapVerificationError(String code) => switch (code) {
        'too-many-requests' =>
          'Too many requests. Please wait a moment and try again.',
        'network-request-failed' =>
          'Network error. Check your connection and try again.',
        _ => 'Could not send verification email. Please try again.',
      };
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final authViewModelProvider =
    StateNotifierProvider.autoDispose<AuthViewModel, AuthState>(
  (ref) => AuthViewModel(
    ref.read(authRepositoryProvider),
    ref.read(usersRepositoryProvider),
  ),
);
