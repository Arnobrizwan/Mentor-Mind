import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/application/viewmodels/rewards/rewards_viewmodel.dart';

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rewardsViewModelProvider);
    return DefaultTabController(
      length: 3,
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
                          _LeaderboardTab(state: state),
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
            color: Colors.black.withOpacity(0.05),
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
              backgroundColor: AppColors.kGold.withOpacity(0.15),
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
      child: TabBar(
        indicatorColor: AppColors.kAccent,
        indicatorWeight: 3,
        labelColor: AppColors.kPrimary,
        unselectedLabelColor: AppColors.kTextMuted,
        labelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        tabs: const [
          Tab(text: 'Badges'),
          Tab(text: 'Leaderboard'),
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
            _EmptyPanel(
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
            _EmptyPanel(
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
      baseColor: AppColors.kGold.withOpacity(0.0),
      highlightColor: AppColors.kGold.withOpacity(0.75),
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
                color: Colors.black.withOpacity(0.04),
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
                color: AppColors.kTextMuted.withOpacity(0.3),
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
                  color: AppColors.kAccent.withOpacity(0.15),
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
                  backgroundColor: AppColors.kAccent.withOpacity(0.15),
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
// Leaderboard tab
// ---------------------------------------------------------------------------

class _LeaderboardTab extends ConsumerWidget {
  final RewardsState state;
  const _LeaderboardTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = state.leaderboardTop;
    if (top.isEmpty) {
      return _EmptyPanel(
        icon: '🏁',
        text: 'Leaderboard is waking up. Pull to refresh.',
        fill: true,
      );
    }
    final podium = top.take(3).toList();
    final rest = top.length > 3 ? top.sublist(3) : <LeaderboardEntry>[];
    final currentUserRow = state.currentUserRow;

    return RefreshIndicator(
      color: AppColors.kAccent,
      onRefresh: () =>
          ref.read(rewardsViewModelProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (podium.length == 3) _Podium(entries: podium),
          if (podium.length < 3) ...[
            for (final e in podium) _LeaderboardRow(entry: e),
          ],
          const SizedBox(height: 14),
          for (final e in rest) _LeaderboardRow(entry: e),
          if (currentUserRow != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            _LeaderboardRow(
              entry: currentUserRow,
              subtitle: 'You’re in ${currentUserRow.rank}th place',
            ),
          ],
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> entries; // length 3
  const _Podium({required this.entries});

  @override
  Widget build(BuildContext context) {
    // Visual order: 2nd | 1st | 3rd
    final first = entries[0];
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _PodiumSlot(
              entry: second,
              height: 100,
              color: const Color(0xFFBFC7D6),
              rank: 2,
              avatarSize: 46,
            ),
          ),
          Expanded(
            child: _PodiumSlot(
              entry: first,
              height: 130,
              color: AppColors.kGold,
              rank: 1,
              avatarSize: 56,
              showCrown: true,
            ),
          ),
          Expanded(
            child: _PodiumSlot(
              entry: third,
              height: 80,
              color: const Color(0xFFCE8A58),
              rank: 3,
              avatarSize: 46,
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  final LeaderboardEntry? entry;
  final double height;
  final Color color;
  final int rank;
  final double avatarSize;
  final bool showCrown;
  const _PodiumSlot({
    required this.entry,
    required this.height,
    required this.color,
    required this.rank,
    required this.avatarSize,
    this.showCrown = false,
  });

  @override
  Widget build(BuildContext context) {
    if (entry == null) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showCrown)
          const Text('👑', style: TextStyle(fontSize: 22))
        else
          const SizedBox(height: 22),
        const SizedBox(height: 2),
        _Avatar(
          url: entry!.avatarUrl,
          name: entry!.name,
          size: avatarSize,
          highlighted: entry!.isCurrentUser,
        ),
        const SizedBox(height: 6),
        Text(
          entry!.isCurrentUser ? 'You' : entry!.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTextStyles.labelMedium.copyWith(fontSize: 13),
        ),
        Text(
          '${entry!.points} pts',
          style: AppTextStyles.labelSmall
              .copyWith(color: AppColors.kPrimary, fontSize: 11),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(10),
            ),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '$rank',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: 20,
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final String? subtitle;
  const _LeaderboardRow({required this.entry, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isMe = entry.isCurrentUser;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isMe
            ? AppColors.kPrimary.withOpacity(0.10)
            : AppColors.kSurface,
        border: isMe
            ? Border.all(color: AppColors.kPrimary.withOpacity(0.25))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${entry.rank}',
              textAlign: TextAlign.center,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.kTextMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _Avatar(
            url: entry.avatarUrl,
            name: entry.name,
            size: 36,
            highlighted: isMe,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelLarge
                            .copyWith(fontSize: 14),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.kPrimary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null)
                  Text(subtitle!, style: AppTextStyles.bodySmall)
                else if (entry.subject != null)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: AppColors.kAccent.withOpacity(0.14),
                    ),
                    child: Text(
                      entry.subject!,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.kAccent,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${entry.points} pts',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              color: AppColors.kPrimary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  final bool highlighted;
  const _Avatar({
    required this.url,
    required this.name,
    required this.size,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.kAccent,
        border: highlighted
            ? Border.all(color: AppColors.kGold, width: 2)
            : null,
        image: url != null
            ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: url == null
          ? Text(
              initials,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: size * 0.38,
              ),
            )
          : null,
    );
  }

  String _initials(String n) {
    final parts = n.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

// ---------------------------------------------------------------------------
// History tab
// ---------------------------------------------------------------------------

class _HistoryTab extends StatelessWidget {
  final RewardsState state;
  const _HistoryTab({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.history.isEmpty) {
      return _EmptyPanel(
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
            color: Colors.black.withOpacity(0.03),
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
            '${entry.points >= 0 ? '+' : ''}${entry.points} pts',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              color: Color(0xFF16A34A),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatWhen(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(that).inDays;
    final time = DateFormat('h:mm a').format(dt);
    if (diff == 0) return 'Today $time';
    if (diff == 1) return 'Yesterday $time';
    if (diff < 7) return '${DateFormat('EEEE').format(dt)} $time';
    return DateFormat('MMM d · h:mm a').format(dt);
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
