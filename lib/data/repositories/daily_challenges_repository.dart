import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/core/constants/quota.dart';
import 'package:mentor_minds/data/models/daily_challenge.dart';
import 'package:mentor_minds/data/services/firebase_providers.dart';

class DailyChallengesRepository {
  DailyChallengesRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  String todayKey() => dhakaDateKey(DateTime.now());

  Stream<DailyChallenge> watchToday() {
    final key = todayKey();
    return _firestore.collection('daily_challenges').doc(key).snapshots().map(
      (snap) {
        if (!snap.exists) return DailyChallenge.fallback(key);
        return DailyChallenge.fromMap(key, snap.data() ?? {});
      },
    );
  }
}

final dailyChallengesRepositoryProvider =
    Provider<DailyChallengesRepository>((ref) {
  return DailyChallengesRepository(firestore: ref.read(firestoreProvider));
});
