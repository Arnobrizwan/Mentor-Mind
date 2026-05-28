import 'package:mentor_minds/data/models/curriculum_config.dart';

const kDefaultTutorSuggestions = <String>[
  'Explain photosynthesis step by step',
  'Help me solve a quadratic equation',
  'Tips for structuring an O Level essay',
];

const kTutorSuggestionsBySubject = <String, List<String>>{
  'Mathematics': [
    'Walk me through solving x² - 5x + 6 = 0',
    'What is differentiation in simple terms?',
    'Practice problem: trigonometry identities',
  ],
  'Physics': [
    'Explain Newton\'s three laws with examples',
    'How do I approach kinematics word problems?',
    'What is the difference between speed and velocity?',
  ],
  'Chemistry': [
    'Balance this equation: H₂ + O₂ → H₂O',
    'Explain moles and Avogadro\'s number',
    'Organic vs inorganic — quick overview',
  ],
  'Biology': [
    'Explain photosynthesis and respiration',
    'What happens during cell division?',
    'Compare plant and animal cells',
  ],
  'English': [
    'How do I structure a persuasive essay?',
    'Explain metaphor vs simile with examples',
    'Summarize a passage in my own words',
  ],
  'ICT': [
    'Difference between RAM and ROM',
    'Pseudocode for finding the largest number in a list',
    'What is a relational database, in simple terms?',
  ],
  'Accounting': [
    'Explain the accounting equation with an example',
    'How do I prepare a trial balance?',
    'What is the difference between debit and credit?',
  ],
  'Economics': [
    'Explain supply and demand with a diagram',
    'What is opportunity cost?',
    'Difference between fiscal and monetary policy',
  ],
  'History': [
    'Causes of World War I — summarized',
    'How did the Mughal Empire fall?',
    'Source-based question tips for Paper 2',
  ],
  'Geography': [
    'Explain the water cycle with a sketch',
    'What causes a tropical cyclone?',
    'Push and pull factors of migration',
  ],
};

/// Subject-aware starter prompts for empty tutor chat.
List<String> tutorSuggestionsFor(String? subject) {
  if (subject == null || subject.isEmpty || subject == 'General') {
    return kDefaultTutorSuggestions;
  }
  return kTutorSuggestionsBySubject[subject] ??
      [
        'Ask MentorBot about $subject',
        'Give me a $subject practice question',
        ...kDefaultTutorSuggestions.take(1),
      ];
}

/// Tutor subject picker options.
///
/// Returns the union of the student's enrolled subjects + every other
/// curriculum subject (or model defaults when admin config is missing), with
/// the enrolled ones first so the student's primary subjects stay at the top.
///
/// This way a student can ask MentorBot about any subject — Biology, History,
/// Geography — without having to re-onboard. The system prompt has playbooks
/// for all of them; restricting the picker would just hide working coverage.
List<String> tutorSubjectOptions(
  List<String> userSubjects, {
  List<String>? fallback,
}) {
  final all = fallback ?? CurriculumConfig.defaults.subjects;
  final seen = <String>{};
  final merged = <String>[];
  for (final s in [...userSubjects, ...all]) {
    if (s.isEmpty) continue;
    if (seen.add(s)) merged.add(s);
  }
  return merged;
}
