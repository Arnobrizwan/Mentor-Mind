// Flutter exports its own `MaterialType` enum (for the Material widget's
// `type` parameter). Our viewmodel also defines a `MaterialType` for
// pdf/video/note content. Hide Flutter's to disambiguate; the Material
// widget's internal usage is unaffected.
import 'package:flutter/material.dart' hide MaterialType;
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:mentor_minds/application/viewmodels/config/remote_config_providers.dart';
import 'package:mentor_minds/application/viewmodels/materials/materials_viewmodel.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/core/theme/app_radius.dart';
import 'package:mentor_minds/core/theme/app_spacing.dart';
import 'package:mentor_minds/core/theme/brand_colors.dart';
import 'package:mentor_minds/data/models/learning_material.dart';
import 'package:mentor_minds/shared/widgets/empty_state.dart';
import 'package:mentor_minds/shared/widgets/pill_button.dart';
import 'package:mentor_minds/shared/widgets/skeleton_block.dart';

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
      backgroundColor: context.brand.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadius.xlRadius),
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
          backgroundColor: context.brand.textDark,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(AppSpacing.lg),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
          duration: const Duration(milliseconds: 2400),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final state = ref.watch(materialsViewModelProvider);
    final curriculum = ref.watch(currentCurriculumConfigProvider);

    return Scaffold(
      backgroundColor: brand.background,
      body: RefreshIndicator(
        color: brand.primary,
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
                subjectFilters: curriculum.materialsSubjectFilters,
                subjectShortLabels: curriculum.subjectShortLabels,
                levelBothSentinel: curriculum.materialsLevelBothSentinel,
                onSelectLevel: (l) => ref
                    .read(materialsViewModelProvider.notifier)
                    .setLevel(l),
                onSelectSubject: (s) => ref
                    .read(materialsViewModelProvider.notifier)
                    .setSubject(s),
                onToggleType: (t) => ref
                    .read(materialsViewModelProvider.notifier)
                    .toggleType(t),
                brandBackground: brand.background,
                brandSurface: brand.surface,
                brandBorder: brand.border,
                brandPrimary: brand.primary,
                brandTextDark: brand.textDark,
              ),
            ),
            if (state.isLoading)
              const _ShimmerGrid()
            else if (state.filteredMaterials.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _MaterialsEmptyState(
                  hasActiveFilters: state.anyFilterActive,
                  onClearFilters: () => ref
                      .read(materialsViewModelProvider.notifier)
                      .clearAllFilters(),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm,
                ),
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

class _MaterialsAppBar extends ConsumerWidget {
  final TextEditingController controller;
  const _MaterialsAppBar({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    return SliverAppBar(
      backgroundColor: brand.surface,
      foregroundColor: brand.textDark,
      surfaceTintColor: brand.surface,
      elevation: 0,
      pinned: true,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.xs),
        child: Text(
          'Learning Materials',
          style: AppTextStyles.headingMedium.copyWith(
            color: brand.textDark,
            fontSize: 20,
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: 'Back',
        onPressed: () async {
          if (context.canPop()) {
            context.pop();
            return;
          }
          // Resolve the user's role-appropriate home so teachers don't
          // get kicked into the student dashboard when they back out of
          // the shared Materials screen.
          final route = await resolveHomeRouteName(ref);
          if (context.mounted) context.goNamed(route);
        },
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.md,
          ),
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
    final brand = context.brand;
    return Container(
      decoration: BoxDecoration(
        color: brand.background,
        borderRadius: AppRadius.mdBorder,
      ),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        style: AppTextStyles.bodyMedium.copyWith(color: brand.textDark),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md,
          ),
          hintText: 'Search notes, videos, PDFs...',
          hintStyle: AppTextStyles.bodyMedium.copyWith(color: brand.textMuted),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: brand.textMuted,
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
                color: brand.textMuted.withValues(alpha: 0.5),
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
//
// Brand colors are passed in via the constructor because
// SliverPersistentHeaderDelegate.build receives its own context that
// can be outside the BrandColors theme scope at hot-reload time. Reading
// brand once at the parent and threading it through avoids subtle
// "extension not found" hot-reload errors.
// ---------------------------------------------------------------------------

class _FiltersHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String selectedLevel;
  final String selectedSubject;
  final MaterialType? selectedType;
  final List<String> subjectFilters;
  final Map<String, String> subjectShortLabels;
  final String levelBothSentinel;
  final ValueChanged<String> onSelectLevel;
  final ValueChanged<String> onSelectSubject;
  final ValueChanged<MaterialType> onToggleType;

  final Color brandBackground;
  final Color brandSurface;
  final Color brandBorder;
  final Color brandPrimary;
  final Color brandTextDark;

  _FiltersHeaderDelegate({
    required this.selectedLevel,
    required this.selectedSubject,
    required this.selectedType,
    required this.subjectFilters,
    required this.subjectShortLabels,
    required this.levelBothSentinel,
    required this.onSelectLevel,
    required this.onSelectSubject,
    required this.onToggleType,
    required this.brandBackground,
    required this.brandSurface,
    required this.brandBorder,
    required this.brandPrimary,
    required this.brandTextDark,
  });

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
      color: brandBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.sm + 2),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                _LevelPill(
                  label: 'O-Level',
                  active: selectedLevel == 'O Level',
                  onTap: () => onSelectLevel('O Level'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _LevelPill(
                  label: 'A-Level',
                  active: selectedLevel == 'A Level',
                  onTap: () => onSelectLevel('A Level'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _LevelPill(
                  label: 'Both',
                  active: selectedLevel == levelBothSentinel,
                  onTap: () => onSelectLevel(levelBothSentinel),
                ),
                const SizedBox(width: AppSpacing.lg),
                Container(width: 1, color: brandBorder),
                const SizedBox(width: AppSpacing.lg),
                for (final t in MaterialType.values) ...[
                  _TypeChip(
                    type: t,
                    active: selectedType == t,
                    onTap: () => onToggleType(t),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: subjectFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, i) {
                final s = subjectFilters[i];
                return _FilterChip(
                  label: subjectShortLabels[s] ?? s,
                  selected: selectedSubject == s,
                  onTap: () => onSelectSubject(s),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _FiltersHeaderDelegate old) {
    return old.selectedLevel != selectedLevel ||
        old.selectedSubject != selectedSubject ||
        old.selectedType != selectedType ||
        old.brandBackground != brandBackground ||
        old.brandSurface != brandSurface;
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
    final brand = context.brand;
    return Material(
      color: active ? brand.primary : brand.surface,
      borderRadius: AppRadius.pillBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillBorder,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md + 2, vertical: 7,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.pillBorder,
            border: Border.all(
              color: active ? brand.primary : brand.border,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: active ? Colors.white : brand.textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Local subject filter chip used inside the materials filter row.
/// (The shared SubjectChip widget is similar but expects 8-pt vertical
/// padding; the materials filter row needs slightly tighter geometry.)
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Material(
      color: selected ? brand.primary : brand.surface,
      borderRadius: AppRadius.pillBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillBorder,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 7,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.pillBorder,
            border: Border.all(
              color: selected ? brand.primary : brand.border,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: selected ? Colors.white : brand.textDark,
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
    final brand = context.brand;
    final color = type.badgeColor;
    return Material(
      color: active ? color : brand.surface,
      borderRadius: AppRadius.pillBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillBorder,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 7,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.pillBorder,
            border: Border.all(color: active ? color : brand.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                type.emoji,
                style: const TextStyle(fontSize: 13, height: 1),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                type.longLabel,
                style: AppTextStyles.labelSmall.copyWith(
                  color: active ? Colors.white : brand.textDark,
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
    final brand = context.brand;
    return Material(
      color: brand.surface,
      borderRadius: AppRadius.lgBorder,
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
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm + 2, AppSpacing.sm,
                  AppSpacing.sm + 2, AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        material.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: brand.textDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs + 2),
                    Row(
                      children: [
                        Expanded(
                          child: _SmallSubjectChip(subject: material.subject),
                        ),
                        const SizedBox(width: AppSpacing.xs + 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.remove_red_eye_outlined,
                              size: 12,
                              color: brand.textMuted,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _fmtViews(material.views),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: brand.textMuted,
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
    final brand = context.brand;
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
              subjectIconFor(material.subject),
              color: Colors.white.withValues(alpha: 0.85),
              size: 46,
            ),
          ),
        Positioned(
          top: AppSpacing.sm,
          left: AppSpacing.sm,
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              shape: BoxShape.circle,
            ),
            child: Text(
              material.level.startsWith('A') ? 'A' : 'O',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: brand.textDark,
                height: 1.0,
              ),
            ),
          ),
        ),
        Positioned(
          top: AppSpacing.sm,
          right: AppSpacing.sm,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs + 2, vertical: 3,
            ),
            decoration: BoxDecoration(
              color: material.type.badgeColor,
              borderRadius: AppRadius.xsBorder,
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 2, vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillBorder,
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
    final brand = context.brand;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: brand.border,
                  borderRadius: AppRadius.xsBorder,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.mdBorder,
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
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        material.title,
                        style: AppTextStyles.headingSmall.copyWith(
                          color: brand.textDark,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          _MetaChip(
                            label: material.subject,
                            color: subjectColorFor(material.subject),
                          ),
                          _MetaChip(
                            label: material.level.startsWith('A')
                                ? 'A-Level'
                                : 'O-Level',
                            color: brand.accent,
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
            const SizedBox(height: AppSpacing.md + 2),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: brand.textMuted,
                ),
                const SizedBox(width: AppSpacing.xs + 2),
                Text(
                  'Uploaded ${DateFormat.yMMMd().format(material.createdAt)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: brand.textMuted,
                  ),
                ),
                const SizedBox(width: AppSpacing.md + 2),
                Icon(
                  Icons.remove_red_eye_outlined,
                  size: 14,
                  color: brand.textMuted,
                ),
                const SizedBox(width: AppSpacing.xs + 2),
                Text(
                  '${material.views} views',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: brand.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl - 4),
            PillButton(
              label: material.type.ctaLabel,
              icon: _ctaIcon(material.type),
              onPressed: onOpen,
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: PillButton(
                label: 'Close',
                variant: PillVariant.ghost,
                fullWidth: false,
                dense: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm, vertical: 3,
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
    final brand = context.brand;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl,
      ),
      child: Center(
        child: isLoadingMore
            ? SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(brand.primary),
                ),
              )
            : hasMore
                ? PillButton(
                    label: 'Load More',
                    icon: Icons.expand_more_rounded,
                    variant: PillVariant.secondary,
                    dense: true,
                    fullWidth: false,
                    onPressed: onLoadMore,
                  )
                : Text(
                    isSearching
                        ? 'End of search results'
                        : 'All materials loaded',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: brand.textMuted,
                    ),
                  ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer loading grid — uses shared SkeletonGroup + SkeletonBlock so the
// shimmer animation matches the rest of the redesign.
// ---------------------------------------------------------------------------

class _ShimmerGrid extends StatelessWidget {
  const _ShimmerGrid();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl,
      ),
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
    final brand = context.brand;
    return Container(
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: AppRadius.lgBorder,
      ),
      child: SkeletonGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 55,
              child: Container(
                decoration: BoxDecoration(
                  color: brand.border,
                  borderRadius: const BorderRadius.vertical(
                    top: AppRadius.lgRadius,
                  ),
                ),
              ),
            ),
            const Expanded(
              flex: 45,
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.sm + 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBlock(height: 10),
                    SizedBox(height: AppSpacing.xs + 2),
                    SkeletonBlock(width: 120, height: 10),
                    Spacer(),
                    SkeletonBlock(width: 60, height: 14),
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
// Empty state — wraps the shared EmptyState with a "Clear filters" CTA
// when filters are active.
// ---------------------------------------------------------------------------

class _MaterialsEmptyState extends StatelessWidget {
  final bool hasActiveFilters;
  final VoidCallback onClearFilters;
  const _MaterialsEmptyState({
    required this.hasActiveFilters,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EmptyState(
        title: 'No materials found',
        message: hasActiveFilters
            ? 'Try adjusting your filters.'
            : 'Materials will appear here as teachers publish them.',
        illustrationAsset: 'assets/images/illustrations/empty_materials.png',
        actionLabel: hasActiveFilters ? 'Clear filters' : null,
        onAction: hasActiveFilters ? onClearFilters : null,
      ),
    );
  }
}
