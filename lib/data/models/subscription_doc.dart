import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------------
// SubscriptionDoc — /subscriptions/{uid} (PAY-01 v2-ready schema)
// ---------------------------------------------------------------------------

class SubscriptionDoc {
  final String userId;
  final String tier;
  final String status;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final String provider;
  final String? providerSubscriptionId;
  final bool cancelAtPeriodEnd;

  const SubscriptionDoc({
    required this.userId,
    required this.tier,
    required this.status,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.provider = 'manual',
    this.providerSubscriptionId,
    this.cancelAtPeriodEnd = false,
  });

  static const empty = SubscriptionDoc(
    userId: '',
    tier: 'free',
    status: 'inactive',
  );

  bool get isPremiumActive =>
      tier == 'premium' &&
      (status == 'active' || status == 'trialing');

  factory SubscriptionDoc.fromMap(String uid, Map<String, dynamic> m) {
    DateTime? ts(dynamic v) =>
        v is Timestamp ? v.toDate() : null;
    return SubscriptionDoc(
      userId: (m['userId'] as String?) ?? uid,
      tier: (m['tier'] as String?) ?? 'free',
      status: (m['status'] as String?) ?? 'inactive',
      currentPeriodStart: ts(m['currentPeriodStart']),
      currentPeriodEnd: ts(m['currentPeriodEnd']),
      provider: (m['provider'] as String?) ?? 'manual',
      providerSubscriptionId: m['providerSubscriptionId'] as String?,
      cancelAtPeriodEnd: (m['cancelAtPeriodEnd'] as bool?) ?? false,
    );
  }
}
