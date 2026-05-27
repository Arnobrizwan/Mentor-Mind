import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:mentor_minds/application/viewmodels/notifications/notifications_viewmodel.dart';
import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/core/theme/app_radius.dart';
import 'package:mentor_minds/core/theme/app_spacing.dart';
import 'package:mentor_minds/core/theme/brand_colors.dart';
import 'package:mentor_minds/data/models/app_notification.dart';
import 'package:mentor_minds/shared/widgets/empty_state.dart';
import 'package:mentor_minds/shared/widgets/pill_button.dart';
import 'package:mentor_minds/shared/widgets/skeleton_block.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final state = ref.watch(notificationsViewModelProvider);
    return Scaffold(
      backgroundColor: brand.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(unreadCount: state.unreadCount),
            _FilterChipsRow(
              selected: state.activeFilter,
              onChanged: (f) => ref
                  .read(notificationsViewModelProvider.notifier)
                  .filterNotifications(f),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: state.isLoading
                  ? const _ListShimmer()
                  : (state.filteredNotifications.isEmpty
                      ? const _EmptyState()
                      : _NotificationsList(
                          items: state.filteredNotifications)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends ConsumerWidget {
  final int unreadCount;
  const _Header({required this.unreadCount});

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
            onPressed: () => context.canPop()
                ? context.pop()
                : context.goNamed(AppRoutes.dashboard),
          ),
          Text(
            'Notifications',
            style: AppTextStyles.headingLarge.copyWith(
              color: brand.textDark, fontSize: 20,
            ),
          ),
          const Spacer(),
          if (unreadCount > 0)
            TextButton(
              onPressed: () async {
                await ref
                    .read(notificationsViewModelProvider.notifier)
                    .markAllAsReadForCurrentUser();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All marked as read'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(milliseconds: 1500),
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: brand.primary,
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              child: const Text('Mark all read'),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chips
// ---------------------------------------------------------------------------

class _FilterChipsRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _FilterChipsRow({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    const items = <(String, String)>[
      (NotificationFilter.all, 'All'),
      (NotificationFilter.announcements, 'Announcements'),
      (NotificationFilter.achievements, 'Achievements'),
      (NotificationFilter.reminders, 'Reminders'),
    ];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final (value, label) = items[i];
          final isSelected = value == selected;
          return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) => onChanged(value),
            backgroundColor: brand.surface,
            selectedColor: brand.primary,
            labelStyle: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isSelected ? Colors.white : brand.textDark,
            ),
            side: BorderSide(
              color: isSelected ? brand.primary : brand.border,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.pillBorder,
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List (grouped by Today / Yesterday / This Week / Earlier)
// ---------------------------------------------------------------------------

class _NotificationsList extends ConsumerWidget {
  final List<AppNotification> items;
  const _NotificationsList({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final groups = _group(items);
    final flattened = <_ListRow>[];
    for (final g in groups) {
      flattened.add(_HeaderRow(g.label));
      for (final n in g.items) {
        flattened.add(_NotifRow(n));
      }
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl,
      ),
      itemCount: flattened.length,
      itemBuilder: (_, i) {
        final row = flattened[i];
        if (row is _HeaderRow) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              0, AppSpacing.md + 2, 0, AppSpacing.sm,
            ),
            child: Text(
              row.label.toUpperCase(),
              style: AppTextStyles.labelSmall.copyWith(
                color: brand.textMuted,
                letterSpacing: 1.2,
              ),
            ),
          );
        }
        final notif = (row as _NotifRow).notification;
        return _NotificationTile(
          notification: notif,
          onTap: () {
            ref
                .read(notificationsViewModelProvider.notifier)
                .markAsRead(notif.id);
            _openDetail(context, notif);
          },
          onLongPress: () => _openLongPressMenu(context, notif, ref),
          onDismissed: () => ref
              .read(notificationsViewModelProvider.notifier)
              .deleteNotification(notif.id),
        );
      },
    );
  }

  List<_Group> _group(List<AppNotification> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(const Duration(days: 6));

    final todayList = <AppNotification>[];
    final yesterdayList = <AppNotification>[];
    final weekList = <AppNotification>[];
    final earlierList = <AppNotification>[];

    for (final n in items) {
      final ts = n.timestamp;
      if (ts == null) {
        earlierList.add(n);
        continue;
      }
      final day = DateTime(ts.year, ts.month, ts.day);
      if (day == today) {
        todayList.add(n);
      } else if (day == yesterday) {
        yesterdayList.add(n);
      } else if (!day.isBefore(weekStart)) {
        weekList.add(n);
      } else {
        earlierList.add(n);
      }
    }
    final result = <_Group>[];
    if (todayList.isNotEmpty) result.add(_Group('Today', todayList));
    if (yesterdayList.isNotEmpty) {
      result.add(_Group('Yesterday', yesterdayList));
    }
    if (weekList.isNotEmpty) result.add(_Group('This Week', weekList));
    if (earlierList.isNotEmpty) result.add(_Group('Earlier', earlierList));
    return result;
  }
}

class _Group {
  final String label;
  final List<AppNotification> items;
  const _Group(this.label, this.items);
}

sealed class _ListRow {}

class _HeaderRow extends _ListRow {
  final String label;
  _HeaderRow(this.label);
}

class _NotifRow extends _ListRow {
  final AppNotification notification;
  _NotifRow(this.notification);
}

// ---------------------------------------------------------------------------
// Tile
// ---------------------------------------------------------------------------

/// Notification-type → tinted icon background. Achievement = gold,
/// reminder = teal, new material = purple (decorative type color),
/// default = primary indigo.
Color _iconBgForType(BuildContext context, String type) {
  final brand = context.brand;
  return switch (type) {
    'achievement' => brand.gold,
    'reminder' => brand.accent,
    'new_material' => const Color(0xFF8B5CF6),
    _ => brand.primary,
  };
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDismissed;
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onLongPress,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final isUnread = !notification.read;
    return Dismissible(
      key: ValueKey('notif-${notification.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: const BoxDecoration(
          color: Color(0xFF16A34A), // semantic "confirm" green
          borderRadius: AppRadius.lgBorder,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.check_rounded, color: Colors.white),
            SizedBox(width: AppSpacing.sm),
            Text(
              'Dismiss',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isUnread
              ? brand.primary.withValues(alpha: 0.06)
              : brand.surface,
          borderRadius: AppRadius.lgBorder,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.lgBorder,
          child: InkWell(
            borderRadius: AppRadius.lgBorder,
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _iconBgForType(context, notification.type),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      notification.icon,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: isUnread
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: brand.textDark,
                          ),
                        ),
                        if (notification.body.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            notification.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: brand.textMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatWhen(notification.timestamp),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: brand.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs + 2),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: brand.primary,
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(width: 8, height: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatWhen(DateTime? dt) {
  if (dt == null) return '';
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return DateFormat('EEE, h:mma').format(dt);
  return DateFormat('MMM d').format(dt);
}

// ---------------------------------------------------------------------------
// Empty state — shared EmptyState
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: EmptyState(
        title: "You're all caught up!",
        message: "We'll let you know when there's something new.",
        icon: Icons.notifications_none_rounded,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Long-press menu
// ---------------------------------------------------------------------------

void _openLongPressMenu(
  BuildContext context,
  AppNotification notif,
  WidgetRef ref,
) {
  final brand = context.brand;
  showModalBottomSheet(
    context: context,
    backgroundColor: brand.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: AppRadius.xxlRadius),
    ),
    builder: (sheetCtx) {
      final sheetBrand = sheetCtx.brand;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: sheetBrand.textMuted.withValues(alpha: 0.3),
                borderRadius: AppRadius.xsBorder,
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            if (!notif.read)
              ListTile(
                leading: Icon(
                  Icons.mark_email_read_rounded, color: sheetBrand.primary,
                ),
                title: Text(
                  'Mark as read',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: sheetBrand.textDark,
                  ),
                ),
                onTap: () {
                  ref
                      .read(notificationsViewModelProvider.notifier)
                      .markAsRead(notif.id);
                  Navigator.of(sheetCtx).pop();
                },
              ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded, color: sheetBrand.error,
              ),
              title: Text(
                'Delete',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: sheetBrand.textDark,
                ),
              ),
              onTap: () {
                ref
                    .read(notificationsViewModelProvider.notifier)
                    .deleteNotification(notif.id);
                Navigator.of(sheetCtx).pop();
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Detail bottom sheet
// ---------------------------------------------------------------------------

void _openDetail(BuildContext context, AppNotification notif) {
  final brand = context.brand;
  showModalBottomSheet(
    context: context,
    backgroundColor: brand.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: AppRadius.xxlRadius),
    ),
    builder: (sheetCtx) {
      final sheetBrand = sheetCtx.brand;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.md + 2, AppSpacing.xl, AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sheetBrand.textMuted.withValues(alpha: 0.3),
                    borderRadius: AppRadius.xsBorder,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg + 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _iconBgForType(sheetCtx, notif.type),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      notif.icon,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      notif.title,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: sheetBrand.textDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md + 2),
              if (notif.body.isNotEmpty)
                Text(
                  notif.body,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: sheetBrand.textDark,
                  ),
                ),
              const SizedBox(height: AppSpacing.sm + 2),
              if (notif.timestamp != null)
                Text(
                  DateFormat('MMM d, y · h:mm a').format(notif.timestamp!),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: sheetBrand.textMuted,
                  ),
                ),
              const SizedBox(height: AppSpacing.lg + 2),
              if (notif.type == 'new_material')
                PillButton(
                  label: 'Open Material',
                  icon: Icons.menu_book_rounded,
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    context.goNamed(AppRoutes.materials);
                  },
                ),
              if (notif.type == 'achievement')
                _GoldPillButton(
                  label: 'View Rewards',
                  icon: Icons.emoji_events_rounded,
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    context.goNamed(AppRoutes.rewards);
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Gold-colored PillButton-shaped CTA for the "achievement" notification type.
/// Mirrors the gold premium upsell from search; gold stays full color in
/// both themes (intentional reward identity moment).
class _GoldPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _GoldPillButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.kGold,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md + 2),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.pillBorder,
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer skeleton
// ---------------------------------------------------------------------------

class _ListShimmer extends StatelessWidget {
  const _ListShimmer();

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return SkeletonGroup(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          height: 74,
          margin: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: brand.surface,
            borderRadius: AppRadius.lgBorder,
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: const Row(
            children: [
              SkeletonBlock(
                width: 48, height: 48, radius: Radius.circular(24),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SkeletonBlock(height: 10),
                    SizedBox(height: AppSpacing.xs + 2),
                    SkeletonBlock(width: 160, height: 10),
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
