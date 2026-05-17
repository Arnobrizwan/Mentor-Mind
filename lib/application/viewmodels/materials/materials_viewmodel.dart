import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show DocumentSnapshot;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/data/models/learning_material.dart';
import 'package:mentor_minds/data/repositories/materials_repository.dart';

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
    loadMaterials(reset: true);
  }

  final MaterialsRepository _materialsRepo;

  // D-02 cursor-pagination exception: DocumentSnapshot is the Firestore cursor
  // type required for paginating getMaterials(). It is stored only within the
  // viewmodel (never surfaced to the UI layer) and passed back to the repo on
  // subsequent page loads. The alternative (storing a page-index int) would
  // require a skip-based query which Firestore does not support.
  DocumentSnapshot? _lastDoc;

  Timer? _searchDebounce;

  // -------------------------------------------------------------------------
  // Load / paginate
  // -------------------------------------------------------------------------

  Future<void> loadMaterials({bool reset = false}) async {
    if (reset) {
      _lastDoc = null;
      state = state.copyWith(
        isLoading: true,
        isLoadingMore: false,
        materials: const [],
        filteredMaterials: const [],
        hasMore: true,
        clearError: true,
      );
    } else {
      if (state.isLoading || state.isLoadingMore || !state.hasMore) {
        return;
      }
      state = state.copyWith(isLoadingMore: true);
    }

    try {
      final result = await _materialsRepo.getMaterials(
        subject: state.selectedSubject == kSubjectAll
            ? null
            : state.selectedSubject,
        level: state.selectedLevel == kLevelBoth ? null : state.selectedLevel,
        type: state.selectedType,
        startAfter: _lastDoc,
        limit: kPageSize,
      );

      _lastDoc = result.lastDoc;

      final newItems = result.items;
      final merged = reset ? newItems : [...state.materials, ...newItems];

      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        materials: merged,
        filteredMaterials: _applySearch(merged, state.searchQuery),
        hasMore: newItems.length == kPageSize,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: 'Could not load materials. Pull to refresh.',
      );
    }
  }

  Future<void> loadMore() => loadMaterials(reset: false);
  Future<void> refresh() => loadMaterials(reset: true);

  // -------------------------------------------------------------------------
  // Filter setters — each triggers a fresh paginated query
  // -------------------------------------------------------------------------

  void setSubject(String subject) {
    if (subject == state.selectedSubject) return;
    state = state.copyWith(selectedSubject: subject);
    loadMaterials(reset: true);
  }

  void setLevel(String level) {
    if (level == state.selectedLevel) return;
    state = state.copyWith(selectedLevel: level);
    loadMaterials(reset: true);
  }

  void toggleType(MaterialType type) {
    final next = state.selectedType == type ? null : type;
    state = state.copyWith(
      selectedType: next,
      clearSelectedType: next == null,
    );
    loadMaterials(reset: true);
  }

  void clearAllFilters() {
    state = state.copyWith(
      selectedSubject: kSubjectAll,
      selectedLevel: kLevelBoth,
      searchQuery: '',
      clearSelectedType: true,
    );
    loadMaterials(reset: true);
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
    _searchDebounce?.cancel();
    super.dispose();
  }
}

final materialsViewModelProvider =
    StateNotifierProvider.autoDispose<MaterialsViewModel, MaterialsState>(
  (ref) => MaterialsViewModel(ref.read(materialsRepositoryProvider)),
);
