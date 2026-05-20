// Phase 3 — emulator smoke test for mentorBotChat end-to-end.
//
// Mirrors integration_test/ping_smoke_test.dart (Phase 2 Plan 02-09):
//   - @Tags(<String>['emulator', 'integration']) at library scope
//   - IntegrationTestWidgetsFlutterBinding.ensureInitialized()
//   - setUpAll(Firebase.initializeApp + configureEmulators)
//   - No App Check activate() — emulator bypasses (RESEARCH Pitfall 6)
//
// REQUIRES the emulator to be running with GEMINI_CLIENT_MODE=fake:
//   1. Add `GEMINI_CLIENT_MODE=fake` to functions/.env.local (or export inline)
//   2. Run: firebase emulators:start --only auth,firestore,storage,functions
//   3. Wait for: ✔  functions[asia-south1-mentorBotChat]: ... initialized
//   4. Run: flutter test integration_test/mentor_bot_smoke_test.dart \
//             --dart-define=USE_EMULATOR=true -d <ios-simulator-UDID>
//
// The fake Gemini client returns the canned response per plan 03-03:
//   { text: 'Fake MentorBot response for testing.', promptTokens: 10, completionTokens: 20 }
// so this test exercises the WIRING + IDEMPOTENCY, not the model behavior.

@Tags(<String>['emulator', 'integration'])
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mentor_minds/data/models/mentor_bot_response.dart';
import 'package:mentor_minds/data/repositories/mentor_bot_repository.dart';
import 'package:mentor_minds/firebase_options.dart';
import 'package:uuid/uuid.dart';

import '../test/_helpers/emulator_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MentorBotRepository repo;

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await configureEmulators();
    // mentorBotChat requires request.auth.uid (plan 03-06). Anonymous auth
    // works against the emulator's Auth emulator with zero setup.
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    container = ProviderContainer();
    repo = container.read(mentorBotRepositoryProvider);
  });

  tearDownAll(() async {
    container.dispose();
    await FirebaseAuth.instance.signOut();
  });

  testWidgets(
    'mentorBotChat smoke — 5-field response shape via emulator',
    (tester) async {
      final sessionId = const Uuid().v4();
      final clientRequestId = const Uuid().v4();
      final stopwatch = Stopwatch()..start();

      final response = await repo.sendMessage(
        sessionId: sessionId,
        clientRequestId: clientRequestId,
        message: 'Hello MentorBot — smoke test',
      );

      stopwatch.stop();

      expect(response, isA<MentorBotResponse>());
      // Fake client returns canned 'Fake MentorBot response for testing.'
      expect(response.text, isNotEmpty);
      expect(response.messageId, isNotEmpty);
      expect(response.promptTokens, greaterThanOrEqualTo(0));
      expect(response.completionTokens, greaterThanOrEqualTo(0));
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(5000),
        reason:
            'Emulator latency < 5s. Production target is < 10s (cold start ~2-4s + Vertex ~3-5s).',
      );
    },
    tags: ['emulator', 'integration'],
  );

  testWidgets(
    'mentorBotChat smoke — idempotent retry returns SAME messageId',
    (tester) async {
      final sessionId = const Uuid().v4();
      final clientRequestId = const Uuid().v4(); // SAME id for both calls

      final first = await repo.sendMessage(
        sessionId: sessionId,
        clientRequestId: clientRequestId,
        message: 'Idempotency probe',
      );
      final second = await repo.sendMessage(
        sessionId: sessionId,
        clientRequestId: clientRequestId,
        message: 'Idempotency probe',
      );

      // Per plan 03-06 D-08: messageId === clientRequestId. Both calls return
      // the same id, proving the server-side dedupe path is hit.
      expect(second.messageId, equals(first.messageId));
      expect(second.text, equals(first.text));
    },
    tags: ['emulator', 'integration'],
  );
}
