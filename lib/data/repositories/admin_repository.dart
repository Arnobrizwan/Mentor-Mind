import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/data/services/firebase_functions_provider.dart';

// ---------------------------------------------------------------------------
// AdminRepository — admin callables (setPremium, sendBroadcast)
// ---------------------------------------------------------------------------

class AdminRepository {
  AdminRepository({required FirebaseFunctions functions})
      : _functions = functions;

  final FirebaseFunctions _functions;

  Future<void> setPremium(String uid, bool isPremium) async {
    await _functions.httpsCallable('setPremium').call<dynamic>({
      'uid': uid,
      'isPremium': isPremium,
    });
  }

  Future<String> sendBroadcast({
    required String title,
    required String body,
    required String recipientRole,
    String type = 'announcement',
  }) async {
    final result = await _functions.httpsCallable('sendBroadcast').call<dynamic>({
      'title': title,
      'body': body,
      'recipientRole': recipientRole,
      'type': type,
    });
    final data =
        (result.data as Map<Object?, Object?>).cast<String, dynamic>();
    return (data['notificationId'] as String?) ?? '';
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(functions: ref.read(firebaseFunctionsProvider));
});
