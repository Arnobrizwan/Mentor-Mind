import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/data/models/ping_response.dart';
import 'package:mentor_minds/data/services/firebase_functions_provider.dart';

// ---------------------------------------------------------------------------
// PingRepository — wraps the `ping` callable (region: asia-south1).
// Returns a decoded PingResponse; never exposes raw HttpsCallableResult.
// No viewmodel consumer in Phase 2 — the integration test (Plan 02-09) is
// the first caller; Phase 3 MentorBotRepository follows this same shape.
// The layered_imports custom_lint rule (Phase 1 D-08) restricts cloud_functions
// imports to lib/data/ only — viewmodels must go through pingRepositoryProvider.
// ---------------------------------------------------------------------------

class PingRepository {
  PingRepository({required FirebaseFunctions functions})
      : _functions = functions;

  final FirebaseFunctions _functions;

  Future<PingResponse> ping() async {
    final result = await _functions.httpsCallable('ping').call<dynamic>();
    // The callable returns Map<Object?, Object?> at runtime, not
    // Map<String, dynamic> — the cast is required (RESEARCH Pattern 8).
    final data = (result.data as Map<Object?, Object?>).cast<String, dynamic>();
    return PingResponse.fromMap(data);
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final pingRepositoryProvider = Provider<PingRepository>((ref) {
  return PingRepository(
    functions: ref.read(firebaseFunctionsProvider),
  );
});
