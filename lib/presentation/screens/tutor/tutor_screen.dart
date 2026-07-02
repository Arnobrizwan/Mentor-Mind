import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:mentor_minds/application/viewmodels/config/remote_config_providers.dart';
import 'package:mentor_minds/application/viewmodels/tutor/chat_viewmodel.dart';
import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/constants/tutor_prompts.dart';
import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/core/theme/app_motion.dart';
import 'package:mentor_minds/core/theme/app_radius.dart';
import 'package:mentor_minds/core/theme/app_spacing.dart';
import 'package:mentor_minds/core/theme/brand_colors.dart';
import 'package:mentor_minds/data/models/chat_message.dart';
import 'package:mentor_minds/shared/widgets/math_markdown.dart';
import 'package:mentor_minds/shared/widgets/pill_button.dart';
import 'package:mentor_minds/shared/widgets/premium_upgrade_modal.dart';

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

  Future<void> _onBack() async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    final route = await resolveHomeRouteName(ref);
    if (mounted) context.goNamed(route);
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
      builder: (ctx) {
        final brand = ctx.brand;
        return AlertDialog(
          backgroundColor: brand.surface,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
          title: Text(
            'Start a new chat?',
            style: AppTextStyles.headingMedium.copyWith(color: brand.textDark),
          ),
          content: Text(
            'Your current conversation is saved and will appear in your '
            'recent sessions.',
            style: AppTextStyles.bodyMedium.copyWith(color: brand.textMuted),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md,
          ),
          actions: [
            PillButton(
              label: 'Cancel',
              variant: PillVariant.ghost,
              fullWidth: false,
              dense: true,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            const SizedBox(width: AppSpacing.sm),
            PillButton(
              label: 'New chat',
              fullWidth: false,
              dense: true,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
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
    final options = tutorSubjectOptions(
      available,
      fallback: ref.read(currentCurriculumConfigProvider).subjects,
    );
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.brand.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadius.xlRadius),
      ),
      builder: (ctx) => _SubjectSheet(current: current, subjects: options),
    );
    if (picked != null && mounted) {
      ref.read(chatViewModelProvider.notifier).selectSubject(picked);
    }
  }

  Future<void> _onAttachImage() async {
    _inputFocus.unfocus();

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
      _toast("Couldn't open the image picker.", background: context.brand.error);
    }
  }

  Future<void> _showUpgradeModal() {
    return PremiumUpgradeModal.show(context);
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
          margin: const EdgeInsets.all(AppSpacing.lg),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
          duration: const Duration(milliseconds: 1800),
        ),
      );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final state = ref.watch(chatViewModelProvider);
    final hasText = _inputCtrl.text.trim().isNotEmpty;
    final hasImage = state.imagePreviewPath != null;
    final canSend = (hasText || hasImage) && !state.isStreaming;

    return Scaffold(
      backgroundColor: brand.background,
      appBar: AppBar(
        backgroundColor: brand.surface,
        foregroundColor: brand.textDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: _onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
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
                ? _EmptyState(
                    suggestions: tutorSuggestionsFor(state.selectedSubject),
                    onSuggestionTap: _onSuggestionTap,
                  )
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
              onAttach: state.isPremium ? _onAttachImage : null,
            ),
        ],
      ),
    );
  }

  void _copyToClipboard(String content) {
    Clipboard.setData(ClipboardData(text: content));
    _toast('Copied to clipboard', background: context.brand.textDark);
  }
}

// ---------------------------------------------------------------------------
// Subject pill + picker sheet
// ---------------------------------------------------------------------------

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
    final brand = context.brand;
    return Material(
      color: brand.primary.withValues(alpha: 0.08),
      borderRadius: AppRadius.pillBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillBorder,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _subjectEmoji(subject),
                style: const TextStyle(fontSize: 14, height: 1),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Flexible(
                child: Text(
                  subject,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: brand.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: brand.primary,
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
    final brand = context.brand;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: brand.border,
                  borderRadius: AppRadius.xsBorder,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Choose a subject',
              style: AppTextStyles.headingMedium.copyWith(
                color: brand.textDark,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
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
    final brand = context.brand;
    return Material(
      color: selected ? brand.primary : brand.surface,
      borderRadius: AppRadius.pillBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillBorder,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md + 2, vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.pillBorder,
            border: Border.all(
              color: selected ? brand.primary : brand.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _subjectEmoji(label),
                style: const TextStyle(fontSize: 14, height: 1),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: selected ? Colors.white : brand.textDark,
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
    final brand = context.brand;
    final displayLevel = level.replaceAll(' ', '-');
    return Container(
      width: double.infinity,
      color: brand.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm + 2,
      ),
      child: Row(
        children: [
          Material(
            color: brand.accent.withValues(alpha: 0.10),
            borderRadius: AppRadius.pillBorder,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadius.pillBorder,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs + 1,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 13,
                      color: brand.accent.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Text(
                      displayLevel,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: brand.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.unfold_more_rounded,
                      size: 12,
                      color: brand.accent.withValues(alpha: 0.85),
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
    final brand = context.brand;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2,
      ),
      color: brand.gold.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(Icons.info_rounded, size: 16, color: brand.gold),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$remaining question${remaining == 1 ? '' : 's'} remaining today',
              style: AppTextStyles.bodySmall.copyWith(
                color: brand.textDark,
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
// Empty state — MentorBot intro + tappable suggestion chips
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.suggestions,
    required this.onSuggestionTap,
  });

  final List<String> suggestions;
  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl, vertical: AppSpacing.xxl,
      ),
      child: Column(
        children: [
          // Mascot in a soft radial halo, with a gentle vertical float.
          // Replaces the previous flat teal-circle-with-icon placeholder.
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Halo — radial accent glow behind the mascot.
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.kAccent.withValues(alpha: 0.28),
                        AppColors.kAccent.withValues(alpha: 0.0),
                      ],
                      stops: const [0.45, 1.0],
                    ),
                  ),
                ),
                // The mascot illustration itself, animated by _FloatingMascot.
                const _FloatingMascot(size: 168),
              ],
            ),
          )
              .animate()
              .scale(
                begin: const Offset(0.7, 0.7),
                end: const Offset(1, 1),
                duration: 500.ms,
                curve: AppMotion.celebrate,
              )
              .fade(duration: 400.ms),
          const SizedBox(height: AppSpacing.md),
          Text(
            "Hello! I'm MentorBot \u{1F44B}",
            textAlign: TextAlign.center,
            style: AppTextStyles.displayMedium.copyWith(
              color: brand.textDark,
              fontSize: 22,
            ),
          )
              .animate(delay: 150.ms)
              .fade(duration: 400.ms)
              .slideY(begin: 0.1, end: 0, duration: 400.ms),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Ask me anything about your O/A Level subjects.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: brand.textMuted,
              height: 1.5,
            ),
          ).animate(delay: 220.ms).fade(duration: 400.ms),
          const SizedBox(height: AppSpacing.xl),
          // Subtle "try one of these" label above the chips so the chips
          // read as starter prompts, not just decorative pills.
          Text(
            'Try one of these',
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(
              color: brand.textMuted,
              letterSpacing: 1.0,
            ),
          ).animate(delay: 280.ms).fade(duration: 400.ms),
          const SizedBox(height: AppSpacing.sm + 2),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < suggestions.length; i++)
                _SuggestionChip(
                  label: suggestions[i],
                  delay: 320 + (i * 80),
                  onTap: () => onSuggestionTap(suggestions[i]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _FloatingMascot — onboarding_hero.png with a gentle vertical bob. Used
// inside _EmptyState as the MentorBot avatar. Ignored for input.
// ---------------------------------------------------------------------------

class _FloatingMascot extends StatefulWidget {
  final double size;
  const _FloatingMascot({required this.size});

  @override
  State<_FloatingMascot> createState() => _FloatingMascotState();
}

class _FloatingMascotState extends State<_FloatingMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final dy = (Curves.easeInOut.transform(_ctrl.value) - 0.5) * 10;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: SizedBox(
        height: widget.size,
        width: widget.size,
        child: Image.asset(
          'assets/images/illustrations/onboarding_hero.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => Icon(
            Icons.smart_toy_rounded,
            size: widget.size * 0.5,
            color: AppColors.kAccent,
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatefulWidget {
  final String label;
  final int delay;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.label,
    required this.delay,
    required this.onTap,
  });

  @override
  State<_SuggestionChip> createState() => _SuggestionChipState();
}

class _SuggestionChipState extends State<_SuggestionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return AnimatedScale(
      scale: _pressed ? 0.94 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.pillBorder,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          borderRadius: AppRadius.pillBorder,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md + 2, vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.pillBorder,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  brand.surface,
                  brand.accent.withValues(alpha: 0.07),
                ],
              ),
              border: Border.all(color: brand.accent.withValues(alpha: 0.30)),
              boxShadow: [
                BoxShadow(
                  color: brand.accent.withValues(alpha: 0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('✨',
                    style: TextStyle(fontSize: 12, height: 1)),
                const SizedBox(width: AppSpacing.xs + 2),
                Flexible(
                  child: Text(
                    widget.label,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: brand.textDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate(delay: Duration(milliseconds: widget.delay))
        .fade(duration: 350.ms)
        .slideY(begin: 0.15, end: 0, duration: 350.ms);
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md, vertical: AppSpacing.md,
      ),
      itemCount: messages.length,
      itemBuilder: (ctx, i) {
        final msg = messages[messages.length - 1 - i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
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
    final brand = context.brand;
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
                padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
                child: ClipRRect(
                  borderRadius: AppRadius.mdBorder,
                  child: _ImageThumb(path: message.imageUrl!, size: 140),
                ),
              ),
            if (message.content.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md + 2, vertical: AppSpacing.sm + 2,
                ),
                decoration: BoxDecoration(
                  color: brand.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: AppRadius.xsRadius,
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
            const SizedBox(height: AppSpacing.xs),
            Text(
              _fmtTime(message.timestamp),
              style: AppTextStyles.bodySmall.copyWith(
                color: brand.textMuted,
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
    final brand = context.brand;
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
              padding: const EdgeInsets.only(
                left: AppSpacing.xs, bottom: AppSpacing.xs,
              ),
              child: Text(
                'MentorBot \u{1F916}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: brand.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: message.isError
                    ? brand.error.withValues(alpha: 0.05)
                    : brand.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: AppRadius.xsRadius,
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
                border: Border(
                  left: BorderSide(
                    color: message.isError ? brand.error : brand.accent,
                    width: 3,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md + 2, AppSpacing.md,
                  AppSpacing.md, AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isStreamingEmpty)
                      const _TypingDots()
                    else
                      MathMarkdownBody(
                        data: message.content,
                        selectable: true,
                        styleSheet: _markdownStyle(context),
                      ),
                    if (message.isError) ...[
                      const SizedBox(height: AppSpacing.sm + 2),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Retry'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: brand.error,
                            side: BorderSide(
                              color: brand.error.withValues(alpha: 0.5),
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs + 2,
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadius.pillBorder,
                            ),
                          ),
                        ),
                      ),
                    ] else if (!message.isStreaming) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          _FeedbackIcon(
                            icon: Icons.thumb_up_alt_outlined,
                            filled: Icons.thumb_up_alt_rounded,
                            active: message.feedback == MessageFeedback.up,
                            activeColor: brand.accent,
                            onTap: () => onFeedback(MessageFeedback.up),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _FeedbackIcon(
                            icon: Icons.thumb_down_alt_outlined,
                            filled: Icons.thumb_down_alt_rounded,
                            active: message.feedback == MessageFeedback.down,
                            activeColor: brand.error,
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
                              minWidth: 28, minHeight: 28,
                            ),
                            icon: Icon(
                              Icons.content_copy_rounded,
                              size: 16,
                              color: brand.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: Text(
                _fmtTime(message.timestamp),
                style: AppTextStyles.bodySmall.copyWith(
                  color: brand.textMuted,
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
    final brand = context.brand;
    return InkResponse(
      onTap: onTap,
      radius: 18,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Icon(
          active ? filled : icon,
          size: 16,
          color: active ? activeColor : brand.textMuted,
        ),
      ),
    );
  }
}

MarkdownStyleSheet _markdownStyle(BuildContext context) {
  final brand = context.brand;
  final base = MarkdownStyleSheet.fromTheme(Theme.of(context));
  return base.copyWith(
    p: AppTextStyles.bodyMedium.copyWith(
      fontSize: 15, height: 1.5, color: brand.textDark,
    ),
    strong: AppTextStyles.bodyMedium.copyWith(
      fontSize: 15, fontWeight: FontWeight.w700, color: brand.textDark,
    ),
    em: AppTextStyles.bodyMedium.copyWith(
      fontSize: 15, fontStyle: FontStyle.italic, color: brand.textDark,
    ),
    h1: AppTextStyles.headingMedium.copyWith(color: brand.textDark),
    h2: AppTextStyles.headingSmall.copyWith(color: brand.textDark),
    h3: AppTextStyles.labelLarge.copyWith(color: brand.textDark),
    listBullet:
        AppTextStyles.bodyMedium.copyWith(fontSize: 15, color: brand.textDark),
    blockquote: AppTextStyles.bodyMedium.copyWith(
      fontSize: 14,
      color: brand.textMuted,
      fontStyle: FontStyle.italic,
    ),
    blockquoteDecoration: BoxDecoration(
      color: brand.accent.withValues(alpha: 0.06),
      borderRadius: AppRadius.smBorder,
      border: Border(left: BorderSide(color: brand.accent, width: 3)),
    ),
    blockquotePadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md, vertical: AppSpacing.sm,
    ),
    code: AppTextStyles.monoSmall.copyWith(
      backgroundColor: brand.surfaceAlt,
      color: brand.textDark,
    ),
    codeblockDecoration: BoxDecoration(
      color: brand.surfaceAlt,
      borderRadius: AppRadius.smBorder,
    ),
    codeblockPadding: const EdgeInsets.all(AppSpacing.md),
    tableBorder: TableBorder.all(color: brand.border),
  );
}

// ---------------------------------------------------------------------------
// Typing dots — used inside an empty streaming AI bubble
// ---------------------------------------------------------------------------

class _TypingDots extends StatelessWidget {
  const _TypingDots();

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: EdgeInsets.only(right: i == 2 ? 0 : AppSpacing.xs),
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: brand.accent,
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
                curve: AppMotion.settle,
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
    final brand = context.brand;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg, vertical: AppSpacing.sm,
      ),
      color: brand.surface,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: AppRadius.mdBorder,
              child: _ImageThumb(path: path, size: 80),
            ),
            Positioned(
              top: -6,
              right: -6,
              child: Material(
                color: brand.textDark,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  onTap: onRemove,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.xs),
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

  Widget _err(BuildContext ctx, Object _, StackTrace? __) {
    final brand = ctx.brand;
    return Container(
      color: brand.border,
      alignment: Alignment.center,
      child: Icon(Icons.broken_image_outlined, color: brand.textMuted),
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

  // Diagram upload is a Premium feature (UC09) — null hides the control for
  // free students entirely.
  final VoidCallback? onAttach;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.canSend,
    required this.isSending,
    required this.onSend,
    this.onAttach,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Material(
      color: brand.surface,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm + 2,
            AppSpacing.md, AppSpacing.sm + 2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (onAttach != null)
                IconButton(
                  onPressed: onAttach,
                  splashRadius: 22,
                  tooltip: 'Attach a diagram (Premium)',
                  icon: Icon(Icons.image_outlined, color: brand.textMuted),
                ),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md + 2),
                  decoration: BoxDecoration(
                    color: brand.background,
                    borderRadius: AppRadius.pillBorder,
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    maxLines: 4,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      color: brand.textDark,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ask MentorBot anything...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: brand.textMuted,
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                      isCollapsed: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
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
    final brand = context.brand;
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: enabled ? brand.primary : brand.border,
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
    final brand = context.brand;
    return Material(
      color: brand.surface,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.lg,
          ),
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
                      color: brand.gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_rounded, size: 18, color: brand.gold,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily limit reached \u{1F512}',
                          style: AppTextStyles.headingSmall.copyWith(
                            color: brand.textDark, fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Upgrade to Premium for unlimited AI tutoring.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: brand.textMuted,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md + 2),
              Row(
                children: [
                  Expanded(
                    child: PillButton(
                      label: 'Remind Tomorrow',
                      variant: PillVariant.secondary,
                      dense: true,
                      onPressed: () => _remindTomorrowToast(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: PillButton(
                      label: 'Upgrade Now',
                      dense: true,
                      onPressed: () => onUpgrade(),
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

  void _remindTomorrowToast(BuildContext context) {
    final brand = context.brand;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "We'll remind you tomorrow.",
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: brand.textDark,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppSpacing.lg),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
        duration: const Duration(milliseconds: 1800),
      ),
    );
  }
}

String _fmtTime(DateTime ts) => DateFormat('h:mm a').format(ts);
