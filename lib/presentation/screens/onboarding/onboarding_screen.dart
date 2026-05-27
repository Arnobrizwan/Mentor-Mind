import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:mentor_minds/application/viewmodels/config/remote_config_providers.dart';
import 'package:mentor_minds/application/viewmodels/onboarding/onboarding_viewmodel.dart';
import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/routes/app_router.dart';

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
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );

  void _back() => _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
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
    final currentPage = ref.watch(onboardingViewModelProvider).currentPage;

    return Scaffold(
      backgroundColor: AppColors.kPrimary,
      body: Column(
        children: [
          // Illustration — top 55%
          const Expanded(
            flex: 55,
            child: _IllustrationPlaceholder(),
          ),

          // Bottom card — top corners 28dp
          Container(
            decoration: const BoxDecoration(
              color: AppColors.kSurface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Learn Smarter with AI',
                  style: AppTextStyles.displayMedium.copyWith(fontSize: 26),
                )
                    .animate()
                    .fade(duration: 500.ms)
                    .slideY(begin: 0.1, end: 0, duration: 500.ms),

                const SizedBox(height: 10),

                Text(
                  'Your personal O/A Level tutor available 24/7, right in your pocket.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.kTextMuted,
                    fontSize: 15,
                    height: 1.6,
                  ),
                )
                    .animate(delay: 80.ms)
                    .fade(duration: 500.ms)
                    .slideY(begin: 0.1, end: 0, duration: 500.ms),

                const SizedBox(height: 24),

                _PageDots(currentPage: currentPage)
                    .animate(delay: 160.ms)
                    .fade(duration: 400.ms),

                const SizedBox(height: 24),

                _OnboardingButton(
                  label: 'Get Started',
                  onPressed: onNext,
                )
                    .animate(delay: 200.ms)
                    .fade(duration: 400.ms)
                    .slideY(begin: 0.1, end: 0, duration: 400.ms),
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
    final state = ref.watch(onboardingViewModelProvider);
    final vm = ref.read(onboardingViewModelProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.kSurface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OnboardingTopBar(onBack: onBack),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Your Level',
                      style: AppTextStyles.headingLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 22,
                      ),
                    )
                        .animate()
                        .fade(duration: 400.ms)
                        .slideY(begin: 0.08, end: 0, duration: 400.ms),

                    const SizedBox(height: 6),

                    Text(
                      "Select the qualification you're preparing for",
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.kTextMuted,
                        height: 1.5,
                      ),
                    )
                        .animate(delay: 60.ms)
                        .fade(duration: 400.ms),

                    const SizedBox(height: 28),

                    // Level cards row
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
                        const SizedBox(width: 12),
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
                        .slideY(begin: 0.1, end: 0, duration: 500.ms),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
              child: _OnboardingButton(
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
    final state = ref.watch(onboardingViewModelProvider);
    final vm = ref.read(onboardingViewModelProvider.notifier);
    final subjects =
        ref.watch(currentCurriculumConfigProvider).subjects;
    final count = state.selectedSubjects.length;

    return Scaffold(
      backgroundColor: AppColors.kSurface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OnboardingTopBar(onBack: onBack),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What do you study?',
                      style: AppTextStyles.headingLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 22,
                      ),
                    )
                        .animate()
                        .fade(duration: 400.ms)
                        .slideY(begin: 0.08, end: 0, duration: 400.ms),

                    const SizedBox(height: 6),

                    Text(
                      'Select at least one subject to personalise your experience',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.kTextMuted,
                        height: 1.5,
                      ),
                    )
                        .animate(delay: 60.ms)
                        .fade(duration: 400.ms),

                    const SizedBox(height: 24),

                    // Subject chip grid — 2 per row
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: 44,
                      ),
                      itemCount: subjects.length,
                      itemBuilder: (context, i) {
                        final subject = subjects[i];
                        final selected =
                            state.selectedSubjects.contains(subject);
                        return _SubjectChip(
                          subject: subject,
                          isSelected: selected,
                          onTap: () => vm.toggleSubject(subject),
                        )
                            .animate(delay: Duration(milliseconds: 80 + i * 30))
                            .fade(duration: 300.ms)
                            .scale(
                              begin: const Offset(0.92, 0.92),
                              end: const Offset(1.0, 1.0),
                              duration: 300.ms,
                              curve: Curves.easeOut,
                            );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Selection counter
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: count > 0
                          ? Text(
                              '$count ${count == 1 ? 'subject' : 'subjects'} selected',
                              key: ValueKey(count),
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.kAccent,
                                fontFamily: 'Inter',
                              ),
                            )
                          : const SizedBox(height: 20, key: ValueKey(0)),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
              child: _OnboardingButton(
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
// Illustration placeholder (Page 1 top area)
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
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Decorative background circles
          const Positioned(
            top: -60,
            right: -60,
            child: _GlowCircle(size: 220, color: Colors.white, opacity: 0.04),
          ),
          const Positioned(
            bottom: -20,
            left: -50,
            child: _GlowCircle(
                size: 180, color: AppColors.kAccent, opacity: 0.10),
          ),
          const Positioned(
            top: 48,
            left: 28,
            child:
                _GlowCircle(size: 56, color: AppColors.kAccent, opacity: 0.14),
          ),
          const Positioned(
            bottom: 60,
            right: 24,
            child: _GlowCircle(size: 40, color: Colors.white, opacity: 0.08),
          ),

          // Main illustration content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // MentorBot floating card
                _FloatingCard(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.kAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            'AI',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'MentorBot',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Ready to help you learn',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Student avatar
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.20),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 52,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 22),

                // Floating subject chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: ['Maths', 'Physics', 'Chemistry']
                      .map(
                        (s) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            s,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          )
              .animate()
              .scale(
                begin: const Offset(0.92, 0.92),
                end: const Offset(1.0, 1.0),
                duration: 700.ms,
                curve: Curves.easeOut,
              )
              .fade(duration: 600.ms),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _GlowCircle(
      {required this.size, required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: opacity),
      ),
    );
  }
}

class _FloatingCard extends StatelessWidget {
  final Widget child;
  const _FloatingCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.kAccent.withValues(alpha: 0.35), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.kAccent.withValues(alpha: 0.18),
            blurRadius: 24,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Level card (Page 2)
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.kPrimary.withValues(alpha: 0.08)
              : AppColors.kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.kPrimary : const Color(0xFFE5E7EB),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 44)),

            const SizedBox(height: 10),

            Text(
              title,
              style: AppTextStyles.headingMedium.copyWith(fontSize: 18),
            ),

            const SizedBox(height: 3),

            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
            ),

            const SizedBox(height: 12),

            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.kPrimary.withValues(alpha: 0.10)
                    : AppColors.kBackground,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: AppTextStyles.labelSmall.copyWith(
                  color: isSelected ? AppColors.kPrimary : AppColors.kTextMuted,
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
// Subject chip (Page 3)
// ---------------------------------------------------------------------------

class _SubjectChip extends StatelessWidget {
  final String subject;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubjectChip({
    required this.subject,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.kPrimary : AppColors.kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.kPrimary,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                subject,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.kPrimary,
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
    return Row(
      children: List.generate(3, (i) {
        final active = i == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(right: 6),
          width: active ? 16 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? AppColors.kAccent : const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(4),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48,
          child: IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: AppColors.kTextDark,
            iconSize: 20,
            splashRadius: 24,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared: primary CTA button — shakes horizontally when tapped while disabled
// ---------------------------------------------------------------------------

class _OnboardingButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;

  const _OnboardingButton({required this.label, this.onPressed});

  @override
  State<_OnboardingButton> createState() => _OnboardingButtonState();
}

class _OnboardingButtonState extends State<_OnboardingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final Animation<double> _shakeOffset;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _shakeOffset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -7.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -7.0, end: 7.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 7.0, end: -5.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 5.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 5.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onPressed != null) {
      widget.onPressed!();
    } else {
      _shakeController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return AnimatedBuilder(
      animation: _shakeOffset,
      builder: (context, child) => Transform.translate(
        offset: Offset(_shakeOffset.value, 0),
        child: child,
      ),
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          height: 52,
          decoration: BoxDecoration(
            color: enabled ? AppColors.kPrimary : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: enabled ? Colors.white : AppColors.kTextMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
