import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:mentor_minds/application/viewmodels/config/remote_config_providers.dart';
import 'package:mentor_minds/application/viewmodels/onboarding/onboarding_viewmodel.dart';
import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/core/theme/app_motion.dart';
import 'package:mentor_minds/core/theme/app_radius.dart';
import 'package:mentor_minds/core/theme/app_spacing.dart';
import 'package:mentor_minds/core/theme/brand_colors.dart';
import 'package:mentor_minds/shared/widgets/pill_button.dart';
import 'package:mentor_minds/shared/widgets/subject_chip.dart';

// ---------------------------------------------------------------------------
// Root screen — owns PageController
// ---------------------------------------------------------------------------

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();

  void _next() => _pageController.nextPage(
        duration: AppMotion.medium,
        curve: AppMotion.standard,
      );

  void _back() => _pageController.previousPage(
        duration: AppMotion.medium,
        curve: AppMotion.standard,
      );

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (page) {
          ref.read(onboardingViewModelProvider.notifier).setPage(page);
        },
        children: [
          _WelcomePage(onNext: _next),
          _SelectLevelPage(onNext: _next, onBack: _back),
          _SelectSubjectsPage(onBack: _back),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PAGE 1 — Welcome
// ---------------------------------------------------------------------------

class _WelcomePage extends ConsumerWidget {
  final VoidCallback onNext;
  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final currentPage = ref.watch(onboardingViewModelProvider).currentPage;

    return Scaffold(
      // Welcome hero is always indigo (brand identity), in both themes.
      backgroundColor: AppColors.kPrimary,
      body: Column(
        children: [
          // Illustration hero — top 55%
          const Expanded(flex: 55, child: _IllustrationPlaceholder()),

          // Bottom card — top corners 28dp; surface follows the theme.
          Container(
            decoration: BoxDecoration(
              color: brand.surface,
              borderRadius: const BorderRadius.vertical(top: AppRadius.xxlRadius),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl + 4,
              AppSpacing.xl,
              AppSpacing.xxxl - 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Learn Smarter with AI',
                  style: AppTextStyles.displayMedium.copyWith(
                    color: brand.textDark,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                )
                    .animate()
                    .fade(duration: 500.ms)
                    .slideY(
                      begin: 0.1,
                      end: 0,
                      duration: 500.ms,
                      curve: AppMotion.standard,
                    ),
                const SizedBox(height: AppSpacing.sm + 2),
                Text(
                  'Your personal O/A Level tutor available 24/7, right in your pocket.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: brand.textMuted,
                    fontSize: 15,
                    height: 1.6,
                  ),
                )
                    .animate(delay: 80.ms)
                    .fade(duration: 500.ms)
                    .slideY(
                      begin: 0.1,
                      end: 0,
                      duration: 500.ms,
                      curve: AppMotion.standard,
                    ),
                const SizedBox(height: AppSpacing.xl),
                _PageDots(currentPage: currentPage)
                    .animate(delay: 160.ms)
                    .fade(duration: 400.ms),
                const SizedBox(height: AppSpacing.xl),
                PillButton(
                  label: 'Get Started',
                  onPressed: onNext,
                )
                    .animate(delay: 200.ms)
                    .fade(duration: 400.ms)
                    .slideY(
                      begin: 0.1,
                      end: 0,
                      duration: 400.ms,
                      curve: AppMotion.standard,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PAGE 2 — Select Level
// ---------------------------------------------------------------------------

class _SelectLevelPage extends ConsumerWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const _SelectLevelPage({required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final state = ref.watch(onboardingViewModelProvider);
    final vm = ref.read(onboardingViewModelProvider.notifier);

    return Scaffold(
      backgroundColor: brand.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OnboardingTopBar(onBack: onBack),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Your Level',
                      style: AppTextStyles.headingLarge.copyWith(
                        color: brand.textDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 22,
                      ),
                    )
                        .animate()
                        .fade(duration: 400.ms)
                        .slideY(
                          begin: 0.08,
                          end: 0,
                          duration: 400.ms,
                          curve: AppMotion.standard,
                        ),
                    const SizedBox(height: AppSpacing.xs + 2),
                    Text(
                      "Select the qualification you're preparing for",
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: brand.textMuted,
                        height: 1.5,
                      ),
                    )
                        .animate(delay: 60.ms)
                        .fade(duration: 400.ms),
                    const SizedBox(height: AppSpacing.xxl - 4),
                    Row(
                      children: [
                        Expanded(
                          child: _LevelCard(
                            emoji: '📘',
                            title: 'O-Level',
                            subtitle: 'Grades 9–10',
                            badge: 'Cambridge / Edexcel',
                            isSelected: state.selectedLevel == 'o_level',
                            onTap: () => vm.setLevel('o_level'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _LevelCard(
                            emoji: '📗',
                            title: 'A-Level',
                            subtitle: 'Grades 11–12',
                            badge: 'Cambridge / Edexcel',
                            isSelected: state.selectedLevel == 'a_level',
                            onTap: () => vm.setLevel('a_level'),
                          ),
                        ),
                      ],
                    )
                        .animate(delay: 120.ms)
                        .fade(duration: 500.ms)
                        .slideY(
                          begin: 0.1,
                          end: 0,
                          duration: 500.ms,
                          curve: AppMotion.standard,
                        ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xxxl - 12,
              ),
              child: PillButton(
                label: 'Continue',
                onPressed: state.canContinueFromLevel ? onNext : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PAGE 3 — Choose Subjects
// ---------------------------------------------------------------------------

class _SelectSubjectsPage extends ConsumerWidget {
  final VoidCallback onBack;
  const _SelectSubjectsPage({required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final state = ref.watch(onboardingViewModelProvider);
    final vm = ref.read(onboardingViewModelProvider.notifier);
    final subjects = ref.watch(currentCurriculumConfigProvider).subjects;
    final count = state.selectedSubjects.length;

    return Scaffold(
      backgroundColor: brand.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OnboardingTopBar(onBack: onBack),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What do you study?',
                      style: AppTextStyles.headingLarge.copyWith(
                        color: brand.textDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 22,
                      ),
                    )
                        .animate()
                        .fade(duration: 400.ms)
                        .slideY(
                          begin: 0.08,
                          end: 0,
                          duration: 400.ms,
                          curve: AppMotion.standard,
                        ),
                    const SizedBox(height: AppSpacing.xs + 2),
                    Text(
                      'Select at least one subject to personalise your experience',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: brand.textMuted,
                        height: 1.5,
                      ),
                    )
                        .animate(delay: 60.ms)
                        .fade(duration: 400.ms),
                    const SizedBox(height: AppSpacing.xl),

                    // Subject chip grid — uses shared SubjectChip widget.
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (var i = 0; i < subjects.length; i++)
                          SubjectChip(
                            label: subjects[i],
                            selected:
                                state.selectedSubjects.contains(subjects[i]),
                            onTap: () => vm.toggleSubject(subjects[i]),
                          )
                              .animate(
                                delay: Duration(milliseconds: 80 + i * 30),
                              )
                              .fade(duration: 300.ms)
                              .scale(
                                begin: const Offset(0.92, 0.92),
                                end: const Offset(1.0, 1.0),
                                duration: 300.ms,
                                curve: AppMotion.standard,
                              ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Selection counter — Duolingo-Brave moment, accent color.
                    AnimatedSwitcher(
                      duration: AppMotion.short,
                      child: count > 0
                          ? Text(
                              '$count ${count == 1 ? 'subject' : 'subjects'} selected',
                              key: ValueKey(count),
                              style: AppTextStyles.labelMedium.copyWith(
                                color: brand.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : const SizedBox(height: 20, key: ValueKey(0)),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xxxl - 12,
              ),
              child: PillButton(
                label: 'Start Learning →',
                onPressed: state.canStartLearning
                    ? () async {
                        final router = ref.read(appRouterProvider);
                        await vm.completeOnboarding(router);
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Illustration hero (Page 1 top area) — always on the indigo brand color.
// ---------------------------------------------------------------------------

class _IllustrationPlaceholder extends StatelessWidget {
  const _IllustrationPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E4BB5), Color(0xFF1A3C8F)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Semantics(
            label: 'MentorBot helping a student learn',
            image: true,
            child: Image.asset(
              'assets/images/illustrations/onboarding_hero.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      )
          .animate()
          .scale(
            begin: const Offset(0.92, 0.92),
            end: const Offset(1.0, 1.0),
            duration: 700.ms,
            curve: AppMotion.standard,
          )
          .fade(duration: 600.ms),
    );
  }
}

// ---------------------------------------------------------------------------
// Level card (Page 2) — themed for light/dark.
// ---------------------------------------------------------------------------

class _LevelCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _LevelCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.short,
        curve: AppMotion.standard,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isSelected
              ? brand.primary.withValues(alpha: 0.08)
              : brand.surface,
          borderRadius: AppRadius.lgBorder,
          border: Border.all(
            color: isSelected ? brand.primary : brand.border,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: AppSpacing.sm + 2),
            Text(
              title,
              style: AppTextStyles.headingMedium.copyWith(
                color: brand.textDark,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: brand.textMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? brand.primary.withValues(alpha: 0.10)
                    : brand.background,
                borderRadius: AppRadius.smBorder,
              ),
              child: Text(
                badge,
                style: AppTextStyles.labelSmall.copyWith(
                  color: isSelected ? brand.primary : brand.textMuted,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page dots indicator
// ---------------------------------------------------------------------------

class _PageDots extends StatelessWidget {
  final int currentPage;
  const _PageDots({required this.currentPage});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Row(
      children: List.generate(3, (i) {
        final active = i == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: AppMotion.standard,
          margin: const EdgeInsets.only(right: AppSpacing.xs + 2),
          width: active ? 16 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? brand.accent : brand.border,
            borderRadius: AppRadius.xsBorder,
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared: top navigation bar (pages 2 & 3)
// ---------------------------------------------------------------------------

class _OnboardingTopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _OnboardingTopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 0,
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48,
          child: IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            tooltip: 'Back',
            color: brand.textDark,
            iconSize: 20,
            splashRadius: 24,
          ),
        ),
      ),
    );
  }
}
