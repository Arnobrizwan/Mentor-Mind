import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:mentor_minds/data/models/curriculum_config.dart';
import 'package:mentor_minds/data/models/gamification_config.dart';
import 'package:mentor_minds/data/models/quotas_config.dart';

// ---------------------------------------------------------------------------
// RemoteConfigService — streams /config/{gamification,curriculum,quotas}.
// Each stream emits the parsed config or the model's hardcoded defaults when
// the doc is missing or malformed, so consumers never deal with a null state.
// Admins edit these docs directly in Firebase Console; clients hot-reload.
// ---------------------------------------------------------------------------

class RemoteConfigService {
  RemoteConfigService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _configs =>
      _firestore.collection('config');

  Stream<GamificationConfig> watchGamification() {
    return _configs.doc('gamification').snapshots().map((snap) {
      final data = snap.data();
      if (data == null || data.isEmpty) return GamificationConfig.defaults;
      return GamificationConfig.fromMap(data);
    }).handleError((_) => GamificationConfig.defaults);
  }

  Stream<CurriculumConfig> watchCurriculum() {
    return _configs.doc('curriculum').snapshots().map((snap) {
      final data = snap.data();
      if (data == null || data.isEmpty) return CurriculumConfig.defaults;
      return CurriculumConfig.fromMap(data);
    }).handleError((_) => CurriculumConfig.defaults);
  }

  Stream<QuotasConfig> watchQuotas() {
    return _configs.doc('quotas').snapshots().map((snap) {
      final data = snap.data();
      if (data == null || data.isEmpty) return QuotasConfig.defaults;
      return QuotasConfig.fromMap(data);
    }).handleError((_) => QuotasConfig.defaults);
  }
}
