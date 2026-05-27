import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:mentor_minds/application/viewmodels/auth/auth_viewmodel.dart';
import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/core/theme/app_motion.dart';
import 'package:mentor_minds/core/theme/app_radius.dart';
import 'package:mentor_minds/core/theme/app_spacing.dart';
import 'package:mentor_minds/core/theme/brand_colors.dart';
import 'package:mentor_minds/shared/widgets/mentor_minds_logo.dart';
import 'package:mentor_minds/shared/widgets/pill_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  late final ProviderSubscription<AuthState> _authListener;
  bool _obscurePass = true;

  @override
  void initState() {
    super.initState();
    _authListener = ref.listenManual<AuthState>(authViewModelProvider, (
      previous,
      next,
    ) {
      final err = next.error;
      if (err != null && err != previous?.error && mounted) {
        _showSnack(err, background: context.brand.error);
      }
    });
  }

  @override
  void dispose() {
    _authListener.close();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final destination = await ref
        .read(authViewModelProvider.notifier)
        .loginWithEmail(_emailCtrl.text, _passCtrl.text);

    if (!mounted || destination == null) return;
    _navigateTo(destination);
  }

  Future<void> _googleSignIn() async {
    FocusScope.of(context).unfocus();

    final destination =
        await ref.read(authViewModelProvider.notifier).loginWithGoogle();

    if (!mounted || destination == null) return;
    _navigateTo(destination);
  }

  void _navigateTo(AuthDestination destination) {
    switch (destination) {
      case AuthDestination.studentDashboard:
        context.goNamed(AppRoutes.dashboard);
      case AuthDestination.teacherDashboard:
        context.goNamed(AppRoutes.teacherDashboard);
      case AuthDestination.admin:
        context.goNamed(AppRoutes.admin);
    }
  }

  Future<void> _onForgotPassword() async {
    FocusScope.of(context).unfocus();

    final email = await _showResetDialog(initial: _emailCtrl.text);
    if (email == null || email.trim().isEmpty || !mounted) return;

    final ok =
        await ref.read(authViewModelProvider.notifier).resetPassword(email);
    if (!mounted || !ok) return;

    _showSnack('Reset email sent!', background: context.brand.accent);
  }

  Future<String?> _showResetDialog({required String initial}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final brand = ctx.brand;
        return AlertDialog(
          backgroundColor: brand.surface,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
          title: Text(
            'Reset password',
            style: AppTextStyles.headingMedium.copyWith(color: brand.textDark),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Enter your email and we'll send you a reset link.",
                style: AppTextStyles.bodyMedium.copyWith(
                  color: brand.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                style: AppTextStyles.bodyMedium.copyWith(color: brand.textDark),
                decoration: const InputDecoration(hintText: 'you@example.com'),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md,
          ),
          actions: [
            PillButton(
              label: 'Cancel',
              variant: PillVariant.ghost,
              fullWidth: false,
              dense: true,
              onPressed: () => Navigator.of(ctx).pop(null),
            ),
            const SizedBox(width: AppSpacing.sm),
            PillButton(
              label: 'Send',
              fullWidth: false,
              dense: true,
              onPressed: () => Navigator.of(ctx).pop(controller.text),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
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
          margin: const EdgeInsets.all(AppSpacing.lg),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
          duration: const Duration(milliseconds: 2400),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final isLoading = ref.watch(
      authViewModelProvider.select((s) => s.isLoading),
    );

    return Scaffold(
      backgroundColor: brand.background,
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: isLoading,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.vertical,
              ),
              child: IntrinsicHeight(
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.xxxl - 8),
                      const _Header(),
                      const SizedBox(height: AppSpacing.xxl + 4),
                      const _TitleBlock()
                          .animate(delay: 220.ms)
                          .fade(duration: 500.ms)
                          .slideY(
                            begin: 0.12,
                            end: 0,
                            duration: 500.ms,
                            curve: AppMotion.standard,
                          ),
                      const SizedBox(height: AppSpacing.xxl - 4),
                      _FormFields(
                        emailCtrl: _emailCtrl,
                        passCtrl: _passCtrl,
                        obscurePass: _obscurePass,
                        onToggleObscure: () =>
                            setState(() => _obscurePass = !_obscurePass),
                        onSubmitEditing: _submit,
                        onForgotPassword: _onForgotPassword,
                      ).animate(delay: 340.ms).fade(duration: 500.ms).slideY(
                            begin: 0.1,
                            end: 0,
                            duration: 500.ms,
                            curve: AppMotion.standard,
                          ),
                      const SizedBox(height: AppSpacing.xl),
                      PillButton(
                        label: 'Sign In',
                        onPressed: isLoading ? null : _submit,
                        loading: isLoading,
                      ).animate(delay: 440.ms).fade(duration: 450.ms),
                      const SizedBox(height: AppSpacing.xl),
                      const _OrDivider()
                          .animate(delay: 520.ms)
                          .fade(duration: 400.ms),
                      const SizedBox(height: AppSpacing.lg + 4),
                      _GoogleButton(
                        isDisabled: isLoading,
                        onPressed: _googleSignIn,
                      ).animate(delay: 580.ms).fade(duration: 450.ms),
                      const Spacer(),
                      const SizedBox(height: AppSpacing.xl),
                      const _RegisterPrompt()
                          .animate(delay: 680.ms)
                          .fade(duration: 400.ms),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header — logo badge + wordmark
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Column(
      children: [
        const _LogoBadge()
            .animate()
            .scale(
              begin: const Offset(0.7, 0.7),
              end: const Offset(1.0, 1.0),
              duration: 550.ms,
              curve: AppMotion.celebrate,
            )
            .fade(duration: 550.ms),
        const SizedBox(height: AppSpacing.md),
        Text(
          'MentorMinds',
          style: AppTextStyles.headingMedium.copyWith(
            color: brand.primary,
            letterSpacing: 0.1,
          ),
        ).animate(delay: 120.ms).fade(duration: 500.ms),
      ],
    );
  }
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      width: 76,
      height: 76,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.kSplashTop, AppColors.kSplashBottom],
        ),
        borderRadius: AppRadius.xlBorder,
        boxShadow: [
          BoxShadow(
            color: brand.primary.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: brand.accent.withValues(alpha: 0.22),
            blurRadius: 36,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const MentorMindsLogo(
        size: 60,
        mode: MentorMindsLogoMode.onDark,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Title block — "Welcome back" + subtitle
// ---------------------------------------------------------------------------

class _TitleBlock extends StatelessWidget {
  const _TitleBlock();

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back',
          style: AppTextStyles.displayMedium.copyWith(color: brand.textDark),
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        Text(
          'Sign in to continue your learning journey.',
          style: AppTextStyles.bodyMedium.copyWith(color: brand.textMuted),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Form fields — email, password, forgot password link
// ---------------------------------------------------------------------------

class _FormFields extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool obscurePass;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmitEditing;
  final VoidCallback onForgotPassword;

  const _FormFields({
    required this.emailCtrl,
    required this.passCtrl,
    required this.obscurePass,
    required this.onToggleObscure,
    required this.onSubmitEditing,
    required this.onForgotPassword,
  });

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? _validateEmail(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Please enter your email';
    if (!_emailRegex.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) return 'Please enter your password';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel('Email'),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          style: AppTextStyles.bodyMedium.copyWith(color: brand.textDark),
          validator: _validateEmail,
          decoration: InputDecoration(
            hintText: 'you@example.com',
            prefixIcon: Icon(
              Icons.mail_outline_rounded,
              color: brand.textMuted,
              size: 20,
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _FieldLabel('Password'),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: passCtrl,
          obscureText: obscurePass,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onFieldSubmitted: (_) => onSubmitEditing(),
          style: AppTextStyles.bodyMedium.copyWith(color: brand.textDark),
          validator: _validatePassword,
          decoration: InputDecoration(
            hintText: 'Enter your password',
            prefixIcon: Icon(
              Icons.lock_outline_rounded,
              color: brand.textMuted,
              size: 20,
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 44, minHeight: 44),
            suffixIcon: IconButton(
              onPressed: onToggleObscure,
              splashRadius: 20,
              icon: Icon(
                obscurePass
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: brand.textMuted,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onForgotPassword,
            style: TextButton.styleFrom(
              foregroundColor: brand.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xs,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Forgot password?',
              style: AppTextStyles.labelMedium.copyWith(color: brand.primary),
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Text(
      text,
      style: AppTextStyles.labelMedium.copyWith(color: brand.textDark),
    );
  }
}

// ---------------------------------------------------------------------------
// Divider — "or continue with"
// ---------------------------------------------------------------------------

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Row(
      children: [
        Expanded(child: Divider(color: brand.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'or continue with',
            style: AppTextStyles.bodySmall.copyWith(color: brand.textMuted),
          ),
        ),
        Expanded(child: Divider(color: brand.border)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Google Sign-In button — kept custom (G glyph + brand-specific layout).
// ---------------------------------------------------------------------------

class _GoogleButton extends StatelessWidget {
  final bool isDisabled;
  final VoidCallback onPressed;

  const _GoogleButton({required this.isDisabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return OutlinedButton(
      onPressed: isDisabled ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        backgroundColor: brand.surface,
        side: BorderSide(color: brand.border),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _GoogleGlyph(),
          const SizedBox(width: AppSpacing.md),
          Text(
            'Continue with Google',
            style: AppTextStyles.labelLarge.copyWith(color: brand.textDark),
          ),
        ],
      ),
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF4285F4),
        borderRadius: AppRadius.xsBorder,
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.0,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Register prompt — footer link to /auth/register
// ---------------------------------------------------------------------------

class _RegisterPrompt extends StatelessWidget {
  const _RegisterPrompt();

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "New to MentorMinds? ",
          style: AppTextStyles.bodyMedium.copyWith(color: brand.textMuted),
        ),
        GestureDetector(
          onTap: () => context.goNamed(AppRoutes.register),
          behavior: HitTestBehavior.opaque,
          child: Text(
            'Create account',
            style: AppTextStyles.labelMedium.copyWith(
              color: brand.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
