import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

/** Map admin broadcast recipientRole to FCM topic name. */
export function topicForRecipientRole(role: string): string {
  switch (role) {
    case "student":
      return "role_student";
    case "teacher":
      return "role_teacher";
    case "admin":
      return "role_admin";
    case "premium_student":
      return "role_premium_student";
    default:
      return "role_all";
  }
}

export async function sendTopicNotification(opts: {
  topic: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}): Promise<void> {
  await admin.messaging().send({
    topic: opts.topic,
    notification: { title: opts.title, body: opts.body },
    data: opts.data ?? {},
    apns: {
      payload: {
        aps: { sound: "default", badge: 1 },
      },
    },
  });
}

/** NOTF-05 — reconcile intended topics to FCM for a device token. */
export async function reconcileFcmTopics(
  token: string,
  before: string[],
  after: string[]
): Promise<void> {
  const prev = new Set(before);
  const next = new Set(after);
  for (const topic of next) {
    if (!prev.has(topic)) {
      const res = await admin.messaging().subscribeToTopic([token], topic);
      functions.logger.info("fcm subscribe", { topic, res });
    }
  }
  for (const topic of prev) {
    if (!next.has(topic)) {
      await admin.messaging().unsubscribeFromTopic([token], topic);
    }
  }
}
