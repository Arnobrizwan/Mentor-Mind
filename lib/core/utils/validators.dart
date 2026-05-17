// Shared validation rules used by auth forms and AuthViewModel.
// Each method returns null when valid, or a user-facing error message.

abstract final class Validators {
  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _upperRegex = RegExp(r'[A-Z]');
  static final RegExp _digitRegex = RegExp(r'\d');

  static String? name(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Please enter your full name';
    if (v.length < 2) return 'Name is too short';
    return null;
  }

  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Please enter your email';
    if (!_emailRegex.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  // Strong password for registration: 8+ chars, 1 uppercase, 1 number.
  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Please create a password';
    if (v.length < 8) return 'Password must be at least 8 characters';
    if (!_upperRegex.hasMatch(v)) return 'Include at least 1 uppercase letter';
    if (!_digitRegex.hasMatch(v)) return 'Include at least 1 number';
    return null;
  }

  // Lighter check for login: never reveal password policy of an existing account.
  static String? loginPassword(String? value) {
    if ((value ?? '').isEmpty) return 'Please enter your password';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return 'Please re-enter your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? role(String? value) {
    if (value != 'student' && value != 'teacher') {
      return 'Please select a valid role';
    }
    return null;
  }
}
