import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/data/models/curriculum_config.dart';
import 'package:mentor_minds/data/models/gamification_config.dart';
import 'package:mentor_minds/data/models/quotas_config.dart';
import 'package:mentor_minds/data/models/subscription_config.dart';
import 'package:mentor_minds/data/models/support_config.dart';
import 'package:mentor_minds/data/services/firebase_providers.dart';
import 'package:mentor_minds/data/services/remote_config_service.dart';

// ---------------------------------------------------------------------------
// Remote config providers — one per /config/* doc.
//
// Two flavors per config:
//   * Stream<X>Provider   — async, reactive; rebuilds widgets on doc edits.
//   * Provider<X> ("current") — synchronous accessor returning the latest
//     emitted value, or the model defaults until the first snapshot arrives.
//     Use this from view-models that need a value during construction.
// ---------------------------------------------------------------------------

final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  return RemoteConfigService(ref.watch(firestoreProvider));
});

// -- Gamification ----------------------------------------------------------

final gamificationConfigStreamProvider =
    StreamProvider<GamificationConfig>((ref) {
  return ref.watch(remoteConfigServiceProvider).watchGamification();
});

final currentGamificationConfigProvider = Provider<GamificationConfig>((ref) {
  return ref.watch(gamificationConfigStreamProvider).maybeWhen(
        data: (cfg) => cfg,
        orElse: () => GamificationConfig.defaults,
      );
});

// -- Curriculum ------------------------------------------------------------

final curriculumConfigStreamProvider =
    StreamProvider<CurriculumConfig>((ref) {
  return ref.watch(remoteConfigServiceProvider).watchCurriculum();
});

final currentCurriculumConfigProvider = Provider<CurriculumConfig>((ref) {
  return ref.watch(curriculumConfigStreamProvider).maybeWhen(
        data: (cfg) => cfg,
        orElse: () => CurriculumConfig.defaults,
      );
});

// -- Quotas ----------------------------------------------------------------

final quotasConfigStreamProvider = StreamProvider<QuotasConfig>((ref) {
  return ref.watch(remoteConfigServiceProvider).watchQuotas();
});

final currentQuotasConfigProvider = Provider<QuotasConfig>((ref) {
  return ref.watch(quotasConfigStreamProvider).maybeWhen(
        data: (cfg) => cfg,
        orElse: () => QuotasConfig.defaults,
      );
});

// -- Subscription ----------------------------------------------------------

final subscriptionConfigStreamProvider =
    StreamProvider<SubscriptionConfig>((ref) {
  return ref.watch(remoteConfigServiceProvider).watchSubscription();
});

final currentSubscriptionConfigProvider =
    Provider<SubscriptionConfig>((ref) {
  return ref.watch(subscriptionConfigStreamProvider).maybeWhen(
        data: (cfg) => cfg,
        orElse: () => SubscriptionConfig.defaults,
      );
});

// -- Support ---------------------------------------------------------------

final supportConfigStreamProvider = StreamProvider<SupportConfig>((ref) {
  return ref.watch(remoteConfigServiceProvider).watchSupport();
});

final currentSupportConfigProvider = Provider<SupportConfig>((ref) {
  return ref.watch(supportConfigStreamProvider).maybeWhen(
        data: (cfg) => cfg,
        orElse: () => SupportConfig.defaults,
      );
});
