import 'dart:ui';

import 'package:flutter/material.dart' hide MaterialType;
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/application/viewmodels/materials/materials_viewmodel.dart';
import 'package:mentor_minds/application/viewmodels/search/search_viewmodel.dart';

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
    final state = ref.watch(searchViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.kBackground,
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
                  ? _ResultsArea(
                      state: state,
                      onResultTap: _onResultTap,
                    )
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
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
      color: AppColors.kSurface,
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
                color: AppColors.kBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                textInputAction: TextInputAction.search,
                style: AppTextStyles.bodyLarge.copyWith(fontSize: 15),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                  hintText: 'Search questions, materials, topics...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.kTextMuted,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.kPrimary,
                    size: 22,
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
                  suffixIcon: hasText
                      ? IconButton(
                          onPressed: onClear,
                          splashRadius: 18,
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.kTextMuted,
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        if (recent.isNotEmpty) ...[
          Row(
            children: [
              Text('Recent Searches', style: AppTextStyles.headingSmall),
              const Spacer(),
              TextButton(
                onPressed: onClearRecent,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.kTextMuted,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Clear all',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.kTextMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < recent.length; i++)
            _RecentRow(
              text: recent[i],
              onTap: () => onPickRecent(recent[i]),
              onRemove: () => onRemoveRecent(i),
            ),
          const SizedBox(height: 24),
        ],
        Text('Trending Topics', style: AppTextStyles.headingSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final topic in kTrendingTopics)
              _TrendingChip(
                label: topic,
                onTap: () => onPickTrending(topic),
              ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 18,
              color: AppColors.kTextMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium,
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(
                Icons.close_rounded,
                size: 16,
                color: AppColors.kTextMuted,
              ),
              splashRadius: 16,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
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
    return Material(
      color: AppColors.kSurface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.trending_up_rounded,
                size: 14,
                color: AppColors.kAccent,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.kTextDark,
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
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Material(
            color: AppColors.kSurface,
            child: TabBar(
              labelColor: AppColors.kPrimary,
              unselectedLabelColor: AppColors.kTextMuted,
              indicatorColor: AppColors.kPrimary,
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
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor:
                            AlwaysStoppedAnimation(AppColors.kPrimary),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (state.materialHits.isNotEmpty) ...[
          _SectionHeader(
            title: 'Materials',
            count: state.materialHits.length,
          ),
          const SizedBox(height: 8),
          for (final h in state.materialHits)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MaterialResultTile(
                hit: h,
                query: state.query,
                onTap: onResultTap,
              ),
            ),
          const SizedBox(height: 16),
        ],
        if (state.sessionHits.isNotEmpty || !state.isPremium) ...[
          _SectionHeader(
            title: 'Past Sessions',
            count: state.sessionHits.length,
          ),
          const SizedBox(height: 8),
          if (!state.isPremium)
            const _SessionsPremiumLock(compact: true)
          else
            for (final h in state.sessionHits)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SessionResultTile(
                  hit: h,
                  query: state.query,
                  onTap: onResultTap,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: state.materialHits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _MaterialResultTile(
        hit: state.materialHits[i],
        query: state.query,
        onTap: onResultTap,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: state.sessionHits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _SessionResultTile(
        hit: state.sessionHits[i],
        query: state.query,
        onTap: onResultTap,
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
    return Material(
      color: AppColors.kSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          onTap();
          context.goNamed(AppRoutes.materials);
        },
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: hit.subjectColor),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.kTextDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            height: 1.3,
                          ),
                          children: _highlight(hit.title, query),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _ChipSmall(
                            label: hit.subject,
                            color: hit.subjectColor,
                          ),
                          const SizedBox(width: 6),
                          _ChipSmall(
                            label: hit.type.label,
                            color: hit.type.badgeColor,
                            compact: true,
                          ),
                          const SizedBox(width: 6),
                          _ChipSmall(
                            label: hit.level.startsWith('A')
                                ? 'A-Level'
                                : 'O-Level',
                            color: AppColors.kAccent,
                            compact: true,
                          ),
                          const Spacer(),
                          Text(
                            DateFormat('MMM d').format(hit.createdAt),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.kTextMuted,
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
        horizontal: compact ? 6 : 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
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
    return Material(
      color: AppColors.kSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          onTap();
          context.goNamed(AppRoutes.tutor);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.kAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '\u{1F916} AI Session',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.kAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _ChipSmall(
                    label: hit.subject,
                    color: hit.subjectColor,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.kTextDark,
                    height: 1.4,
                  ),
                  children: _highlight(hit.preview, query),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    DateFormat('MMM d, h:mm a').format(hit.updatedAt),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.kTextMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: const BoxDecoration(
                      color: AppColors.kTextMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${hit.messageCount} message${hit.messageCount == 1 ? '' : 's'}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.kTextMuted,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: AppColors.kTextMuted,
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
    return Row(
      children: [
        Text(
          title,
          style: AppTextStyles.labelLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.kPrimary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.kPrimary,
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
// No results
// ---------------------------------------------------------------------------

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.kPrimary.withOpacity(0.08),
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.kPrimary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "No results for '$query'",
            textAlign: TextAlign.center,
            style: AppTextStyles.headingSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Try different keywords or browse all materials.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.kTextMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => context.goNamed(AppRoutes.materials),
            icon: const Icon(Icons.menu_book_rounded, size: 16),
            label: const Text('Browse Materials'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.kPrimary,
              side: BorderSide(color: AppColors.kPrimary.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ],
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
    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 0 : 16),
      child: Stack(
        children: [
          // Blurred fake session tiles behind
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Column(
              children: [
                for (var i = 0; i < (compact ? 2 : 3); i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _FakeSessionTile(index: i),
                  ),
              ],
            ),
          ),
          Positioned.fill(
            child: Container(color: AppColors.kBackground.withOpacity(0.4)),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 16,
              vertical: compact ? 16 : 32,
            ),
            child: _UpgradeCard(),
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
    final subject = _subjects[index % _subjects.length];
    final color = subjectColorFor(subject);
    return Material(
      color: AppColors.kSurface,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.kAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '\u{1F916} AI Session',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.kAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
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
            const SizedBox(height: 10),
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 10,
              width: 160,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 8,
              width: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.kSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
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
                  color: AppColors.kGold.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '\u{1F512} Upgrade to search your full chat history',
            textAlign: TextAlign.center,
            style: AppTextStyles.headingSmall.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Premium members get unlimited access to every past AI Tutor '
            "session — even ones from months ago.",
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.kTextMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        'Premium plans are coming soon.',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: Colors.white),
                      ),
                      backgroundColor: AppColors.kTextDark,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      duration: const Duration(milliseconds: 1800),
                    ),
                  );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kGold,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
              ),
              child: const Text('Go Premium'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Highlighting helper
// ---------------------------------------------------------------------------

List<TextSpan> _highlight(String text, String query) {
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
        style: const TextStyle(
          color: AppColors.kPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    start = i + needle.length;
  }

  return spans;
}
