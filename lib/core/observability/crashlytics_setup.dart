import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// OBSV-01/05 — Crashlytics + device keys. Call once after Firebase.initializeApp.
Future<void> configureCrashlytics() async {
  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(!kDebugMode);

  FlutterError.onError =
      FirebaseCrashlytics.instance.recordFlutterFatalError;

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  try {
    final info = await PackageInfo.fromPlatform();
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCustomKey('app_version', info.version);
    await crashlytics.setCustomKey('build_number', info.buildNumber);

    final deviceInfo = DeviceInfoPlugin();
    final ios = await deviceInfo.iosInfo;
    await crashlytics.setCustomKey('device_model', ios.utsname.machine);
    await crashlytics.setCustomKey('ios_version', ios.systemVersion);
  } catch (e) {
    debugPrint('Crashlytics keys failed: $e');
  }
}

/// Wraps [runApp] with zone error forwarding to Crashlytics.
void runAppGuarded(void Function() appRunner) {
  runZonedGuarded(
    appRunner,
    (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}
