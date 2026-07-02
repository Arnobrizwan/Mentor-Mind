import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/data/models/learning_material.dart';
import 'package:mentor_minds/data/repositories/auth_repository.dart';
import 'package:mentor_minds/data/repositories/materials_repository.dart';
import 'package:mentor_minds/data/repositories/users_repository.dart';

// ---------------------------------------------------------------------------
// Filter sentinel values — lowercase, as specified
// ---------------------------------------------------------------------------

const String kSubjectAll = 'all';
const String kLevelBoth = 'both';
const int kPageSize = 20;
const Duration kSearchDebounce = Duration(milliseconds: 300);

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class MaterialsState {
  final bool isLoading;      // initial load / filter change
  final bool isLoadingMore;  // pagination
  final String? error;

  final List<LearningMaterial> materials;
  final List<LearningMaterial> filteredMaterials;

  final String selectedSubject; // 'all' or subject name
  final String selectedLevel;   // 'both' | 'O Level' | 'A Level'
  final MaterialType? selectedType;
  final String searchQuery;

  final bool hasMore;

  const MaterialsState({
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.materials = const [],
    this.filteredMaterials = const [],
    this.selectedSubject = kSubjectAll,
    this.selectedLevel = kLevelBoth,
    this.selectedType,
    this.searchQuery = '',
    this.hasMore = true,
  });

  bool get anyFilterActive =>
      searchQuery.trim().isNotEmpty ||
      selectedSubject != kSubjectAll ||
      selectedLevel != kLevelBoth ||
      selectedType != null;

  MaterialsState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    List<LearningMaterial>? materials,
    List<LearningMaterial>? filteredMaterials,
    String? selectedSubject,
    String? selectedLevel,
    MaterialType? selectedType,
    String? searchQuery,
    bool? hasMore,
    bool clearError = false,
    bool clearSelectedType = false,
  }) {
    return MaterialsState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      materials: materials ?? this.materials,
      filteredMaterials: filteredMaterials ?? this.filteredMaterials,
      selectedSubject: selectedSubject ?? this.selectedSubject,
      selectedLevel: selectedLevel ?? this.selectedLevel,
      selectedType:
          clearSelectedType ? null : (selectedType ?? this.selectedType),
      searchQuery: searchQuery ?? this.searchQuery,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

// ---------------------------------------------------------------------------
// ViewModel
// ---------------------------------------------------------------------------

class MaterialsViewModel extends StateNotifier<MaterialsState> {
  MaterialsViewModel(this._materialsRepo) : super(const MaterialsState()) {
    _resubscribe(reset: true);
  }

  final MaterialsRepository _materialsRepo;

  // Live browse: a Firestore snapshot stream with a growing limit stands in
  // for cursor pagination — new/edited/deleted materials appear without a
  // manual refresh (spec: live data everywhere), and "load more" simply
  // widens the window.
  StreamSubscription<List<LearningMaterial>>? _sub;
  int _limit = kPageSize;

  Timer? _searchDebounce;

  // -------------------------------------------------------------------------
  // Load / paginate
  // -------------------------------------------------------------------------

  void _resubscribe({bool reset = false}) {
    _sub?.cancel();
    if (reset) {
      _limit = kPageSize;
      state = state.copyWith(
        isLoading: true,
        isLoadingMore: false,
        materials: const [],
        filteredMaterials: const [],
        hasMore: true,
        clearError: true,
      );
    }

    _sub = _materialsRepo
        .streamMaterials(
      subject:
          state.selectedSubject == kSubjectAll ? null : state.selectedSubject,
      level: state.selectedLevel == kLevelBoth ? null : state.selectedLevel,
      type: state.selectedType,
      limit: _limit,
    )
        .listen(
      (items) {
        if (!mounted) return;
        state = state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          materials: items,
          filteredMaterials: _applySearch(items, state.searchQuery),
          hasMore: items.length >= _limit,
          clearError: true,
        );
      },
      onError: (_) {
        if (!mounted) return;
        state = state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          error: 'Could not load materials. Pull to refresh.',
        );
      },
    );
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    _limit += kPageSize;
    _resubscribe();
  }

  Future<void> refresh() async => _resubscribe(reset: true);

  // -------------------------------------------------------------------------
  // Filter setters — each triggers a fresh paginated query
  // -------------------------------------------------------------------------

  void setSubject(String subject) {
    if (subject == state.selectedSubject) return;
    state = state.copyWith(selectedSubject: subject);
    _resubscribe(reset: true);
  }

  void setLevel(String level) {
    if (level == state.selectedLevel) return;
    state = state.copyWith(selectedLevel: level);
    _resubscribe(reset: true);
  }

  void toggleType(MaterialType type) {
    final next = state.selectedType == type ? null : type;
    state = state.copyWith(
      selectedType: next,
      clearSelectedType: next == null,
    );
    _resubscribe(reset: true);
  }

  void clearAllFilters() {
    state = state.copyWith(
      selectedSubject: kSubjectAll,
      selectedLevel: kLevelBoth,
      searchQuery: '',
      clearSelectedType: true,
    );
    _resubscribe(reset: true);
  }

  // -------------------------------------------------------------------------
  // Search — client-side, debounced 300ms
  // -------------------------------------------------------------------------

  void searchMaterials(String query) {
    // Update text immediately so the field reflects input without waiting.
    state = state.copyWith(searchQuery: query);

    _searchDebounce?.cancel();
    _searchDebounce = Timer(kSearchDebounce, () {
      if (!mounted) return;
      state = state.copyWith(
        filteredMaterials: _applySearch(state.materials, query),
      );
    });
  }

  List<LearningMaterial> _applySearch(
    List<LearningMaterial> items,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where((m) =>
            m.title.toLowerCase().contains(q) ||
            m.subject.toLowerCase().contains(q))
        .toList(growable: false);
  }

  // -------------------------------------------------------------------------
  // View tracking
  // -------------------------------------------------------------------------

  Future<void> incrementViewCount(String materialId) async {
    // Optimistic bump so the UI reflects immediately.
    final updated = state.materials
        .map((m) =>
            m.materialId == materialId ? m.copyWith(views: m.views + 1) : m)
        .toList(growable: false);
    state = state.copyWith(
      materials: updated,
      filteredMaterials: _applySearch(updated, state.searchQuery),
    );

    try {
      await _materialsRepo.incrementViewCount(materialId);
    } catch (_) {
      // Server didn't take it — harmless; next load will reconcile.
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }
}

final materialsViewModelProvider =
    StateNotifierProvider.autoDispose<MaterialsViewModel, MaterialsState>(
  (ref) => MaterialsViewModel(ref.read(materialsRepositoryProvider)),
);

// Role of the signed-in user — gates the teacher/admin upload entry on the
// materials screen (server rules enforce the real permission).
final materialsUserRoleProvider =
    FutureProvider.autoDispose<String?>((ref) async {
  final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
  if (uid == null) return null;
  final doc = await ref.watch(usersRepositoryProvider).getUserDocRaw(uid);
  return doc?['role'] as String?;
});
