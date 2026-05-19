// ---------------------------------------------------------------------------
// PingResponse — decoded response from the `ping` callable (functions/src/index.ts).
// Server returns: { ok: true, timestamp: <ms-since-epoch>, region: 'asia-south1' }
// All fields use safe-cast `as T? ?? default` — never bare `as bool` or `as int`
// (RESEARCH Pattern 8 + Phase 1 model convention).
// ---------------------------------------------------------------------------

class PingResponse {
  const PingResponse({
    required this.ok,
    required this.timestamp,
    required this.region,
  });

  final bool ok;
  final int timestamp;
  final String region;

  factory PingResponse.fromMap(Map<String, dynamic> map) {
    return PingResponse(
      ok: (map['ok'] as bool?) ?? false,
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      region: (map['region'] as String?) ?? '',
    );
  }
}
