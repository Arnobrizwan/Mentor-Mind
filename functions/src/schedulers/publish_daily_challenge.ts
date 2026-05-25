import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as functions from "firebase-functions";
import { db } from "../lib/admin";
import { getDhakaDateKey } from "../lib/quota";
import { sendTopicNotification } from "../lib/fcm";

const CHALLENGE_POOL: { subject: string; question: string }[] = [
  {
    subject: "Physics",
    question:
      "A 2 kg block slides down a frictionless 30° incline. Find its acceleration (g = 10 m/s²).",
  },
  {
    subject: "Mathematics",
    question:
      "Solve for x: 2x² − 5x + 2 = 0. Show your working for full marks.",
  },
  {
    subject: "Chemistry",
    question:
      "Balance: Fe + O₂ → Fe₂O₃. How many moles of O₂ are needed for 4 mol Fe?",
  },
  {
    subject: "Biology",
    question:
      "Describe the role of mitochondria in cellular respiration (3 marks).",
  },
  {
    subject: "English",
    question:
      'Write one thesis sentence for: "Social media helps O Level students learn."',
  },
];

function pickChallenge(dateKey: string): { subject: string; question: string } {
  let hash = 0;
  for (let i = 0; i < dateKey.length; i++) {
    hash = (hash * 31 + dateKey.charCodeAt(i)) >>> 0;
  }
  return CHALLENGE_POOL[hash % CHALLENGE_POOL.length]!;
}

/** DASH-02 — daily challenge doc + FCM broadcast at Dhaka midnight (18:00 UTC). */
export const publishDailyChallenge = onSchedule(
  {
    schedule: "0 18 * * *",
    timeZone: "UTC",
    region: "asia-south1",
  },
  async () => {
    const dateKey = getDhakaDateKey();
    const picked = pickChallenge(dateKey);
    const ref = db.collection("daily_challenges").doc(dateKey);

    await ref.set(
      {
        dateKey,
        subject: picked.subject,
        question: picked.question,
        pointsReward: 25,
        publishedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    try {
      await sendTopicNotification({
        topic: "role_all",
        title: "Daily Challenge is live 🎯",
        body: `${picked.subject}: ${picked.question.substring(0, 80)}…`,
        data: {
          type: "daily_challenge",
          recipientRole: "all",
          dateKey,
        },
      });
    } catch (err) {
      functions.logger.warn("publishDailyChallenge FCM failed", {
        err: err instanceof Error ? err.message : String(err),
      });
    }

    functions.logger.info("publishDailyChallenge ok", { dateKey });
  }
);
