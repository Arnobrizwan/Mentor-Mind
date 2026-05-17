import 'package:mentor_minds/data/models/app_notification.dart';

// ---------------------------------------------------------------------------
// notification_factory.dart — Test data builder for AppNotification.
// ---------------------------------------------------------------------------

AppNotification buildAppNotification({
  String id = 'notif-1',
  String title = 'Test Notification',
  String body = 'Test notification body',
  String type = 'announcement',
  String recipientRole = 'student',
  String? deeplink,
  DateTime? timestamp,
  bool read = false,
}) {
  return AppNotification(
    id: id,
    title: title,
    body: body,
    type: type,
    recipientRole: recipientRole,
    deeplink: deeplink,
    timestamp: timestamp,
    read: read,
  );
}
