// ---------------------------------------------------------------------------
// QuotasConfig — /config/quotas doc shape.
// MIRROR: functions/src/lib/rate_limit.ts is the SERVER source of truth. The
// values here only drive client display (remaining counter, warning banner).
// Server enforcement is independent — keep the server in sync when the
// admin updates this doc.
// ---------------------------------------------------------------------------

class QuotasConfig {
  /// Free-tier daily text messages (Dhaka day).
  final int dailyTextLimit;

  /// Free-tier daily image/diagram messages (Dhaka day).
  final int dailyImageLimit;

  /// Show the "almost at limit" banner when this many text messages remain.
  final int warningThreshold;

  /// Shared quota timezone — must match functions/src/lib/quota.ts QUOTA_TZ.
  final String timezone;

  const QuotasConfig({
    required this.dailyTextLimit,
    required this.dailyImageLimit,
    required this.warningThreshold,
    required this.timezone,
  });

  factory QuotasConfig.fromMap(Map<String, dynamic> data) => QuotasConfig(
        dailyTextLimit: (data['dailyTextLimit'] as num?)?.toInt() ??
            defaults.dailyTextLimit,
        dailyImageLimit: (data['dailyImageLimit'] as num?)?.toInt() ??
            defaults.dailyImageLimit,
        warningThreshold: (data['warningThreshold'] as num?)?.toInt() ??
            defaults.warningThreshold,
        timezone: (data['timezone'] as String?) ?? defaults.timezone,
      );

  Map<String, dynamic> toMap() => {
        'dailyTextLimit': dailyTextLimit,
        'dailyImageLimit': dailyImageLimit,
        'warningThreshold': warningThreshold,
        'timezone': timezone,
      };

  // Defaults mirror lib/core/constants/quota_limits.dart + quota.dart.
  static const QuotasConfig defaults = QuotasConfig(
    dailyTextLimit: 30,
    dailyImageLimit: 3,
    warningThreshold: 8,
    timezone: 'Asia/Dhaka',
  );
}
