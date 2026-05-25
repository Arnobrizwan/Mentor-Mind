import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/application/viewmodels/dashboard/dashboard_viewmodel.dart';
import 'package:mentor_minds/data/models/daily_challenge.dart';
import 'package:mentor_minds/data/services/messaging_service.dart';
import 'package:mentor_minds/data/models/badge_item.dart';
import 'package:mentor_minds/data/models/material_item.dart';
import 'package:mentor_minds/data/models/session_item.dart';
import 'package:mentor_minds/data/models/subject_progress.dart';

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
        // Home — stay
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
    final state = ref.watch(dashboardViewModelProvider);
    _maybeRegisterFcm(state);

    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.kPrimary,
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  sliver: SliverList.list(
                    children: [
                      const _QuickActionRow(),
                      const SizedBox(height: 20),
                      _DailyChallengeCard(
                        challenge: state.dailyChallenge,
                        resetsAt: state.dailyChallengeResetsAt,
                      ),
                      const SizedBox(height: 24),
                      _SubjectProgressSection(subjects: state.subjects),
                      const SizedBox(height: 24),
                      _RecentSessionsSection(
                        sessions: state.recentSessions,
                      ),
                      const SizedBox(height: 24),
                      _MaterialsCarousel(materials: state.materials),
                      const SizedBox(height: 24),
                      _BadgeShowcase(
                        badges: state.badges,
                        totalCount: state.totalBadgeCount,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_awardAmount != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 12,
              left: 0,
              right: 0,
              child: Center(child: _AwardToast(amount: _awardAmount!)),
            ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        index: _navIndex,
        onTap: _onNavTap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Daily-login award toast — "+5 pts 🎉"
// ---------------------------------------------------------------------------

class _AwardToast extends StatelessWidget {
  final int amount;
  const _AwardToast({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.kGold,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.kGold.withOpacity(0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 18, color: Colors.white),
          const SizedBox(width: 6),
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
          curve: Curves.easeOutBack,
        )
        .fade(duration: 220.ms)
        .then(delay: 1600.ms)
        .fade(begin: 1, end: 0, duration: 400.ms)
        .slideY(begin: 0, end: -0.3, duration: 400.ms);
  }
}

// ---------------------------------------------------------------------------
// Sliver AppBar — crossfades between collapsed "MentorMinds + bell" and the
// expanded greeting + date + points chip.
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
              // Collapsed-state top bar: logo (fades in as we collapse) + bell
              Positioned(
                top: topInset,
                left: 0,
                right: 0,
                height: kToolbarHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
              // Expanded content — greeting, date/streak, points chip
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
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
                                '${_greeting(DateTime.now())}, '
                                '$firstName! \u{1F44B}',
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
                            const SizedBox(width: 8),
                            _PointsChip(points: points),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dateAndStreak(DateTime.now(), streak),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.80),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.kGold,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.kGold.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 4),
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
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.kError,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.kPrimary, width: 1.5),
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
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionTile(
            emoji: '\u{1F4DA}',
            label: 'Materials',
            onTap: () => context.goNamed(AppRoutes.materials),
          ),
        ),
        const SizedBox(width: 12),
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
    return Material(
      color: AppColors.kPrimary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28, height: 1)),
              const SizedBox(height: 6),
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
// Daily challenge — gradient card with periodic countdown
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.kAccent, Color(0xFF009B82)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.kAccent.withOpacity(0.25),
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
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
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
          const SizedBox(height: 8),
          Text(
            widget.challenge != null
                ? "${widget.challenge!.subject}: ${widget.challenge!.question}"
                : "Loading today's challenge…",
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.92),
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () => context.goNamed(AppRoutes.tutor),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
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
                const SizedBox(width: 6),
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
        _SectionHeader(
          title: 'Your Subjects',
          trailing: subjects.isEmpty ? null : 'Manage',
          onTrailingTap: () => context.goNamed(AppRoutes.profile),
        ),
        const SizedBox(height: 14),
        if (subjects.isEmpty)
          const _EmptyStateCard(
            icon: Icons.menu_book_outlined,
            message:
                'Pick your subjects in Profile to start tracking progress.',
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: subjects.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (_, i) => _SubjectProgressRing(subject: subjects[i]),
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
                    backgroundColor: subject.color.withOpacity(0.15),
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
          const SizedBox(height: 8),
          Text(
            subject.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.kTextDark,
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
        _SectionHeader(
          title: 'Recent Sessions',
          trailing: 'View All',
          onTrailingTap: () => context.goNamed(AppRoutes.tutor),
        ),
        const SizedBox(height: 12),
        if (sessions.isEmpty)
          const _EmptyStateCard(
            icon: Icons.chat_bubble_outline_rounded,
            message: 'Ask the AI tutor a question to start your first session.',
          )
        else
          Column(
            children: [
              for (var i = 0; i < sessions.length; i++) ...[
                _SessionTile(session: sessions[i]),
                if (i != sessions.length - 1) const SizedBox(height: 10),
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
    return Material(
      color: AppColors.kSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => context.goNamed(AppRoutes.tutor),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _SubjectChip(
                label: session.subject,
                color: session.subjectColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.question,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.kTextDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _timeAgo(session.timestamp),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.kTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.kTextMuted,
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

class _SubjectChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SubjectChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
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
        _SectionHeader(
          title: 'New Materials',
          trailing: 'Browse All',
          onTrailingTap: () => context.goNamed(AppRoutes.materials),
        ),
        const SizedBox(height: 12),
        if (materials.isEmpty)
          const _EmptyStateCard(
            icon: Icons.auto_stories_outlined,
            message: 'Materials will appear here as teachers publish them.',
          )
        else
          SizedBox(
            height: 182,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: materials.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
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
    return SizedBox(
      width: 140,
      child: Material(
        color: AppColors.kSurface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => context.goNamed(AppRoutes.materials),
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail area — gradient tinted by subject
              Container(
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
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
                      left: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(999),
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
                      right: 8,
                      top: 8,
                      child: Icon(
                        Icons.auto_stories_rounded,
                        color: Colors.white.withOpacity(0.85),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.kTextDark,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      material.subject,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.kTextMuted,
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
        _SectionHeader(
          title: 'My Badges',
          trailing: totalCount > badges.length ? 'See all' : null,
          onTrailingTap: () => context.goNamed(AppRoutes.rewards),
        ),
        const SizedBox(height: 12),
        if (badges.isEmpty)
          const _EmptyStateCard(
            icon: Icons.emoji_events_outlined,
            message: 'Keep learning to earn your first badge.',
          )
        else
          Row(
            children: [
              for (final b in badges) ...[
                _BadgeCard(badge: b),
                const SizedBox(width: 12),
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
    return SizedBox(
      width: 70,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: badge.color.withOpacity(0.14),
              border: Border.all(
                color: badge.color.withOpacity(0.35),
                width: 1.5,
              ),
            ),
            child: Icon(badge.icon, color: badge.color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            badge.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.kTextDark,
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
                color: AppColors.kPrimary.withOpacity(0.08),
                border: Border.all(
                  color: AppColors.kPrimary.withOpacity(0.25),
                  width: 1.5,
                ),
              ),
              child: Text(
                '+$extra',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.kPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'more',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.kTextMuted,
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
// Section header + empty state helpers
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  const _SectionHeader({
    required this.title,
    this.trailing,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: AppTextStyles.headingSmall.copyWith(
            color: AppColors.kTextDark,
            fontSize: 16,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          TextButton(
            onPressed: onTrailingTap,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.kPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trailing!,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.kPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: AppColors.kPrimary,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyStateCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.kTextMuted, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.kTextMuted,
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom nav — Material 3 NavigationBar
// ---------------------------------------------------------------------------

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: AppColors.kSurface,
        indicatorColor: AppColors.kPrimary.withOpacity(0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTextStyles.labelSmall.copyWith(
            color: selected ? AppColors.kPrimary : AppColors.kTextMuted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 11,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.kPrimary : AppColors.kTextMuted,
            size: 22,
          );
        }),
        height: 68,
      ),
      child: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onTap,
        surfaceTintColor: AppColors.kSurface,
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
