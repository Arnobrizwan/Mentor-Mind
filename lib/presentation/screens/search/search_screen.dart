import 'dart:ui';

import 'package:flutter/material.dart' hide MaterialType;
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:mentor_minds/application/viewmodels/search/search_viewmodel.dart';
import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/core/theme/app_radius.dart';
import 'package:mentor_minds/core/theme/app_spacing.dart';
import 'package:mentor_minds/core/theme/brand_colors.dart';
import 'package:mentor_minds/data/models/learning_material.dart';
import 'package:mentor_minds/data/models/material_search_hit.dart';
import 'package:mentor_minds/data/models/session_search_hit.dart';
import 'package:mentor_minds/shared/widgets/empty_state.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    ref.read(searchViewModelProvider.notifier).search(_ctrl.text);
    setState(() {}); // rebuild so clear button appears/disappears
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _clear() {
    _ctrl.clear();
    _focus.requestFocus();
  }

  void _applyQuery(String q) {
    _ctrl.text = q;
    _ctrl.selection =
        TextSelection.fromPosition(TextPosition(offset: q.length));
    _focus.requestFocus();
  }

  void _onResultTap() {
    ref.read(searchViewModelProvider.notifier).saveRecentSearch(_ctrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final state = ref.watch(searchViewModelProvider);

    return Scaffold(
      backgroundColor: brand.background,
      body: SafeArea(
        child: Column(
          children: [
            _SearchHeader(
              controller: _ctrl,
              focusNode: _focus,
              hasText: _ctrl.text.isNotEmpty,
              onClear: _clear,
              onBack: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.goNamed(AppRoutes.dashboard);
                }
              },
            ),
            Expanded(
              child: state.hasQuery
                  ? _ResultsArea(state: state, onResultTap: _onResultTap)
                  : _IdleArea(
                      recent: state.recentSearches,
                      onPickRecent: _applyQuery,
                      onRemoveRecent: (i) => ref
                          .read(searchViewModelProvider.notifier)
                          .clearRecentSearch(i),
                      onClearRecent: () => ref
                          .read(searchViewModelProvider.notifier)
                          .clearAllRecent(),
                      onPickTrending: _applyQuery,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header — back + search field
// ---------------------------------------------------------------------------

class _SearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final VoidCallback onClear;
  final VoidCallback onBack;

  const _SearchHeader({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.onClear,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm, AppSpacing.sm, AppSpacing.lg, AppSpacing.md,
      ),
      color: brand.surface,
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            splashRadius: 22,
          ),
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: brand.background,
                borderRadius: AppRadius.lgBorder,
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                textInputAction: TextInputAction.search,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: brand.textDark, fontSize: 15,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.lg, horizontal: AppSpacing.xs,
                  ),
                  hintText: 'Search questions, materials, topics...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: brand.textMuted,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: brand.primary,
                    size: 22,
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
                  suffixIcon: hasText
                      ? IconButton(
                          onPressed: onClear,
                          splashRadius: 18,
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: brand.textMuted,
                          ),
                        )
                      : null,
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
// Idle area — recent searches + trending topics
// ---------------------------------------------------------------------------

class _IdleArea extends StatelessWidget {
  final List<String> recent;
  final ValueChanged<String> onPickRecent;
  final ValueChanged<int> onRemoveRecent;
  final VoidCallback onClearRecent;
  final ValueChanged<String> onPickTrending;

  const _IdleArea({
    required this.recent,
    required this.onPickRecent,
    required this.onRemoveRecent,
    required this.onClearRecent,
    required this.onPickTrending,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.xl - 4, AppSpacing.lg, AppSpacing.xl,
      ),
      children: [
        if (recent.isNotEmpty) ...[
          Row(
            children: [
              Text(
                'Recent Searches',
                style: AppTextStyles.headingSmall.copyWith(
                  color: brand.textDark,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onClearRecent,
                style: TextButton.styleFrom(
                  foregroundColor: brand.textMuted,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs, vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Clear all',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: brand.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < recent.length; i++)
            _RecentRow(
              text: recent[i],
              onTap: () => onPickRecent(recent[i]),
              onRemove: () => onRemoveRecent(i),
            ),
          const SizedBox(height: AppSpacing.xl),
        ],
        Text(
          'Trending Topics',
          style: AppTextStyles.headingSmall.copyWith(color: brand.textDark),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final topic in kTrendingTopics)
              _TrendingChip(label: topic, onTap: () => onPickTrending(topic)),
          ],
        ),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RecentRow({
    required this.text,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdBorder,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs, vertical: AppSpacing.sm + 2,
        ),
        child: Row(
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 18,
              color: brand.textMuted,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(color: brand.textDark),
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: Icon(
                Icons.close_rounded, size: 16, color: brand.textMuted,
              ),
              splashRadius: 16,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TrendingChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Material(
      color: brand.surface,
      borderRadius: AppRadius.pillBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillBorder,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md + 2, vertical: 9,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.pillBorder,
            border: Border.all(color: brand.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.trending_up_rounded, size: 14, color: brand.accent,
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: brand.textDark,
                  fontWeight: FontWeight.w600,
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
// Results area — tabs + per-tab list
// ---------------------------------------------------------------------------

class _ResultsArea extends StatelessWidget {
  final SearchState state;
  final VoidCallback onResultTap;

  const _ResultsArea({required this.state, required this.onResultTap});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Material(
            color: brand.surface,
            child: TabBar(
              labelColor: brand.primary,
              unselectedLabelColor: brand.textMuted,
              indicatorColor: brand.primary,
              indicatorWeight: 2.5,
              labelStyle: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: AppTextStyles.labelMedium,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Materials'),
                Tab(text: 'My Sessions'),
              ],
            ),
          ),
          Divider(height: 1, color: brand.border),
          Expanded(
            child: state.isLoading
                ? Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(brand.primary),
                      ),
                    ),
                  )
                : TabBarView(
                    children: [
                      _AllTab(state: state, onResultTap: onResultTap),
                      _MaterialsTab(state: state, onResultTap: onResultTap),
                      _SessionsTab(state: state, onResultTap: onResultTap),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// All tab — mixed list with section headers
// ---------------------------------------------------------------------------

class _AllTab extends StatelessWidget {
  final SearchState state;
  final VoidCallback onResultTap;
  const _AllTab({required this.state, required this.onResultTap});

  @override
  Widget build(BuildContext context) {
    if (state.totalHits == 0) {
      return _NoResults(query: state.query);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl,
      ),
      children: [
        if (state.materialHits.isNotEmpty) ...[
          _SectionHeader(title: 'Materials', count: state.materialHits.length),
          const SizedBox(height: AppSpacing.sm),
          for (final h in state.materialHits)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
              child: _MaterialResultTile(
                hit: h, query: state.query, onTap: onResultTap,
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (state.sessionHits.isNotEmpty || !state.isPremium) ...[
          _SectionHeader(
            title: 'Past Sessions',
            count: state.sessionHits.length,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!state.isPremium)
            const _SessionsPremiumLock(compact: true)
          else
            for (final h in state.sessionHits)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
                child: _SessionResultTile(
                  hit: h, query: state.query, onTap: onResultTap,
                ),
              ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Materials tab
// ---------------------------------------------------------------------------

class _MaterialsTab extends StatelessWidget {
  final SearchState state;
  final VoidCallback onResultTap;
  const _MaterialsTab({required this.state, required this.onResultTap});

  @override
  Widget build(BuildContext context) {
    if (state.materialHits.isEmpty) {
      return _NoResults(query: state.query);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl,
      ),
      itemCount: state.materialHits.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm + 2),
      itemBuilder: (_, i) => _MaterialResultTile(
        hit: state.materialHits[i], query: state.query, onTap: onResultTap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sessions tab
// ---------------------------------------------------------------------------

class _SessionsTab extends StatelessWidget {
  final SearchState state;
  final VoidCallback onResultTap;
  const _SessionsTab({required this.state, required this.onResultTap});

  @override
  Widget build(BuildContext context) {
    if (!state.isPremium) {
      return const _SessionsPremiumLock();
    }
    if (state.sessionHits.isEmpty) {
      return _NoResults(query: state.query);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl,
      ),
      itemCount: state.sessionHits.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm + 2),
      itemBuilder: (_, i) => _SessionResultTile(
        hit: state.sessionHits[i], query: state.query, onTap: onResultTap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Material result tile
// ---------------------------------------------------------------------------

class _MaterialResultTile extends StatelessWidget {
  final MaterialSearchHit hit;
  final String query;
  final VoidCallback onTap;

  const _MaterialResultTile({
    required this.hit,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Material(
      color: brand.surface,
      borderRadius: AppRadius.mdBorder,
      child: InkWell(
        onTap: () {
          onTap();
          context.goNamed(AppRoutes.materials);
        },
        borderRadius: AppRadius.mdBorder,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: hit.subjectColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md,
                    AppSpacing.md, AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: AppTextStyles.labelMedium.copyWith(
                            color: brand.textDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            height: 1.3,
                          ),
                          children: _highlight(hit.title, query, brand.primary),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs + 2),
                      Row(
                        children: [
                          _ChipSmall(
                            label: hit.subject, color: hit.subjectColor,
                          ),
                          const SizedBox(width: AppSpacing.xs + 2),
                          _ChipSmall(
                            label: hit.type.label,
                            color: hit.type.badgeColor,
                            compact: true,
                          ),
                          const SizedBox(width: AppSpacing.xs + 2),
                          _ChipSmall(
                            label: hit.level.startsWith('A')
                                ? 'A-Level'
                                : 'O-Level',
                            color: brand.accent,
                            compact: true,
                          ),
                          const Spacer(),
                          Text(
                            DateFormat('MMM d').format(hit.createdAt),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: brand.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _ChipSmall extends StatelessWidget {
  final String label;
  final Color color;
  final bool compact;
  const _ChipSmall({
    required this.label,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : AppSpacing.sm, vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppRadius.pillBorder,
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Session result tile
// ---------------------------------------------------------------------------

class _SessionResultTile extends StatelessWidget {
  final SessionSearchHit hit;
  final String query;
  final VoidCallback onTap;

  const _SessionResultTile({
    required this.hit,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Material(
      color: brand.surface,
      borderRadius: AppRadius.mdBorder,
      child: InkWell(
        onTap: () {
          onTap();
          context.goNamed(AppRoutes.tutor);
        },
        borderRadius: AppRadius.mdBorder,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: brand.accent.withValues(alpha: 0.12),
                      borderRadius: AppRadius.pillBorder,
                    ),
                    child: Text(
                      '\u{1F916} AI Session',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: brand.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  _ChipSmall(
                    label: hit.subject,
                    color: hit.subjectColor,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: brand.textDark,
                    height: 1.4,
                  ),
                  children: _highlight(hit.preview, query, brand.primary),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text(
                    DateFormat('MMM d, h:mm a').format(hit.updatedAt),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: brand.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: brand.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${hit.messageCount} message${hit.messageCount == 1 ? '' : 's'}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: brand.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: brand.textMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Row(
      children: [
        Text(
          title,
          style: AppTextStyles.labelLarge.copyWith(
            color: brand.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs + 2, vertical: 2,
          ),
          decoration: BoxDecoration(
            color: brand.primary.withValues(alpha: 0.10),
            borderRadius: AppRadius.pillBorder,
          ),
          child: Text(
            '$count',
            style: AppTextStyles.labelSmall.copyWith(
              color: brand.primary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// No results — wraps the shared EmptyState (search variant) with a
// "Browse Materials" CTA.
// ---------------------------------------------------------------------------

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EmptyState(
        title: "No results for '$query'",
        message: 'Try different keywords or browse all materials.',
        variant: EmptyStateVariant.search,
        actionLabel: 'Browse Materials',
        onAction: () => context.goNamed(AppRoutes.materials),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Premium lock for Sessions tab (free user)
// ---------------------------------------------------------------------------

class _SessionsPremiumLock extends StatelessWidget {
  final bool compact;
  const _SessionsPremiumLock({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 0 : AppSpacing.lg),
      child: Stack(
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Column(
              children: [
                for (var i = 0; i < (compact ? 2 : 3); i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
                    child: _FakeSessionTile(index: i),
                  ),
              ],
            ),
          ),
          Positioned.fill(
            child: Container(
              color: brand.background.withValues(alpha: 0.4),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? AppSpacing.sm : AppSpacing.lg,
              vertical: compact ? AppSpacing.lg : AppSpacing.xxl,
            ),
            child: const _UpgradeCard(),
          ),
        ],
      ),
    );
  }
}

class _FakeSessionTile extends StatelessWidget {
  final int index;
  const _FakeSessionTile({required this.index});

  static const _subjects = ['Physics', 'Mathematics', 'Chemistry'];

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final subject = _subjects[index % _subjects.length];
    final color = subjectColorFor(subject);
    return Material(
      color: brand.surface,
      borderRadius: AppRadius.mdBorder,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: brand.accent.withValues(alpha: 0.12),
                    borderRadius: AppRadius.pillBorder,
                  ),
                  child: Text(
                    '\u{1F916} AI Session',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: brand.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs + 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: AppRadius.pillBorder,
                  ),
                  child: Text(
                    subject,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: brand.border,
                borderRadius: AppRadius.xsBorder,
              ),
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            Container(
              height: 10,
              width: 160,
              decoration: BoxDecoration(
                color: brand.border,
                borderRadius: AppRadius.xsBorder,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              height: 8,
              width: 100,
              decoration: BoxDecoration(
                color: brand.border,
                borderRadius: AppRadius.xsBorder,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard();

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl - 4),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: AppRadius.lgBorder,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.kGold, Color(0xFFE28A00)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.kGold.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_rounded, color: Colors.white, size: 24,
            ),
          ),
          const SizedBox(height: AppSpacing.md + 2),
          Text(
            '\u{1F512} Upgrade to search your full chat history',
            textAlign: TextAlign.center,
            style: AppTextStyles.headingSmall.copyWith(
              color: brand.textDark, fontSize: 15,
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            'Premium members get unlimited access to every past AI Tutor '
            "session — even ones from months ago.",
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: brand.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _GoPremiumButton(),
        ],
      ),
    );
  }
}

/// Custom gold pill button — the premium identity moment. Not theme-flipped:
/// gold stays gold in both modes (matches the existing Upgrade Modal).
class _GoPremiumButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _showComingSoon(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.kGold,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(44),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.pillBorder,
          ),
        ),
        child: const Text('Go Premium'),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    final brand = context.brand;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Premium plans are coming soon.',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: brand.textDark,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(AppSpacing.lg),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
          duration: const Duration(milliseconds: 1800),
        ),
      );
  }
}

// ---------------------------------------------------------------------------
// Highlighting helper — highlight matches in `text` against `query` using
// the brand primary color.
// ---------------------------------------------------------------------------

List<TextSpan> _highlight(String text, String query, Color highlightColor) {
  final q = query.trim();
  if (q.isEmpty) return [TextSpan(text: text)];

  final spans = <TextSpan>[];
  final lower = text.toLowerCase();
  final needle = q.toLowerCase();
  var start = 0;

  while (start < text.length) {
    final i = lower.indexOf(needle, start);
    if (i == -1) {
      spans.add(TextSpan(text: text.substring(start)));
      break;
    }
    if (i > start) {
      spans.add(TextSpan(text: text.substring(start, i)));
    }
    spans.add(
      TextSpan(
        text: text.substring(i, i + needle.length),
        style: TextStyle(
          color: highlightColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    start = i + needle.length;
  }

  return spans;
}
