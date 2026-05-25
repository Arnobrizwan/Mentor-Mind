import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:mentor_minds/application/viewmodels/admin/admin_viewmodel.dart';
import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/routes/app_router.dart';

// ---------------------------------------------------------------------------
// AdminScreen — Phase 5 ADMN-01..08 (5-tab panel)
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not authorized')),
        );
        context.goNamed(AppRoutes.dashboard);
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
            ],
          ),
        );
      },
    );
  }

  Widget _tabBody(AdminState admin, bool wide) {
    final child = switch (_tabIndex) {
      0 => _DashboardTab(userCount: admin.users.length),
      1 => _UsersTab(
          users: admin.users,
          hasMore: admin.hasMoreUsers,
          onLoadMore: () =>
              ref.read(adminViewModelProvider.notifier).loadUsers(),
          onTogglePremium: (row) =>
              ref.read(adminViewModelProvider.notifier).togglePremium(row),
        ),
      2 => const _ContentTab(),
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
      _ => const SizedBox.shrink(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 16, 16, 8),
          child: Row(
            children: [
              const Text('Admin Panel', style: AppTextStyles.headingLarge),
              const Spacer(),
              if (admin.error != null)
                Flexible(
                  child: Text(
                    admin.error!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.kError,
                    ),
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

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({required this.userCount});

  final int userCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatCard(label: 'Users loaded', value: '$userCount'),
            const _StatCard(label: 'DAU (today)', value: '—'),
            const _StatCard(label: 'Premium', value: '—'),
            const _StatCard(label: 'Messages today', value: '—'),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Recent activity', style: AppTextStyles.headingSmall),
        const SizedBox(height: 8),
        Text(
          'Full activity feed ships with Analytics in a later pass.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.kTextMuted),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.kTextMuted.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.kTextMuted),
          ),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.headingMedium),
        ],
      ),
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab({
    required this.users,
    required this.hasMore,
    required this.onLoadMore,
    required this.onTogglePremium,
  });

  final List<AdminUserRow> users;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final void Function(AdminUserRow row) onTogglePremium;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Center(child: Text('No users loaded'));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: users.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i == users.length) {
          return TextButton(
            onPressed: onLoadMore,
            child: const Text('Load more'),
          );
        }
        final row = users[i];
        final isPremium = row.subscriptionType == 'premium';
        return ListTile(
          title: Text(row.name),
          subtitle: Text('${row.email} · ${row.role} · ${row.points} pts'),
          trailing: PopupMenuButton<String>(
            onSelected: (action) {
              if (action == 'premium') onTogglePremium(row);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'premium',
                child: Text(isPremium ? 'Revoke premium' : 'Grant premium'),
              ),
            ],
          ),
          leading: CircleAvatar(
            backgroundColor: isPremium
                ? AppColors.kGold.withValues(alpha: 0.3)
                : AppColors.kPrimary.withValues(alpha: 0.15),
            child: Icon(
              isPremium ? Icons.star : Icons.person,
              color: isPremium ? AppColors.kGold : AppColors.kPrimary,
              size: 20,
            ),
          ),
        );
      },
    );
  }
}

class _ContentTab extends StatelessWidget {
  const _ContentTab();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Upload material', style: AppTextStyles.headingSmall),
          const SizedBox(height: 8),
          Text(
            'Teacher content upload + Storage write will connect in Phase 7 polish. '
            'Use Firebase Console or seed script for now.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.kTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}

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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Broadcast', style: AppTextStyles.headingSmall),
        const SizedBox(height: 12),
        TextField(
          controller: titleController,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: bodyController,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Body'),
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 16),
        FilledButton(onPressed: onSend, child: const Text('Send broadcast')),
      ],
    );
  }
}

class _AnalyticsTab extends ConsumerWidget {
  const _AnalyticsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(adminViewModelProvider);

    if (admin.analyticsLoading && admin.usageLogDays.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (admin.analyticsError != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(admin.analyticsError!, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => ref
                .read(adminViewModelProvider.notifier)
                .loadUsageAnalytics(),
            child: const Text('Retry'),
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
      padding: const EdgeInsets.all(16),
      children: [
        Text('Gemini usage (last ${days.length} days)',
            style: AppTextStyles.headingSmall),
        const SizedBox(height: 8),
        Text(
          '${admin.totalCallsLast14Days} calls · '
          '\$${admin.totalCostLast14Days.toStringAsFixed(2)} estimated',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.kTextMuted),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: days.isEmpty
              ? Center(
                  child: Text(
                    'No usage_log data yet — MentorBot calls will appear here.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.kTextMuted,
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
                        color: AppColors.kPrimary,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          'Source: /system/usage_log_{YYYY-MM-DD} (server-written)',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.kTextMuted),
        ),
        if (days.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text('Daily breakdown', style: AppTextStyles.labelLarge),
          const SizedBox(height: 8),
          for (final d in days.reversed)
            ListTile(
              dense: true,
              title: Text(d.dateKey, style: AppTextStyles.bodyMedium),
              subtitle: Text(
                '${d.calls} calls · ${d.promptTokens + d.completionTokens} tokens',
                style: AppTextStyles.bodySmall,
              ),
              trailing: Text(
                '\$${d.estimatedCostUsd.toStringAsFixed(3)}',
                style: AppTextStyles.labelMedium,
              ),
            ),
        ],
      ],
    );
  }
}
