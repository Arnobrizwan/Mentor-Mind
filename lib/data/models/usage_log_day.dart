// ---------------------------------------------------------------------------
// UsageLogDay — one day's aggregate from /system/usage_log_{YYYY-MM-DD}.
// Written by mentorBotChat (Admin SDK only); admins read for analytics tab.
// ---------------------------------------------------------------------------

class UsageLogDay {
  const UsageLogDay({
    required this.dateKey,
    required this.calls,
    required this.promptTokens,
    required this.completionTokens,
    required this.estimatedCostUsd,
  });

  final String dateKey;
  final int calls;
  final int promptTokens;
  final int completionTokens;
  final double estimatedCostUsd;

  factory UsageLogDay.fromDoc(String docId, Map<String, dynamic> data) {
    final dateKey = docId.startsWith('usage_log_')
        ? docId.substring('usage_log_'.length)
        : docId;
    return UsageLogDay(
      dateKey: dateKey,
      calls: (data['calls'] as num?)?.toInt() ?? 0,
      promptTokens: (data['promptTokens'] as num?)?.toInt() ?? 0,
      completionTokens: (data['completionTokens'] as num?)?.toInt() ?? 0,
      estimatedCostUsd: (data['estimatedCostUsd'] as num?)?.toDouble() ?? 0,
    );
  }
}
