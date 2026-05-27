// ---------------------------------------------------------------------------
// CurriculumConfig — /config/curriculum doc shape.
// Source of truth for subjects shown in onboarding, profile, materials
// filters, and tutor fallbacks. Falls back to the original hardcoded list
// when the Firestore doc is empty or unreachable.
// ---------------------------------------------------------------------------

class CurriculumConfig {
  final List<String> subjects;
  final List<String> levels;
  final Map<String, String> subjectShortLabels;
  final String materialsSubjectAllSentinel;
  final String materialsLevelBothSentinel;

  const CurriculumConfig({
    required this.subjects,
    required this.levels,
    required this.subjectShortLabels,
    required this.materialsSubjectAllSentinel,
    required this.materialsLevelBothSentinel,
  });

  /// Materials filter row: "all" sentinel + every curriculum subject.
  List<String> get materialsSubjectFilters =>
      [materialsSubjectAllSentinel, ...subjects];

  /// Short display label for a subject filter chip; falls back to the id.
  String shortLabelFor(String subject) =>
      subjectShortLabels[subject] ?? subject;

  static CurriculumConfig fromMap(Map<String, dynamic> data) {
    final subjects = ((data['subjects'] as List?) ?? const [])
        .map((e) => e.toString())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    final levels = ((data['levels'] as List?) ?? const [])
        .map((e) => e.toString())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    final shortRaw = (data['subjectShortLabels'] as Map?) ?? const {};
    final short = <String, String>{
      for (final entry in shortRaw.entries)
        entry.key.toString(): entry.value.toString(),
    };
    return CurriculumConfig(
      subjects: subjects.isEmpty ? defaults.subjects : subjects,
      levels: levels.isEmpty ? defaults.levels : levels,
      subjectShortLabels:
          short.isEmpty ? defaults.subjectShortLabels : short,
      materialsSubjectAllSentinel:
          (data['materialsSubjectAllSentinel'] as String?) ??
              defaults.materialsSubjectAllSentinel,
      materialsLevelBothSentinel:
          (data['materialsLevelBothSentinel'] as String?) ??
              defaults.materialsLevelBothSentinel,
    );
  }

  Map<String, dynamic> toMap() => {
        'subjects': subjects,
        'levels': levels,
        'subjectShortLabels': subjectShortLabels,
        'materialsSubjectAllSentinel': materialsSubjectAllSentinel,
        'materialsLevelBothSentinel': materialsLevelBothSentinel,
      };

  // Defaults mirror lib/core/constants/curriculum_subjects.dart +
  // lib/application/viewmodels/materials/materials_viewmodel.dart sentinels.
  static const CurriculumConfig defaults = CurriculumConfig(
    subjects: [
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
    ],
    levels: ['O Level', 'A Level'],
    subjectShortLabels: {
      'all': 'All',
      'Mathematics': 'Math',
    },
    materialsSubjectAllSentinel: 'all',
    materialsLevelBothSentinel: 'both',
  );
}
