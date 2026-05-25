import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:mentor_minds/core/observability/crashlytics_setup.dart';
import 'package:mentor_minds/data/services/messaging_service.dart';
import 'package:mentor_minds/presentation/app/app_shell.dart';

import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await configureCrashlytics();
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

  // App Check — emits a token per-call for any callable with enforceAppCheck.
  // Release builds use App Attest where available (iOS 14+ Secure Enclave),
  // silently falling back to DeviceCheck on devices/accounts where App Attest
  // is not provisioned. Debug builds use the Debug provider — auto-generates
  // a UUID token that must be registered in Firebase Console (BACKEND_SETUP §6).
  // The Functions emulator bypasses App Check validation (RESEARCH Pitfall 6).
  // Provider choice locked by free-Apple-Developer-account decision; see CONTEXT D-02.
  await FirebaseAppCheck.instance.activate(
    appleProvider: kReleaseMode
        ? AppleProvider.appAttestWithDeviceCheckFallback
        : AppleProvider.debug,
  );

  // When launched with --dart-define=USE_EMULATOR=true, redirect all SDK
  // calls to the local Firebase Emulator Suite instead of the production
  // project. The const-conditional is evaluated at compile time so release
  // builds (without the dart-define) tree-shake this branch entirely.
  // lib/main.dart MUST NOT import from test/ — the 3-line wiring is
  // intentionally duplicated here; the shared helper lives in
  // test/_helpers/emulator_setup.dart for use by integration tests only.
  const bool useEmulator =
      bool.fromEnvironment('USE_EMULATOR', defaultValue: false);
  if (useEmulator) {
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
    FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
  }

  // NOTF-01 — FCM must initialize before runApp; background handler registered here.
  final container = ProviderContainer();
  await container.read(messagingServiceProvider).initialize();

  runAppGuarded(
    () => runApp(
      UncontrolledProviderScope(
        container: container,
        child: const MentorMindsApp(),
      ),
    ),
  );
}

class MentorMindsApp extends ConsumerWidget {
  const MentorMindsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'MentorMinds',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => AppShell(child: child),
    );
  }
}
