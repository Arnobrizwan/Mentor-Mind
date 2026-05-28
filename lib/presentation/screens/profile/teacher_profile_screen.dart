import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:mentor_minds/application/viewmodels/auth/auth_viewmodel.dart';
import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/core/theme/app_radius.dart';
import 'package:mentor_minds/core/theme/app_spacing.dart';
import 'package:mentor_minds/core/theme/brand_colors.dart';
import 'package:mentor_minds/data/models/profile_user.dart';
import 'package:mentor_minds/data/repositories/users_repository.dart';
import 'package:mentor_minds/data/services/firebase_providers.dart';

// ---------------------------------------------------------------------------
// TeacherProfileScreen
//
// Mirror of /profile but role-scoped to teachers:
//   * No points / level / streak / premium / badges sections.
//   * Shows approval status, subjects taught, upload statistics instead.
//   * Back navigation always returns to /dashboard/teacher (never the student
//     dashboard, which would be wrong for this role).
//   * Sign-out routes to /auth/login the same way the student profile does.
// ---------------------------------------------------------------------------

class TeacherProfileScreen extends ConsumerStatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  ConsumerState<TeacherProfileScreen> createState() =>
      _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends ConsumerState<TeacherProfileScreen> {
  // See teacher_dashboard_screen.dart for the rationale — Firestore does not
  // auto-retry PERMISSION_DENIED, so we re-key the inner listener on retry.
  int _retryKey = 0;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final auth = ref.watch(firebaseAuthProvider);

    return Scaffold(
      backgroundColor: brand.background,
      body: StreamBuilder<User?>(
        stream: auth.userChanges(),
        initialData: auth.currentUser,
        builder: (context, authSnap) {
          final uid = authSnap.data?.uid;
          if (uid == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<ProfileUser>(
            key: ValueKey('teacher_profile_view_${uid}_$_retryKey'),
            stream: ref
                .read(usersRepositoryProvider)
                .watchProfileUser(uid),
            builder: (context, snap) {
              if (snap.hasError) {
                return _ProfileLoadError(
                  message: snap.error.toString(),
                  onRetry: () => setState(() => _retryKey++),
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _TeacherProfileBody(user: snap.data!);
            },
          );
        },
      ),
    );
  }
}

class _ProfileLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ProfileLoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: brand.error, size: 36),
            const SizedBox(height: AppSpacing.md),
            Text(
              "Couldn't load profile",
              style: AppTextStyles.headingSmall
                  .copyWith(color: brand.textDark),
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall
                  .copyWith(color: brand.textMuted, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: brand.primary),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherProfileBody extends ConsumerWidget {
  final ProfileUser user;
  const _TeacherProfileBody({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: brand.background,
          surfaceTintColor: Colors.transparent,
          foregroundColor: brand.textDark,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back to dashboard',
            onPressed: () => _backToDashboard(context),
          ),
          title: Text(
            'My Profile',
            style: AppTextStyles.headingMedium.copyWith(color: brand.primary),
          ),
          actions: [
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
            AppSpacing.lg, AppSpacing.sm,
            AppSpacing.lg, AppSpacing.xxl,
          ),
          sliver: SliverList.list(
            children: [
              _IdentityCard(user: user),
              const SizedBox(height: AppSpacing.lg),
              _ApprovalChip(isApproved: user.isApproved),
              const SizedBox(height: AppSpacing.lg),
              _SubjectsSection(subjects: user.subjects),
              const SizedBox(height: AppSpacing.lg),
              _StatsRow(uid: user.uid),
              const SizedBox(height: AppSpacing.lg),
              _SupportLinks(),
              const SizedBox(height: AppSpacing.lg),
              _SignOutButton(onTap: () => _confirmSignOut(context, ref)),
            ],
          ),
        ),
      ],
    );
  }

  void _backToDashboard(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoutes.teacherDashboard);
    }
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
// _IdentityCard — avatar + name + email + role pill.
// ---------------------------------------------------------------------------

class _IdentityCard extends StatelessWidget {
  final ProfileUser user;
  const _IdentityCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: AppRadius.lgBorder,
        boxShadow: [
          BoxShadow(
            color: brand.primary.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72, height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [brand.primary, AppColors.kSplashBottom],
              ),
            ),
            child: Text(
              user.initials,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: AppTextStyles.headingMedium.copyWith(
                    color: brand.textDark,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style:
                      AppTextStyles.bodySmall.copyWith(color: brand.textMuted),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs + 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: brand.primary.withValues(alpha: 0.14),
                    borderRadius: AppRadius.pillBorder,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school_rounded,
                          color: brand.primary, size: 12),
                      const SizedBox(width: 3),
                      Text(
                        'Teacher',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: brand.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ApprovalChip — gold "pending" or accent "approved" badge.
// ---------------------------------------------------------------------------

class _ApprovalChip extends StatelessWidget {
  final bool isApproved;
  const _ApprovalChip({required this.isApproved});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final color = isApproved ? brand.accent : brand.gold;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: color.withValues(alpha: 0.40)),
      ),
      child: Row(
        children: [
          Icon(
            isApproved
                ? Icons.verified_rounded
                : Icons.hourglass_top_rounded,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isApproved ? 'Approved teacher' : 'Approval pending',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: brand.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isApproved
                      ? "You can publish materials and send announcements."
                      : "An admin is reviewing your account. You'll get "
                          "publish + announcement access once approved.",
                  style: AppTextStyles.bodySmall
                      .copyWith(color: brand.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SubjectsSection — chip row of subjects the teacher is registered for.
// ---------------------------------------------------------------------------

class _SubjectsSection extends StatelessWidget {
  final List<String> subjects;
  const _SubjectsSection({required this.subjects});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: brand.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subjects you teach',
            style: AppTextStyles.labelLarge.copyWith(
              color: brand.textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (subjects.isEmpty)
            Text(
              'No subjects added yet. Edit your profile to add them.',
              style: AppTextStyles.bodySmall.copyWith(color: brand.textMuted),
            )
          else
            Wrap(
              spacing: AppSpacing.xs + 2,
              runSpacing: AppSpacing.xs + 2,
              children: [
                for (final s in subjects)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + 2, vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: brand.primary.withValues(alpha: 0.10),
                      borderRadius: AppRadius.pillBorder,
                    ),
                    child: Text(
                      s,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: brand.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _StatsRow — live counts: # uploads, total views across uploads.
// ---------------------------------------------------------------------------

class _StatsRow extends ConsumerWidget {
  final String uid;
  const _StatsRow({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.watch(firestoreProvider);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: fs
          .collection('materials')
          .where('uploadedBy', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        final uploads = docs.length;
        final views = docs.fold<int>(
          0,
          (acc, d) => acc + ((d.data()['views'] as num?)?.toInt() ?? 0),
        );
        return Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.upload_file_rounded,
                label: 'Uploads',
                value: '$uploads',
                tint: AppColors.kPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatTile(
                icon: Icons.visibility_outlined,
                label: 'Total views',
                value: '$views',
                tint: AppColors.kAccent,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: tint.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, color: tint, size: 22),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTextStyles.headingMedium
                      .copyWith(color: brand.textDark, fontSize: 20),
                ),
                Text(
                  label,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: brand.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SupportLinks — help email, privacy policy, terms.
// ---------------------------------------------------------------------------

class _SupportLinks extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    return Container(
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: brand.border),
      ),
      child: Column(
        children: [
          _SupportRow(
            icon: Icons.help_outline_rounded,
            label: 'Help & FAQ',
            onTap: () => context.goNamed(AppRoutes.helpFaq),
          ),
          Divider(height: 1, color: brand.border),
          _SupportRow(
            icon: Icons.shield_outlined,
            label: 'Privacy policy',
            onTap: () => context.goNamed(AppRoutes.privacy),
          ),
          Divider(height: 1, color: brand.border),
          _SupportRow(
            icon: Icons.description_outlined,
            label: 'Terms of service',
            onTap: () => context.goNamed(AppRoutes.terms),
          ),
        ],
      ),
    );
  }
}

class _SupportRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SupportRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md + 2, vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(icon, color: brand.primary, size: 20),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: brand.textDark),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: brand.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SignOutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(Icons.logout_rounded, color: brand.error),
        label: Text(
          'Sign out',
          style: TextStyle(color: brand.error, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md + 2),
          side: BorderSide(color: brand.error.withValues(alpha: 0.40)),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.mdBorder,
          ),
        ),
      ),
    );
  }
}

