import { onDocumentWritten } from "firebase-functions/v2/firestore";
import * as functions from "firebase-functions";
import { reconcileFcmTopics } from "../lib/fcm";

/** NOTF-05 — server-side topic reconciler when /users/{uid}.fcmTopics changes. */
export const onUserFcmSync = onDocumentWritten(
  {
    document: "users/{uid}",
    region: "asia-south1",
  },
  async (event) => {
    const after = event.data?.after?.data();
    if (!after) return;

    const token = after["fcmToken"] as string | undefined;
    const topics = (after["fcmTopics"] as string[]) ?? [];
    if (!token || topics.length === 0) return;

    const before = event.data?.before?.data();
    const prevTopics = (before?.["fcmTopics"] as string[]) ?? [];

    try {
      await reconcileFcmTopics(token, prevTopics, topics);
    } catch (err) {
      functions.logger.error("onUserFcmSync failed", {
        uid: event.params["uid"],
        err: err instanceof Error ? err.message : String(err),
      });
    }
  }
);
