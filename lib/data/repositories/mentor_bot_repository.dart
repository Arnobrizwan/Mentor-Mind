// ---------------------------------------------------------------------------
// MentorBotRepository — single entry point for the `mentorBotChat` callable.
//
// Phase 3 D-06: every send carries a clientRequestId (UUIDv4) so the server
// can idempotency-dedupe retries. Caller (ChatViewModel) generates the id
// once per user-initiated send and reuses it for retries.
//
// Phase 1 D-02 layering: ViewModels NEVER import `cloud_functions`; they
// import `package:mentor_minds/data/repositories/mentor_bot_repository.dart`
// instead. custom_lint `layered_imports` rule enforces this.
//
// Phase 2 D-PATTERNS cast: `httpsCallable().call()` returns a `result` whose
// `data` field is `Map<Object?, Object?>` at runtime — not Map<String,dynamic>.
// We cast via `.cast<String, dynamic>()` BEFORE passing to fromMap.
// ---------------------------------------------------------------------------

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/data/models/mentor_bot_response.dart';
import 'package:mentor_minds/data/services/firebase_functions_provider.dart';

class MentorBotRepository {
  MentorBotRepository({required FirebaseFunctions functions})
      : _functions = functions;

  final FirebaseFunctions _functions;

  /// Invokes the `mentorBotChat` callable on `asia-south1` with the given
  /// payload. Throws `FirebaseFunctionsException` on server-side rejection
  /// (resource-exhausted, unauthenticated, unavailable, internal, etc — D-07).
  ///
  /// Idempotency: pass the SAME [clientRequestId] across retries to get the
  /// SAME server-side messageId without re-invoking Gemini (D-CONTEXT D-06).
  Future<MentorBotResponse> sendMessage({
    required String sessionId,
    required String clientRequestId,
    required String message,
    String? imageUrl,
    String? subject,
    String? level,
  }) async {
    final result = await _functions
        .httpsCallable('mentorBotChat')
        .call<dynamic>(<String, dynamic>{
      'sessionId': sessionId,
      'clientRequestId': clientRequestId,
      'message': message,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (subject != null) 'subject': subject,
      if (level != null) 'level': level,
    });

    final data =
        (result.data as Map<Object?, Object?>).cast<String, dynamic>();
    return MentorBotResponse.fromMap(data);
  }
}

final mentorBotRepositoryProvider = Provider<MentorBotRepository>((ref) {
  return MentorBotRepository(
    functions: ref.read(firebaseFunctionsProvider),
  );
});
