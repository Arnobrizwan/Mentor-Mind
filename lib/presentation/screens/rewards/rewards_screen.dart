import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import 'package:mentor_minds/application/viewmodels/rewards/rewards_viewmodel.dart';
import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/core/theme/app_radius.dart';
import 'package:mentor_minds/core/theme/app_spacing.dart';
import 'package:mentor_minds/core/theme/brand_colors.dart';
import 'package:mentor_minds/data/models/earned_badge.dart';
import 'package:mentor_minds/data/models/history_entry.dart';
import 'package:mentor_minds/data/models/locked_badge.dart';
import 'package:mentor_minds/data/models/milestone.dart';
import 'package:mentor_minds/shared/widgets/skeleton_block.dart';

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final state = ref.watch(rewardsViewModelProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: brand.background,
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
    final brand = context.brand;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs, AppSpacing.xs, AppSpacing.xs, AppSpacing.lg,
      ),
      color: brand.background,
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.goNamed(AppRoutes.dashboard),
              ),
              Text(
                'My Rewards',
                style: AppTextStyles.headingLarge.copyWith(
                  color: brand.textDark, fontSize: 20,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 48), // balance for centered title feel
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          _PointsCountUp(points: state.points),
          const SizedBox(height: AppSpacing.lg + 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
    final brand = context.brand;
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
            const SizedBox(width: AppSpacing.xs + 2),
            Text(
              '$shown',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 36,
                fontWeight: FontWeight.w700,
                // Gold stays gold in both themes (intentional reward identity).
                color: AppColors.kGold,
                height: 1.1,
              ),
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(
              'pts',
              style: AppTextStyles.labelMedium.copyWith(
                color: brand.textMuted, fontSize: 14,
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
    final brand = context.brand;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: AppRadius.lgBorder,
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
          Text(
            title,
            style: AppTextStyles.headingSmall.copyWith(color: brand.textDark),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          ClipRRect(
            borderRadius: AppRadius.pillBorder,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppColors.kGold.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.kGold),
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(color: brand.textMuted),
          ),
          if (rewardHint.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Next reward: $rewardHint',
              style: AppTextStyles.labelSmall.copyWith(color: brand.primary),
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
    final brand = context.brand;
    return Container(
      color: brand.background,
      child: TabBar(
        indicatorColor: brand.accent,
        indicatorWeight: 3,
        labelColor: brand.primary,
        unselectedLabelColor: brand.textMuted,
        labelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        tabs: const [
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
    final brand = context.brand;
    return RefreshIndicator(
      color: brand.accent,
      onRefresh: () => ref.read(rewardsViewModelProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl,
        ),
        children: [
          _SectionHeader(label: 'Earned (${state.earned.length})'),
          const SizedBox(height: AppSpacing.sm + 2),
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
          const SizedBox(height: AppSpacing.xl - 2),
          _SectionHeader(label: 'Locked (${state.locked.length})'),
          const SizedBox(height: AppSpacing.sm + 2),
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
    final brand = context.brand;
    return Text(
      label,
      style: AppTextStyles.headingSmall.copyWith(
        color: brand.textDark, fontSize: 15,
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
      crossAxisSpacing: AppSpacing.sm + 2,
      mainAxisSpacing: AppSpacing.sm + 2,
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

    // Recently-earned: gold shimmer + gold border. Identity moment —
    // identical in both themes.
    return Shimmer.fromColors(
      baseColor: AppColors.kGold.withValues(alpha: 0.0),
      highlightColor: AppColors.kGold.withValues(alpha: 0.75),
      period: const Duration(milliseconds: 1800),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.lgBorder,
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
    final brand = context.brand;
    return Material(
      color: brand.surface,
      borderRadius: AppRadius.lgBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgBorder,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgBorder,
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
                        decoration: BoxDecoration(
                          color: brand.textMuted,
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
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: brand.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  color: brand.textMuted,
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
    backgroundColor: context.brand.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: AppRadius.xxlRadius),
    ),
    builder: (sheetCtx) {
      final brand = sheetCtx.brand;
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl - 4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: brand.textMuted.withValues(alpha: 0.3),
                  borderRadius: AppRadius.xsBorder,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg + 2),
            Center(
              child: Opacity(
                opacity: isEarned ? 1.0 : 0.6,
                child: Text(info.emoji, style: const TextStyle(fontSize: 80)),
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            Center(
              child: Text(
                info.name,
                style: AppTextStyles.headingMedium.copyWith(
                  color: brand.textDark,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            Text(
              info.description,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: brand.textDark),
            ),
            const SizedBox(height: AppSpacing.md + 2),
            if (isEarned)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.pillBorder,
                    color: brand.accent.withValues(alpha: 0.15),
                  ),
                  child: Text(
                    badge.earnedAt == null
                        ? 'Earned'
                        : 'Earned · ${DateFormat('MMM d, y').format(badge.earnedAt!)}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: brand.accent,
                    ),
                  ),
                ),
              )
            else ...[
              Text(
                'How to unlock: ${info.unlockHint}',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(color: brand.textMuted),
              ),
              if (progressFraction != null) ...[
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: AppRadius.pillBorder,
                  child: LinearProgressIndicator(
                    value: progressFraction,
                    minHeight: 8,
                    backgroundColor: brand.accent.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(brand.accent),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs + 2),
                Text(
                  '$progress / $target',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: brand.textMuted,
                  ),
                ),
              ],
            ],
          ],
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// History tab (leaderboard removed — REWD-07)
// ---------------------------------------------------------------------------

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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl,
      ),
      itemCount: state.history.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _HistoryTile(entry: state.history[i]),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryEntry entry;
  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: AppRadius.mdBorder,
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
              color: brand.background,
              borderRadius: AppRadius.smBorder,
            ),
            child: Text(entry.icon, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.action,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: brand.textDark, fontSize: 14,
                  ),
                ),
                if (entry.timestamp != null)
                  Text(
                    _formatWhen(entry.timestamp!),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: brand.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '+${entry.points}',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              color: brand.accent,
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
    final brand = context.brand;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 40)),
        const SizedBox(height: AppSpacing.sm + 2),
        Text(
          text,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(color: brand.textMuted),
        ),
      ],
    );
    if (!fill) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl - 4),
        child: Center(child: content),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: content,
      ),
    );
  }
}

class _RewardsShimmer extends StatelessWidget {
  const _RewardsShimmer();

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return SkeletonGroup(
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: 180,
            height: 40,
            decoration: BoxDecoration(
              color: brand.surface,
              borderRadius: AppRadius.smBorder,
            ),
          ),
          const SizedBox(height: AppSpacing.xl - 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                color: brand.surface,
                borderRadius: AppRadius.lgBorder,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl - 4),
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: brand.surface,
              borderRadius: AppRadius.smBorder,
            ),
          ),
          const SizedBox(height: AppSpacing.md + 2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: AppSpacing.sm + 2,
                mainAxisSpacing: AppSpacing.sm + 2,
                childAspectRatio: 0.82,
                children: [
                  for (var i = 0; i < 6; i++)
                    Container(
                      decoration: BoxDecoration(
                        color: brand.surface,
                        borderRadius: AppRadius.lgBorder,
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
