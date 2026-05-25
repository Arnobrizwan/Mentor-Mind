import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { Change, DocumentSnapshot } from "firebase-functions/v2/firestore";
import { db } from "../lib/admin";
import { getDhakaDateKey } from "../lib/quota";
import {
  awardPoints,
  buildDedupeKey,
  bumpUserCounters,
  evaluateAndGrantBadges,
  isDailyLoginRewarded,
  markDailyLoginRewarded,
} from "../lib/rewards";

type MessageData = {
  role?: string;
  clientRequestId?: string;
  imageUrl?: string;
  subject?: string;
};

async function resolveSession(
  sessionId: string
): Promise<{ uid: string; subject?: string } | null> {
  const snap = await db.collection("sessions").doc(sessionId).get();
  const data = snap.data();
  if (!data) return null;
  const uid = data["uid"] ?? data["userId"];
  if (typeof uid !== "string") return null;
  const subject =
    typeof data["subject"] === "string" ? data["subject"] : undefined;
  return { uid, subject };
}

async function handleUserMessage(
  uid: string,
  sessionId: string,
  messageId: string,
  data: MessageData
): Promise<void> {
  const clientRequestId = data.clientRequestId ?? messageId;
  const meta = { clientRequestId, sessionId, messageId };
  const dateKey = getDhakaDateKey();

  const counterPatch: Record<string, unknown> = {
    totalQuestions: admin.firestore.FieldValue.increment(1),
  };
  if (data.subject) {
    counterPatch[`questionsPerSubject.${data.subject}`] =
      admin.firestore.FieldValue.increment(1);
  }
  if (data.imageUrl) {
    counterPatch["diagramUploads"] = admin.firestore.FieldValue.increment(1);
  }
  await bumpUserCounters(uid, counterPatch);

  if (!(await isDailyLoginRewarded(uid, dateKey))) {
    const dailyKey = buildDedupeKey({
      type: "daily_login",
      date: dateKey,
      uid,
    });
    const awarded = await awardPoints(uid, "daily_login", dailyKey, meta);
    if (awarded) {
      await markDailyLoginRewarded(uid, dateKey);
    }
  }

  if (data.imageUrl) {
    const diagramKey = buildDedupeKey({
      type: "upload_diagram",
      clientRequestId,
      sessionId,
    });
    await awardPoints(uid, "upload_diagram", diagramKey, meta);
  }

  await evaluateAndGrantBadges(uid, meta);
}

async function handleAssistantMessage(
  uid: string,
  sessionId: string,
  messageId: string,
  data: MessageData
): Promise<void> {
  const clientRequestId = data.clientRequestId ?? messageId;
  const meta = { clientRequestId, sessionId, messageId };

  const completeKey = buildDedupeKey({
    type: "complete_session",
    clientRequestId,
    sessionId,
  });
  const awarded = await awardPoints(
    uid,
    "complete_session",
    completeKey,
    meta
  );
  if (awarded) {
    await bumpUserCounters(uid, {
      sessionsCompleted: admin.firestore.FieldValue.increment(1),
    });
  }

  await evaluateAndGrantBadges(uid, meta);
}

export async function processMessageWrite(
  sessionId: string,
  messageId: string,
  change: Change<DocumentSnapshot | undefined>
): Promise<void> {
  const after = change.after;
  if (!after?.exists) return;

  const data = after.data() as MessageData | undefined;
  if (!data?.role) return;

  const session = await resolveSession(sessionId);
  if (!session) {
    functions.logger.warn("onSessionMessageWrite: session missing uid", {
      sessionId,
      messageId,
    });
    return;
  }
  const { uid } = session;
  const enriched: MessageData = {
    ...data,
    subject: data.subject ?? session.subject,
  };

  try {
    if (data.role === "user") {
      await handleUserMessage(uid, sessionId, messageId, enriched);
    } else if (data.role === "assistant") {
      await handleAssistantMessage(uid, sessionId, messageId, enriched);
    }
  } catch (err) {
    functions.logger.error("onSessionMessageWrite: award failed", {
      uid,
      sessionId,
      messageId,
      err: err instanceof Error ? err.message : String(err),
    });
    try {
      await db.collection("system").doc(`rewards_errors_${Date.now()}`).set({
        uid,
        sessionId,
        messageId,
        error: err instanceof Error ? err.message : String(err),
        at: new Date().toISOString(),
      });
    } catch {
      // best-effort dead letter
    }
  }
}

/** REWD-01 — server-authoritative rewards on session message writes. */
export const onSessionMessageWrite = onDocumentWritten(
  {
    document: "sessions/{sessionId}/messages/{messageId}",
    region: "asia-south1",
  },
  async (event) => {
    const sessionId = event.params["sessionId"];
    const messageId = event.params["messageId"];
    if (!sessionId || !messageId || !event.data) return;
    await processMessageWrite(sessionId, messageId, event.data);
  }
);
