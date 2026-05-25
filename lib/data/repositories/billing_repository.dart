import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/data/services/firebase_functions_provider.dart';

// ---------------------------------------------------------------------------
// BillingRepository — Stripe Checkout + Customer Portal callables (PAY-06/07)
// ---------------------------------------------------------------------------

class BillingRepository {
  BillingRepository({required FirebaseFunctions functions})
      : _functions = functions;

  final FirebaseFunctions _functions;

  Future<String> createCheckoutSession() async {
    final result = await _functions
        .httpsCallable('createCheckoutSession')
        .call<dynamic>();
    final data =
        (result.data as Map<Object?, Object?>).cast<String, dynamic>();
    return (data['url'] as String?) ?? '';
  }

  Future<String> createPortalSession() async {
    final result = await _functions
        .httpsCallable('createPortalSession')
        .call<dynamic>();
    final data =
        (result.data as Map<Object?, Object?>).cast<String, dynamic>();
    return (data['url'] as String?) ?? '';
  }
}

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepository(functions: ref.read(firebaseFunctionsProvider));
});
