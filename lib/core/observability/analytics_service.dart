import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// OBSV-03/04 — Firebase Analytics wrapper for custom events.
class AnalyticsService {
  AnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;

  FirebaseAnalyticsObserver get screenObserver =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> logSendMessage() => _log('send_message');

  Future<void> logUploadImage() => _log('upload_image');

  Future<void> logCompleteSession() => _log('complete_session');

  Future<void> logEarnBadge(String badgeId) =>
      _log('earn_badge', {'badge_id': badgeId});

  Future<void> logUpgradeStarted() => _log('upgrade_started');

  Future<void> logUpgradeCompleted() => _log('upgrade_completed');

  Future<void> _log(String name, [Map<String, Object>? params]) {
    return _analytics.logEvent(name: name, parameters: params);
  }
}

final firebaseAnalyticsProvider = Provider<FirebaseAnalytics>((ref) {
  return FirebaseAnalytics.instance;
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(ref.read(firebaseAnalyticsProvider));
});
