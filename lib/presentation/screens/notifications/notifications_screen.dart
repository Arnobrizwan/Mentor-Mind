import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/application/viewmodels/notifications/notifications_viewmodel.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsViewModelProvider);
    return Scaffold(
      backgroundColor: AppColors.kBackground,
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
            const SizedBox(height: 8),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
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
            style: AppTextStyles.headingLarge.copyWith(fontSize: 20),
          ),
          const Spacer(),
          if (unreadCount > 0)
            TextButton(
              onPressed: () async {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid == null) return;
                final role = await _resolveRole(uid);
                await ref
                    .read(notificationsViewModelProvider.notifier)
                    .markAllAsRead(uid, role);
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
                foregroundColor: AppColors.kPrimary,
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

  Future<String> _resolveRole(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return (doc.data()?['role'] as String?)?.trim() ?? 'student';
    } catch (_) {
      return 'student';
    }
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (value, label) = items[i];
          final isSelected = value == selected;
          return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) => onChanged(value),
            backgroundColor: AppColors.kSurface,
            selectedColor: AppColors.kPrimary,
            labelStyle: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isSelected ? Colors.white : AppColors.kTextDark,
            ),
            side: BorderSide(
              color: isSelected
                  ? AppColors.kPrimary
                  : const Color(0xFFE6E9F2),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: flattened.length,
      itemBuilder: (_, i) {
        final row = flattened[i];
        if (row is _HeaderRow) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
            child: Text(
              row.label.toUpperCase(),
              style: AppTextStyles.labelSmall.copyWith(letterSpacing: 1.2),
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

Color _iconBgForType(String type) => switch (type) {
      'achievement' => AppColors.kGold,
      'reminder' => AppColors.kAccent,
      'new_material' => const Color(0xFF8B5CF6),
      _ => AppColors.kPrimary,
    };

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
    final isUnread = !notification.read;
    return Dismissible(
      key: ValueKey('notif-${notification.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.check_rounded, color: Colors.white),
            SizedBox(width: 8),
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
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color:
              isUnread ? const Color(0xFFF0F4FF) : AppColors.kSurface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _iconBgForType(notification.type),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      notification.icon,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                            color: AppColors.kTextDark,
                          ),
                        ),
                        if (notification.body.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            notification.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: AppColors.kTextMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatWhen(notification.timestamp),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: AppColors.kTextMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.kPrimary,
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
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: AppColors.kPrimary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 48,
                color: AppColors.kPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "You're all caught up!",
              style: AppTextStyles.headingMedium,
            ),
            const SizedBox(height: 6),
            Text(
              "We'll let you know when there's something new.",
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.kSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.kTextMuted.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          if (!notif.read)
            ListTile(
              leading: const Icon(Icons.mark_email_read_rounded,
                  color: AppColors.kPrimary),
              title: const Text('Mark as read'),
              onTap: () {
                ref
                    .read(notificationsViewModelProvider.notifier)
                    .markAsRead(notif.id);
                Navigator.of(sheetCtx).pop();
              },
            ),
          ListTile(
            leading:
                const Icon(Icons.delete_outline_rounded, color: AppColors.kError),
            title: const Text('Delete'),
            onTap: () {
              ref
                  .read(notificationsViewModelProvider.notifier)
                  .deleteNotification(notif.id);
              Navigator.of(sheetCtx).pop();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Detail bottom sheet
// ---------------------------------------------------------------------------

void _openDetail(BuildContext context, AppNotification notif) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.kSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.kTextMuted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _iconBgForType(notif.type),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    notif.icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    notif.title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.kTextDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (notif.body.isNotEmpty)
              Text(
                notif.body,
                style: AppTextStyles.bodyMedium,
              ),
            const SizedBox(height: 10),
            if (notif.timestamp != null)
              Text(
                DateFormat('MMM d, y · h:mm a').format(notif.timestamp!),
                style: AppTextStyles.bodySmall,
              ),
            const SizedBox(height: 18),
            if (notif.type == 'new_material')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    context.goNamed(AppRoutes.materials);
                  },
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('Open Material'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            if (notif.type == 'achievement')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    context.goNamed(AppRoutes.rewards);
                  },
                  icon: const Icon(Icons.emoji_events_rounded),
                  label: const Text('View Rewards'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kGold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Shimmer
// ---------------------------------------------------------------------------

class _ListShimmer extends StatelessWidget {
  const _ListShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE6E9F2),
      highlightColor: const Color(0xFFF7F9FD),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          height: 74,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.kSurface,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
