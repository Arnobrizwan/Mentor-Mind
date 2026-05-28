import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/application/viewmodels/config/remote_config_providers.dart';
import 'package:mentor_minds/core/constants/quota.dart';
import 'package:mentor_minds/core/observability/analytics_service.dart';
import 'package:mentor_minds/core/utils/email_verification.dart';
import 'package:mentor_minds/data/models/chat_message.dart';
import 'package:mentor_minds/data/models/mentor_bot_response.dart';
import 'package:mentor_minds/data/models/quotas_config.dart';
import 'package:mentor_minds/data/repositories/auth_repository.dart';
import 'package:mentor_minds/data/repositories/mentor_bot_repository.dart';
import 'package:mentor_minds/data/models/subscription_doc.dart';
import 'package:mentor_minds/data/repositories/sessions_repository.dart';
import 'package:mentor_minds/data/repositories/storage_repository.dart';
import 'package:mentor_minds/data/repositories/subscriptions_repository.dart';
import 'package:mentor_minds/data/repositories/users_repository.dart';
import 'package:uuid/uuid.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isStreaming;
  final String selectedSubject;
  final String selectedLevel;
  final int dailyMessageCount;
  final int dailyLimit;
  final int warningThreshold;
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
    this.dailyLimit = 30,
    this.warningThreshold = 8,
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
      !isPremium &&
          dailyMessageCount >=
              (dailyLimit - warningThreshold).clamp(0, dailyLimit) &&
          dailyMessageCount < dailyLimit;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isStreaming,
    String? selectedSubject,
    String? selectedLevel,
    int? dailyMessageCount,
    int? dailyLimit,
    int? warningThreshold,
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
      warningThreshold: warningThreshold ?? this.warningThreshold,
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
    this._ref,
    this._mentorBotRepository,
    this._authRepo,
    this._usersRepo,
    this._subscriptionsRepo,
    this._sessionsRepo,
    this._storageRepo,
    this._analytics,
  ) : super(ChatState(
          dailyLimit: _ref.read(currentQuotasConfigProvider).dailyTextLimit,
          warningThreshold:
              _ref.read(currentQuotasConfigProvider).warningThreshold,
        )) {
    _loadContext();
    _watchQuotasConfig();
  }

  final Ref _ref;
  final MentorBotRepository _mentorBotRepository;
  final AuthRepository _authRepo;
  final UsersRepository _usersRepo;
  final SubscriptionsRepository _subscriptionsRepo;
  final SessionsRepository _sessionsRepo;
  final StorageRepository _storageRepo;
  final AnalyticsService _analytics;
  final Random _random = Random();

  StreamSubscription<SubscriptionDoc>? _subSub;

  void _watchQuotasConfig() {
    _ref.listen<QuotasConfig>(
      currentQuotasConfigProvider,
      (_, next) {
        if (!mounted) return;
        state = state.copyWith(
          dailyLimit: next.dailyTextLimit,
          warningThreshold: next.warningThreshold,
          canSendMessage: state.isPremium ||
              state.dailyMessageCount < next.dailyTextLimit,
        );
      },
    );
  }

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
      final todayKey = dhakaDateKey(DateTime.now());

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
      final subType =
          await _subscriptionsRepo.getSubscriptionType(uid);
      final claimPremium = await _resolvePremiumFromToken();
      final isPremium = subType == 'premium' || claimPremium;
      final count = (usage['messageCount'] as num?)?.toInt() ?? 0;

      state = state.copyWith(
        isLoading: false,
        availableSubjects: subjects,
        selectedSubject: subjects.isNotEmpty ? subjects.first : 'General',
        selectedLevel: level,
        isPremium: isPremium,
        dailyMessageCount: count,
        canSendMessage: isPremium || count < state.dailyLimit,
      );

      _subSub?.cancel();
      _subSub = _subscriptionsRepo.watchSubscription(uid).listen(
        (sub) {
          final premium = sub.isPremiumActive;
          if (premium != state.isPremium) {
            state = state.copyWith(
              isPremium: premium,
              canSendMessage:
                  premium || state.dailyMessageCount < state.dailyLimit,
            );
            if (premium) {
              unawaited(_authRepo.currentUser?.getIdToken(true));
            }
          }
        },
        // Non-fatal — keep the last-known premium flag rather than blanking
        // the tutor on a transient stream error (network blip, auth refresh,
        // rules eval). Logged for diagnostics so we notice systemic failures.
        onError: (Object e) {
          debugPrint('chat_viewmodel: subscription stream error: $e');
        },
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

    if (requiresEmailVerification(_authRepo.currentUser)) {
      state = state.copyWith(
        error:
            'Please verify your email before using MentorBot. Check your inbox.',
      );
      return;
    }

    // Rate limit check
    if (!state.canSendMessage) {
      state = state.copyWith(limitModalRequested: true);
      return;
    }

    // Phase 3 AI-10: clientRequestId generated ONCE per user-initiated send.
    // Persist the same id across retries for server-side idempotency (plan 03-06).
    final clientRequestId = const Uuid().v4();

    final now = DateTime.now();
    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      role: MessageRole.user,
      content: trimmed,
      timestamp: now,
      imageUrl: imageFile?.path,
    );
    final aiPlaceholder = ChatMessage(
      id: const Uuid().v4(),
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

      if (imageFile != null) {
        final uid = _authRepo.currentUser!.uid;
        uploadedUrl = await _storageRepo.uploadImage(
          uid: uid,
          file: imageFile,
          suffix: '${_random.nextInt(99999)}.jpg',
        );
        _updateMessage(userMsg.id, imageUrl: uploadedUrl);

        // Phase 3 AI-10: non-streaming Future call for image branch.
        // isStreaming flag stays in ChatState — drives the typing indicator —
        // but now means "awaiting the Future" instead of "consuming a Stream".
        final MentorBotResponse imageResponse =
            await _mentorBotRepository.sendMessage(
          sessionId: state.sessionId ?? const Uuid().v4(),
          clientRequestId: clientRequestId,
          message: trimmed,
          imageUrl: uploadedUrl,
          subject: state.selectedSubject,
          level: state.selectedLevel,
        );
        finalText = imageResponse.text;
        _updateMessage(
          aiPlaceholder.id,
          content: finalText,
          isStreaming: false,
        );
      } else {
        // Phase 3 AI-10: non-streaming Future call. isStreaming flag stays in
        // ChatState — drives the typing indicator — but now means "awaiting the
        // Future" instead of "consuming a Stream". Same UX.
        final MentorBotResponse response =
            await _mentorBotRepository.sendMessage(
          sessionId: state.sessionId ?? const Uuid().v4(),
          clientRequestId: clientRequestId,
          message: trimmed,
          subject: state.selectedSubject,
          level: state.selectedLevel,
        );
        finalText = response.text;
        _updateMessage(aiPlaceholder.id, content: finalText, isStreaming: false);
      }

      final newCount = state.dailyMessageCount + 1;
      state = state.copyWith(
        isStreaming: false,
        dailyMessageCount: newCount,
        canSendMessage:
            state.isPremium || newCount < state.dailyLimit,
      );

      unawaited(_saveSession());
      unawaited(_analytics.logSendMessage());
      if (imageFile != null) {
        unawaited(_analytics.logUploadImage());
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
    if (requiresEmailVerification(_authRepo.currentUser)) return;

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

  Future<bool> _resolvePremiumFromToken() async {
    final token = await _authRepo.currentUser?.getIdTokenResult();
    final claims = token?.claims;
    return claims != null && claims['premium'] == true;
  }

  @override
  void dispose() {
    _subSub?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final chatViewModelProvider =
    StateNotifierProvider.autoDispose<ChatViewModel, ChatState>((ref) {
  return ChatViewModel(
    ref,
    ref.read(mentorBotRepositoryProvider),
    ref.read(authRepositoryProvider),
    ref.read(usersRepositoryProvider),
    ref.read(subscriptionsRepositoryProvider),
    ref.read(sessionsRepositoryProvider),
    ref.read(storageRepositoryProvider),
    ref.read(analyticsServiceProvider),
  );
});
