import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:mentor_minds/application/viewmodels/dashboard/dashboard_viewmodel.dart';
import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/core/theme/app_motion.dart';
import 'package:mentor_minds/core/theme/app_radius.dart';
import 'package:mentor_minds/core/theme/app_spacing.dart';
import 'package:mentor_minds/core/theme/brand_colors.dart';
import 'package:mentor_minds/data/models/badge_item.dart';
import 'package:mentor_minds/data/models/daily_challenge.dart';
import 'package:mentor_minds/data/models/material_item.dart';
import 'package:mentor_minds/data/models/session_item.dart';
import 'package:mentor_minds/data/models/subject_progress.dart';
import 'package:mentor_minds/data/services/messaging_service.dart';
import 'package:mentor_minds/shared/widgets/empty_state.dart';
import 'package:mentor_minds/shared/widgets/section_header.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _navIndex = 0;
  late final ProviderSubscription<DashboardState> _dashboardListener;
  bool _fcmRegistered = false;

  // Daily-login award toast — one-shot pill anchored below the app bar.
  int? _awardAmount;
  Timer? _awardHideTimer;

  @override
  void initState() {
    super.initState();
    _dashboardListener = ref.listenManual<DashboardState>(
      dashboardViewModelProvider,
      (prev, next) {
        final wasAwarded = prev?.justAwardedDailyPoints ?? false;
        if (next.justAwardedDailyPoints && !wasAwarded && mounted) {
          _showAwardToast(next.dailyAwardAmount);
          ref.read(dashboardViewModelProvider.notifier).ackDailyAward();
        }
      },
    );
  }

  @override
  void dispose() {
    _dashboardListener.close();
    _awardHideTimer?.cancel();
    super.dispose();
  }

  void _onNavTap(int index) {
    if (index == _navIndex) return;
    setState(() => _navIndex = index);
    switch (index) {
      case 0:
        break;
      case 1:
        context.goNamed(AppRoutes.tutor);
      case 2:
        context.goNamed(AppRoutes.materials);
      case 3:
        context.goNamed(AppRoutes.rewards);
      case 4:
        context.goNamed(AppRoutes.profile);
    }
  }

  void _showAwardToast(int amount) {
    setState(() => _awardAmount = amount);
    _awardHideTimer?.cancel();
    _awardHideTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      setState(() => _awardAmount = null);
    });
  }

  void _maybeRegisterFcm(DashboardState state) {
    if (!ref.read(fcmRegistrationEnabledProvider)) return;
    final user = state.user;
    if (user == null || _fcmRegistered) return;
    _fcmRegistered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final isPremium = user.subscriptionType == 'premium';
      await ref.read(messagingServiceProvider).ensureRegistered(
            context: context,
            role: user.role,
            isPremium: isPremium,
          );
      if (!mounted) return;
      ref.read(messagingServiceProvider).handlePendingNavigation(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final state = ref.watch(dashboardViewModelProvider);
    _maybeRegisterFcm(state);

    return Scaffold(
      backgroundColor: brand.background,
      body: Stack(
        children: [
          RefreshIndicator(
            color: brand.primary,
            onRefresh: () =>
                ref.read(dashboardViewModelProvider.notifier).refresh(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _DashboardAppBar(
                  firstName: state.firstName,
                  points: state.points,
                  streak: state.streak,
                  level: state.user?.level ?? '',
                  notificationCount: state.notificationCount,
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl,
                  ),
                  sliver: SliverList.list(
                    children: [
                      const _QuickActionRow(),
                      const SizedBox(height: AppSpacing.xl - 4),
                      _DailyChallengeCard(
                        challenge: state.dailyChallenge,
                        resetsAt: state.dailyChallengeResetsAt,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _SubjectProgressSection(subjects: state.subjects),
                      const SizedBox(height: AppSpacing.xl),
                      _RecentSessionsSection(sessions: state.recentSessions),
                      const SizedBox(height: AppSpacing.xl),
                      _MaterialsCarousel(materials: state.materials),
                      const SizedBox(height: AppSpacing.xl),
                      _BadgeShowcase(
                        badges: state.badges,
                        totalCount: state.totalBadgeCount,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_awardAmount != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + kToolbarHeight +
                  AppSpacing.md,
              left: 0,
              right: 0,
              child: Center(child: _AwardToast(amount: _awardAmount!)),
            ),
        ],
      ),
      bottomNavigationBar: _BottomNav(index: _navIndex, onTap: _onNavTap),
    );
  }
}

// ---------------------------------------------------------------------------
// Daily-login award toast — "+5 pts 🎉" (gold pill, identical in both themes)
// ---------------------------------------------------------------------------

class _AwardToast extends StatelessWidget {
  final int amount;
  const _AwardToast({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.kGold,
        borderRadius: AppRadius.pillBorder,
        boxShadow: [
          BoxShadow(
            color: AppColors.kGold.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 18, color: Colors.white),
          const SizedBox(width: AppSpacing.xs + 2),
          Text(
            '+$amount pts \u{1F389}',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
        ],
      ),
    )
        .animate()
        .scale(
          begin: const Offset(0.7, 0.7),
          end: const Offset(1.0, 1.0),
          duration: 260.ms,
          curve: AppMotion.celebrate,
        )
        .fade(duration: 220.ms)
        .then(delay: 1600.ms)
        .fade(begin: 1, end: 0, duration: 400.ms)
        .slideY(begin: 0, end: -0.3, duration: 400.ms);
  }
}

// ---------------------------------------------------------------------------
// Sliver app bar — soft hero with a faded illustration backdrop, a stack-in
// greeting card, and animated chips. Replaces the previous flat-indigo block.
// ---------------------------------------------------------------------------

class _DashboardAppBar extends StatelessWidget {
  final String firstName;
  final int points;
  final int streak;
  final String level;
  final int notificationCount;

  const _DashboardAppBar({
    required this.firstName,
    required this.points,
    required this.streak,
    required this.level,
    required this.notificationCount,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    const expandedHeight = 220.0;
    return SliverAppBar(
      pinned: true,
      expandedHeight: expandedHeight,
      backgroundColor: brand.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: brand.textDark,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: LayoutBuilder(
        builder: (ctx, constraints) {
          final topInset = MediaQuery.of(ctx).padding.top;
          final maxH = expandedHeight + topInset;
          final minH = kToolbarHeight + topInset;
          final t =
              ((constraints.maxHeight - minH) / (maxH - minH)).clamp(0.0, 1.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              // Soft wash behind everything — indigo bleed at the top fading
              // into the page background, so the action row feels continuous.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      brand.primary.withValues(alpha: 0.10),
                      brand.accent.withValues(alpha: 0.06),
                      brand.background,
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
              // Faded illustration backdrop — top-right, gently floating.
              // Opacity scales with the collapse factor so the hero fades as
              // the user scrolls into the rest of the dashboard.
              Positioned(
                top: topInset + 8,
                right: 8,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.26 * t,
                    child: const _FloatingHeroArt(size: 120),
                  ),
                ),
              ),
              // Top bar — wordmark + bell.
              Positioned(
                top: topInset,
                left: 0,
                right: 0,
                height: kToolbarHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Row(
                    children: [
                      Text(
                        'MentorMinds',
                        style: AppTextStyles.headingMedium.copyWith(
                          color: brand.primary,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const Spacer(),
                      _NotificationBell(count: notificationCount),
                    ],
                  ),
                ),
              ),
              // Tip strip — sits between the wordmark and the greeting card,
              // filling the visual gap. Time-of-day aware lead + a rotating
              // daily study tip selected by day-of-year (deterministic).
              Positioned(
                top: topInset + kToolbarHeight - 4,
                left: AppSpacing.lg,
                right: 110,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: t,
                    child: _HeroTipStrip(now: DateTime.now()),
                  ),
                ),
              ),
              // Expanded — greeting card stacks in over the backdrop.
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.md,
                child: IgnorePointer(
                  ignoring: t < 0.15,
                  child: Opacity(
                    opacity: t,
                    child: _HeroGreetingCard(
                      firstName: firstName,
                      points: points,
                      streak: streak,
                      level: level,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _FloatingHeroArt — onboarding_hero.png with a subtle vertical float loop.
// Pure decoration, ignored for input. Errors fall back to a soft sparkle so
// missing assets never leave a broken UI behind.
// ---------------------------------------------------------------------------

class _FloatingHeroArt extends StatefulWidget {
  final double size;
  const _FloatingHeroArt({required this.size});

  @override
  State<_FloatingHeroArt> createState() => _FloatingHeroArtState();
}

class _FloatingHeroArtState extends State<_FloatingHeroArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final dy = (Curves.easeInOut.transform(_ctrl.value) - 0.5) * 8;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: SizedBox(
        height: widget.size,
        width: widget.size,
        child: Image.asset(
          'assets/images/illustrations/onboarding_hero.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _HeroTipStrip — short two-line tagline that fills the gap between the
// wordmark and the greeting card. Line 1 is time-of-day aware; line 2 is a
// rotating study tip selected by day-of-year (deterministic per day so a
// student sees the same tip across re-opens).
// ---------------------------------------------------------------------------

class _HeroTipStrip extends StatelessWidget {
  final DateTime now;
  const _HeroTipStrip({required this.now});

  static const _tips = <String>[
    '25 focused min > 2 h scattered.',
    'Pick one weak topic. Master it.',
    'Active recall > re-reading.',
    'Skim yesterday’s notes (5 min).',
    'Quick wins compound. Show up.',
    'Small habits build big grades.',
    'One question = one step ahead.',
    'Past papers > endless theory.',
    'Sleep is study. Don’t skip it.',
    'Teach it. That’s how it sticks.',
  ];

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final lead = _leadFor(now);
    final tip = _tips[_dayOfYear(now) % _tips.length];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('✨', style: TextStyle(fontSize: 14, height: 1)),
        const SizedBox(width: AppSpacing.xs + 2),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lead,
                style: AppTextStyles.bodySmall.copyWith(
                  color: brand.primary,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ).animate().fadeIn(duration: 320.ms).slideX(begin: -0.15, end: 0),
              const SizedBox(height: 1),
              Text(
                tip,
                style: AppTextStyles.bodySmall.copyWith(
                  color: brand.textMuted,
                  fontSize: 11.5,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ).animate().fadeIn(delay: 120.ms, duration: 320.ms)
                  .slideX(begin: -0.15, end: 0),
            ],
          ),
        ),
      ],
    );
  }

  static String _leadFor(DateTime now) {
    final h = now.hour;
    if (h < 6) return 'Burning the midnight oil?';
    if (h < 12) return 'Ready when you are.';
    if (h < 17) return 'Pick up where you left off.';
    if (h < 21) return 'One more topic before you wind down?';
    return 'Quick session before bed?';
  }

  // Days since Jan 1 of the same year. Deterministic across reboots and time
  // zones (uses local-time DateTime as caller passes in).
  static int _dayOfYear(DateTime d) {
    final start = DateTime(d.year, 1, 1);
    return d.difference(start).inDays;
  }
}

// ---------------------------------------------------------------------------
// _HeroGreetingCard — white card stacked over the backdrop. Holds the
// greeting line and a chip row (streak / points / level).
// ---------------------------------------------------------------------------

class _HeroGreetingCard extends StatelessWidget {
  final String firstName;
  final int points;
  final int streak;
  final String level;

  const _HeroGreetingCard({
    required this.firstName,
    required this.points,
    required this.streak,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final greeting = _greetingFor(DateTime.now());
    final dateLabel = DateFormat('EEE, MMM d').format(DateTime.now());
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md + 2, AppSpacing.lg, AppSpacing.md + 2,
      ),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: AppRadius.lgBorder,
        boxShadow: [
          BoxShadow(
            color: brand.primary.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting, $firstName! \u{1F44B}',
            style: AppTextStyles.headingMedium.copyWith(
              color: brand.textDark,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.25, end: 0),
          const SizedBox(height: AppSpacing.xs),
          Text(
            dateLabel,
            style: AppTextStyles.bodySmall.copyWith(
              color: brand.textMuted,
              height: 1.2,
            ),
          ).animate().fadeIn(delay: 80.ms, duration: 350.ms),
          const SizedBox(height: AppSpacing.sm + 2),
          Wrap(
            spacing: AppSpacing.xs + 2,
            runSpacing: AppSpacing.xs + 2,
            children: [
              _HeroChip(
                emoji: '\u{1F525}',
                label: '$streak day${streak == 1 ? '' : 's'}',
                background: brand.gold,
                foreground: Colors.white,
              ).animate().fadeIn(delay: 200.ms, duration: 300.ms)
                  .slideX(begin: -0.2, end: 0),
              _HeroChip(
                icon: Icons.star_rounded,
                label: '$points pts',
                background: brand.accent,
                foreground: Colors.white,
              ).animate().fadeIn(delay: 300.ms, duration: 300.ms)
                  .slideX(begin: -0.2, end: 0),
              if (level.isNotEmpty)
                _HeroChip(
                  icon: Icons.school_rounded,
                  label: level,
                  background: brand.primary,
                  foreground: Colors.white,
                ).animate().fadeIn(delay: 400.ms, duration: 300.ms)
                    .slideX(begin: -0.2, end: 0),
            ],
          ),
        ],
      ),
    );
  }

  String _greetingFor(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

// ---------------------------------------------------------------------------
// _HeroChip — pill chip used inside _HeroGreetingCard. One of `emoji` or
// `icon` is shown on the left; `label` is always shown.
// ---------------------------------------------------------------------------

class _HeroChip extends StatelessWidget {
  final String? emoji;
  final IconData? icon;
  final String label;
  final Color background;
  final Color foreground;

  const _HeroChip({
    this.emoji,
    this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  }) : assert(emoji != null || icon != null);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.pillBorder,
        boxShadow: [
          BoxShadow(
            color: background.withValues(alpha: 0.30),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 14, color: foreground)
          else
            Text(emoji!, style: const TextStyle(fontSize: 13, height: 1)),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: foreground,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final int count;
  const _NotificationBell({required this.count});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Material(
      color: brand.primary.withValues(alpha: 0.10),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () => context.goNamed(AppRoutes.notifications),
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs + 2),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.notifications_none_rounded,
                color: brand.primary,
                size: 22,
              ),
              if (count > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: brand.error,
                      borderRadius: AppRadius.pillBorder,
                      border:
                          Border.all(color: brand.background, width: 1.5),
                    ),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick action row — Ask AI / Materials / Rewards
// ---------------------------------------------------------------------------

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow();

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Row(
      children: [
        Expanded(
          child: _QuickActionTile(
            emoji: '\u{1F916}',
            label: 'Ask AI',
            tint: brand.primary,
            tintDark: _darken(brand.primary, 0.18),
            onTap: () => context.goNamed(AppRoutes.tutor),
          ).animate().fadeIn(delay: 250.ms, duration: 350.ms)
              .slideY(begin: 0.2, end: 0),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _QuickActionTile(
            emoji: '\u{1F4DA}',
            label: 'Materials',
            tint: brand.accent,
            tintDark: _darken(brand.accent, 0.22),
            onTap: () => context.goNamed(AppRoutes.materials),
          ).animate().fadeIn(delay: 350.ms, duration: 350.ms)
              .slideY(begin: 0.2, end: 0),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _QuickActionTile(
            emoji: '\u{1F3C6}',
            label: 'Rewards',
            tint: brand.gold,
            tintDark: _darken(brand.gold, 0.22),
            onTap: () => context.goNamed(AppRoutes.rewards),
          ).animate().fadeIn(delay: 450.ms, duration: 350.ms)
              .slideY(begin: 0.2, end: 0),
        ),
      ],
    );
  }

  // Returns [c] shifted by [amount] toward black in HSL — used for the
  // top-left → bottom-right gradient on each action tile so they read as
  // dimensional rather than flat.
  static Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
}

class _QuickActionTile extends StatefulWidget {
  final String emoji;
  final String label;
  final Color tint;
  final Color tintDark;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.emoji,
    required this.label,
    required this.tint,
    required this.tintDark,
    required this.onTap,
  });

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.lgBorder,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          borderRadius: AppRadius.lgBorder,
          child: Container(
            height: 84,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.lgBorder,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [widget.tint, widget.tintDark],
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.tint.withValues(alpha: 0.30),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(widget.emoji,
                    style: const TextStyle(fontSize: 28, height: 1)),
                const SizedBox(height: AppSpacing.xs + 2),
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Daily challenge — teal gradient (brand identity, identical in both themes)
// ---------------------------------------------------------------------------

class _DailyChallengeCard extends StatefulWidget {
  final DailyChallenge? challenge;
  final DateTime resetsAt;
  const _DailyChallengeCard({
    required this.challenge,
    required this.resetsAt,
  });

  @override
  State<_DailyChallengeCard> createState() => _DailyChallengeCardState();
}

class _DailyChallengeCardState extends State<_DailyChallengeCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _countdown() {
    final remaining = widget.resetsAt.difference(DateTime.now());
    if (remaining.isNegative) return 'Resetting now…';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    return 'Resets in ${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg + 2),
      decoration: BoxDecoration(
        borderRadius: AppRadius.xlBorder,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.kAccent, Color(0xFF009B82)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.kAccent.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Daily Challenge \u{1F3AF}',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: AppRadius.pillBorder,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      _countdown(),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.challenge != null
                ? "${widget.challenge!.subject}: ${widget.challenge!.question}"
                : "Loading today's challenge…",
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.md + 2),
          OutlinedButton(
            onPressed: () => context.goNamed(AppRoutes.tutor),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 1.4),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.pillBorder,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Attempt Now',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs + 2),
                const Icon(Icons.arrow_forward_rounded, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Subject progress — horizontal row of rings
// ---------------------------------------------------------------------------

class _SubjectProgressSection extends StatelessWidget {
  final List<SubjectProgress> subjects;
  const _SubjectProgressSection({required this.subjects});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Your Subjects',
          actionLabel: subjects.isEmpty ? null : 'Manage',
          onAction: () => context.goNamed(AppRoutes.profile),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: AppSpacing.md + 2),
        if (subjects.isEmpty)
          const EmptyState(
            title: 'No subjects yet',
            message:
                'Pick your subjects in Profile to start tracking progress.',
            icon: Icons.menu_book_outlined,
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.lg,
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: subjects.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppSpacing.lg),
              itemBuilder: (_, i) =>
                  _SubjectProgressRing(subject: subjects[i]),
            ),
          ),
      ],
    );
  }
}

class _SubjectProgressRing extends StatelessWidget {
  final SubjectProgress subject;
  const _SubjectProgressRing({required this.subject});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final pct = (subject.progress * 100).round();
    return SizedBox(
      width: 92,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.lgBorder,
        child: InkWell(
          onTap: () => context.goNamed(AppRoutes.tutor),
          borderRadius: AppRadius.lgBorder,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Animated fill — tweens from 0 to progress on mount.
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0,
                          end: subject.progress.clamp(0.0, 1.0),
                        ),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (_, value, __) => SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: value,
                            strokeWidth: 6,
                            strokeCap: StrokeCap.round,
                            backgroundColor:
                                subject.color.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation(subject.color),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$pct%',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: subject.color,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'of 100',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: subject.color.withValues(alpha: 0.7),
                              fontSize: 9,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                      // Subject emoji chip — top-right of the ring.
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: brand.surface,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: subject.color.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            _subjectEmoji(subject.name),
                            style: const TextStyle(fontSize: 13, height: 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  subject.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: brand.textDark,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Subject → emoji mapping, mirrored from tutor_screen.dart's local helper.
// Kept inline here (one feature = one directory; no barrel files).
String _subjectEmoji(String s) => switch (s) {
      'Mathematics' => '\u{1F4D0}',
      'Physics' => '\u{269B}\u{FE0F}',
      'Chemistry' => '\u{1F9EA}',
      'Biology' => '\u{1F9EC}',
      'English' => '\u{1F4D6}',
      'ICT' => '\u{1F4BB}',
      'Accounting' => '\u{1F9EE}',
      'Economics' => '\u{1F4CA}',
      'History' => '\u{1F4DC}',
      'Geography' => '\u{1F30D}',
      _ => '\u{1F393}',
    };

// ---------------------------------------------------------------------------
// Recent AI sessions
// ---------------------------------------------------------------------------

class _RecentSessionsSection extends StatelessWidget {
  final List<SessionItem> sessions;
  const _RecentSessionsSection({required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recent Sessions',
          actionLabel: 'View All',
          onAction: () => context.goNamed(AppRoutes.tutor),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: AppSpacing.md),
        if (sessions.isEmpty)
          const EmptyState(
            title: 'No sessions yet',
            message: 'Ask the AI tutor a question to start your first session.',
            icon: Icons.chat_bubble_outline_rounded,
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.lg,
            ),
          )
        else
          Column(
            children: [
              for (var i = 0; i < sessions.length; i++) ...[
                _SessionTile(session: sessions[i]),
                if (i != sessions.length - 1)
                  const SizedBox(height: AppSpacing.sm + 2),
              ],
            ],
          ),
      ],
    );
  }
}

class _SessionTile extends StatefulWidget {
  final SessionItem session;
  const _SessionTile({required this.session});

  @override
  State<_SessionTile> createState() => _SessionTileState();
}

class _SessionTileState extends State<_SessionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final s = widget.session;
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: brand.surface,
        borderRadius: AppRadius.lgBorder,
        child: InkWell(
          onTap: () => context.goNamed(AppRoutes.tutor),
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          borderRadius: AppRadius.lgBorder,
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Subject-colored accent strip — gives each tile a distinct
                // visual anchor before the text content is even read.
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: s.subjectColor,
                    borderRadius: const BorderRadius.horizontal(
                      left: AppRadius.lgRadius,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.md,
                      AppSpacing.md + 2, AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        _SubjectTag(
                          label: s.subject,
                          color: s.subjectColor,
                          emoji: _subjectEmoji(s.subject),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.question,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: brand.textDark,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _timeAgo(s.timestamp),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: brand.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: brand.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(ts);
  }
}

/// Small subject-colored label tag (decorative, not selectable). Optional
/// leading emoji for the dashboard's recent-sessions tiles.
class _SubjectTag extends StatelessWidget {
  final String label;
  final Color color;
  final String? emoji;
  const _SubjectTag({
    required this.label,
    required this.color,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null) ...[
            Text(emoji!, style: const TextStyle(fontSize: 11, height: 1)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Materials carousel
// ---------------------------------------------------------------------------

class _MaterialsCarousel extends StatelessWidget {
  final List<MaterialItem> materials;
  const _MaterialsCarousel({required this.materials});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'New Materials',
          actionLabel: 'Browse All',
          onAction: () => context.goNamed(AppRoutes.materials),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: AppSpacing.md),
        if (materials.isEmpty)
          const EmptyState(
            title: 'No materials yet',
            message: 'Materials will appear here as teachers publish them.',
            icon: Icons.auto_stories_outlined,
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.lg,
            ),
          )
        else
          SizedBox(
            height: 182,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: materials.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppSpacing.md),
              itemBuilder: (_, i) => _MaterialCard(material: materials[i]),
            ),
          ),
      ],
    );
  }
}

class _MaterialCard extends StatefulWidget {
  final MaterialItem material;
  const _MaterialCard({required this.material});

  @override
  State<_MaterialCard> createState() => _MaterialCardState();
}

class _MaterialCardState extends State<_MaterialCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final m = widget.material;
    return AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: SizedBox(
      width: 140,
      child: Material(
        color: brand.surface,
        borderRadius: AppRadius.lgBorder,
        child: InkWell(
          onTap: () => context.goNamed(AppRoutes.materials),
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          borderRadius: AppRadius.lgBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: AppRadius.lgRadius,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: m.gradient,
                  ),
                ),
                child: Stack(
                  children: [
                    // Subject emoji — top-left of the gradient, on a soft
                    // translucent circle so it reads against any gradient.
                    Positioned(
                      left: AppSpacing.sm,
                      top: AppSpacing.sm,
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _subjectEmoji(m.subject),
                          style: const TextStyle(fontSize: 15, height: 1),
                        ),
                      ),
                    ),
                    Positioned(
                      left: AppSpacing.sm + 2,
                      bottom: AppSpacing.sm + 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: AppRadius.pillBorder,
                        ),
                        child: Text(
                          m.level,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: AppSpacing.sm,
                      top: AppSpacing.sm,
                      child: Icon(
                        Icons.auto_stories_rounded,
                        color: Colors.white.withValues(alpha: 0.85),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm + 2, AppSpacing.sm + 2,
                  AppSpacing.sm + 2, AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: brand.textDark,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      m.subject,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: brand.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Badges
// ---------------------------------------------------------------------------

class _BadgeShowcase extends StatelessWidget {
  final List<BadgeItem> badges;
  final int totalCount;
  const _BadgeShowcase({required this.badges, required this.totalCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'My Badges',
          actionLabel: totalCount > badges.length ? 'See all' : null,
          onAction: () => context.goNamed(AppRoutes.rewards),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: AppSpacing.md),
        if (badges.isEmpty)
          const EmptyState(
            title: 'No badges yet',
            message: 'Keep learning to earn your first badge.',
            icon: Icons.emoji_events_outlined,
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.lg,
            ),
          )
        else
          Row(
            children: [
              for (final b in badges) ...[
                _BadgeCard(badge: b),
                const SizedBox(width: AppSpacing.md),
              ],
              if (totalCount > badges.length)
                _BadgeMoreCard(extra: totalCount - badges.length),
            ],
          ),
      ],
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final BadgeItem badge;
  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return SizedBox(
      width: 70,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: badge.color.withValues(alpha: 0.14),
              border: Border.all(
                color: badge.color.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Icon(badge.icon, color: badge.color, size: 28),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            badge.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: brand.textDark,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeMoreCard extends StatelessWidget {
  final int extra;
  const _BadgeMoreCard({required this.extra});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return SizedBox(
      width: 70,
      child: GestureDetector(
        onTap: () => context.goNamed(AppRoutes.rewards),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: brand.primary.withValues(alpha: 0.08),
                border: Border.all(
                  color: brand.primary.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Text(
                '+$extra',
                style: AppTextStyles.labelLarge.copyWith(
                  color: brand.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            Text(
              'more',
              style: AppTextStyles.bodySmall.copyWith(
                color: brand.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom nav — Material 3 NavigationBar (theme-aware)
// ---------------------------------------------------------------------------

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: brand.surface,
        indicatorColor: brand.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTextStyles.labelSmall.copyWith(
            color: selected ? brand.primary : brand.textMuted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 11,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? brand.primary : brand.textMuted,
            size: 22,
          );
        }),
        height: 68,
      ),
      child: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onTap,
        surfaceTintColor: brand.surface,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy_rounded),
            label: 'AI Tutor',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Materials',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events_rounded),
            label: 'Rewards',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
