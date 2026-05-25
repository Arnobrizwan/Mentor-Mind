// MIRROR: functions/src/lib/rate_limit.ts DAILY_TEXT_LIMIT / DAILY_IMAGE_LIMIT.
// Client display + canSendMessage checks must match server enforcement.

/// Free-tier daily text messages (UTC+6 day). Premium bypasses on server.
const int kDailyTextLimit = 30;

/// Free-tier daily image/diagram messages (UTC+6 day).
const int kDailyImageLimit = 3;

/// Show "almost at limit" banner when this many messages remain (text).
const int kDailyLimitWarningThreshold = 8;
