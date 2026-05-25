import * as admin from "firebase-admin";
import { onCall } from "firebase-functions/v2/https";
import { db } from "../lib/admin";
import { requireAdmin } from "../lib/admin_guard";
import { internal } from "../lib/errors";

/** ADMN-06 — admin broadcast notification doc (FCM delivery in Phase 6). */
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
    await ref.set({
      title,
      body,
      recipientRole,
      type,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { ok: true, notificationId: ref.id };
  }
);
