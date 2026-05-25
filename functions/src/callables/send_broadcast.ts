import * as admin from "firebase-admin";
import { onCall } from "firebase-functions/v2/https";
import * as functions from "firebase-functions";
import { db } from "../lib/admin";
import { requireAdmin } from "../lib/admin_guard";
import { internal } from "../lib/errors";
import { sendTopicNotification, topicForRecipientRole } from "../lib/fcm";

/** ADMN-06 — admin broadcast: Firestore doc + FCM topic (NOTF-01/02). */
export const sendBroadcast = onCall(
  {
    region: "asia-south1",
    enforceAppCheck: true,
  },
  async (request) => {
    await requireAdmin(request);
    const data = (request.data ?? {}) as Record<string, unknown>;
    const title = typeof data["title"] === "string" ? data["title"].trim() : "";
    const body = typeof data["body"] === "string" ? data["body"].trim() : "";
    const recipientRole =
      typeof data["recipientRole"] === "string"
        ? data["recipientRole"]
        : "all";
    const type =
      typeof data["type"] === "string" ? data["type"] : "announcement";

    if (!title || !body) {
      throw internal("title and body are required");
    }

    const ref = db.collection("notifications").doc();
    const now = admin.firestore.FieldValue.serverTimestamp();
    await ref.set({
      title,
      body,
      recipientRole,
      type,
      read: false,
      timestamp: now,
      createdAt: now,
    });

    const topic = topicForRecipientRole(recipientRole);
    try {
      await sendTopicNotification({
        topic,
        title,
        body,
        data: {
          notificationId: ref.id,
          type,
          recipientRole,
        },
      });
    } catch (err) {
      functions.logger.warn("sendBroadcast FCM failed (doc still written)", {
        err: err instanceof Error ? err.message : String(err),
      });
    }

    return { ok: true, notificationId: ref.id };
  }
);
