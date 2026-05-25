import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/application/viewmodels/rewards/rewards_viewmodel.dart';
import 'package:mentor_minds/data/models/earned_badge.dart';
import 'package:mentor_minds/data/models/history_entry.dart';
import 'package:mentor_minds/data/models/locked_badge.dart';
import 'package:mentor_minds/data/models/milestone.dart';

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rewardsViewModelProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.kBackground,
        body: SafeArea(
          child: state.isLoading
              ? const _RewardsShimmer()
              : Column(
                  children: [
                    _Header(state: state),
                    const _TabBar(),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _BadgesTab(state: state),
                          _HistoryTab(state: state),
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
// Header — title + animated count-up + progress card
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final RewardsState state;
  const _Header({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
      color: AppColors.kBackground,
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.goNamed(AppRoutes.dashboard),
              ),
              Text(
                'My Rewards',
                style: AppTextStyles.headingLarge.copyWith(fontSize: 20),
              ),
              const Spacer(),
              const SizedBox(width: 48), // balance for centered title feel
            ],
          ),
          const SizedBox(height: 6),
          _PointsCountUp(points: state.points),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _MilestoneCard(milestone: state.nextMilestone),
          ),
        ],
      ),
    );
  }
}

class _PointsCountUp extends StatefulWidget {
  final int points;
  const _PointsCountUp({required this.points});

  @override
  State<_PointsCountUp> createState() => _PointsCountUpState();
}

class _PointsCountUpState extends State<_PointsCountUp> {
  int _from = 0;

  @override
  void didUpdateWidget(covariant _PointsCountUp old) {
    super.didUpdateWidget(old);
    if (old.points != widget.points) _from = old.points;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _from.toDouble(), end: widget.points.toDouble()),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final shown = value.round();
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text('⭐', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 6),
            Text(
              '$shown',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: AppColors.kGold,
                height: 1.1,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'pts',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.kTextMuted,
                fontSize: 14,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  final Milestone milestone;
  const _MilestoneCard({required this.milestone});

  @override
  Widget build(BuildContext context) {
    if (milestone.isMaxed) {
      return _card(
        context,
        title: 'Max tier reached 🎉',
        subtitle: 'All milestones unlocked. Keep learning for bonus perks.',
        progress: 1.0,
        rewardHint: '',
      );
    }
    final remaining = milestone.remaining;
    return _card(
      context,
      title: 'Next milestone: ${milestone.target} pts',
      subtitle: remaining == 1
          ? 'You need 1 more point!'
          : 'You need $remaining more points!',
      progress: milestone.progress,
      rewardHint: milestone.rewardHint,
    );
  }

  Widget _card(
    BuildContext context, {
    required String title,
    required String subtitle,
    required double progress,
    required String rewardHint,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.kSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.headingSmall),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppColors.kGold.withValues(alpha: 0.15),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.kGold),
            ),
          ),
          const SizedBox(height: 10),
          Text(subtitle, style: AppTextStyles.bodySmall),
          if (rewardHint.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Next reward: $rewardHint',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.kPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab bar
// ---------------------------------------------------------------------------

class _TabBar extends StatelessWidget {
  const _TabBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.kBackground,
      child: const TabBar(
        indicatorColor: AppColors.kAccent,
        indicatorWeight: 3,
        labelColor: AppColors.kPrimary,
        unselectedLabelColor: AppColors.kTextMuted,
        labelStyle: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        tabs: [
          Tab(text: 'Badges'),
          Tab(text: 'History'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Badges tab
// ---------------------------------------------------------------------------

class _BadgesTab extends ConsumerWidget {
  final RewardsState state;
  const _BadgesTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: AppColors.kAccent,
      onRefresh: () =>
          ref.read(rewardsViewModelProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _SectionHeader(label: 'Earned (${state.earned.length})'),
          const SizedBox(height: 10),
          if (state.earned.isEmpty)
            const _EmptyPanel(
              icon: '🎖️',
              text: 'No badges yet — keep studying to earn your first one.',
            )
          else
            _BadgeGrid(
              children: state.earned
                  .map((e) => _EarnedBadgeCard(badge: e))
                  .toList(),
            ),
          const SizedBox(height: 22),
          _SectionHeader(label: 'Locked (${state.locked.length})'),
          const SizedBox(height: 10),
          if (state.locked.isEmpty)
            const _EmptyPanel(
              icon: '🏅',
              text: 'All badges unlocked — you legend.',
            )
          else
            _BadgeGrid(
              children: state.locked
                  .map((l) => _LockedBadgeCard(badge: l))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.headingSmall.copyWith(
        color: AppColors.kTextDark,
        fontSize: 15,
      ),
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  final List<Widget> children;
  const _BadgeGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.82,
      children: children,
    );
  }
}

class _EarnedBadgeCard extends StatelessWidget {
  final EarnedBadge badge;
  const _EarnedBadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    final card = _BadgeCardContent(
      emoji: badge.info.emoji,
      emojiOpacity: 1.0,
      name: badge.info.name,
      caption: badge.earnedAt == null
          ? 'Earned'
          : 'Earned ${DateFormat('MMM d').format(badge.earnedAt!)}',
      showLock: false,
      onTap: () => _openBadgeSheet(context, badge: badge),
    );

    if (!badge.recentlyEarned) return card;

    return Shimmer.fromColors(
      baseColor: AppColors.kGold.withValues(alpha: 0.0),
      highlightColor: AppColors.kGold.withValues(alpha: 0.75),
      period: const Duration(milliseconds: 1800),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.kGold, width: 1.5),
        ),
        child: card,
      ),
    );
  }
}

class _LockedBadgeCard extends StatelessWidget {
  final LockedBadge badge;
  const _LockedBadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    return _BadgeCardContent(
      emoji: badge.info.emoji,
      emojiOpacity: 0.5,
      name: badge.info.name,
      caption: badge.info.unlockHint,
      showLock: true,
      onTap: () => _openBadgeSheet(context, locked: badge),
    );
  }
}

class _BadgeCardContent extends StatelessWidget {
  final String emoji;
  final double emojiOpacity;
  final String name;
  final String caption;
  final bool showLock;
  final VoidCallback onTap;
  const _BadgeCardContent({
    required this.emoji,
    required this.emojiOpacity,
    required this.name,
    required this.caption,
    required this.showLock,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.kSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: emojiOpacity,
                    child: Text(
                      emoji,
                      style: TextStyle(
                        fontSize: 40,
                        color: showLock ? Colors.grey : null,
                      ),
                    ),
                  ),
                  if (showLock)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: AppColors.kTextMuted,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.kTextDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  color: AppColors.kTextMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _openBadgeSheet(
  BuildContext context, {
  EarnedBadge? badge,
  LockedBadge? locked,
}) {
  final info = badge?.info ?? locked!.info;
  final isEarned = badge != null;
  final progress = locked?.currentProgress;
  final target = info.target;
  final progressFraction = (target != null && target > 0 && progress != null)
      ? (progress / target).clamp(0.0, 1.0)
      : null;

  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.kSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.kTextMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Opacity(
              opacity: isEarned ? 1.0 : 0.6,
              child: Text(info.emoji, style: const TextStyle(fontSize: 80)),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(info.name, style: AppTextStyles.headingMedium),
          ),
          const SizedBox(height: 6),
          Text(
            info.description,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 14),
          if (isEarned)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: AppColors.kAccent.withValues(alpha: 0.15),
                ),
                child: Text(
                  badge.earnedAt == null
                      ? 'Earned'
                      : 'Earned · ${DateFormat('MMM d, y').format(badge.earnedAt!)}',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.kAccent),
                ),
              ),
            )
          else ...[
            Text(
              'How to unlock: ${info.unlockHint}',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
            if (progressFraction != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progressFraction,
                  minHeight: 8,
                  backgroundColor: AppColors.kAccent.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.kAccent),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$progress / $target',
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSmall,
              ),
            ],
          ],
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// History tab (leaderboard removed — REWD-07)
// ---------------------------------------------------------------------------

// Leaderboard UI deleted — see git history if restoring v2 cohort leaderboard.

class _HistoryTab extends StatelessWidget {
  final RewardsState state;
  const _HistoryTab({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.history.isEmpty) {
      return const _EmptyPanel(
        icon: '🌱',
        text: 'Start learning to earn your first points!',
        fill: true,
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: state.history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _HistoryTile(entry: state.history[i]),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryEntry entry;
  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.kSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.kBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(entry.icon, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.action,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppTextStyles.labelLarge.copyWith(fontSize: 14),
                ),
                if (entry.timestamp != null)
                  Text(
                    _formatWhen(entry.timestamp!),
                    style: AppTextStyles.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+${entry.points}',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              color: AppColors.kAccent,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  String _formatWhen(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(t);
  }
}


// ---------------------------------------------------------------------------
// Shared empty panel + shimmer
// ---------------------------------------------------------------------------

class _EmptyPanel extends StatelessWidget {
  final String icon;
  final String text;
  final bool fill;
  const _EmptyPanel({
    required this.icon,
    required this.text,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall,
        ),
      ],
    );
    if (!fill) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(child: content),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: content,
      ),
    );
  }
}

class _RewardsShimmer extends StatelessWidget {
  const _RewardsShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE6E9F2),
      highlightColor: const Color(0xFFF7F9FD),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 180,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.kSurface,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.kSurface,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.kSurface,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.82,
                children: [
                  for (var i = 0; i < 6; i++)
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.kSurface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
