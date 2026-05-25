# Phase 6 — FCM iOS Wiring + Notifications + Daily Challenge

**Status:** Complete (2026-05-25)  
**Depends on:** Phase 5

## Delivered

### Client
- `MessagingService` — permission rationale, APNs poll (10s), topic subscribe, token refresh, `fcmToken`/`fcmTopics` on `/users/{uid}`
- `firebase_messaging_background.dart` — `@pragma('vm:entry-point')` persists pushes to `/notifications`
- `flutter_local_notifications` foreground banners (NOTF-03)
- Dashboard wires FCM on first load + daily challenge stream from `/daily_challenges/{dateKey}`
- iOS: `UIBackgroundModes` remote-notification, `aps-environment` development

### Backend
- `sendBroadcast` — Firestore doc + FCM topic send
- `publishDailyChallenge` — scheduler `0 18 * * *` UTC (Dhaka midnight)
- `onUserFcmSync` — reconciles `fcmTopics` via Admin SDK

### Rules / indexes
- `/daily_challenges` read-only for clients
- `/notifications` create allowed for `source: fcm_client` mirror
- Composite index `recipientRole + timestamp`

## Manual setup (one-time)

1. Firebase Console → Cloud Messaging → Apple app → upload **APNs .p8** key for `com.mentorminds.mentorMinds`
2. Xcode → Runner → Signing & Capabilities → **Push Notifications** + **Background Modes → Remote notifications**
3. Deploy: `firebase deploy --only firestore:rules,firestore:indexes,functions --project mentor-mind-aa765`
4. Seed today (optional): `node functions/tool/seed-daily-challenge.js`

## Topics

| Topic | Audience |
|-------|----------|
| `role_all` | Everyone |
| `role_student` | Free students |
| `role_premium_student` | Premium students |
| `role_teacher` | Teachers |
| `role_admin` | Admins |
