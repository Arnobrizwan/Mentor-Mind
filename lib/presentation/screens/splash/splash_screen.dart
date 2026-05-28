import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:mentor_minds/application/viewmodels/splash/splash_viewmodel.dart';
import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/core/theme/app_motion.dart';
import 'package:mentor_minds/core/theme/app_radius.dart';
import 'package:mentor_minds/core/theme/app_spacing.dart';
import 'package:mentor_minds/shared/widgets/mentor_minds_logo.dart';

// ---------------------------------------------------------------------------
// SplashScreen — intentionally dark in both light & dark theme. The indigo
// gradient is part of the brand identity, so we use the light-theme indigo
// tokens directly (AppColors.kSplashTop/Bottom) regardless of system theme.
// ---------------------------------------------------------------------------

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeOutController;
  late final Animation<double> _screenOpacity;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _fadeOutController = AnimationController(
      vsync: this,
      duration: AppMotion.medium,
    );
    _screenOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeOutController, curve: AppMotion.standard),
    );
    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    final destination = await ref
        .read(splashViewModelProvider.notifier)
        .resolveDestination();
    if (!mounted) return;

    final error = ref.read(splashViewModelProvider).error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error,
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.kError,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(AppSpacing.lg),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
          duration: const Duration(milliseconds: 1800),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted) return;
    }

    await _fadeOutController.forward();
    if (!mounted) return;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    switch (destination) {
      case SplashDestination.studentDashboard:
        context.goNamed(AppRoutes.dashboard);
      case SplashDestination.teacherDashboard:
        context.goNamed(AppRoutes.teacherDashboard);
      case SplashDestination.admin:
        context.goNamed(AppRoutes.admin);
      case SplashDestination.login:
        context.goNamed(AppRoutes.login);
      case SplashDestination.onboarding:
        context.goNamed(AppRoutes.onboarding);
    }
  }

  @override
  void dispose() {
    _fadeOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _screenOpacity,
      builder: (context, child) => Opacity(
        opacity: _screenOpacity.value,
        child: child,
      ),
      child: Scaffold(
        backgroundColor: AppColors.kSplashBottom,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.kSplashTop, AppColors.kSplashBottom],
            ),
          ),
          child: const SafeArea(
            child: Column(
              children: [
                Spacer(flex: 3),
                _LogoSection(),
                Spacer(flex: 3),
                _DotsIndicator(),
                SizedBox(height: AppSpacing.xxxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Logo section: lettermark + app name + tagline
// ---------------------------------------------------------------------------

class _LogoSection extends StatelessWidget {
  const _LogoSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Brand mark — scale up + fade, slight overshoot for delight.
        const _Lettermark()
            .animate()
            .scale(
              begin: const Offset(0.6, 0.6),
              end: const Offset(1.0, 1.0),
              duration: AppMotion.long,
              curve: AppMotion.celebrate,
            )
            .fade(duration: AppMotion.long),

        const SizedBox(height: AppSpacing.xl),

        // App name — staggered 150ms after the mark.
        Text(
          'MentorMinds',
          style: AppTextStyles.displayMedium.copyWith(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        )
            .animate(delay: 150.ms)
            .fade(duration: 500.ms)
            .slideY(
              begin: 0.15,
              end: 0,
              duration: 500.ms,
              curve: AppMotion.standard,
            ),

        const SizedBox(height: AppSpacing.sm),

        // Tagline — staggered 300ms after the mark.
        Text(
          'Learn Smarter. Score Higher.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 14,
            letterSpacing: 0.1,
          ),
        )
            .animate(delay: 300.ms)
            .fade(duration: 500.ms)
            .slideY(
              begin: 0.15,
              end: 0,
              duration: 500.ms,
              curve: AppMotion.standard,
            ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Lettermark — Option B brand mark on a frosted card with a teal bloom.
// The frosted backdrop keeps continuity with the splash gradient; the
// MentorMindsLogo inside renders the M + chat-bubble mark in onDark mode.
// ---------------------------------------------------------------------------

class _Lettermark extends StatelessWidget {
  const _Lettermark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: AppRadius.xxlBorder,
        border: Border.all(
          color: AppColors.kAccent.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.kAccent.withValues(alpha: 0.50),
            blurRadius: 28,
          ),
          BoxShadow(
            color: AppColors.kAccent.withValues(alpha: 0.18),
            blurRadius: 72,
            spreadRadius: 12,
          ),
        ],
      ),
      child: const MentorMindsLogo(
        size: 72,
        mode: MentorMindsLogoMode.onDark,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dots loading indicator — staggered pulse in teal
// ---------------------------------------------------------------------------

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: const BoxDecoration(
            color: AppColors.kAccent,
            shape: BoxShape.circle,
          ),
        )
            .animate(
              delay: Duration(milliseconds: 700 + (i * 160)),
              onPlay: (controller) => controller.repeat(reverse: true),
            )
            .fade(
              begin: 0.20,
              end: 1.0,
              duration: 550.ms,
              curve: AppMotion.settle,
            );
      }),
    );
  }
}
