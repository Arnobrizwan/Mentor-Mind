import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:mentor_minds/application/viewmodels/auth/auth_viewmodel.dart';
import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/core/theme/app_radius.dart';
import 'package:mentor_minds/core/theme/app_spacing.dart';
import 'package:mentor_minds/core/theme/brand_colors.dart';
import 'package:mentor_minds/data/models/material_item.dart';
import 'package:mentor_minds/data/models/profile_user.dart';
import 'package:mentor_minds/data/repositories/materials_repository.dart';
import 'package:mentor_minds/data/repositories/users_repository.dart';
import 'package:mentor_minds/data/services/firebase_providers.dart';
import 'package:mentor_minds/presentation/screens/dashboard/teacher_upload_sheet.dart';
import 'package:mentor_minds/shared/widgets/empty_state.dart';
import 'package:mentor_minds/shared/widgets/section_header.dart';

// ---------------------------------------------------------------------------
// Teacher Dashboard
//
// Lands here from /dashboard/teacher (router) when an authenticated user has
// role == 'teacher' (auth_viewmodel.dart:448 + splash_viewmodel.dart:86).
//
// Why this screen exists separately from the student dashboard:
//   * Different KPIs: teachers care about library reach in their subjects and
//     their own uploads, not their streak/points.
//   * Approval gate: an unapproved teacher (`isApproved: false`) can't write
//     materials — we surface that pending state up top instead of letting them
//     hit a silent Firestore rules rejection.
//   * Capability set: a teacher's primary verbs are "upload" and "browse my
//     subjects". Students get tutor + materials + rewards + search.
// ---------------------------------------------------------------------------

class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final auth = ref.watch(firebaseAuthProvider);
    final uid = auth.currentUser?.uid;

    if (uid == null) {
      // Auth state torn down mid-frame — splash will redirect on next pump.
      return Scaffold(
        backgroundColor: brand.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: brand.background,
      body: StreamBuilder<ProfileUser>(
        stream:
            ref.watch(usersRepositoryProvider).watchProfileUser(uid),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _TeacherBody(user: snap.data!);
        },
      ),
    );
  }
}

class _TeacherBody extends ConsumerWidget {
  final ProfileUser user;
  const _TeacherBody({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final firstName =
        user.name.split(' ').first.isEmpty ? 'Teacher' : user.name.split(' ').first;
    final isApproved = user.isApproved;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: brand.background,
          surfaceTintColor: Colors.transparent,
          foregroundColor: brand.textDark,
          elevation: 0,
          title: Text(
            'Teacher Dashboard',
            style: AppTextStyles.headingMedium.copyWith(color: brand.primary),
          ),
          actions: [
            IconButton(
              tooltip: 'Profile',
              onPressed: () => context.goNamed(AppRoutes.profile),
              icon: Icon(Icons.person_outline_rounded, color: brand.primary),
            ),
            IconButton(
              tooltip: 'Sign out',
              onPressed: () => _confirmSignOut(context, ref),
              icon: Icon(Icons.logout_rounded, color: brand.primary),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl,
          ),
          sliver: SliverList.list(
            children: [
              _Greeting(name: firstName, subjects: user.subjects),
              const SizedBox(height: AppSpacing.md),
              _ApprovalBanner(isApproved: isApproved),
              const SizedBox(height: AppSpacing.lg),
              _KpiRow(uid: user.uid, subjects: user.subjects),
              const SizedBox(height: AppSpacing.xl),
              _QuickActionsRow(user: user),
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(
                title: 'Materials in your subjects',
                actionLabel: 'View all',
                onAction: () => context.goNamed(AppRoutes.materials),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: AppSpacing.md),
              _MaterialsInSubjects(subjects: user.subjects),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader(
                title: 'My recent uploads',
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: AppSpacing.md),
              _MyUploads(uid: user.uid),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final brand = context.brand;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          "You'll need to sign back in to access your dashboard.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: brand.primary),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(authViewModelProvider.notifier).signOut();
    if (!context.mounted) return;
    context.goNamed(AppRoutes.login);
  }
}

// ---------------------------------------------------------------------------
// _Greeting — name + role/subjects header.
// ---------------------------------------------------------------------------

class _Greeting extends StatelessWidget {
  final String name;
  final List<String> subjects;
  const _Greeting({required this.name, required this.subjects});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md + 2, AppSpacing.lg, AppSpacing.md + 2,
      ),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: AppRadius.lgBorder,
        boxShadow: [
          BoxShadow(
            color: brand.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, $name \u{1F468}\u{200D}\u{1F3EB}',
            style: AppTextStyles.headingMedium.copyWith(
              color: brand.textDark,
              height: 1.2,
            ),
          ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subjects.isEmpty
                ? 'No subjects selected yet.'
                : subjects.join(' · '),
            style: AppTextStyles.bodyMedium.copyWith(color: brand.textMuted),
          ).animate().fadeIn(delay: 100.ms, duration: 350.ms),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ApprovalBanner — only renders if /users/{uid}.isApproved is false.
// Tells the teacher their account is still being reviewed by an admin and
// what they can / cannot do until then.
// ---------------------------------------------------------------------------

class _ApprovalBanner extends StatelessWidget {
  final bool isApproved;
  const _ApprovalBanner({required this.isApproved});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    if (isApproved) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: brand.gold.withValues(alpha: 0.12),
        borderRadius: AppRadius.lgBorder,
        border:
            Border.all(color: brand.gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hourglass_top_rounded, color: brand.gold),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Approval pending',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: brand.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "An admin is reviewing your account. You can browse the "
                  "library, but uploading materials is blocked until you're "
                  "approved.",
                  style: AppTextStyles.bodySmall.copyWith(
                    color: brand.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 350.ms);
  }
}

// ---------------------------------------------------------------------------
// _KpiRow — three quick stats: subjects taught, materials in your subjects,
// your own uploads. Live numbers via streams; falls back to '—' while loading.
// ---------------------------------------------------------------------------

class _KpiRow extends ConsumerWidget {
  final String uid;
  final List<String> subjects;
  const _KpiRow({required this.uid, required this.subjects});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            icon: Icons.menu_book_rounded,
            label: 'Subjects',
            value: '${subjects.length}',
            tint: AppColors.kPrimary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _SubjectMaterialsKpiCard(subjects: subjects),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _UploadsKpiCard(uid: uid),
        ),
      ],
    );
  }
}

class _SubjectMaterialsKpiCard extends ConsumerWidget {
  final List<String> subjects;
  const _SubjectMaterialsKpiCard({required this.subjects});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.watch(firestoreProvider);
    final stream = subjects.isEmpty
        ? Stream<int>.value(0)
        : fs
            .collection('materials')
            .where('subject', whereIn: subjects.take(10).toList())
            .snapshots()
            .map((s) => s.size);
    return StreamBuilder<int>(
      stream: stream,
      builder: (_, snap) => _KpiCard(
        icon: Icons.collections_bookmark_rounded,
        label: 'In subjects',
        value: snap.hasData ? '${snap.data}' : '—',
        tint: AppColors.kAccent,
      ),
    );
  }
}

class _UploadsKpiCard extends ConsumerWidget {
  final String uid;
  const _UploadsKpiCard({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.watch(firestoreProvider);
    return StreamBuilder<int>(
      stream: fs
          .collection('materials')
          .where('uploadedBy', isEqualTo: uid)
          .snapshots()
          .map((s) => s.size),
      builder: (_, snap) => _KpiCard(
        icon: Icons.upload_file_rounded,
        label: 'My uploads',
        value: snap.hasData ? '${snap.data}' : '—',
        tint: AppColors.kGold,
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2, vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: tint.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tint, size: 22),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            value,
            style: AppTextStyles.displayMedium.copyWith(
              color: brand.textDark,
              fontSize: 20,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: brand.textMuted),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 350.ms)
        .slideY(begin: 0.15, end: 0);
  }
}

// ---------------------------------------------------------------------------
// _QuickActionsRow — Upload Material / Library / Profile.
// "Send Announcement" intentionally omitted — firestore rules currently block
// teacher-created notifications (admin-only). See firestore.rules:171.
// ---------------------------------------------------------------------------

class _QuickActionsRow extends ConsumerWidget {
  final ProfileUser user;
  const _QuickActionsRow({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            emoji: '\u{1F4C4}',
            label: 'Upload\nmaterial',
            tint: AppColors.kPrimary,
            onTap: () => _openUploadSheet(context, ref, user),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _ActionTile(
            emoji: '\u{1F4DA}',
            label: 'Browse\nlibrary',
            tint: AppColors.kAccent,
            onTap: () => context.goNamed(AppRoutes.materials),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _ActionTile(
            emoji: '\u{1F464}',
            label: 'My\nprofile',
            tint: AppColors.kGold,
            onTap: () => context.goNamed(AppRoutes.profile),
          ),
        ),
      ],
    );
  }

  Future<void> _openUploadSheet(
    BuildContext context,
    WidgetRef ref,
    ProfileUser u,
  ) async {
    final brand = context.brand;
    if (!u.isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: brand.gold,
          content: const Text('Uploading is blocked until your account is approved.'),
        ),
      );
      return;
    }
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: brand.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadius.xlRadius),
      ),
      builder: (_) => TeacherUploadSheet(user: u),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: brand.primary,
          content: const Text('Material published.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

class _ActionTile extends StatefulWidget {
  final String emoji;
  final String label;
  final Color tint;
  final VoidCallback onTap;
  const _ActionTile({
    required this.emoji,
    required this.label,
    required this.tint,
    required this.onTap,
  });

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dark = HSLColor.fromColor(widget.tint);
    final darker =
        dark.withLightness((dark.lightness - 0.18).clamp(0.0, 1.0)).toColor();
    return AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.lgBorder,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          borderRadius: AppRadius.lgBorder,
          child: Container(
            height: 96,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.lgBorder,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [widget.tint, darker],
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.tint.withValues(alpha: 0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(widget.emoji,
                    style: const TextStyle(fontSize: 26, height: 1)),
                const SizedBox(height: AppSpacing.xs + 2),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MaterialsInSubjects — horizontal carousel of materials in the teacher's
// subjects (what their students see). Empty state if subjects[] is empty.
// ---------------------------------------------------------------------------

class _MaterialsInSubjects extends ConsumerWidget {
  final List<String> subjects;
  const _MaterialsInSubjects({required this.subjects});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (subjects.isEmpty) {
      return const EmptyState(
        title: 'No subjects yet',
        message: 'Add subjects to your profile to see materials here.',
        icon: Icons.menu_book_outlined,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.lg,
        ),
      );
    }
    return StreamBuilder<List<MaterialItem>>(
      stream: ref
          .watch(materialsRepositoryProvider)
          .streamDashboardMaterialsBySubjects(subjects, limit: 8),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final items = snap.data!;
        if (items.isEmpty) {
          return const EmptyState(
            title: 'Nothing published yet',
            message: 'Be the first to publish material for these subjects.',
            icon: Icons.auto_stories_outlined,
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.lg,
            ),
          );
        }
        return SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppSpacing.md),
            itemBuilder: (_, i) => _TeacherMaterialCard(item: items[i]),
          ),
        );
      },
    );
  }
}

class _TeacherMaterialCard extends StatelessWidget {
  final MaterialItem item;
  const _TeacherMaterialCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.lgBorder,
        child: InkWell(
          onTap: () => context.goNamed(AppRoutes.materials),
          borderRadius: AppRadius.lgBorder,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: AppRadius.lgBorder,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: item.gradient,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: AppRadius.pillBorder,
                      ),
                      child: Text(
                        item.level,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.auto_stories_rounded,
                        size: 16, color: Colors.white),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subject,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MyUploads — list of materials this teacher uploaded (where uploadedBy
// matches their uid). Empty state with an upload CTA when blank.
// ---------------------------------------------------------------------------

class _MyUploads extends ConsumerWidget {
  final String uid;
  const _MyUploads({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.watch(firestoreProvider);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: fs
          .collection('materials')
          .where('uploadedBy', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const EmptyState(
            title: 'No uploads yet',
            message:
                'Tap "Upload material" above to publish your first resource.',
            icon: Icons.upload_file_outlined,
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.lg,
            ),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < docs.length; i++) ...[
              _UploadRow(doc: docs[i]),
              if (i != docs.length - 1)
                const SizedBox(height: AppSpacing.sm + 2),
            ],
          ],
        );
      },
    );
  }
}

class _UploadRow extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _UploadRow({required this.doc});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final data = doc.data();
    final title = (data['title'] as String?) ?? 'Untitled';
    final subject = (data['subject'] as String?) ?? '—';
    final level = (data['level'] as String?) ?? '';
    final views = (data['views'] as num?)?.toInt() ?? 0;
    return Material(
      color: brand.surface,
      borderRadius: AppRadius.lgBorder,
      child: InkWell(
        onTap: () => context.goNamed(AppRoutes.materials),
        borderRadius: AppRadius.lgBorder,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md + 2, vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: brand.primary.withValues(alpha: 0.10),
                  borderRadius: AppRadius.smBorder,
                ),
                child:
                    Icon(Icons.description_rounded, color: brand.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: brand.textDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      level.isEmpty ? subject : '$subject · $level',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: brand.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: brand.accent.withValues(alpha: 0.14),
                  borderRadius: AppRadius.pillBorder,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility_outlined,
                        size: 12, color: brand.accent),
                    const SizedBox(width: 3),
                    Text(
                      '$views',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: brand.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
