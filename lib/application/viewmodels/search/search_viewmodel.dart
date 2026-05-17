import 'dart:async';

import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/data/models/learning_material.dart';
import 'package:mentor_minds/data/models/material_search_hit.dart';
import 'package:mentor_minds/data/models/session_search_hit.dart';
import 'package:mentor_minds/data/repositories/auth_repository.dart';
import 'package:mentor_minds/data/repositories/materials_repository.dart';
import 'package:mentor_minds/data/repositories/sessions_repository.dart';
import 'package:mentor_minds/data/repositories/subscriptions_repository.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const List<String> kTrendingTopics = [
  'Photosynthesis',
  'Quadratic equations',
  "Newton's laws",
  'Essay structure',
];

const List<String> _kKnownSubjects = [
  'Mathematics',
  'Physics',
  'Chemistry',
  'Biology',
  'English',
  'ICT',
  'Accounting',
  'Economics',
  'History',
  'Geography',
];

const int kRecentSearchesMax = 5;
const String _kRecentSearchesKey = 'recent_searches';
const Duration _kDebounce = Duration(milliseconds: 350);
const Duration _kFreeSessionWindow = Duration(days: 7);

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class SearchState {
  final String query;
  final bool isLoading;
  final String? error;

  final List<String> recentSearches;
  final List<MaterialSearchHit> materialHits;
  final List<SessionSearchHit> sessionHits;

  final bool isPremium;
  final int activeTab; // 0 = All, 1 = Materials, 2 = Sessions

  const SearchState({
    this.query = '',
    this.isLoading = false,
    this.error,
    this.recentSearches = const [],
    this.materialHits = const [],
    this.sessionHits = const [],
    this.isPremium = false,
    this.activeTab = 0,
  });

  bool get hasQuery => query.trim().isNotEmpty;
  int get totalHits => materialHits.length + sessionHits.length;

  SearchState copyWith({
    String? query,
    bool? isLoading,
    String? error,
    List<String>? recentSearches,
    List<MaterialSearchHit>? materialHits,
    List<SessionSearchHit>? sessionHits,
    bool? isPremium,
    int? activeTab,
    bool clearError = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      recentSearches: recentSearches ?? this.recentSearches,
      materialHits: materialHits ?? this.materialHits,
      sessionHits: sessionHits ?? this.sessionHits,
      isPremium: isPremium ?? this.isPremium,
      activeTab: activeTab ?? this.activeTab,
    );
  }
}

// ---------------------------------------------------------------------------
// ViewModel
// ---------------------------------------------------------------------------

class SearchViewModel extends StateNotifier<SearchState> {
  SearchViewModel(
    this._authRepo,
    this._sessionsRepo,
    this._materialsRepo,
    this._subscriptionsRepo,
  ) : super(const SearchState()) {
    _init();
  }

  final AuthRepository _authRepo;
  final SessionsRepository _sessionsRepo;
  final MaterialsRepository _materialsRepo;
  final SubscriptionsRepository _subscriptionsRepo;

  Timer? _debounce;

  Future<void> _init() async {
    await Future.wait([_loadRecent(), _loadPremium()]);
  }

  Future<void> _loadRecent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kRecentSearchesKey) ?? const [];
      if (!mounted) return;
      state = state.copyWith(recentSearches: list);
    } catch (_) {}
  }

  Future<void> _loadPremium() async {
    final uid = _authRepo.currentUser?.uid;
    if (uid == null) return;
    try {
      final type = await _subscriptionsRepo.getSubscriptionType(uid);
      if (!mounted) return;
      state = state.copyWith(isPremium: type == 'premium');
    } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // search(query) — public entry, debounced
  // -------------------------------------------------------------------------

  void search(String query) {
    state = state.copyWith(query: query);
    _debounce?.cancel();

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        materialHits: const [],
        sessionHits: const [],
        isLoading: false,
      );
      return;
    }

    state = state.copyWith(isLoading: true);
    _debounce = Timer(_kDebounce, () {
      if (!mounted) return;
      _runSearch(trimmed);
    });
  }

  Future<void> _runSearch(String q) async {
    try {
      final parts = await Future.wait([
        _searchMaterials(q),
        _searchSessions(_authRepo.currentUser?.uid, q, state.isPremium),
      ]);
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        materialHits: parts[0] as List<MaterialSearchHit>,
        sessionHits: parts[1] as List<SessionSearchHit>,
        clearError: true,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Search failed: $e',
      );
    }
  }

  // -------------------------------------------------------------------------
  // Recent searches
  // -------------------------------------------------------------------------

  Future<void> saveRecentSearch(String q) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return;
    final deduped = [
      trimmed,
      ...state.recentSearches
          .where((s) => s.toLowerCase() != trimmed.toLowerCase()),
    ];
    final capped = deduped.take(kRecentSearchesMax).toList(growable: false);
    state = state.copyWith(recentSearches: capped);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kRecentSearchesKey, capped);
    } catch (_) {}
  }

  Future<void> clearRecentSearch(int index) async {
    if (index < 0 || index >= state.recentSearches.length) return;
    final next = [...state.recentSearches]..removeAt(index);
    state = state.copyWith(recentSearches: next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kRecentSearchesKey, next);
    } catch (_) {}
  }

  Future<void> clearAllRecent() async {
    state = state.copyWith(recentSearches: const []);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kRecentSearchesKey);
    } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // Active tab
  // -------------------------------------------------------------------------

  void setActiveTab(int tab) {
    if (tab == state.activeTab) return;
    state = state.copyWith(activeTab: tab);
  }

  // -------------------------------------------------------------------------
  // _searchMaterials — delegates to MaterialsRepository
  // -------------------------------------------------------------------------

  Future<List<MaterialSearchHit>> _searchMaterials(String query) async {
    final rawDocs = await _materialsRepo.searchMaterialDocs(
      query,
      knownSubjects: _kKnownSubjects,
    );
    final byId = <String, LearningMaterial>{};
    for (final raw in rawDocs) {
      // Reconstruct a LearningMaterial from the raw map. We reuse the
      // QueryDocumentSnapshot-based factory by wrapping it as a fake doc; instead
      // the repo returns raw maps so we use the fromMap path if available,
      // or a lightweight reconstruction.
      final id = raw['id'] as String? ?? '';
      final m = _materialFromRaw(id, raw);
      byId[id] = m;
    }
    return byId.values
        .map(MaterialSearchHit.fromLearningMaterial)
        .toList(growable: false);
  }

  LearningMaterial _materialFromRaw(String id, Map<String, dynamic> raw) {
    return LearningMaterial(
      materialId: id,
      title: (raw['title'] as String?)?.trim().isNotEmpty == true
          ? (raw['title'] as String).trim()
          : 'Untitled',
      subject: (raw['subject'] as String?) ?? 'General',
      level: (raw['level'] as String?) ?? 'O Level',
      type: MaterialTypeX.parse(raw['type'] as String?) ?? MaterialType.note,
      fileUrl: (raw['fileUrl'] as String?) ?? (raw['url'] as String?) ?? '',
      thumbnailUrl: raw['thumbnailUrl'] as String?,
      uploadedBy: raw['uploadedBy'] as String?,
      views: (raw['views'] as num?)?.toInt() ?? 0,
      createdAt: raw['createdAt'] is DateTime
          ? raw['createdAt'] as DateTime
          : DateTime.now(),
    );
  }

  // -------------------------------------------------------------------------
  // _searchSessions — client-side content filter, scoped by premium tier.
  // Delegates to SessionsRepository which owns the Firestore query.
  // -------------------------------------------------------------------------

  Future<List<SessionSearchHit>> _searchSessions(
    String? uid,
    String query,
    bool isPremium,
  ) async {
    final q = query.trim().toLowerCase();
    if (uid == null || q.isEmpty) return const [];

    final since =
        isPremium ? null : DateTime.now().subtract(_kFreeSessionWindow);

    final docs = await _sessionsRepo.searchSessionDocs(
      uid,
      limit: 100,
      since: since,
    );

    final hits = <SessionSearchHit>[];
    for (final data in docs) {
      final messages = ((data['messages'] as List?) ?? const [])
          .whereType<Map>()
          .toList();

      Map? matchedMsg;
      for (final m in messages) {
        final content = (m['content'] as String?) ?? '';
        if (content.toLowerCase().contains(q)) {
          matchedMsg = m;
          break;
        }
      }

      final title = (data['title'] as String?) ?? '';
      final lastQ = (data['lastQuestion'] as String?) ?? '';
      final titleMatch = title.toLowerCase().contains(q) ||
          lastQ.toLowerCase().contains(q);

      if (matchedMsg == null && !titleMatch) continue;

      final preview = matchedMsg != null
          ? (matchedMsg['content'] as String?) ?? ''
          : (lastQ.isNotEmpty ? lastQ : title);

      // updatedAt is returned as a Timestamp from Firestore (raw map from repo).
      // The repo layer does NOT decode timestamps in searchSessionDocs because
      // the field is used only here as a display value. We decode it locally.
      final dynamic rawTs = data['updatedAt'];
      DateTime updatedAt;
      if (rawTs is DateTime) {
        updatedAt = rawTs;
      } else {
        // cloud_firestore Timestamp — access via dynamic to avoid importing
        // the Firestore SDK in this viewmodel.
        try {
          updatedAt = (rawTs as dynamic).toDate() as DateTime;
        } catch (_) {
          updatedAt = DateTime.now();
        }
      }

      hits.add(SessionSearchHit(
        id: data['id'] as String? ?? '',
        subject: (data['subject'] as String?) ?? 'General',
        preview: preview,
        messageCount:
            (data['messageCount'] as num?)?.toInt() ?? messages.length,
        updatedAt: updatedAt,
      ));
    }

    return hits;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final searchViewModelProvider =
    StateNotifierProvider.autoDispose<SearchViewModel, SearchState>(
  (ref) => SearchViewModel(
    ref.read(authRepositoryProvider),
    ref.read(sessionsRepositoryProvider),
    ref.read(materialsRepositoryProvider),
    ref.read(subscriptionsRepositoryProvider),
  ),
);

// ---------------------------------------------------------------------------
// highlightMatch — split text around the query, mark matches in kPrimary bold
// ---------------------------------------------------------------------------

List<TextSpan> highlightMatch(
  String text,
  String query, {
  TextStyle? baseStyle,
}) {
  final q = query.trim();
  if (q.isEmpty) return [TextSpan(text: text, style: baseStyle)];

  final spans = <TextSpan>[];
  final lower = text.toLowerCase();
  final needle = q.toLowerCase();
  var start = 0;

  while (start < text.length) {
    final i = lower.indexOf(needle, start);
    if (i == -1) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
      break;
    }
    if (i > start) {
      spans.add(TextSpan(text: text.substring(start, i), style: baseStyle));
    }
    spans.add(
      TextSpan(
        text: text.substring(i, i + needle.length),
        style: (baseStyle ?? const TextStyle()).copyWith(
          color: AppColors.kPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    start = i + needle.length;
  }
  return spans;
}
