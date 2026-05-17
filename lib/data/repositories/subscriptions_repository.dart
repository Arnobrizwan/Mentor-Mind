import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// SubscriptionsRepository — /subscriptions/{uid} (D-01 stub)
// STUB — Phase 5 populates /subscriptions/{uid} and replaces these literal
// returns with real Firestore reads. In Phase 1 the repo is scaffolded so the
// import graph is stable and viewmodels can consume it without a breaking
// change when Phase 5 wires the real data.
// ---------------------------------------------------------------------------

class SubscriptionsRepository {
  const SubscriptionsRepository();

  /// STUB — returns 'free' until Phase 5 populates /subscriptions/{uid}.
  Future<String?> getSubscriptionType(String uid) async {
    return 'free';
  }

  /// STUB — returns false until Phase 5 populates /subscriptions/{uid}.
  Future<bool> isSubscriptionActive(String uid) async {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final subscriptionsRepositoryProvider = Provider<SubscriptionsRepository>((ref) {
  return const SubscriptionsRepository();
});
