import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/core/theme/app_radius.dart';
import 'package:mentor_minds/core/theme/app_spacing.dart';
import 'package:mentor_minds/core/theme/brand_colors.dart';
import 'package:mentor_minds/data/services/firebase_providers.dart';
import 'package:mentor_minds/presentation/screens/dashboard/teacher_announcement_sheet.dart';

// ---------------------------------------------------------------------------
// TeacherInboxScreen
//
// Replaces the generic /notifications view when a teacher taps the Inbox tab.
// Surfaces only what's actually relevant to a teacher:
//   * "Sent" — announcements this teacher created (where createdBy == uid)
//   * "From admin" — notifications targeted at recipientRole 'teacher' or 'all'
//
// Avoids reusing the student notifications screen so the teacher experience
// stays role-isolated end-to-end — no perceived "redirect into the student
// flow" when they tap the bottom-nav Inbox.
// ---------------------------------------------------------------------------

class TeacherInboxScreen extends ConsumerStatefulWidget {
  const TeacherInboxScreen({super.key});

  @override
  ConsumerState<TeacherInboxScreen> createState() =>
      _TeacherInboxScreenState();
}

class _TeacherInboxScreenState extends ConsumerState<TeacherInboxScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final auth = ref.watch(firebaseAuthProvider);
    return Scaffold(
      backgroundColor: brand.background,
      body: SafeArea(
        child: StreamBuilder<User?>(
          stream: auth.userChanges(),
          initialData: auth.currentUser,
          builder: (context, authSnap) {
            final uid = authSnap.data?.uid;
            if (uid == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: [
                _InboxAppBar(),
                _TabRow(controller: _tabs),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _SentTab(teacherUid: uid),
                      const _AdminMessagesTab(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: _TeacherInboxBottomNav(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: brand.primary,
        onPressed: () => _openAnnouncementSheet(context),
        icon: const Icon(Icons.campaign_rounded, color: Colors.white),
        label: const Text(
          'New announcement',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _openAnnouncementSheet(BuildContext context) async {
    final brand = context.brand;
    final auth = ref.read(firebaseAuthProvider);
    final user = auth.currentUser;
    if (user == null) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: brand.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadius.xlRadius),
      ),
      builder: (_) => TeacherAnnouncementSheet(
        teacherUid: user.uid,
        teacherName: user.displayName ?? 'Teacher',
      ),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: brand.primary,
          content: const Text('Announcement sent to your students.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// _InboxAppBar — title + role-aware back button.
// ---------------------------------------------------------------------------

class _InboxAppBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs, AppSpacing.xs, AppSpacing.md, AppSpacing.xs,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: () async {
              if (context.canPop()) {
                context.pop();
                return;
              }
              final route = await resolveHomeRouteName(ref);
              if (context.mounted) context.goNamed(route);
            },
          ),
          Text(
            'Inbox',
            style: AppTextStyles.headingLarge.copyWith(
              color: brand.textDark, fontSize: 20,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TabRow — two pill tabs (Sent / From admin) styled to match the brand.
// ---------------------------------------------------------------------------

class _TabRow extends StatelessWidget {
  final TabController controller;
  const _TabRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg, vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: brand.border),
      ),
      child: TabBar(
        controller: controller,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: brand.primary,
          borderRadius: AppRadius.pillBorder,
        ),
        labelColor: Colors.white,
        unselectedLabelColor: brand.textMuted,
        labelStyle: AppTextStyles.labelLarge,
        dividerColor: Colors.transparent,
        padding: const EdgeInsets.all(4),
        tabs: const [
          Tab(text: 'Sent'),
          Tab(text: 'From admin'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SentTab — announcements this teacher has sent.
// ---------------------------------------------------------------------------

class _SentTab extends ConsumerWidget {
  final String teacherUid;
  const _SentTab({required this.teacherUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final fs = ref.watch(firestoreProvider);
    // No orderBy on the query — sorting client-side avoids needing a
    // composite index on (createdBy, createdAt).
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: fs
          .collection('notifications')
          .where('createdBy', isEqualTo: teacherUid)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _InboxError(message: snap.error.toString());
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = [...snap.data!.docs]..sort((a, b) {
            final ta = _ts(a.data());
            final tb = _ts(b.data());
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
          });
        if (docs.isEmpty) {
          return _InboxEmpty(
            icon: Icons.send_rounded,
            title: "You haven't sent any announcements yet",
            message:
                'Tap "New announcement" below to broadcast a note to your '
                'students.',
            tint: brand.primary,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, 96,
          ),
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: AppSpacing.sm + 2),
          itemBuilder: (_, i) {
            final d = docs[i].data();
            return _SentRow(data: d);
          },
        );
      },
    );
  }

  static DateTime? _ts(Map<String, dynamic> d) {
    final raw = d['timestamp'] ?? d['createdAt'];
    return raw is Timestamp ? raw.toDate() : null;
  }
}

class _SentRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SentRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final title = (data['title'] as String?) ?? 'Untitled';
    final body = (data['body'] as String?) ?? '';
    final ts = data['timestamp'] ?? data['createdAt'];
    final when = ts is Timestamp ? _timeAgo(ts.toDate()) : '';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: brand.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign_rounded,
                  color: brand.primary, size: 18),
              const SizedBox(width: AppSpacing.xs + 2),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: brand.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                when,
                style: AppTextStyles.bodySmall
                    .copyWith(color: brand.textMuted, fontSize: 11),
              ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs + 2),
            Text(
              body,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: brand.textMuted, height: 1.4),
            ),
          ],
          const SizedBox(height: AppSpacing.xs + 2),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: 2,
            ),
            decoration: BoxDecoration(
              color: brand.accent.withValues(alpha: 0.14),
              borderRadius: AppRadius.pillBorder,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.groups_outlined,
                    size: 12, color: brand.accent),
                const SizedBox(width: 3),
                Text(
                  'Sent to all students',
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
    );
  }

  String _timeAgo(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(ts);
  }
}

// ---------------------------------------------------------------------------
// _AdminMessagesTab — admin / all-role notifications.
// ---------------------------------------------------------------------------

class _AdminMessagesTab extends ConsumerWidget {
  const _AdminMessagesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final fs = ref.watch(firestoreProvider);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: fs
          .collection('notifications')
          .where('recipientRole', whereIn: ['teacher', 'all'])
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _InboxError(message: snap.error.toString());
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = [...snap.data!.docs]
          // Only show admin-authored / global notices in this tab — we
          // exclude teacher-authored announcements which already appear in
          // the Sent tab.
          ..removeWhere((d) =>
              (d.data()['source'] as String?) == 'teacher_announcement')
          ..sort((a, b) {
            final ta = _ts(a.data());
            final tb = _ts(b.data());
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
          });
        if (docs.isEmpty) {
          return _InboxEmpty(
            icon: Icons.mark_email_read_outlined,
            title: 'Inbox zero',
            message: 'No messages from admins or platform notices right now.',
            tint: brand.accent,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, 96,
          ),
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: AppSpacing.sm + 2),
          itemBuilder: (_, i) {
            final d = docs[i].data();
            return _AdminRow(data: d);
          },
        );
      },
    );
  }

  static DateTime? _ts(Map<String, dynamic> d) {
    final raw = d['timestamp'] ?? d['createdAt'];
    return raw is Timestamp ? raw.toDate() : null;
  }
}

class _AdminRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AdminRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final title = (data['title'] as String?) ?? 'Notification';
    final body = (data['body'] as String?) ??
        (data['message'] as String?) ??
        '';
    final type = (data['type'] as String?) ?? 'announcement';
    final ts = data['timestamp'] ?? data['createdAt'];
    final icon = switch (type) {
      'achievement' => Icons.emoji_events_rounded,
      'reminder' => Icons.notifications_active_rounded,
      'new_material' => Icons.menu_book_rounded,
      _ => Icons.campaign_rounded,
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: brand.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: brand.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: brand.primary, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: brand.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: brand.textMuted, height: 1.4,
                    ),
                  ),
                ],
                if (ts is Timestamp) ...[
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d · h:mm a').format(ts.toDate()),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: brand.textMuted, fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty + error helpers
// ---------------------------------------------------------------------------

class _InboxEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color tint;
  const _InboxEmpty({
    required this.icon,
    required this.title,
    required this.message,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: tint, size: 28),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
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
          ],
        ),
      ),
    );
  }
}

class _InboxError extends StatelessWidget {
  final String message;
  const _InboxError({required this.message});

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
              "Couldn't load inbox",
              style: AppTextStyles.headingSmall.copyWith(color: brand.textDark),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall
                  .copyWith(color: brand.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom nav (replica of teacher dashboard's so the tab stays selected).
// ---------------------------------------------------------------------------

class _TeacherInboxBottomNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: brand.surface,
        indicatorColor: brand.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTextStyles.labelSmall.copyWith(
            color: selected ? brand.primary : brand.textMuted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 11,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? brand.primary : brand.textMuted,
            size: 22,
          );
        }),
        height: 68,
      ),
      child: NavigationBar(
        selectedIndex: 2, // Inbox is active here
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.goNamed(AppRoutes.teacherDashboard);
            case 1:
              context.goNamed(AppRoutes.materials);
            case 2:
              break; // already inbox
            case 3:
              context.goNamed(AppRoutes.teacherProfile);
          }
        },
        surfaceTintColor: brand.surface,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: 'Inbox',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
