// ---------------------------------------------------------------------------
// MentorBotResponse — decoded response from the `mentorBotChat` callable.
//
// Server returns (plan 03-06 handler):
//   {
//     text: String,             // the assistant's reply
//     promptTokens: int,        // tokens consumed by the prompt (display + cost)
//     completionTokens: int,    // tokens consumed by the response
//     messageId: String,        // server-side messageId (==clientRequestId per D-08)
//     createdAt: int,           // epoch ms (Timestamp.toMillis on the server)
//   }
//
// Safe-cast every field per Phase 1 D-02 model convention (`as T? ?? default`).
// ---------------------------------------------------------------------------

class MentorBotResponse {
  const MentorBotResponse({
    required this.text,
    required this.promptTokens,
    required this.completionTokens,
    required this.messageId,
    required this.createdAt,
  });

  final String text;
  final int promptTokens;
  final int completionTokens;
  final String messageId;
  final DateTime createdAt;

  factory MentorBotResponse.fromMap(Map<String, dynamic> map) {
    final createdAtRaw = map['createdAt'];
    final createdAt = createdAtRaw is int
        ? DateTime.fromMillisecondsSinceEpoch(createdAtRaw)
        : (createdAtRaw is num
            ? DateTime.fromMillisecondsSinceEpoch(createdAtRaw.toInt())
            : DateTime.now());

    return MentorBotResponse(
      text: (map['text'] as String?) ?? '',
      promptTokens: (map['promptTokens'] as num?)?.toInt() ?? 0,
      completionTokens: (map['completionTokens'] as num?)?.toInt() ?? 0,
      messageId: (map['messageId'] as String?) ?? '',
      createdAt: createdAt,
    );
  }
}
