import 'package:mentor_minds/data/models/curriculum_config.dart';

// ---------------------------------------------------------------------------
// DEPRECATED hardcoded curriculum constants — retained as fallback for code
// paths that can't reach Riverpod (e.g. pure-Dart helpers). The CANONICAL
// source is /config/curriculum via currentCurriculumConfigProvider.
//
// New code MUST read from the provider so admins can edit the catalog
// without a release: ref.watch(currentCurriculumConfigProvider).subjects
// ---------------------------------------------------------------------------

final List<String> kCurriculumSubjects = CurriculumConfig.defaults.subjects;

final List<String> kMaterialsSubjectFilters = <String>[
  CurriculumConfig.defaults.materialsSubjectAllSentinel,
  ...CurriculumConfig.defaults.subjects,
];

final Map<String, String> kMaterialsSubjectShortLabels =
    CurriculumConfig.defaults.subjectShortLabels;
