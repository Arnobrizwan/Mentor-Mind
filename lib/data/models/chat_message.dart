import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------------
// ChatMessage — a single message in a MentorBot tutoring session.
// Stored in Firestore via toMap/fromMap; serialises MessageRole and
// MessageFeedback as lowercase strings.
// ---------------------------------------------------------------------------

enum MessageRole { user, assistant }

enum MessageFeedback { up, down }

class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final MessageFeedback? feedback;
  final String? imageUrl;
  final bool isError;
  final bool isStreaming;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.feedback,
    this.imageUrl,
    this.isError = false,
    this.isStreaming = false,
  });

  ChatMessage copyWith({
    String? content,
    MessageFeedback? feedback,
    String? imageUrl,
    bool? isError,
    bool? isStreaming,
    bool clearFeedback = false,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      imageUrl: imageUrl ?? this.imageUrl,
      isError: isError ?? this.isError,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'role': role.name,
        'content': content,
        'timestamp': Timestamp.fromDate(timestamp),
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (feedback != null) 'feedback': feedback!.name,
        if (isError) 'isError': true,
      };

  static ChatMessage fromMap(Map<String, dynamic> m) {
    return ChatMessage(
      id: (m['id'] as String?) ??
          'm_${DateTime.now().microsecondsSinceEpoch}',
      role: MessageRole.values.firstWhere(
        (r) => r.name == (m['role'] as String?),
        orElse: () => MessageRole.user,
      ),
      content: (m['content'] as String?) ?? '',
      timestamp:
          (m['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: m['imageUrl'] as String?,
      feedback: (m['feedback'] as String?) == null
          ? null
          : MessageFeedback.values.firstWhere(
              (f) => f.name == (m['feedback'] as String),
              orElse: () => MessageFeedback.up,
            ),
      isError: m['isError'] == true,
    );
  }
}
