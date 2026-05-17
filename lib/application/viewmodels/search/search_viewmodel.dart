import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/application/viewmodels/materials/materials_viewmodel.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class MaterialSearchHit {
  final String id;
  final String title;
  final String subject;
  final String level;
  final MaterialType type;
  final DateTime createdAt;

  const MaterialSearchHit({
    required this.id,
    required this.title,
    required this.subject,
    required this.level,
    required this.type,
    required this.createdAt,
  });

  factory MaterialSearchHit.fromLearningMaterial(LearningMaterial m) {
    return MaterialSearchHit(
      id: m.materialId,
      title: m.title,
      subject: m.subject,
      level: m.level,
      type: m.type,
      createdAt: m.createdAt,
    );
  }

  Color get subjectColor => subjectColorFor(subject);
}

class SessionSearchHit {
  final String id;
  final String subject;
  final String preview;
  final int messageCount;
  final DateTime updatedAt;

  const SessionSearchHit({
    required this.id,
    required this.subject,
    required this.preview,
    required this.messageCount,
    required this.updatedAt,
  });

  Color get subjectColor => subjectColorFor(subject);
}

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
  SearchViewModel() : super(const SearchState()) {
    _init();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
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
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final type =
          (doc.data()?['subscriptionType'] as String?)?.toLowerCase();
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
        searchMaterials(q),
        searchSessions(_auth.currentUser?.uid, q, state.isPremium),
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
  // searchMaterials — Firestore title prefix + subject exact match
  // -------------------------------------------------------------------------

  Future<List<MaterialSearchHit>> searchMaterials(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    // 1. Title prefix query — idiomatic Firestore "starts with".
    //    Note: this is case-sensitive. For a production-grade, case-insensitive
    //    search we'd index a `titleLower` field on each doc. For MVP we also
    //    run a lowercased variant to catch common cases.
    final queries = <Future<QuerySnapshot<Map<String, dynamic>>>>[
      _titlePrefixQuery(q),
      if (q[0].toUpperCase() != q[0])
        _titlePrefixQuery(q[0].toUpperCase() + q.substring(1)),
    ];

    // 2. Subject exact-match if the query matches a known subject prefix.
    final matchingSubject = _kKnownSubjects.firstWhere(
      (s) => s.toLowerCase().startsWith(q.toLowerCase()),
      orElse: () => '',
    );
    if (matchingSubject.isNotEmpty) {
      queries.add(
        _firestore
            .collection('materials')
            .where('subject', isEqualTo: matchingSubject)
            .orderBy('createdAt', descending: true)
            .limit(10)
            .get(),
      );
    }

    final snaps = await Future.wait(queries);
    final byId = <String, LearningMaterial>{};
    for (final snap in snaps) {
      for (final doc in snap.docs) {
        final m = LearningMaterial.fromDoc(doc);
        byId[m.materialId] = m;
      }
    }
    return byId.values
        .map(MaterialSearchHit.fromLearningMaterial)
        .toList(growable: false);
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _titlePrefixQuery(String q) {
    final end = '$q';
    return _firestore
        .collection('materials')
        .where('title', isGreaterThanOrEqualTo: q)
        .where('title', isLessThan: end)
        .limit(10)
        .get();
  }

  // -------------------------------------------------------------------------
  // searchSessions — client-side content filter, scoped by premium
  // -------------------------------------------------------------------------

  Future<List<SessionSearchHit>> searchSessions(
    String? uid,
    String query,
    bool isPremium,
  ) async {
    final q = query.trim().toLowerCase();
    if (uid == null || q.isEmpty) return const [];

    Query<Map<String, dynamic>> base = _firestore
        .collection('sessions')
        .where('userId', isEqualTo: uid)
        .orderBy('updatedAt', descending: true);

    if (!isPremium) {
      final cutoff = DateTime.now().subtract(_kFreeSessionWindow);
      base = base.where(
        'updatedAt',
        isGreaterThan: Timestamp.fromDate(cutoff),
      );
    }

    final snap = await base.limit(100).get();
    final hits = <SessionSearchHit>[];

    for (final doc in snap.docs) {
      final data = doc.data();
      final messages = ((data['messages'] as List?) ?? const [])
          .whereType<Map>()
          .toList();

      // Find the matched message (first hit) so we can use its content
      // as the preview.
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

      hits.add(SessionSearchHit(
        id: doc.id,
        subject: (data['subject'] as String?) ?? 'General',
        preview: preview,
        messageCount:
            (data['messageCount'] as num?)?.toInt() ?? messages.length,
        updatedAt:
            (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
  (ref) => SearchViewModel(),
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
