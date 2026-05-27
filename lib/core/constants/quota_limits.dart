import 'package:mentor_minds/data/models/quotas_config.dart';

// MIRROR: functions/src/lib/rate_limit.ts DAILY_TEXT_LIMIT / DAILY_IMAGE_LIMIT.
// Client display + canSendMessage checks must match server enforcement.
//
// DEPRECATED — the live values come from /config/quotas via
// currentQuotasConfigProvider. These re-export the model defaults so any
// existing import site still resolves, but new code should read the
// provider instead.

final int kDailyTextLimit = QuotasConfig.defaults.dailyTextLimit;
final int kDailyImageLimit = QuotasConfig.defaults.dailyImageLimit;
final int kDailyLimitWarningThreshold = QuotasConfig.defaults.warningThreshold;
