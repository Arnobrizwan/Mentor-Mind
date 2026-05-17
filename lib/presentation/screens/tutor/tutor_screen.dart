import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/application/viewmodels/tutor/chat_viewmodel.dart';

class TutorScreen extends ConsumerStatefulWidget {
  const TutorScreen({super.key});

  @override
  ConsumerState<TutorScreen> createState() => _TutorScreenState();
}

class _TutorScreenState extends ConsumerState<TutorScreen> {
  final _inputCtrl = TextEditingController();
  final _inputFocus = FocusNode();
  late final ProviderSubscription<ChatState> _chatListener;

  @override
  void initState() {
    super.initState();
    _chatListener = ref.listenManual<ChatState>(chatViewModelProvider, (
      prev,
      next,
    ) {
      if (next.limitModalRequested &&
          !(prev?.limitModalRequested ?? false) &&
          mounted) {
        _showUpgradeModal();
        ref.read(chatViewModelProvider.notifier).ackLimitModal();
      }
    });
    _inputCtrl.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _chatListener.close();
    _inputCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  void _onBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.goNamed(AppRoutes.dashboard);
    }
  }

  Future<void> _onSend() async {
    final text = _inputCtrl.text.trim();
    final path = ref.read(chatViewModelProvider).imagePreviewPath;
    File? imgFile;
    if (path != null) {
      final f = File(path);
      if (await f.exists()) imgFile = f;
    }
    if (text.isEmpty && imgFile == null) return;
    _inputCtrl.clear();
    await ref
        .read(chatViewModelProvider.notifier)
        .sendMessage(text, imageFile: imgFile);
  }

  void _onSuggestionTap(String suggestion) {
    _inputCtrl.text = suggestion;
    _inputCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
    _inputFocus.requestFocus();
  }

  Future<void> _onNewChat() async {
    final hasMessages = ref.read(chatViewModelProvider).messages.isNotEmpty;
    if (!hasMessages) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.kSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Start a new chat?', style: AppTextStyles.headingMedium),
        content: Text(
          'Your current conversation is saved and will appear in your '
          'recent sessions.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.kTextMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.kTextMuted,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('New chat'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      ref.read(chatViewModelProvider.notifier).newChat();
      _inputCtrl.clear();
    }
  }

  Future<void> _showSubjectSheet(
    String current,
    List<String> available,
  ) async {
    final options = available.isNotEmpty ? available : _fallbackSubjects;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SubjectSheet(current: current, subjects: options),
    );
    if (picked != null && mounted) {
      ref.read(chatViewModelProvider.notifier).selectSubject(picked);
    }
  }

  Future<void> _onAttachImage(bool isPremium) async {
    _inputFocus.unfocus();
    if (!isPremium) {
      await _showUpgradeModal();
      return;
    }

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null || !mounted) return;
      ref.read(chatViewModelProvider.notifier).setImagePreview(picked.path);
    } catch (_) {
      if (!mounted) return;
      _toast("Couldn't open the image picker.", background: AppColors.kError);
    }
  }

  Future<void> _showUpgradeModal() {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _UpgradeSheet(),
    );
  }

  void _toast(String msg, {required Color background}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(milliseconds: 1800),
        ),
      );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatViewModelProvider);
    final hasText = _inputCtrl.text.trim().isNotEmpty;
    final hasImage = state.imagePreviewPath != null;
    final canSend = (hasText || hasImage) && !state.isStreaming;

    return Scaffold(
      backgroundColor: AppColors.kBackground,
      appBar: AppBar(
        backgroundColor: AppColors.kSurface,
        foregroundColor: AppColors.kTextDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: _onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: _SubjectPill(
          subject: state.selectedSubject,
          onTap: () => _showSubjectSheet(
            state.selectedSubject,
            state.availableSubjects,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _onNewChat,
            tooltip: 'New chat',
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _LevelRow(
            level: state.selectedLevel,
            onTap: () => ref.read(chatViewModelProvider.notifier).toggleLevel(),
          ),
          if (state.showLimitWarning)
            _LimitWarningBanner(remaining: state.messagesRemaining),
          Expanded(
            child: state.messages.isEmpty
                ? _EmptyState(onSuggestionTap: _onSuggestionTap)
                : _MessageList(
                    messages: state.messages,
                    onCopy: _copyToClipboard,
                    onFeedback: (id, fb) => ref
                        .read(chatViewModelProvider.notifier)
                        .setFeedback(id, fb),
                    onRetry: () => ref
                        .read(chatViewModelProvider.notifier)
                        .retryLastMessage(),
                  ),
          ),
          if (state.imagePreviewPath != null)
            _ImagePreview(
              path: state.imagePreviewPath!,
              onRemove: () =>
                  ref.read(chatViewModelProvider.notifier).removeImagePreview(),
            ),
          if (!state.canSendMessage && !state.isPremium)
            _LimitReachedCard(onUpgrade: _showUpgradeModal)
          else
            _InputBar(
              controller: _inputCtrl,
              focusNode: _inputFocus,
              canSend: canSend,
              isSending: state.isStreaming,
              onSend: _onSend,
              onAttach: () => _onAttachImage(state.isPremium),
            ),
        ],
      ),
    );
  }

  void _copyToClipboard(String content) {
    Clipboard.setData(ClipboardData(text: content));
    _toast('Copied to clipboard', background: AppColors.kTextDark);
  }
}

// ---------------------------------------------------------------------------
// Subject pill + picker sheet
// ---------------------------------------------------------------------------

const _fallbackSubjects = [
  'Mathematics',
  'Physics',
  'Chemistry',
  'Biology',
  'English',
  'ICT',
  'Accounting',
  'Economics',
  'History',
  'Geography',
];

String _subjectEmoji(String s) => switch (s) {
      'Mathematics' => '\u{1F4D0}',
      'Physics' => '\u{269B}\u{FE0F}',
      'Chemistry' => '\u{1F9EA}',
      'Biology' => '\u{1F9EC}',
      'English' => '\u{1F4D6}',
      'ICT' => '\u{1F4BB}',
      'Accounting' => '\u{1F9EE}',
      'Economics' => '\u{1F4CA}',
      'History' => '\u{1F4DC}',
      'Geography' => '\u{1F30D}',
      _ => '\u{1F393}',
    };

class _SubjectPill extends StatelessWidget {
  final String subject;
  final VoidCallback onTap;

  const _SubjectPill({required this.subject, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.kPrimary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _subjectEmoji(subject),
                style: const TextStyle(fontSize: 14, height: 1),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  subject,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.kPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppColors.kPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectSheet extends StatelessWidget {
  final String current;
  final List<String> subjects;
  const _SubjectSheet({required this.current, required this.subjects});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Choose a subject', style: AppTextStyles.headingMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in subjects)
                  _SubjectChoiceChip(
                    label: s,
                    selected: s == current,
                    onTap: () => Navigator.of(context).pop(s),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SubjectChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.kPrimary : AppColors.kSurface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.kPrimary : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_subjectEmoji(label),
                  style: const TextStyle(fontSize: 14, height: 1)),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: selected ? Colors.white : AppColors.kTextDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Level row — tappable chip below the AppBar
// ---------------------------------------------------------------------------

class _LevelRow extends StatelessWidget {
  final String level;
  final VoidCallback onTap;

  const _LevelRow({required this.level, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final displayLevel = level.replaceAll(' ', '-');
    return Container(
      width: double.infinity,
      color: AppColors.kSurface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Material(
            color: AppColors.kAccent.withOpacity(0.10),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 13,
                      color: AppColors.kAccent.withOpacity(0.85),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      displayLevel,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.kAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.unfold_more_rounded,
                      size: 12,
                      color: AppColors.kAccent.withOpacity(0.85),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Free-limit warning banner
// ---------------------------------------------------------------------------

class _LimitWarningBanner extends StatelessWidget {
  final int remaining;
  const _LimitWarningBanner({required this.remaining});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.kGold.withOpacity(0.12),
      child: Row(
        children: [
          const Icon(Icons.info_rounded, size: 16, color: AppColors.kGold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$remaining question${remaining == 1 ? '' : 's'} remaining today',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.kTextDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final ValueChanged<String> onSuggestionTap;
  const _EmptyState({required this.onSuggestionTap});

  static const _suggestions = [
    'Explain photosynthesis',
    'Solve quadratic',
    'Essay tips',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.kAccent,
                  AppColors.kAccent.withOpacity(0.65),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.kAccent.withOpacity(0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              size: 50,
              color: Colors.white,
            ),
          )
              .animate()
              .scale(
                begin: const Offset(0.7, 0.7),
                end: const Offset(1, 1),
                duration: 500.ms,
                curve: Curves.easeOutBack,
              )
              .fade(duration: 400.ms),
          const SizedBox(height: 20),
          Text(
            "Hello! I'm MentorBot \u{1F44B}",
            textAlign: TextAlign.center,
            style: AppTextStyles.displayMedium.copyWith(fontSize: 22),
          )
              .animate(delay: 150.ms)
              .fade(duration: 400.ms)
              .slideY(begin: 0.1, end: 0, duration: 400.ms),
          const SizedBox(height: 8),
          Text(
            'Ask me anything about your O/A Level subjects.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.kTextMuted,
              height: 1.5,
            ),
          ).animate(delay: 220.ms).fade(duration: 400.ms),
          const SizedBox(height: 28),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final s in _suggestions)
                _SuggestionChip(
                  label: s,
                  onTap: () => onSuggestionTap(s),
                ),
            ],
          )
              .animate(delay: 300.ms)
              .fade(duration: 450.ms)
              .slideY(begin: 0.1, end: 0, duration: 450.ms),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.kSurface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.kTextDark,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message list + bubbles
// ---------------------------------------------------------------------------

class _MessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final ValueChanged<String> onCopy;
  final void Function(String id, MessageFeedback fb) onFeedback;
  final VoidCallback onRetry;

  const _MessageList({
    required this.messages,
    required this.onCopy,
    required this.onFeedback,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (ctx, i) {
        final msg = messages[messages.length - 1 - i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: msg.role == MessageRole.user
              ? _UserBubble(message: msg)
              : _AiBubble(
                  message: msg,
                  onCopy: () => onCopy(msg.content),
                  onFeedback: (fb) => onFeedback(msg.id, fb),
                  onRetry: onRetry,
                ),
        );
      },
    );
  }
}

class _UserBubble extends StatelessWidget {
  final ChatMessage message;
  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: w * 0.75),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (message.imageUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _ImageThumb(path: message.imageUrl!, size: 140),
                ),
              ),
            if (message.content.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.kPrimary,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text(
                  message.content,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              _fmtTime(message.timestamp),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.kTextMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onCopy;
  final ValueChanged<MessageFeedback> onFeedback;
  final VoidCallback onRetry;

  const _AiBubble({
    required this.message,
    required this.onCopy,
    required this.onFeedback,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isStreamingEmpty = message.isStreaming && message.content.isEmpty;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: w * 0.82),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                'MentorBot \u{1F916}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.kAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: message.isError
                    ? AppColors.kError.withOpacity(0.05)
                    : AppColors.kSurface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
                border: Border(
                  left: BorderSide(
                    color:
                        message.isError ? AppColors.kError : AppColors.kAccent,
                    width: 3,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isStreamingEmpty)
                      const _TypingDots()
                    else
                      MarkdownBody(
                        data: message.content,
                        selectable: true,
                        styleSheet: _markdownStyle(context),
                      ),
                    if (message.isError) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Retry'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.kError,
                            side: BorderSide(
                              color: AppColors.kError.withOpacity(0.5),
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ] else if (!message.isStreaming) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _FeedbackIcon(
                            icon: Icons.thumb_up_alt_outlined,
                            filled: Icons.thumb_up_alt_rounded,
                            active: message.feedback == MessageFeedback.up,
                            activeColor: AppColors.kAccent,
                            onTap: () => onFeedback(MessageFeedback.up),
                          ),
                          const SizedBox(width: 8),
                          _FeedbackIcon(
                            icon: Icons.thumb_down_alt_outlined,
                            filled: Icons.thumb_down_alt_rounded,
                            active: message.feedback == MessageFeedback.down,
                            activeColor: AppColors.kError,
                            onTap: () => onFeedback(MessageFeedback.down),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: onCopy,
                            tooltip: 'Copy',
                            splashRadius: 16,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            icon: const Icon(
                              Icons.content_copy_rounded,
                              size: 16,
                              color: AppColors.kTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                _fmtTime(message.timestamp),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.kTextMuted,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackIcon extends StatelessWidget {
  final IconData icon;
  final IconData filled;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _FeedbackIcon({
    required this.icon,
    required this.filled,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 18,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          active ? filled : icon,
          size: 16,
          color: active ? activeColor : AppColors.kTextMuted,
        ),
      ),
    );
  }
}

MarkdownStyleSheet _markdownStyle(BuildContext context) {
  final base = MarkdownStyleSheet.fromTheme(Theme.of(context));
  return base.copyWith(
    p: AppTextStyles.bodyMedium.copyWith(fontSize: 15, height: 1.5),
    strong: AppTextStyles.bodyMedium.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w700,
    ),
    em: AppTextStyles.bodyMedium.copyWith(
      fontSize: 15,
      fontStyle: FontStyle.italic,
    ),
    h1: AppTextStyles.headingMedium,
    h2: AppTextStyles.headingSmall,
    h3: AppTextStyles.labelLarge,
    listBullet: AppTextStyles.bodyMedium.copyWith(fontSize: 15),
    blockquote: AppTextStyles.bodyMedium.copyWith(
      fontSize: 14,
      color: AppColors.kTextMuted,
      fontStyle: FontStyle.italic,
    ),
    blockquoteDecoration: BoxDecoration(
      color: AppColors.kAccent.withOpacity(0.06),
      borderRadius: BorderRadius.circular(6),
      border: const Border(
        left: BorderSide(color: AppColors.kAccent, width: 3),
      ),
    ),
    blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    code: AppTextStyles.monoSmall.copyWith(
      backgroundColor: const Color(0xFFF3F4F6),
      color: AppColors.kTextDark,
    ),
    codeblockDecoration: BoxDecoration(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(8),
    ),
    codeblockPadding: const EdgeInsets.all(12),
    tableBorder: TableBorder.all(color: const Color(0xFFE5E7EB)),
  );
}

// ---------------------------------------------------------------------------
// Typing dots — used inside empty streaming AI bubble
// ---------------------------------------------------------------------------

class _TypingDots extends StatelessWidget {
  const _TypingDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: EdgeInsets.only(right: i == 2 ? 0 : 4),
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.kAccent,
              shape: BoxShape.circle,
            ),
          )
              .animate(
                delay: Duration(milliseconds: i * 200),
                onPlay: (c) => c.repeat(reverse: true),
              )
              .scaleXY(
                begin: 0.6,
                end: 1.2,
                duration: 600.ms,
                curve: Curves.easeInOut,
              )
              .fadeIn(begin: 0.35, duration: 600.ms),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Image preview (above input bar)
// ---------------------------------------------------------------------------

class _ImagePreview extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;

  const _ImagePreview({required this.path, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.kSurface,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _ImageThumb(path: path, size: 80),
            ),
            Positioned(
              top: -6,
              right: -6,
              child: Material(
                color: AppColors.kTextDark,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  onTap: onRemove,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  final String path;
  final double size;
  const _ImageThumb({required this.path, required this.size});

  @override
  Widget build(BuildContext context) {
    final isNetwork = path.startsWith('http');
    return SizedBox(
      width: size,
      height: size,
      child: isNetwork
          ? Image.network(path, fit: BoxFit.cover, errorBuilder: _err)
          : Image.file(File(path), fit: BoxFit.cover, errorBuilder: _err),
    );
  }

  Widget _err(BuildContext _, Object __, StackTrace? ___) {
    return Container(
      color: const Color(0xFFE5E7EB),
      alignment: Alignment.center,
      child:
          const Icon(Icons.broken_image_outlined, color: AppColors.kTextMuted),
    );
  }
}

// ---------------------------------------------------------------------------
// Input bar
// ---------------------------------------------------------------------------

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool canSend;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.canSend,
    required this.isSending,
    required this.onSend,
    required this.onAttach,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.kSurface,
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.08),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: onAttach,
                splashRadius: 22,
                tooltip: 'Attach image',
                icon: const Icon(
                  Icons.image_outlined,
                  color: AppColors.kTextMuted,
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.kBackground,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    maxLines: 4,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      color: AppColors.kTextDark,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ask MentorBot anything...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.kTextMuted,
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      isCollapsed: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SendButton(
                enabled: canSend,
                loading: isSending,
                onPressed: onSend,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  const _SendButton({
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: enabled ? AppColors.kPrimary : const Color(0xFFCBD5E1),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          customBorder: const CircleBorder(),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Daily limit reached — blocks the input area
// ---------------------------------------------------------------------------

class _LimitReachedCard extends StatelessWidget {
  final Future<void> Function() onUpgrade;
  const _LimitReachedCard({required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.kSurface,
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.08),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.kGold.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 18,
                      color: AppColors.kGold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily limit reached \u{1F512}',
                          style: AppTextStyles.headingSmall.copyWith(
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Upgrade to Premium for unlimited AI tutoring.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.kTextMuted,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "We'll remind you tomorrow.",
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: AppColors.kTextDark,
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          duration: const Duration(milliseconds: 1800),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.kTextDark,
                        minimumSize: const Size.fromHeight(44),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Remind Tomorrow'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => onUpgrade(),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: const Text('Upgrade Now'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Upgrade modal
// ---------------------------------------------------------------------------

class _UpgradeSheet extends StatelessWidget {
  const _UpgradeSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.kGold, Color(0xFFE28A00)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.kGold.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text('Upgrade to Premium', style: AppTextStyles.headingLarge),
            const SizedBox(height: 6),
            Text(
              'Unlimited AI tutoring, diagram uploads, priority answers, '
              'and more.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.kTextMuted,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('See Premium plans'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.kTextMuted,
              ),
              child: const Text('Maybe later'),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtTime(DateTime ts) => DateFormat('h:mm a').format(ts);
