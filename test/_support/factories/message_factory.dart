import 'package:mentor_minds/data/models/chat_message.dart';

// ---------------------------------------------------------------------------
// message_factory.dart — Test data builder for ChatMessage.
// MessageRole and MessageFeedback enums live in chat_message.dart (Plan 04).
// ---------------------------------------------------------------------------

ChatMessage buildChatMessage({
  String id = 'msg-1',
  String content = 'hello',
  MessageRole role = MessageRole.user,
  DateTime? timestamp,
  MessageFeedback? feedback,
  String? imageUrl,
  bool isError = false,
  bool isStreaming = false,
}) {
  return ChatMessage(
    id: id,
    role: role,
    content: content,
    timestamp: timestamp ?? DateTime(2026, 1, 1),
    feedback: feedback,
    imageUrl: imageUrl,
    isError: isError,
    isStreaming: isStreaming,
  );
}
