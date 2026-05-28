import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/theme/app_radius.dart';
import 'package:mentor_minds/core/theme/app_spacing.dart';
import 'package:mentor_minds/core/theme/brand_colors.dart';
import 'package:mentor_minds/data/services/firebase_providers.dart';

// ---------------------------------------------------------------------------
// TeacherAnnouncementSheet
//
// Lets an approved teacher post a student-targeted announcement to
// /notifications. Firestore rules (firestore.rules:169) accept this when:
//   * isApprovedTeacher() == true
//   * source == 'teacher_announcement'
//   * createdBy == auth.uid
//   * recipientRole == 'student'
//   * type == 'announcement'
//   * read == false
//
// We DON'T target a specific student or subject yet — the rules only allow
// the broadcast role-target. Could be tightened in a future iteration to
// "students enrolled in any of my subjects" via a Cloud Function.
// ---------------------------------------------------------------------------

class TeacherAnnouncementSheet extends ConsumerStatefulWidget {
  final String teacherUid;
  final String teacherName;
  const TeacherAnnouncementSheet({
    super.key,
    required this.teacherUid,
    required this.teacherName,
  });

  @override
  ConsumerState<TeacherAnnouncementSheet> createState() =>
      _TeacherAnnouncementSheetState();
}

class _TeacherAnnouncementSheetState
    extends ConsumerState<TeacherAnnouncementSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    if (body.isEmpty) {
      setState(() => _error = 'Body is required.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final fs = ref.read(firestoreProvider);
      final docId =
          'tann_${widget.teacherUid.substring(0, 6).padRight(6, '_')}_${DateTime.now().millisecondsSinceEpoch}';
      await fs.collection('notifications').doc(docId).set({
        'title': title,
        'body': body,
        'type': 'announcement',
        'recipientRole': 'student',
        'source': 'teacher_announcement',
        'createdBy': widget.teacherUid,
        'createdByName': widget.teacherName,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.code == 'permission-denied'
            ? "You're not authorized to send announcements yet. Your "
                "teacher account may still be awaiting admin approval."
            : 'Send failed: ${e.message ?? e.code}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Send failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final insets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: brand.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Send announcement',
                style: AppTextStyles.headingMedium
                    .copyWith(color: brand.textDark),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Goes out to every student on MentorMinds. Use it for class '
                'reminders, schedule changes, or new resources you\'ve just '
                'published.',
                style:
                    AppTextStyles.bodySmall.copyWith(color: brand.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. New worksheet uploaded',
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLength: 60,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _bodyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Body',
                  hintText: 'Add a short note for your students.',
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLength: 220,
                maxLines: 3,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm + 2),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm + 2),
                  decoration: BoxDecoration(
                    color: brand.error.withValues(alpha: 0.10),
                    borderRadius: AppRadius.smBorder,
                    border:
                        Border.all(color: brand.error.withValues(alpha: 0.40)),
                  ),
                  child: Text(
                    _error!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: brand.error, height: 1.4),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _sending ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: brand.primary,
                      ),
                      onPressed: _sending ? null : _submit,
                      child: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white,
                              ),
                            )
                          : const Text('Send to students'),
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
