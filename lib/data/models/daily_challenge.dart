import 'package:cloud_firestore/cloud_firestore.dart';

class DailyChallenge {
  final String dateKey;
  final String subject;
  final String question;
  final int pointsReward;

  const DailyChallenge({
    required this.dateKey,
    required this.subject,
    required this.question,
    this.pointsReward = 25,
  });

  factory DailyChallenge.fromMap(String dateKey, Map<String, dynamic> m) {
    return DailyChallenge(
      dateKey: dateKey,
      subject: (m['subject'] as String?) ?? 'General',
      question: (m['question'] as String?) ?? '',
      pointsReward: (m['pointsReward'] as num?)?.toInt() ?? 25,
    );
  }

  static DailyChallenge fallback(String dateKey) => DailyChallenge(
        dateKey: dateKey,
        subject: 'Physics',
        question:
            'A 2 kg block slides down a frictionless incline of 30°. '
            'Find its acceleration. (Take g = 10 m/s²)',
      );
}
