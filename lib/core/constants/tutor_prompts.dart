import 'package:mentor_minds/core/constants/curriculum_subjects.dart';

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

/// Ensures fallback picker includes curriculum list.
List<String> tutorSubjectOptions(List<String> userSubjects) {
  if (userSubjects.isNotEmpty) return userSubjects;
  return kCurriculumSubjects;
}
