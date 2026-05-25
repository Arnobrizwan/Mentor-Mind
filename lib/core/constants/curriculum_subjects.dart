// ---------------------------------------------------------------------------
// Curriculum subjects — single source of truth for onboarding, profile,
// materials filters, and tutor fallbacks. Keep in sync with seed data.
// ---------------------------------------------------------------------------

const kCurriculumSubjects = <String>[
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

/// Materials filter chips: "all" + every curriculum subject.
const kMaterialsSubjectFilters = <String>[
  'all',
  ...kCurriculumSubjects,
];

const kMaterialsSubjectShortLabels = <String, String>{
  'all': 'All',
  'Mathematics': 'Math',
};
