/**
 * Seeds /daily_challenges/{YYYY-MM-DD} for today (Dhaka date key).
 * Usage: node tool/seed-daily-challenge.js
 */
const admin = require("firebase-admin");

function dhakaDateKey() {
  const now = new Date();
  const dhaka = new Date(now.getTime() + 6 * 60 * 60 * 1000);
  const y = dhaka.getUTCFullYear();
  const m = String(dhaka.getUTCMonth() + 1).padStart(2, "0");
  const d = String(dhaka.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

const POOL = [
  {
    subject: "Physics",
    question:
      "A 2 kg block slides down a frictionless 30° incline. Find its acceleration (g = 10 m/s²).",
  },
];

async function main() {
  admin.initializeApp({ projectId: "mentor-mind-aa765" });
  const db = admin.firestore();
  const dateKey = dhakaDateKey();
  const picked = POOL[0];
  await db.collection("daily_challenges").doc(dateKey).set(
    {
      dateKey,
      subject: picked.subject,
      question: picked.question,
      pointsReward: 25,
      publishedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  console.log("Seeded daily_challenges/" + dateKey);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
