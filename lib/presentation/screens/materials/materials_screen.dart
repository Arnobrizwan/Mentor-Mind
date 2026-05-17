// Flutter exports its own `MaterialType` enum (for the Material widget's
// `type` parameter). Our viewmodel also defines a `MaterialType` for
// pdf/video/note content. Hide Flutter's to disambiguate; the Material
// widget's internal usage is unaffected.
import 'package:flutter/material.dart' hide MaterialType;
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/application/viewmodels/materials/materials_viewmodel.dart';
import 'package:mentor_minds/data/models/learning_material.dart';

class MaterialsScreen extends ConsumerStatefulWidget {
  const MaterialsScreen({super.key});

  @override
  ConsumerState<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends ConsumerState<MaterialsScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      ref
          .read(materialsViewModelProvider.notifier)
          .searchMaterials(_searchCtrl.text);
    });
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    // Auto-load more when within 400px of the bottom.
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.maxScrollExtent - pos.pixels < 400) {
      final state = ref.read(materialsViewModelProvider);
      if (state.hasMore &&
          !state.isLoading &&
          !state.isLoadingMore &&
          state.materials.isNotEmpty) {
        ref.read(materialsViewModelProvider.notifier).loadMore();
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _openDetail(LearningMaterial m) async {
    ref
        .read(materialsViewModelProvider.notifier)
        .incrementViewCount(m.materialId);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.kSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MaterialDetailSheet(
        material: m,
        onOpen: () {
          Navigator.of(ctx).pop();
          _handleOpen(m);
        },
      ),
    );
  }

  void _handleOpen(LearningMaterial m) {
    // url_launcher swap-in: replace the snackbar with
    //   await launchUrl(Uri.parse(m.fileUrl), mode: LaunchMode.externalApplication);
    final url = m.fileUrl;
    final message = url.isEmpty
        ? 'This material has no file attached yet.'
        : '${m.type.ctaLabel}: $url';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.kTextDark,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(milliseconds: 2400),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(materialsViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: RefreshIndicator(
        color: AppColors.kPrimary,
        onRefresh: () =>
            ref.read(materialsViewModelProvider.notifier).refresh(),
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _MaterialsAppBar(controller: _searchCtrl),
            SliverPersistentHeader(
              pinned: true,
              delegate: _FiltersHeaderDelegate(
                selectedLevel: state.selectedLevel,
                selectedSubject: state.selectedSubject,
                selectedType: state.selectedType,
                onSelectLevel: (l) => ref
                    .read(materialsViewModelProvider.notifier)
                    .setLevel(l),
                onSelectSubject: (s) => ref
                    .read(materialsViewModelProvider.notifier)
                    .setSubject(s),
                onToggleType: (t) => ref
                    .read(materialsViewModelProvider.notifier)
                    .toggleType(t),
              ),
            ),
            if (state.isLoading)
              const _ShimmerGrid()
            else if (state.filteredMaterials.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  hasActiveFilters: state.anyFilterActive,
                  onClearFilters: () => ref
                      .read(materialsViewModelProvider.notifier)
                      .clearAllFilters(),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    mainAxisExtent: 220,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    childCount: state.filteredMaterials.length,
                    (ctx, i) => _MaterialCard(
                      material: state.filteredMaterials[i],
                      onTap: () => _openDetail(state.filteredMaterials[i]),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _PaginationFooter(
                  isLoadingMore: state.isLoadingMore,
                  hasMore: state.hasMore,
                  isSearching: state.searchQuery.trim().isNotEmpty,
                  onLoadMore: () => ref
                      .read(materialsViewModelProvider.notifier)
                      .loadMore(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// App bar — title + back + search field
// ---------------------------------------------------------------------------

class _MaterialsAppBar extends StatelessWidget {
  final TextEditingController controller;
  const _MaterialsAppBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: AppColors.kSurface,
      foregroundColor: AppColors.kTextDark,
      surfaceTintColor: AppColors.kSurface,
      elevation: 0,
      pinned: true,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          'Learning Materials',
          style: AppTextStyles.headingMedium.copyWith(fontSize: 20),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.canPop()
            ? context.pop()
            : context.goNamed(AppRoutes.dashboard),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: _SearchField(controller: controller),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.kBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          hintText: 'Search notes, videos, PDFs...',
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.kTextMuted,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.kTextMuted,
            size: 20,
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 40),
          suffixIcon: Tooltip(
            message: 'Voice search — coming soon',
            child: IconButton(
              onPressed: null,
              icon: Icon(
                Icons.mic_none_rounded,
                color: AppColors.kTextMuted.withOpacity(0.5),
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filters header (pinned)
// ---------------------------------------------------------------------------

class _FiltersHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String selectedLevel;
  final String selectedSubject;
  final MaterialType? selectedType;
  final ValueChanged<String> onSelectLevel;
  final ValueChanged<String> onSelectSubject;
  final ValueChanged<MaterialType> onToggleType;

  _FiltersHeaderDelegate({
    required this.selectedLevel,
    required this.selectedSubject,
    required this.selectedType,
    required this.onSelectLevel,
    required this.onSelectSubject,
    required this.onToggleType,
  });

  static const _subjects = <String>[
    kSubjectAll,
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'English',
    'ICT',
    'Accounting',
  ];

  static const _subjectShortLabels = <String, String>{
    kSubjectAll: 'All',
    'Mathematics': 'Math',
  };

  static const _height = 124.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.kBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _LevelPill(
                  label: 'O-Level',
                  active: selectedLevel == 'O Level',
                  onTap: () => onSelectLevel('O Level'),
                ),
                const SizedBox(width: 8),
                _LevelPill(
                  label: 'A-Level',
                  active: selectedLevel == 'A Level',
                  onTap: () => onSelectLevel('A Level'),
                ),
                const SizedBox(width: 8),
                _LevelPill(
                  label: 'Both',
                  active: selectedLevel == kLevelBoth,
                  onTap: () => onSelectLevel(kLevelBoth),
                ),
                const SizedBox(width: 16),
                Container(width: 1, color: const Color(0xFFE5E7EB)),
                const SizedBox(width: 16),
                for (final t in MaterialType.values) ...[
                  _TypeChip(
                    type: t,
                    active: selectedType == t,
                    onTap: () => onToggleType(t),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _subjects.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = _subjects[i];
                return _SubjectChip(
                  label: _subjectShortLabels[s] ?? s,
                  selected: selectedSubject == s,
                  onTap: () => onSelectSubject(s),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _FiltersHeaderDelegate old) {
    return old.selectedLevel != selectedLevel ||
        old.selectedSubject != selectedSubject ||
        old.selectedType != selectedType;
  }
}

class _LevelPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _LevelPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.kPrimary : AppColors.kSurface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? AppColors.kPrimary : const Color(0xFFE5E7EB),
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: active ? Colors.white : AppColors.kTextDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SubjectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.kPrimary : AppColors.kSurface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.kPrimary : const Color(0xFFE5E7EB),
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: selected ? Colors.white : AppColors.kTextDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final MaterialType type;
  final bool active;
  final VoidCallback onTap;

  const _TypeChip({
    required this.type,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = type.badgeColor;
    return Material(
      color: active ? color : AppColors.kSurface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? color : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                type.emoji,
                style: const TextStyle(fontSize: 13, height: 1),
              ),
              const SizedBox(width: 6),
              Text(
                type.longLabel,
                style: AppTextStyles.labelSmall.copyWith(
                  color: active ? Colors.white : AppColors.kTextDark,
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
// Material card
// ---------------------------------------------------------------------------

class _MaterialCard extends StatelessWidget {
  final LearningMaterial material;
  final VoidCallback onTap;

  const _MaterialCard({required this.material, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.kSurface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 55, child: _ThumbnailArea(material: material)),
            Expanded(
              flex: 45,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        material.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelMedium.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _SmallSubjectChip(subject: material.subject),
                        ),
                        const SizedBox(width: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.remove_red_eye_outlined,
                              size: 12,
                              color: AppColors.kTextMuted,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _fmtViews(material.views),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.kTextMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
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
    );
  }

  String _fmtViews(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _ThumbnailArea extends StatelessWidget {
  final LearningMaterial material;
  const _ThumbnailArea({required this.material});

  @override
  Widget build(BuildContext context) {
    final hasThumb = (material.thumbnailUrl ?? '').isNotEmpty;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasThumb)
          Image.network(
            material.thumbnailUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _GradientBg(colors: material.subjectGradient),
          )
        else
          _GradientBg(colors: material.subjectGradient),
        if (!hasThumb)
          Center(
            child: Icon(
              _iconForType(material.type),
              color: Colors.white.withOpacity(0.55),
              size: 42,
            ),
          ),
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              shape: BoxShape.circle,
            ),
            child: Text(
              material.level.startsWith('A') ? 'A' : 'O',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.kTextDark,
                height: 1.0,
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: material.type.badgeColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              material.type.label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.3,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _iconForType(MaterialType t) => switch (t) {
        MaterialType.pdf   => Icons.picture_as_pdf_rounded,
        MaterialType.video => Icons.play_circle_fill_rounded,
        MaterialType.note  => Icons.description_rounded,
      };
}

class _GradientBg extends StatelessWidget {
  final List<Color> colors;
  const _GradientBg({required this.colors});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
    );
  }
}

class _SmallSubjectChip extends StatelessWidget {
  final String subject;
  const _SmallSubjectChip({required this.subject});

  @override
  Widget build(BuildContext context) {
    final color = subjectColorFor(subject);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        subject,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail bottom sheet
// ---------------------------------------------------------------------------

class _MaterialDetailSheet extends StatelessWidget {
  final LearningMaterial material;
  final VoidCallback onOpen;

  const _MaterialDetailSheet({
    required this.material,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: material.subjectGradient,
                    ),
                  ),
                  child: Text(
                    material.type.emoji,
                    style: const TextStyle(fontSize: 26, height: 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        material.title,
                        style: AppTextStyles.headingSmall,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _MetaChip(
                            label: material.subject,
                            color: subjectColorFor(material.subject),
                          ),
                          _MetaChip(
                            label: material.level.startsWith('A')
                                ? 'A-Level'
                                : 'O-Level',
                            color: AppColors.kAccent,
                          ),
                          _MetaChip(
                            label: material.type.longLabel,
                            color: material.type.badgeColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: AppColors.kTextMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  'Uploaded ${DateFormat.yMMMd().format(material.createdAt)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.kTextMuted,
                  ),
                ),
                const SizedBox(width: 14),
                const Icon(
                  Icons.remove_red_eye_outlined,
                  size: 14,
                  color: AppColors.kTextMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  '${material.views} views',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.kTextMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onOpen,
              icon: Icon(_ctaIcon(material.type), size: 18),
              label: Text(material.type.ctaLabel),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.kTextMuted,
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _ctaIcon(MaterialType t) => switch (t) {
        MaterialType.pdf   => Icons.picture_as_pdf_rounded,
        MaterialType.video => Icons.play_arrow_rounded,
        MaterialType.note  => Icons.menu_book_rounded,
      };
}

class _MetaChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MetaChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pagination footer — "Load More" button or "All materials loaded"
// ---------------------------------------------------------------------------

class _PaginationFooter extends StatelessWidget {
  final bool isLoadingMore;
  final bool hasMore;
  final bool isSearching;
  final VoidCallback onLoadMore;

  const _PaginationFooter({
    required this.isLoadingMore,
    required this.hasMore,
    required this.isSearching,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Center(
        child: isLoadingMore
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(AppColors.kPrimary),
                ),
              )
            : hasMore
                ? OutlinedButton.icon(
                    onPressed: onLoadMore,
                    icon: const Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                    ),
                    label: const Text('Load More'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.kPrimary,
                      side: BorderSide(
                        color: AppColors.kPrimary.withOpacity(0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                  )
                : Text(
                    isSearching
                        ? 'End of search results'
                        : 'All materials loaded',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.kTextMuted,
                    ),
                  ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer loading grid
// ---------------------------------------------------------------------------

class _ShimmerGrid extends StatelessWidget {
  const _ShimmerGrid();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          mainAxisExtent: 220,
        ),
        delegate: SliverChildBuilderDelegate(
          childCount: 6,
          (_, __) => const _ShimmerCard(),
        ),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE5E7EB),
      highlightColor: const Color(0xFFF3F4F6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 55,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE5E7EB),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(14)),
                ),
              ),
            ),
            Expanded(
              flex: 45,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 10,
                      width: double.infinity,
                      color: const Color(0xFFE5E7EB),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 10,
                      width: 120,
                      color: const Color(0xFFE5E7EB),
                    ),
                    const Spacer(),
                    Container(
                      height: 14,
                      width: 60,
                      color: const Color(0xFFE5E7EB),
                    ),
                  ],
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
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final bool hasActiveFilters;
  final VoidCallback onClearFilters;
  const _EmptyState({
    required this.hasActiveFilters,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.kPrimary.withOpacity(0.08),
            ),
            child: const Icon(
              Icons.menu_book_outlined,
              size: 60,
              color: AppColors.kPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No materials found',
            textAlign: TextAlign.center,
            style: AppTextStyles.headingMedium,
          ),
          const SizedBox(height: 6),
          Text(
            hasActiveFilters
                ? 'Try adjusting your filters.'
                : 'Materials will appear here as teachers publish them.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.kTextMuted,
              height: 1.4,
            ),
          ),
          if (hasActiveFilters) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label: const Text('Clear filters'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.kPrimary,
                side: BorderSide(color: AppColors.kPrimary.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
