import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:mentor_minds/application/viewmodels/admin/admin_viewmodel.dart';
import 'package:mentor_minds/application/viewmodels/config/remote_config_providers.dart';
import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/core/theme/app_radius.dart';
import 'package:mentor_minds/core/theme/app_spacing.dart';
import 'package:mentor_minds/core/theme/brand_colors.dart';
import 'package:mentor_minds/data/services/firebase_providers.dart';
import 'package:mentor_minds/presentation/screens/dashboard/teacher_upload_sheet.dart';
import 'package:mentor_minds/shared/widgets/pill_button.dart';

// ---------------------------------------------------------------------------
// AdminScreen — 6 tabs (Dashboard / Users / Content / Notifications /
// Analytics / Config). Phase-5 of the redesign brings it onto the design
// system so admins flipping into dark mode don't see legacy white surfaces.
// ---------------------------------------------------------------------------

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  int _tabIndex = 0;
  bool _redirected = false;

  final _broadcastTitle = TextEditingController();
  final _broadcastBody = TextEditingController();
  String _broadcastRole = 'student';

  @override
  void dispose() {
    _broadcastTitle.dispose();
    _broadcastBody.dispose();
    super.dispose();
  }

  void _maybeRedirect(AdminState admin) {
    if (_redirected || admin.isLoading) return;
    if (!admin.isAuthorized) {
      _redirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not authorized')),
        );
        // Send the user to THEIR role-appropriate home, not always the
        // student dashboard. A teacher who accidentally hits /admin should
        // bounce back to /dashboard/teacher, not /dashboard.
        final route = await resolveHomeRouteName(ref);
        if (!mounted) return;
        context.goNamed(route);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(adminViewModelProvider);
    _maybeRedirect(admin);

    if (admin.isLoading || !admin.isAuthorized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final body = _tabBody(admin, wide);

        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _tabIndex,
                  onDestinationSelected: (i) => setState(() => _tabIndex = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: Text('Dashboard'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.people_outline),
                      selectedIcon: Icon(Icons.people),
                      label: Text('Users'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.folder_outlined),
                      selectedIcon: Icon(Icons.folder),
                      label: Text('Content'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.campaign_outlined),
                      selectedIcon: Icon(Icons.campaign),
                      label: Text('Notifications'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.insights_outlined),
                      selectedIcon: Icon(Icons.insights),
                      label: Text('Analytics'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.tune_outlined),
                      selectedIcon: Icon(Icons.tune),
                      label: Text('Config'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (i) => setState(() => _tabIndex = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline),
                label: 'Users',
              ),
              NavigationDestination(
                icon: Icon(Icons.folder_outlined),
                label: 'Content',
              ),
              NavigationDestination(
                icon: Icon(Icons.campaign_outlined),
                label: 'Notifications',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                label: 'Analytics',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune_outlined),
                label: 'Config',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tabBody(AdminState admin, bool wide) {
    final brand = context.brand;
    final child = switch (_tabIndex) {
      0 => _DashboardTab(
          totalUsers: admin.totalUsersCount ?? admin.users.length,
          premium: admin.premiumUsersCount,
          materials: admin.materialsCount,
          pendingApprovals: admin.pendingTeachers.length,
        ),
      1 => _UsersTab(
          users: admin.users,
          pendingTeachers: admin.pendingTeachers,
          hasMore: admin.hasMoreUsers,
          onLoadMore: () =>
              ref.read(adminViewModelProvider.notifier).loadUsers(),
          onTogglePremium: (row) =>
              ref.read(adminViewModelProvider.notifier).togglePremium(row),
          onApproveTeacher: (row) =>
              ref.read(adminViewModelProvider.notifier).approveTeacher(row),
        ),
      2 => _ContentTab(adminUid: ref.read(firebaseAuthProvider).currentUser?.uid ?? ''),
      3 => _NotificationsTab(
          titleController: _broadcastTitle,
          bodyController: _broadcastBody,
          role: _broadcastRole,
          onRoleChanged: (r) => setState(() => _broadcastRole = r),
          onSend: () async {
            final title = _broadcastTitle.text.trim();
            final body = _broadcastBody.text.trim();
            if (title.isEmpty || body.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Title and body required')),
              );
              return;
            }
            await ref.read(adminViewModelProvider.notifier).sendBroadcast(
                  title: title,
                  body: body,
                  recipientRole: _broadcastRole,
                );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Broadcast queued')),
            );
            _broadcastTitle.clear();
            _broadcastBody.clear();
          },
        ),
      4 => const _AnalyticsTab(),
      5 => const _ConfigTab(),
      _ => const SizedBox.shrink(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            wide ? AppSpacing.xl : AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Text(
                'Admin Panel',
                style: AppTextStyles.headingLarge.copyWith(
                  color: brand.textDark,
                ),
              ),
              const Spacer(),
              if (admin.error != null)
                Flexible(
                  child: Text(
                    admin.error!,
                    style: AppTextStyles.bodySmall.copyWith(color: brand.error),
                    textAlign: TextAlign.end,
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard tab — KPI cards (placeholders until analytics fills in)
// ---------------------------------------------------------------------------

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({
    required this.totalUsers,
    required this.premium,
    required this.materials,
    required this.pendingApprovals,
  });

  final int totalUsers;
  final int? premium;
  final int? materials;
  final int pendingApprovals;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _KpiCard(label: 'Total users', value: '$totalUsers'),
            _KpiCard(
              label: 'Premium',
              value: premium != null ? '$premium' : '—',
            ),
            _KpiCard(
              label: 'Materials',
              value: materials != null ? '$materials' : '—',
            ),
            _KpiCard(
              label: 'Pending approvals',
              value: '$pendingApprovals',
              tint: pendingApprovals > 0 ? brand.gold : null,
            ),
          ],
        ),
        if (pendingApprovals > 0) ...[
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: brand.gold.withValues(alpha: 0.10),
              borderRadius: AppRadius.lgBorder,
              border: Border.all(color: brand.gold.withValues(alpha: 0.40)),
            ),
            child: Row(
              children: [
                Icon(Icons.hourglass_top_rounded, color: brand.gold),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Text(
                    '$pendingApprovals teacher${pendingApprovals == 1 ? '' : 's'} '
                    'waiting for approval. Open the Users tab to review.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: brand.textDark),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Recent activity',
          style: AppTextStyles.headingSmall.copyWith(color: brand.textDark),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Full activity feed ships with Analytics in a later pass.',
          style: AppTextStyles.bodyMedium.copyWith(color: brand.textMuted),
        ),
      ],
    );
  }
}

/// Lightweight KPI tile used on the admin dashboard. Distinct from the
/// shared StatCard (which takes an icon + tint) — this is label-on-top
/// + big number, no icon.
class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    this.tint,
  });

  final String label;
  final String value;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final effectiveTint = tint ?? brand.border;
    return Container(
      width: 160,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: AppRadius.mdBorder,
        border: Border.all(
          color: tint != null ? effectiveTint : brand.border,
          width: tint != null ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: tint ?? brand.textMuted,
              fontWeight:
                  tint != null ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            value,
            style: AppTextStyles.headingMedium.copyWith(
              color: tint ?? brand.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Users tab
// ---------------------------------------------------------------------------

class _UsersTab extends StatelessWidget {
  const _UsersTab({
    required this.users,
    required this.pendingTeachers,
    required this.hasMore,
    required this.onLoadMore,
    required this.onTogglePremium,
    required this.onApproveTeacher,
  });

  final List<AdminUserRow> users;
  final List<AdminUserRow> pendingTeachers;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final void Function(AdminUserRow row) onTogglePremium;
  final void Function(AdminUserRow row) onApproveTeacher;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    if (users.isEmpty && pendingTeachers.isEmpty) {
      return Center(
        child: Text(
          'No users loaded',
          style: AppTextStyles.bodyMedium.copyWith(color: brand.textMuted),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        if (pendingTeachers.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.hourglass_top_rounded, color: brand.gold),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                'Pending teacher approvals',
                style: AppTextStyles.headingSmall.copyWith(
                  color: brand.textDark,
                ),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs + 2, vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: brand.gold.withValues(alpha: 0.18),
                  borderRadius: AppRadius.pillBorder,
                ),
                child: Text(
                  '${pendingTeachers.length}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: brand.gold, fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final row in pendingTeachers)
            _PendingTeacherTile(
              row: row,
              onApprove: () => onApproveTeacher(row),
            ),
          const SizedBox(height: AppSpacing.lg),
          Divider(color: brand.border),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'All users',
            style: AppTextStyles.headingSmall.copyWith(color: brand.textDark),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        ...List.generate(users.length, (i) {
          final row = users[i];
          final isPremium = row.subscriptionType == 'premium';
          return Column(
            children: [
              ListTile(
                title: Text(
                  row.name,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: brand.textDark,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  '${row.email} · ${row.role} · ${row.points} pts',
                  style:
                      AppTextStyles.bodySmall.copyWith(color: brand.textMuted),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'premium') onTogglePremium(row);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'premium',
                      child:
                          Text(isPremium ? 'Revoke premium' : 'Grant premium'),
                    ),
                  ],
                ),
                leading: CircleAvatar(
                  backgroundColor: isPremium
                      ? AppColors.kGold.withValues(alpha: 0.3)
                      : brand.primary.withValues(alpha: 0.15),
                  child: Icon(
                    isPremium ? Icons.star : Icons.person,
                    color: isPremium ? AppColors.kGold : brand.primary,
                    size: 20,
                  ),
                ),
              ),
              if (i != users.length - 1)
                Divider(height: 1, color: brand.border),
            ],
          );
        }),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: PillButton(
              label: 'Load more',
              variant: PillVariant.secondary,
              dense: true,
              fullWidth: false,
              onPressed: onLoadMore,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _PendingTeacherTile — single row in the Users tab's approval queue.
// ---------------------------------------------------------------------------

class _PendingTeacherTile extends StatelessWidget {
  const _PendingTeacherTile({required this.row, required this.onApprove});

  final AdminUserRow row;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: brand.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: brand.gold.withValues(alpha: 0.20),
            child: Icon(Icons.school_rounded, color: brand.gold, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: brand.textDark, fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  row.email,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style:
                      AppTextStyles.bodySmall.copyWith(color: brand.textMuted),
                ),
                if (row.subjects.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    row.subjects.join(' · '),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: brand.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: brand.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2,
              ),
            ),
            onPressed: onApprove,
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Content tab — admin material upload via the shared TeacherUploadSheet.
// Lists recent uploads from any source so admins can verify what's live.
// ---------------------------------------------------------------------------

class _ContentTab extends ConsumerWidget {
  const _ContentTab({required this.adminUid});

  final String adminUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final curriculum = ref.watch(currentCurriculumConfigProvider);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload material',
            style: AppTextStyles.headingSmall.copyWith(color: brand.textDark),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Publish a new study resource. The sheet writes directly to '
            '/materials with your uid as uploadedBy.',
            style: AppTextStyles.bodyMedium.copyWith(color: brand.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          PillButton(
            label: 'Open upload form',
            icon: Icons.upload_file_rounded,
            onPressed: adminUid.isEmpty
                ? null
                : () => showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: brand.surface,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: AppRadius.xlRadius),
                      ),
                      builder: (_) => TeacherUploadSheet(
                        uploaderUid: adminUid,
                        availableSubjects: curriculum.subjects,
                      ),
                    ).then((ok) {
                      if (ok == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: brand.primary,
                            content: const Text('Material published.'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Recent uploads',
            style: AppTextStyles.headingSmall.copyWith(color: brand.textDark),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ref
                  .watch(firestoreProvider)
                  .collection('materials')
                  .orderBy('createdAt', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2));
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Text(
                    'No materials yet.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: brand.textMuted),
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: brand.border),
                  itemBuilder: (_, i) {
                    final d = docs[i].data();
                    final title = (d['title'] as String?) ?? 'Untitled';
                    final subject = (d['subject'] as String?) ?? '';
                    final level = (d['level'] as String?) ?? '';
                    final views = (d['views'] as num?)?.toInt() ?? 0;
                    return ListTile(
                      dense: true,
                      title: Text(
                        title,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: brand.textDark),
                      ),
                      subtitle: Text(
                        '$subject · $level',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: brand.textMuted),
                      ),
                      trailing: Text(
                        '$views \u{1F441}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: brand.textMuted),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifications tab — broadcast composer
// ---------------------------------------------------------------------------

class _NotificationsTab extends StatelessWidget {
  const _NotificationsTab({
    required this.titleController,
    required this.bodyController,
    required this.role,
    required this.onRoleChanged,
    required this.onSend,
  });

  final TextEditingController titleController;
  final TextEditingController bodyController;
  final String role;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'Broadcast',
          style: AppTextStyles.headingSmall.copyWith(color: brand.textDark),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: titleController,
          style: AppTextStyles.bodyMedium.copyWith(color: brand.textDark),
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: bodyController,
          maxLines: 4,
          style: AppTextStyles.bodyMedium.copyWith(color: brand.textDark),
          decoration: const InputDecoration(labelText: 'Body'),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: role,
          decoration: const InputDecoration(labelText: 'Recipient role'),
          items: const [
            DropdownMenuItem(value: 'student', child: Text('Students')),
            DropdownMenuItem(value: 'teacher', child: Text('Teachers')),
            DropdownMenuItem(value: 'all', child: Text('All')),
          ],
          onChanged: (v) {
            if (v != null) onRoleChanged(v);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        PillButton(
          label: 'Send broadcast',
          icon: Icons.send_rounded,
          onPressed: onSend,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Analytics tab — Gemini usage line chart + daily breakdown
// ---------------------------------------------------------------------------

class _AnalyticsTab extends ConsumerWidget {
  const _AnalyticsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final admin = ref.watch(adminViewModelProvider);

    if (admin.analyticsLoading && admin.usageLogDays.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (admin.analyticsError != null) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            admin.analyticsError!,
            style: AppTextStyles.bodyMedium.copyWith(color: brand.textDark),
          ),
          const SizedBox(height: AppSpacing.md),
          PillButton(
            label: 'Retry',
            icon: Icons.refresh_rounded,
            fullWidth: false,
            onPressed: () => ref
                .read(adminViewModelProvider.notifier)
                .loadUsageAnalytics(),
          ),
        ],
      );
    }

    final days = admin.usageLogDays;
    final spots = <FlSpot>[
      for (var i = 0; i < days.length; i++)
        FlSpot(i.toDouble(), days[i].calls.toDouble()),
    ];
    final maxCalls = days.isEmpty
        ? 1.0
        : days.map((d) => d.calls).reduce((a, b) => a > b ? a : b).toDouble();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'Gemini usage (last ${days.length} days)',
          style: AppTextStyles.headingSmall.copyWith(color: brand.textDark),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${admin.totalCallsLast14Days} calls · '
          '\$${admin.totalCostLast14Days.toStringAsFixed(2)} estimated',
          style: AppTextStyles.bodySmall.copyWith(color: brand.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 220,
          child: days.isEmpty
              ? Center(
                  child: Text(
                    'No usage_log data yet — MentorBot calls will appear here.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: brand.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxCalls * 1.2,
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: brand.primary,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Source: /system/usage_log_{YYYY-MM-DD} (server-written)',
          style: AppTextStyles.bodySmall.copyWith(color: brand.textMuted),
        ),
        if (days.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Daily breakdown',
            style: AppTextStyles.labelLarge.copyWith(color: brand.textDark),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final d in days.reversed)
            ListTile(
              dense: true,
              title: Text(
                d.dateKey,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: brand.textDark,
                ),
              ),
              subtitle: Text(
                '${d.calls} calls · ${d.promptTokens + d.completionTokens} tokens',
                style: AppTextStyles.bodySmall.copyWith(color: brand.textMuted),
              ),
              trailing: Text(
                '\$${d.estimatedCostUsd.toStringAsFixed(3)}',
                style: AppTextStyles.labelMedium.copyWith(
                  color: brand.textDark,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Config tab — live view of /config/{gamification,curriculum,quotas}.
// Read-only: admins edit values in Firebase Console; the app reloads
// automatically through the stream providers.
// ---------------------------------------------------------------------------

class _ConfigTab extends ConsumerWidget {
  const _ConfigTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final gamAsync = ref.watch(gamificationConfigStreamProvider);
    final curAsync = ref.watch(curriculumConfigStreamProvider);
    final quoAsync = ref.watch(quotasConfigStreamProvider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'Live values streamed from /config/* in Firestore. '
          'Edit these docs in Firebase Console to change them — the app '
          'reloads automatically.',
          style: AppTextStyles.bodySmall.copyWith(color: brand.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),

        // -- /config/quotas --
        _ConfigSection(
          title: '/config/quotas',
          asyncStatus: quoAsync,
          builder: (cfg) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ConfigRow('Daily text limit', '${cfg.dailyTextLimit}'),
              _ConfigRow('Daily image limit', '${cfg.dailyImageLimit}'),
              _ConfigRow('Warning threshold', '${cfg.warningThreshold}'),
              _ConfigRow('Timezone', cfg.timezone),
            ],
          ),
        ),

        // -- /config/curriculum --
        _ConfigSection(
          title: '/config/curriculum',
          asyncStatus: curAsync,
          builder: (cfg) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ConfigRow('Levels', cfg.levels.join(' · ')),
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                'Subjects (${cfg.subjects.length})',
                style: AppTextStyles.labelMedium.copyWith(
                  color: brand.textDark,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs + 2,
                runSpacing: AppSpacing.xs + 2,
                children: [
                  for (final s in cfg.subjects)
                    Chip(
                      label: Text(
                        s,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: brand.textDark,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: brand.background,
                      side: BorderSide(color: brand.border),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs + 2),
              _ConfigRow(
                'Subject "all" sentinel',
                cfg.materialsSubjectAllSentinel,
              ),
              _ConfigRow(
                'Level "both" sentinel',
                cfg.materialsLevelBothSentinel,
              ),
            ],
          ),
        ),

        // -- /config/gamification --
        _ConfigSection(
          title: '/config/gamification',
          asyncStatus: gamAsync,
          builder: (cfg) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ConfigRow('Streak grace days', '${cfg.streakGraceDays}'),
              _ConfigRow(
                'Streak lookback days',
                '${cfg.streakLookbackDays}',
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Badges (${cfg.badges.length})',
                style: AppTextStyles.labelMedium.copyWith(
                  color: brand.textDark,
                ),
              ),
              const SizedBox(height: AppSpacing.xs + 2),
              for (final b in cfg.badges)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${b.name} · target ${b.target ?? '—'}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: brand.textDark,
                              ),
                            ),
                            Text(
                              'id: ${b.id} · field: ${b.progressField ?? '—'}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: brand.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Milestones (${cfg.milestones.length})',
                style: AppTextStyles.labelMedium.copyWith(
                  color: brand.textDark,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final m in cfg.milestones)
                _ConfigRow('${m.points} pts', m.rewardHint),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConfigSection<T> extends StatelessWidget {
  const _ConfigSection({
    required this.title,
    required this.asyncStatus,
    required this.builder,
  });

  final String title;
  final AsyncValue<T> asyncStatus;
  final Widget Function(T value) builder;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: AppRadius.mdBorder,
        border: Border.all(color: brand.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: AppTextStyles.headingSmall.copyWith(
                  color: brand.textDark,
                ),
              ),
              const Spacer(),
              if (asyncStatus.isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          asyncStatus.when(
            data: builder,
            error: (e, _) => Text(
              'Could not load: $e',
              style: AppTextStyles.bodySmall.copyWith(color: brand.error),
            ),
            loading: () => Text(
              'Loading…',
              style: AppTextStyles.bodySmall.copyWith(color: brand.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(color: brand.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(color: brand.textDark),
            ),
          ),
        ],
      ),
    );
  }
}
