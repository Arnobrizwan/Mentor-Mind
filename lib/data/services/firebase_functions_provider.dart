import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// FirebaseFunctions SDK singleton provider — the test override seam.
// Pinned to region 'asia-south1' to match the server-side `region: 'asia-south1'`
// option on every callable in functions/src/index.ts (Plan 02-03). Cross-region
// mismatch routes the call to us-central1 and 404s (RESEARCH Threat T-2-03-WRONG-REGION).
//
// Tests inject a mocked FirebaseFunctions via ProviderScope.overrides before
// any repository provider is first read. The `useFunctionsEmulator` redirect
// for local emulator runs lives in lib/main.dart's USE_EMULATOR block (Plan 02-08)
// and in test/_helpers/emulator_setup.dart for integration tests.
// ---------------------------------------------------------------------------

final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  return FirebaseFunctions.instanceFor(region: 'asia-south1');
});
