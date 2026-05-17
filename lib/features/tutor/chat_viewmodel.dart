import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/gemini_service.dart';

// ---------------------------------------------------------------------------
// Message model
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

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class ChatState {
  static const defaultDailyLimit = 10;

  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isStreaming;
  final String selectedSubject;
  final String selectedLevel;
  final int dailyMessageCount;
  final int dailyLimit;
  final bool isPremium;
  final bool canSendMessage;
  final String? sessionId;

  // Screen-only extras
  final String? error;
  final List<String> availableSubjects;
  final String? imagePreviewPath;
  final bool limitModalRequested;

  const ChatState({
    this.messages = const [],
    this.isLoading = true,
    this.isStreaming = false,
    this.selectedSubject = 'General',
    this.selectedLevel = 'O Level',
    this.dailyMessageCount = 0,
    this.dailyLimit = defaultDailyLimit,
    this.isPremium = false,
    this.canSendMessage = true,
    this.sessionId,
    this.error,
    this.availableSubjects = const [],
    this.imagePreviewPath,
    this.limitModalRequested = false,
  });

  bool get hasReachedLimit => !canSendMessage && !isPremium;

  int get messagesRemaining => isPremium
      ? -1
      : (dailyLimit - dailyMessageCount).clamp(0, dailyLimit);

  bool get showLimitWarning =>
      !isPremium && dailyMessageCount >= 8 && dailyMessageCount < dailyLimit;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isStreaming,
    String? selectedSubject,
    String? selectedLevel,
    int? dailyMessageCount,
    int? dailyLimit,
    bool? isPremium,
    bool? canSendMessage,
    String? sessionId,
    String? error,
    List<String>? availableSubjects,
    String? imagePreviewPath,
    bool? limitModalRequested,
    bool clearError = false,
    bool clearSession = false,
    bool clearImagePreview = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isStreaming: isStreaming ?? this.isStreaming,
      selectedSubject: selectedSubject ?? this.selectedSubject,
      selectedLevel: selectedLevel ?? this.selectedLevel,
      dailyMessageCount: dailyMessageCount ?? this.dailyMessageCount,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      isPremium: isPremium ?? this.isPremium,
      canSendMessage: canSendMessage ?? this.canSendMessage,
      sessionId: clearSession ? null : (sessionId ?? this.sessionId),
      error: clearError ? null : (error ?? this.error),
      availableSubjects: availableSubjects ?? this.availableSubjects,
      imagePreviewPath: clearImagePreview
          ? null
          : (imagePreviewPath ?? this.imagePreviewPath),
      limitModalRequested:
          limitModalRequested ?? this.limitModalRequested,
    );
  }
}

// ---------------------------------------------------------------------------
// ViewModel
// ---------------------------------------------------------------------------

class ChatViewModel extends StateNotifier<ChatState> {
  ChatViewModel(this._gemini) : super(const ChatState()) {
    _loadContext();
  }

  final GeminiService _gemini;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Random _random = Random();

  // -------------------------------------------------------------------------
  // Load — subjects, level, premium flag, today's usage
  // -------------------------------------------------------------------------

  Future<void> _loadContext() async {
    final user = _auth.currentUser;
    if (user == null) {
      state = state.copyWith(isLoading: false, canSendMessage: false);
      return;
    }

    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      final usageRef = userRef.collection('usage').doc(_todayKey());

      final results = await Future.wait([userRef.get(), usageRef.get()]);
      final data = results[0].data() ?? <String, dynamic>{};
      final usage = results[1].data() ?? <String, dynamic>{};

      final subjects = ((data['subjects'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false);
      final level =
          (data['level'] as String?)?.trim().isNotEmpty == true
              ? (data['level'] as String).trim()
              : 'O Level';
      final isPremium =
          (data['subscriptionType'] as String?)?.toLowerCase() == 'premium';
      final count = (usage['messageCount'] as num?)?.toInt() ?? 0;

      state = state.copyWith(
        isLoading: false,
        availableSubjects: subjects,
        selectedSubject: subjects.isNotEmpty ? subjects.first : 'General',
        selectedLevel: level,
        isPremium: isPremium,
        dailyMessageCount: count,
        canSendMessage: isPremium || count < ChatState.defaultDailyLimit,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load your preferences.',
        canSendMessage: false,
      );
    }
  }

  // -------------------------------------------------------------------------
  // Simple setters
  // -------------------------------------------------------------------------

  void selectSubject(String s) {
    if (s == state.selectedSubject) return;
    state = state.copyWith(selectedSubject: s);
  }

  void toggleLevel() {
    state = state.copyWith(
      selectedLevel: state.selectedLevel == 'A Level' ? 'O Level' : 'A Level',
    );
  }

  void newChat() {
    _gemini.resetSession();
    state = state.copyWith(
      messages: const [],
      clearSession: true,
      clearImagePreview: true,
    );
  }

  void setImagePreview(String path) =>
      state = state.copyWith(imagePreviewPath: path);

  void removeImagePreview() =>
      state = state.copyWith(clearImagePreview: true);

  void setFeedback(String messageId, MessageFeedback fb) {
    final updated = state.messages.map((m) {
      if (m.id != messageId) return m;
      final clear = m.feedback == fb;
      return m.copyWith(
        feedback: clear ? null : fb,
        clearFeedback: clear,
      );
    }).toList(growable: false);
    state = state.copyWith(messages: updated);
  }

  void ackLimitModal() =>
      state = state.copyWith(limitModalRequested: false);

  // -------------------------------------------------------------------------
  // Send — text or text + image
  // -------------------------------------------------------------------------

  Future<void> sendMessage(String text, {File? imageFile}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && imageFile == null) return;
    if (state.isStreaming) return;

    // Rate limit check
    if (!state.canSendMessage) {
      state = state.copyWith(limitModalRequested: true);
      return;
    }

    final isFirstMessage = state.sessionId == null;
    final now = DateTime.now();
    final userMsg = ChatMessage(
      id: _genId('u'),
      role: MessageRole.user,
      content: trimmed,
      timestamp: now,
      imageUrl: imageFile != null ? imageFile.path : null,
    );
    final aiPlaceholder = ChatMessage(
      id: _genId('a'),
      role: MessageRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      isStreaming: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg, aiPlaceholder],
      isStreaming: true,
      clearImagePreview: true,
    );

    try {
      String? uploadedUrl;
      String finalText = '';

      if (imageFile != null && state.isPremium) {
        uploadedUrl = await _uploadImage(imageFile);
        _updateMessage(userMsg.id, imageUrl: uploadedUrl);

        final bytes = await imageFile.readAsBytes();
        finalText = await _gemini.analyzeImage(
          imageBytes: bytes,
          question: trimmed,
          subject: state.selectedSubject,
        );
        _updateMessage(
          aiPlaceholder.id,
          content: finalText,
          isStreaming: false,
        );
      } else {
        final buffer = StringBuffer();
        await for (final chunk in _gemini.sendMessage(
          text: trimmed,
          subject: state.selectedSubject,
          level: state.selectedLevel,
        )) {
          buffer.write(chunk);
          _updateMessage(aiPlaceholder.id, content: buffer.toString());
        }
        finalText = buffer.toString();
        _updateMessage(aiPlaceholder.id, isStreaming: false);
      }

      final newCount = state.dailyMessageCount + 1;
      state = state.copyWith(
        isStreaming: false,
        dailyMessageCount: newCount,
        canSendMessage:
            state.isPremium || newCount < state.dailyLimit,
      );

      unawaited(_saveSession());
      unawaited(_incrementUsage());
      if (isFirstMessage) {
        unawaited(_awardPoints('complete_session'));
      }
    } catch (_) {
      _updateMessage(
        aiPlaceholder.id,
        content: 'Sorry, I ran into a problem. Tap retry to try again.',
        isError: true,
        isStreaming: false,
      );
      state = state.copyWith(isStreaming: false);
    }
  }

  Future<void> retryLastMessage() async {
    // Find the last user message and resend it.
    for (var i = state.messages.length - 1; i >= 0; i--) {
      if (state.messages[i].role == MessageRole.user) {
        final lastUser = state.messages[i];
        // Drop the failed AI response + the retried user turn from state
        // so sendMessage can append fresh copies.
        final trimmed = state.messages.sublist(0, i);
        state = state.copyWith(messages: trimmed);
        await sendMessage(lastUser.content);
        return;
      }
    }
  }

  // -------------------------------------------------------------------------
  // Session persistence
  // -------------------------------------------------------------------------

  Future<void> _saveSession() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final sessions = _firestore.collection('sessions');
    var sid = state.sessionId;
    final ref = sid == null ? sessions.doc() : sessions.doc(sid);
    sid ??= ref.id;

    final lastUserMsg = state.messages
        .where((m) => m.role == MessageRole.user)
        .lastOrNull;
    final title = (lastUserMsg?.content.isNotEmpty ?? false)
        ? (lastUserMsg!.content.length > 60
            ? '${lastUserMsg.content.substring(0, 57)}…'
            : lastUserMsg.content)
        : 'Chat session';

    try {
      await ref.set({
        'userId': uid,
        'subject': state.selectedSubject,
        'level': state.selectedLevel,
        'title': title,
        'lastQuestion': lastUserMsg?.content ?? '',
        'messageCount': state.messages.length,
        'messages':
            state.messages.map((m) => m.toMap()).toList(growable: false),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (state.sessionId != sid && mounted) {
        state = state.copyWith(sessionId: sid);
      }
    } catch (_) {
      // Non-fatal — chat continues regardless of persistence.
    }
  }

  Future<void> loadSession(String sessionId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final doc =
          await _firestore.collection('sessions').doc(sessionId).get();
      final data = doc.data();
      if (data == null) {
        state = state.copyWith(isLoading: false, error: 'Session not found.');
        return;
      }
      final msgs = ((data['messages'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromMap)
          .toList(growable: false);

      _gemini.resetSession();
      state = state.copyWith(
        isLoading: false,
        sessionId: sessionId,
        messages: msgs,
        selectedSubject:
            (data['subject'] as String?) ?? state.selectedSubject,
        selectedLevel: (data['level'] as String?) ?? state.selectedLevel,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load session.',
      );
    }
  }

  // -------------------------------------------------------------------------
  // Storage + usage + rewards side-effects
  // -------------------------------------------------------------------------

  Future<String> _uploadImage(File file) async {
    final uid = _auth.currentUser!.uid;
    final name =
        '${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(99999)}.jpg';
    final ref = _storage.ref().child('uploads').child(uid).child(name);
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<void> _incrementUsage() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('usage')
          .doc(_todayKey())
          .set({
        'date': _todayKey(),
        'messageCount': FieldValue.increment(1),
        'lastMessageAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Silent.
    }
  }

  Future<void> _awardPoints(String type) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final amount = switch (type) {
      'complete_session' => 2,
      _ => 1,
    };
    try {
      final batch = _firestore.batch();
      batch.update(_firestore.collection('users').doc(uid), {
        'points': FieldValue.increment(amount),
      });
      batch.set(
        _firestore.collection('rewards').doc(uid),
        {
          'userId': uid,
          'points': FieldValue.increment(amount),
          'history': FieldValue.arrayUnion([
            {
              'type': type,
              'points': amount,
              'at': Timestamp.now(),
            }
          ]),
        },
        SetOptions(merge: true),
      );
      await batch.commit();
    } catch (_) {
      // Silent.
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  void _updateMessage(
    String id, {
    String? content,
    bool? isStreaming,
    String? imageUrl,
    bool? isError,
  }) {
    if (!mounted) return;
    final updated = state.messages.map((m) {
      if (m.id != id) return m;
      return m.copyWith(
        content: content,
        isStreaming: isStreaming,
        imageUrl: imageUrl,
        isError: isError,
      );
    }).toList(growable: false);
    state = state.copyWith(messages: updated);
  }

  static String _todayKey() {
    final d = DateTime.now();
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${pad(d.month)}-${pad(d.day)}';
  }

  String _genId(String prefix) {
    final ts = DateTime.now().microsecondsSinceEpoch;
    return '${prefix}_${ts}_${_random.nextInt(9999)}';
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final geminiServiceProvider = Provider<GeminiService>((ref) {
  final svc = GeminiService();
  ref.onDispose(svc.resetSession);
  return svc;
});

final chatViewModelProvider =
    StateNotifierProvider.autoDispose<ChatViewModel, ChatState>((ref) {
  final gemini = ref.watch(geminiServiceProvider);
  return ChatViewModel(gemini);
});
