import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/core/utils/validators.dart';
import 'package:mentor_minds/application/viewmodels/auth/auth_viewmodel.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  late final ProviderSubscription<AuthState> _authListener;

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;
  String _role = 'student';

  // Server-side email error, attached to the exact email value that failed.
  // Cleared automatically as the user edits away from that value.
  String? _duplicateEmail;
  String? _duplicateEmailMsg;

  @override
  void initState() {
    super.initState();
    _authListener = ref.listenManual<AuthState>(authViewModelProvider, (
      previous,
      next,
    ) {
      final err = next.error;
      if (err == null || err == previous?.error || !mounted) return;

      if (next.errorField == AuthErrorField.email) {
        // Render inline: tag the current email value and re-validate the form
        // so the field turns red.
        setState(() {
          _duplicateEmail = _emailCtrl.text.trim();
          _duplicateEmailMsg = err;
        });
        _formKey.currentState?.validate();
        return;
      }

      _showSnack(err, background: AppColors.kError);
    });
    _nameCtrl.addListener(_onFieldChanged);
    _emailCtrl.addListener(_onFieldChanged);
    _passCtrl.addListener(_onFieldChanged);
    _confirmCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _authListener.close();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Derived state
  // -------------------------------------------------------------------------

  _PasswordStrength get _strength {
    final p = _passCtrl.text;
    if (p.isEmpty) return _PasswordStrength.none;
    var met = 0;
    if (p.length >= 8) met++;
    if (RegExp(r'[A-Z]').hasMatch(p)) met++;
    if (RegExp(r'\d').hasMatch(p)) met++;
    return switch (met) {
      3 => _PasswordStrength.strong,
      2 => _PasswordStrength.medium,
      _ => _PasswordStrength.weak,
    };
  }

  bool get _isFormValid {
    if (Validators.name(_nameCtrl.text) != null) return false;
    if (Validators.email(_emailCtrl.text) != null) return false;
    if (_strength != _PasswordStrength.strong) return false;
    if (_confirmCtrl.text != _passCtrl.text) return false;
    if (!_agreedToTerms) return false;
    return true;
  }

  // -------------------------------------------------------------------------
  // Validators (form-level — Validators class is source of truth)
  // -------------------------------------------------------------------------

  String? _emailValidator(String? v) {
    final trimmed = (v ?? '').trim();
    if (_duplicateEmail != null &&
        trimmed.toLowerCase() == _duplicateEmail!.toLowerCase()) {
      return _duplicateEmailMsg;
    }
    return Validators.email(v);
  }

  String? _confirmValidator(String? v) =>
      Validators.confirmPassword(v, _passCtrl.text);

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_isFormValid) return;

    final destination =
        await ref.read(authViewModelProvider.notifier).registerWithEmail(
              name: _nameCtrl.text,
              email: _emailCtrl.text,
              password: _passCtrl.text,
              confirmPassword: _confirmCtrl.text,
              role: _role,
              termsAccepted: _agreedToTerms,
            );

    if (!mounted || destination == null) return;

    // Spec: after successful registration go to /dashboard. The dashboard is
    // responsible for rendering the "please verify your email" banner.
    switch (destination) {
      case AuthDestination.studentDashboard:
        context.goNamed(AppRoutes.dashboard);
      case AuthDestination.teacherDashboard:
        context.goNamed(AppRoutes.teacherDashboard);
      case AuthDestination.admin:
        context.goNamed(AppRoutes.admin);
    }
  }

  void _openLegal(String title) {
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          24 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(title, style: AppTextStyles.headingMedium),
            const SizedBox(height: 12),
            Text(
              'Full document coming soon. By continuing you agree to '
              'MentorMinds handling your data for learning personalization '
              'and exam prep services.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.kTextMuted,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String message, {required Color background}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(milliseconds: 2400),
        ),
      );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(
      authViewModelProvider.select((s) => s.isLoading),
    );

    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: _buildFormView(isLoading),
    );
  }

  Widget _buildFormView(bool isLoading) {
    return AbsorbPointer(
      absorbing: isLoading,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: [
            const _CurvedHeader(title: 'Create Your Account'),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FieldLabel('Full Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameCtrl,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      style: AppTextStyles.bodyMedium,
                      validator: Validators.name,
                      decoration: _dec(
                        hint: 'e.g. Arnob Rizwan',
                        icon: Icons.person_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FieldLabel('Email Address'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      style: AppTextStyles.bodyMedium,
                      validator: _emailValidator,
                      decoration: _dec(
                        hint: 'you@example.com',
                        icon: Icons.mail_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FieldLabel('Password'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscurePass,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      style: AppTextStyles.bodyMedium,
                      validator: Validators.password,
                      decoration: _dec(
                        hint: 'Create a password',
                        icon: Icons.lock_outline_rounded,
                        suffix: IconButton(
                          onPressed: () => setState(
                            () => _obscurePass = !_obscurePass,
                          ),
                          splashRadius: 20,
                          icon: Icon(
                            _obscurePass
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.kTextMuted,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _PasswordStrengthIndicator(strength: _strength),
                    const SizedBox(height: 6),
                    Text(
                      '8+ chars • 1 uppercase • 1 number',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.kTextMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FieldLabel('Confirm Password'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      style: AppTextStyles.bodyMedium,
                      validator: _confirmValidator,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: _dec(
                        hint: 'Re-enter your password',
                        icon: Icons.lock_outline_rounded,
                        suffix: IconButton(
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                          splashRadius: 20,
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.kTextMuted,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _RoleSelector(
                      role: _role,
                      onChanged: (r) => setState(() => _role = r),
                    ),
                    const SizedBox(height: 20),
                    _TermsCheckbox(
                      value: _agreedToTerms,
                      onChanged: (v) =>
                          setState(() => _agreedToTerms = v ?? false),
                      onTapTerms: () => _openLegal('Terms of Service'),
                      onTapPrivacy: () => _openLegal('Privacy Policy'),
                    ),
                    const SizedBox(height: 24),
                    _CreateAccountButton(
                      enabled: _isFormValid,
                      isLoading: isLoading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 24),
                    const _LoginPrompt(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.kTextMuted, size: 20),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      suffixIcon: suffix,
    );
  }
}

// ---------------------------------------------------------------------------
// Curved gradient header
// ---------------------------------------------------------------------------

class _CurvedHeader extends StatelessWidget {
  final String title;
  const _CurvedHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipPath(
          clipper: _CurvedHeaderClipper(),
          child: Container(
            width: double.infinity,
            height: 220,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.kSplashTop, AppColors.kSplashBottom],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 48), // room for back button
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ).animate().fade(duration: 450.ms).slideY(
                          begin: 0.15,
                          end: 0,
                          duration: 450.ms,
                          curve: Curves.easeOut,
                        ),
                    const SizedBox(height: 6),
                    Text(
                      'Join MentorMinds and start learning smarter.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.78),
                      ),
                    ).animate(delay: 120.ms).fade(duration: 450.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: IconButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.goNamed(AppRoutes.login);
                  }
                },
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                splashRadius: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CurvedHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height - 36)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height + 12,
        size.width,
        size.height - 36,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ---------------------------------------------------------------------------
// Password strength indicator
// ---------------------------------------------------------------------------

enum _PasswordStrength { none, weak, medium, strong }

class _PasswordStrengthIndicator extends StatelessWidget {
  final _PasswordStrength strength;
  const _PasswordStrengthIndicator({required this.strength});

  @override
  Widget build(BuildContext context) {
    final (fraction, color, label) = switch (strength) {
      _PasswordStrength.none => (0.0, const Color(0xFFE5E7EB), ''),
      _PasswordStrength.weak => (0.33, AppColors.kError, 'Weak'),
      _PasswordStrength.medium => (0.66, AppColors.kGold, 'Medium'),
      _PasswordStrength.strong => (1.0, AppColors.kAccent, 'Strong'),
    };

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                Container(height: 6, color: const Color(0xFFE5E7EB)),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  widthFactor: fraction,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 6,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 64,
          child: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: AppTextStyles.labelSmall.copyWith(
                color: strength == _PasswordStrength.none
                    ? AppColors.kTextMuted
                    : color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Role selector — Student | Teacher chips
// ---------------------------------------------------------------------------

class _RoleSelector extends StatelessWidget {
  final String role;
  final ValueChanged<String> onChanged;

  const _RoleSelector({required this.role, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'I am a:',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.kTextDark,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _RoleChip(
                label: 'Student',
                icon: Icons.school_outlined,
                selected: role == 'student',
                onTap: () => onChanged('student'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RoleChip(
                label: 'Teacher',
                icon: Icons.menu_book_outlined,
                selected: role == 'teacher',
                onTap: () => onChanged('teacher'),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: role == 'teacher'
              ? const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: _TeacherNotice(),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.kPrimary : AppColors.kSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.kPrimary : const Color(0xFFE5E7EB),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : AppColors.kTextMuted,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.labelLarge.copyWith(
                  color: selected ? Colors.white : AppColors.kTextDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherNotice extends StatelessWidget {
  const _TeacherNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.kGold.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.kGold.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.kGold,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Teacher accounts require admin approval before you can '
              'publish materials.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.kTextDark,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Terms checkbox with tappable legal links
// ---------------------------------------------------------------------------

class _TermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onTapTerms;
  final VoidCallback onTapPrivacy;

  const _TermsCheckbox({
    required this.value,
    required this.onChanged,
    required this.onTapTerms,
    required this.onTapPrivacy,
  });

  @override
  Widget build(BuildContext context) {
    final linkStyle = AppTextStyles.bodyMedium.copyWith(
      color: AppColors.kPrimary,
      fontWeight: FontWeight.w600,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.kPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: RichText(
                text: TextSpan(
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.kTextDark,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms of Service',
                      style: linkStyle,
                      recognizer: TapGestureRecognizer()..onTap = onTapTerms,
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: linkStyle,
                      recognizer: TapGestureRecognizer()..onTap = onTapPrivacy,
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Create Account button — disabled until form is valid
// ---------------------------------------------------------------------------

class _CreateAccountButton extends StatelessWidget {
  final bool enabled;
  final bool isLoading;
  final VoidCallback onPressed;

  const _CreateAccountButton({
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && !isLoading;
    return ElevatedButton(
      onPressed: active ? onPressed : null,
      style: ElevatedButton.styleFrom(
        disabledBackgroundColor: AppColors.kPrimary.withOpacity(0.35),
        disabledForegroundColor: Colors.white,
      ),
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : const Text('Create Account'),
    );
  }
}

// ---------------------------------------------------------------------------
// Login prompt footer
// ---------------------------------------------------------------------------

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.kTextMuted,
          ),
        ),
        GestureDetector(
          onTap: () => context.goNamed(AppRoutes.login),
          behavior: HitTestBehavior.opaque,
          child: Text(
            'Login',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.kPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Field label — small helper used across all form fields
// ---------------------------------------------------------------------------

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.labelMedium.copyWith(color: AppColors.kTextDark),
    );
  }
}
