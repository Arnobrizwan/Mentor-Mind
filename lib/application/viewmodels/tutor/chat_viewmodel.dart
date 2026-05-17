import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/core/services/gemini_service.dart';
import 'package:mentor_minds/data/models/chat_message.dart';
import 'package:mentor_minds/data/repositories/auth_repository.dart';
import 'package:mentor_minds/data/repositories/sessions_repository.dart';
import 'package:mentor_minds/data/repositories/storage_repository.dart';
import 'package:mentor_minds/data/repositories/users_repository.dart';

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
  ChatViewModel(
    this._gemini,
    this._authRepo,
    this._usersRepo,
    this._sessionsRepo,
    this._storageRepo,
  ) : super(const ChatState()) {
    _loadContext();
  }

  final GeminiService _gemini;
  final AuthRepository _authRepo;
  final UsersRepository _usersRepo;
  final SessionsRepository _sessionsRepo;
  final StorageRepository _storageRepo;
  final Random _random = Random();

  // -------------------------------------------------------------------------
  // Load — subjects, level, premium flag, today's usage
  // -------------------------------------------------------------------------

  Future<void> _loadContext() async {
    final user = _authRepo.currentUser;
    if (user == null) {
      state = state.copyWith(isLoading: false, canSendMessage: false);
      return;
    }

    try {
      final uid = user.uid;
      final todayKey = _todayKey();

      final results = await Future.wait([
        _usersRepo.getUserDocRaw(uid),
        _usersRepo.getUsageDoc(uid, todayKey),
      ]);
      final data = results[0] ?? <String, dynamic>{};
      final usage = results[1] ?? <String, dynamic>{};

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
        final uid = _authRepo.currentUser!.uid;
        uploadedUrl = await _storageRepo.uploadImage(
          uid: uid,
          file: imageFile,
          suffix: '${_random.nextInt(99999)}.jpg',
        );
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
    final uid = _authRepo.currentUser?.uid;
    if (uid == null) return;

    final lastUserMsg = state.messages
        .where((m) => m.role == MessageRole.user)
        .lastOrNull;
    final title = (lastUserMsg?.content.isNotEmpty ?? false)
        ? (lastUserMsg!.content.length > 60
            ? '${lastUserMsg.content.substring(0, 57)}…'
            : lastUserMsg.content)
        : 'Chat session';

    try {
      final newSid = await _sessionsRepo.saveSession(
        uid,
        {
          'userId': uid,
          'subject': state.selectedSubject,
          'level': state.selectedLevel,
          'title': title,
          'lastQuestion': lastUserMsg?.content ?? '',
          'messageCount': state.messages.length,
          'messages':
              state.messages.map((m) => m.toMap()).toList(growable: false),
        },
        sessionId: state.sessionId,
      );

      if (state.sessionId != newSid && mounted) {
        state = state.copyWith(sessionId: newSid);
      }
    } catch (_) {
      // Non-fatal — chat continues regardless of persistence.
    }
  }

  Future<void> loadSession(String sessionId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _sessionsRepo.getSession(sessionId);
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
  // Usage + rewards side-effects
  // -------------------------------------------------------------------------

  Future<void> _incrementUsage() async {
    final uid = _authRepo.currentUser?.uid;
    if (uid == null) return;
    try {
      await _usersRepo.incrementUsageMessageCount(uid, _todayKey());
    } catch (_) {
      // Silent.
    }
  }

  Future<void> _awardPoints(String type) async {
    final uid = _authRepo.currentUser?.uid;
    if (uid == null) return;
    final amount = switch (type) {
      'complete_session' => 2,
      _ => 1,
    };
    try {
      await _usersRepo.awardSessionPoints(uid, type, amount);
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
  return ChatViewModel(
    gemini,
    ref.read(authRepositoryProvider),
    ref.read(usersRepositoryProvider),
    ref.read(sessionsRepositoryProvider),
    ref.read(storageRepositoryProvider),
  );
});
