import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/core/constants/app_colors.dart';

// ---------------------------------------------------------------------------
// Filter sentinel values — lowercase, as specified
// ---------------------------------------------------------------------------

const String kSubjectAll = 'all';
const String kLevelBoth = 'both';
const int kPageSize = 20;
const Duration kSearchDebounce = Duration(milliseconds: 300);

// ---------------------------------------------------------------------------
// MaterialType + helpers
// ---------------------------------------------------------------------------

enum MaterialType { pdf, video, note }

extension MaterialTypeX on MaterialType {
  String get label => switch (this) {
        MaterialType.pdf   => 'PDF',
        MaterialType.video => 'VIDEO',
        MaterialType.note  => 'NOTE',
      };

  String get longLabel => switch (this) {
        MaterialType.pdf   => 'PDF',
        MaterialType.video => 'Video',
        MaterialType.note  => 'Notes',
      };

  String get emoji => switch (this) {
        MaterialType.pdf   => '\u{1F4C4}',
        MaterialType.video => '\u{1F3AC}',
        MaterialType.note  => '\u{1F4DD}',
      };

  Color get badgeColor => switch (this) {
        MaterialType.pdf   => const Color(0xFFEF4444),
        MaterialType.video => const Color(0xFF8B5CF6),
        MaterialType.note  => const Color(0xFFF59E0B),
      };

  String get ctaLabel => switch (this) {
        MaterialType.pdf   => 'Open PDF',
        MaterialType.video => 'Watch Video',
        MaterialType.note  => 'Read Note',
      };

  static MaterialType? parse(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'pdf':
        return MaterialType.pdf;
      case 'video':
        return MaterialType.video;
      case 'note':
      case 'notes':
        return MaterialType.note;
      default:
        return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Subject color mapping
// ---------------------------------------------------------------------------

const _subjectColors = <String, Color>{
  'Mathematics': Color(0xFF3B82F6),
  'Physics':     Color(0xFF6366F1),
  'Chemistry':   Color(0xFF22C55E),
  'Biology':     Color(0xFF14B8A6),
  'English':     Color(0xFFEC4899),
  'ICT':         Color(0xFF06B6D4),
  'Accounting':  Color(0xFFF59E0B),
  'Economics':   Color(0xFFEF4444),
  'History':     Color(0xFFA855F7),
  'Geography':   Color(0xFF10B981),
};

Color subjectColorFor(String s) =>
    _subjectColors[s] ?? AppColors.kPrimary;

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class LearningMaterial {
  final String materialId;
  final String title;
  final String subject;
  final String level;
  final String fileUrl;
  final MaterialType type;
  final String? thumbnailUrl;
  final String? uploadedBy;
  final int views;
  final DateTime createdAt;

  const LearningMaterial({
    required this.materialId,
    required this.title,
    required this.subject,
    required this.level,
    required this.fileUrl,
    required this.type,
    required this.views,
    required this.createdAt,
    this.thumbnailUrl,
    this.uploadedBy,
  });

  LearningMaterial copyWith({int? views}) {
    return LearningMaterial(
      materialId: materialId,
      title: title,
      subject: subject,
      level: level,
      fileUrl: fileUrl,
      type: type,
      views: views ?? this.views,
      createdAt: createdAt,
      thumbnailUrl: thumbnailUrl,
      uploadedBy: uploadedBy,
    );
  }

  factory LearningMaterial.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return LearningMaterial(
      materialId: doc.id,
      title: ((data['title'] as String?)?.trim().isNotEmpty ?? false)
          ? (data['title'] as String).trim()
          : 'Untitled',
      subject: (data['subject'] as String?) ?? 'General',
      level: (data['level'] as String?) ?? 'O Level',
      fileUrl: (data['fileUrl'] as String?) ??
          (data['url'] as String?) ??
          '',
      type:
          MaterialTypeX.parse(data['type'] as String?) ?? MaterialType.note,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      uploadedBy: data['uploadedBy'] as String?,
      views: (data['views'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
          (data['uploadedAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
    );
  }

  List<Color> get subjectGradient {
    final base = subjectColorFor(subject);
    final hsl = HSLColor.fromColor(base);
    final darker =
        hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();
    return [base, darker];
  }
}

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
  MaterialsViewModel() : super(const MaterialsState()) {
    loadMaterials(reset: true);
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  Timer? _searchDebounce;

  // -------------------------------------------------------------------------
  // Query composition — applies server-side filters.
  // Firestore composite-index requirements documented in BACKEND_SETUP.md /
  // firestore.indexes.json. On first run of a new filter combination,
  // Firestore will log a console URL to auto-create the missing index.
  // -------------------------------------------------------------------------

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q = _firestore
        .collection('materials')
        .orderBy('createdAt', descending: true);

    if (state.selectedSubject != kSubjectAll) {
      q = q.where('subject', isEqualTo: state.selectedSubject);
    }
    if (state.selectedLevel != kLevelBoth) {
      q = q.where('level', isEqualTo: state.selectedLevel);
    }
    if (state.selectedType != null) {
      q = q.where('type', isEqualTo: state.selectedType!.name);
    }
    return q;
  }

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
      if (state.isLoading ||
          state.isLoadingMore ||
          !state.hasMore) {
        return;
      }
      state = state.copyWith(isLoadingMore: true);
    }

    try {
      Query<Map<String, dynamic>> q = _buildQuery();
      if (_lastDoc != null) {
        q = q.startAfterDocument(_lastDoc!);
      }
      q = q.limit(kPageSize);

      final snap = await q.get();
      if (snap.docs.isNotEmpty) {
        _lastDoc = snap.docs.last;
      }

      final newItems = snap.docs
          .map(LearningMaterial.fromDoc)
          .toList(growable: false);
      final merged =
          reset ? newItems : [...state.materials, ...newItems];

      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        materials: merged,
        filteredMaterials: _applySearch(merged, state.searchQuery),
        hasMore: snap.docs.length == kPageSize,
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
      await _firestore
          .collection('materials')
          .doc(materialId)
          .update({'views': FieldValue.increment(1)});
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
  (ref) => MaterialsViewModel(),
);
