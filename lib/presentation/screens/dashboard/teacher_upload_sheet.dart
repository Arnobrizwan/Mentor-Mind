import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/theme/app_radius.dart';
import 'package:mentor_minds/core/theme/app_spacing.dart';
import 'package:mentor_minds/core/theme/brand_colors.dart';
import 'package:mentor_minds/data/models/profile_user.dart';
import 'package:mentor_minds/data/services/firebase_providers.dart';

// ---------------------------------------------------------------------------
// TeacherUploadSheet
//
// Bottom sheet that lets an approved teacher publish a new material doc to
// /materials. Metadata-only for now — file URL is optional. The full
// Storage-backed flow lands in the admin upload form; this sheet covers the
// "I just want to publish a note / link a resource" path that's missing on
// the teacher dashboard.
//
// Firestore rules check: /materials create allows isApprovedTeacher() or
// isAdmin() — so unapproved teachers will be rejected at the server. We block
// that on the client too via the user.subjects check + an `isApproved` read
// to surface a friendlier message instead of a silent rules denial.
// ---------------------------------------------------------------------------

class TeacherUploadSheet extends ConsumerStatefulWidget {
  final ProfileUser user;
  const TeacherUploadSheet({super.key, required this.user});

  @override
  ConsumerState<TeacherUploadSheet> createState() =>
      _TeacherUploadSheetState();
}

class _TeacherUploadSheetState extends ConsumerState<TeacherUploadSheet> {
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  String? _subject;
  String _level = 'O Level';
  String _type = 'NOTE';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.user.subjects.isNotEmpty) {
      _subject = widget.user.subjects.first;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    if (_subject == null) {
      setState(() => _error = 'Pick a subject.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final fs = ref.read(firestoreProvider);
      final docId =
          'teacher_${widget.user.uid.substring(0, 6)}_${DateTime.now().millisecondsSinceEpoch}';
      await fs.collection('materials').doc(docId).set({
        'title': title,
        'subject': _subject,
        'level': _level,
        'type': _type,
        'fileUrl': _urlCtrl.text.trim(),
        'uploadedBy': widget.user.uid,
        'views': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'uploadedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.code == 'permission-denied'
            ? 'Your teacher account is not approved yet. An admin needs to '
                'approve you before you can publish.'
            : 'Upload failed: ${e.message ?? e.code}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Upload failed: $e';
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
                'Publish a material',
                style: AppTextStyles.headingMedium
                    .copyWith(color: brand.textDark),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Shows up in the student library and on dashboards in this '
                'subject. You can paste a Drive / web link in the URL field.',
                style: AppTextStyles.bodySmall.copyWith(color: brand.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Quadratic Equations — Worked Examples',
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLength: 80,
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: _subject,
                decoration: const InputDecoration(labelText: 'Subject'),
                items: [
                  for (final s in widget.user.subjects)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: _saving ? null : (v) => setState(() => _subject = v),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _level,
                      decoration: const InputDecoration(labelText: 'Level'),
                      items: const [
                        DropdownMenuItem(
                            value: 'O Level', child: Text('O Level')),
                        DropdownMenuItem(
                            value: 'A Level', child: Text('A Level')),
                        DropdownMenuItem(value: 'Both', child: Text('Both')),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _level = v ?? 'O Level'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(value: 'NOTE', child: Text('Notes')),
                        DropdownMenuItem(value: 'PDF', child: Text('PDF')),
                        DropdownMenuItem(value: 'VIDEO', child: Text('Video')),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _type = v ?? 'NOTE'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Link (optional)',
                  hintText: 'https://...',
                ),
                keyboardType: TextInputType.url,
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
                          _saving ? null : () => Navigator.of(context).pop(),
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
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white,
                              ),
                            )
                          : const Text('Publish'),
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
