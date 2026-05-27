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
// Sliver app bar — always indigo gradient hero (brand identity, both themes).
// ---------------------------------------------------------------------------

class _DashboardAppBar extends StatelessWidget {
  final String firstName;
  final int points;
  final int streak;
  final int notificationCount;

  const _DashboardAppBar({
    required this.firstName,
    required this.points,
    required this.streak,
    required this.notificationCount,
  });

  @override
  Widget build(BuildContext context) {
    const expandedHeight = 140.0;
    return SliverAppBar(
      pinned: true,
      expandedHeight: expandedHeight,
      backgroundColor: AppColors.kPrimary,
      foregroundColor: Colors.white,
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
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.kPrimary, AppColors.kSplashBottom],
                  ),
                ),
              ),
              Positioned(
                top: topInset,
                left: 0,
                right: 0,
                height: kToolbarHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Row(
                    children: [
                      Opacity(
                        opacity: 1 - t,
                        child: Text(
                          'MentorMinds',
                          style: AppTextStyles.headingMedium.copyWith(
                            color: Colors.white,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      const Spacer(),
                      _NotificationBell(count: notificationCount),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.md + 2,
                child: IgnorePointer(
                  ignoring: t < 0.15,
                  child: Opacity(
                    opacity: t,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_greeting(DateTime.now())}, $firstName! \u{1F44B}',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  height: 1.25,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _PointsChip(points: points),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _dateAndStreak(DateTime.now(), streak),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.80),
                            height: 1.3,
                          ),
                        ),
                      ],
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

  String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _dateAndStreak(DateTime now, int streak) {
    final date = DateFormat('EEE, MMM d').format(now);
    return '$date • $streak \u{1F525} day streak';
  }
}

class _PointsChip extends StatelessWidget {
  final int points;
  const _PointsChip({required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: AppColors.kGold,
        borderRadius: AppRadius.pillBorder,
        boxShadow: [
          BoxShadow(
            color: AppColors.kGold.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: Colors.white),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$points pts',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
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
    return IconButton(
      onPressed: () => context.goNamed(AppRoutes.notifications),
      splashRadius: 22,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            color: Colors.white,
            size: 24,
          ),
          if (count > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.kError,
                  borderRadius: AppRadius.pillBorder,
                  border:
                      Border.all(color: AppColors.kPrimary, width: 1.5),
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
    return Row(
      children: [
        Expanded(
          child: _QuickActionTile(
            emoji: '\u{1F916}',
            label: 'Ask AI',
            onTap: () => context.goNamed(AppRoutes.tutor),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _QuickActionTile(
            emoji: '\u{1F4DA}',
            label: 'Materials',
            onTap: () => context.goNamed(AppRoutes.materials),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _QuickActionTile(
            emoji: '\u{1F3C6}',
            label: 'Rewards',
            onTap: () => context.goNamed(AppRoutes.rewards),
          ),
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Material(
      color: brand.primary,
      borderRadius: AppRadius.lgBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgBorder,
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.md,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28, height: 1)),
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                label,
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
      width: 88,
      child: Column(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: subject.progress.clamp(0.0, 1.0),
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    backgroundColor: subject.color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(subject.color),
                  ),
                ),
                Text(
                  '$pct%',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: subject.color,
                    fontWeight: FontWeight.w700,
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
    );
  }
}

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

class _SessionTile extends StatelessWidget {
  final SessionItem session;
  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Material(
      color: brand.surface,
      borderRadius: AppRadius.lgBorder,
      child: InkWell(
        onTap: () => context.goNamed(AppRoutes.tutor),
        borderRadius: AppRadius.lgBorder,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md + 2, vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              _SubjectTag(label: session.subject, color: session.subjectColor),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.question,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: brand.textDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _timeAgo(session.timestamp),
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

/// Small subject-colored label tag (decorative, not selectable).
class _SubjectTag extends StatelessWidget {
  final String label;
  final Color color;
  const _SubjectTag({required this.label, required this.color});

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
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
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

class _MaterialCard extends StatelessWidget {
  final MaterialItem material;
  const _MaterialCard({required this.material});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return SizedBox(
      width: 140,
      child: Material(
        color: brand.surface,
        borderRadius: AppRadius.lgBorder,
        child: InkWell(
          onTap: () => context.goNamed(AppRoutes.materials),
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
                    colors: material.gradient,
                  ),
                ),
                child: Stack(
                  children: [
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
                          material.level,
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
                      material.title,
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
                      material.subject,
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
