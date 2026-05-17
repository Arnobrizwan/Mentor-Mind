import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

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
  }

  runApp(const ProviderScope(child: MentorMindsApp()));
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
    );
  }
}
