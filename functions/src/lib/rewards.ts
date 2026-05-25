import { createHash } from "crypto";
import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { db } from "./admin";

// Mirrors lib/application/viewmodels/rewards/gamification_viewmodel.dart _pointsMap
export const POINTS_MAP: Record<string, number> = {
  daily_login: 5,
  complete_session: 10,
  five_questions_session: 15,
  upload_diagram: 20,
  daily_challenge: 25,
  streak_7: 50,
  streak_30: 200,
  earn_badge: 30,
};

export const BADGE_IDS = [
  "first_step",
  "curious_learner",
  "dedicated_learner",
  "week_warrior",
  "month_master",
  "diagram_detective",
  "subject_expert",
] as const;

export type BadgeId = (typeof BADGE_IDS)[number];

export type LedgerMeta = {
  clientRequestId?: string;
  sessionId?: string;
  messageId?: string;
  badgeId?: string;
};

export type UserStats = {
  sessionsCompleted: number;
  totalQuestions: number;
  diagramUploads: number;
  streakDays: number;
  maxQuestionsInOneSubject: number;
  badges: Set<string>;
};

const AWARDED_BY = "cloudFunction:onSessionMessageWrite@v1";

/** Build a stable dedupe key for ledger idempotency (D-02). */
export function buildDedupeKey(
  parts: Record<string, string | undefined>
): string {
  return Object.entries(parts)
    .filter(([, v]) => v != null && v.length > 0)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([k, v]) => `${k}=${v}`)
    .join("|");
}

/** Deterministic ledger doc id for idempotent awards (D-02). */
export function ledgerDocId(dedupeKey: string): string {
  return createHash("sha256").update(dedupeKey).digest("hex").slice(0, 40);
}

/**
 * Idempotent points award: writes ledger + mirrors points on /users and /rewards.
 * Returns true if a new award was written.
 */
export async function awardPoints(
  uid: string,
  type: string,
  dedupeKey: string,
  meta: LedgerMeta = {}
): Promise<boolean> {
  const amount = POINTS_MAP[type];
  if (amount == null) {
    functions.logger.warn("rewards: unknown award type", { uid, type });
    return false;
  }

  const now = admin.firestore.Timestamp.now();
  const userRef = db.collection("users").doc(uid);
  const rewardsRef = db.collection("rewards").doc(uid);
  const ledgerRef = rewardsRef.collection("ledger").doc(ledgerDocId(dedupeKey));

  let wrote = false;
  await db.runTransaction(async (txn) => {
    const existing = await txn.get(ledgerRef);
    if (existing.exists) return;

    wrote = true;
    txn.set(ledgerRef, {
      type,
      amount,
      dedupeKey,
      ...(meta.clientRequestId
        ? { clientRequestId: meta.clientRequestId }
        : {}),
      ...(meta.sessionId ? { sessionId: meta.sessionId } : {}),
      ...(meta.messageId ? { messageId: meta.messageId } : {}),
      ...(meta.badgeId ? { badgeId: meta.badgeId } : {}),
      awardedAt: now,
      awardedBy: AWARDED_BY,
    });
    txn.set(
      userRef,
      { points: admin.firestore.FieldValue.increment(amount) },
      { merge: true }
    );
    txn.set(
      rewardsRef,
      {
        userId: uid,
        points: admin.firestore.FieldValue.increment(amount),
      },
      { merge: true }
    );
  });

  return wrote;
}

export async function initRewardsDoc(uid: string): Promise<void> {
  const ref = db.collection("rewards").doc(uid);
  const snap = await ref.get();
  if (snap.exists) return;
  await ref.set({
    userId: uid,
    points: 0,
    badges: [],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

export async function loadUserStats(uid: string): Promise<UserStats> {
  const userSnap = await db.collection("users").doc(uid).get();
  const data = userSnap.data() ?? {};
  const badges = new Set<string>(
    ((data["badges"] as string[] | undefined) ?? []).map(String)
  );
  const perSubject = data["questionsPerSubject"];
  let maxQuestionsInOneSubject = 0;
  if (perSubject && typeof perSubject === "object") {
    for (const v of Object.values(perSubject as Record<string, unknown>)) {
      const n = typeof v === "number" ? v : Number(v);
      if (!Number.isNaN(n) && n > maxQuestionsInOneSubject) {
        maxQuestionsInOneSubject = n;
      }
    }
  }
  return {
    sessionsCompleted: (data["sessionsCompleted"] as number) ?? 0,
    totalQuestions: (data["totalQuestions"] as number) ?? 0,
    diagramUploads: (data["diagramUploads"] as number) ?? 0,
    streakDays: (data["streakDays"] as number) ?? 0,
    maxQuestionsInOneSubject,
    badges,
  };
}

export function eligibleBadges(stats: UserStats): BadgeId[] {
  const earned: BadgeId[] = [];
  const has = (id: BadgeId) => stats.badges.has(id);
  if (!has("first_step") && stats.sessionsCompleted >= 1) {
    earned.push("first_step");
  }
  if (!has("curious_learner") && stats.totalQuestions >= 50) {
    earned.push("curious_learner");
  }
  if (!has("dedicated_learner") && stats.sessionsCompleted >= 5) {
    earned.push("dedicated_learner");
  }
  if (!has("week_warrior") && stats.streakDays >= 7) {
    earned.push("week_warrior");
  }
  if (!has("month_master") && stats.streakDays >= 30) {
    earned.push("month_master");
  }
  if (!has("diagram_detective") && stats.diagramUploads >= 10) {
    earned.push("diagram_detective");
  }
  if (!has("subject_expert") && stats.maxQuestionsInOneSubject >= 100) {
    earned.push("subject_expert");
  }
  return earned;
}

export async function grantBadges(
  uid: string,
  badgeIds: BadgeId[],
  meta: LedgerMeta
): Promise<void> {
  if (badgeIds.length === 0) return;

  const userRef = db.collection("users").doc(uid);
  const rewardsRef = db.collection("rewards").doc(uid);
  const now = admin.firestore.FieldValue.serverTimestamp();
  const earnedAt: Record<string, admin.firestore.FieldValue> = {};
  for (const id of badgeIds) {
    earnedAt[id] = now;
  }

  await db.runTransaction(async (txn) => {
    txn.set(
      userRef,
      { badges: admin.firestore.FieldValue.arrayUnion(...badgeIds) },
      { merge: true }
    );
    txn.set(
      rewardsRef,
      {
        userId: uid,
        badges: admin.firestore.FieldValue.arrayUnion(...badgeIds),
        earnedAt,
      },
      { merge: true }
    );
  });

  for (const badgeId of badgeIds) {
    const dedupeKey = buildDedupeKey({
      type: "earn_badge",
      badgeId,
      sessionId: meta.sessionId,
      clientRequestId: meta.clientRequestId,
    });
    await awardPoints(uid, "earn_badge", dedupeKey, { ...meta, badgeId });
  }
}

export async function evaluateAndGrantBadges(
  uid: string,
  meta: LedgerMeta
): Promise<void> {
  const stats = await loadUserStats(uid);
  const newBadges = eligibleBadges(stats);
  await grantBadges(uid, newBadges, meta);
}

export async function markDailyLoginRewarded(
  uid: string,
  dateKey: string
): Promise<void> {
  await db
    .collection("users")
    .doc(uid)
    .collection("usage")
    .doc(dateKey)
    .set(
      {
        date: dateKey,
        loginRewarded: true,
        loginRewardedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
}

export async function isDailyLoginRewarded(
  uid: string,
  dateKey: string
): Promise<boolean> {
  const snap = await db
    .collection("users")
    .doc(uid)
    .collection("usage")
    .doc(dateKey)
    .get();
  return snap.data()?.["loginRewarded"] === true;
}

export async function bumpUserCounters(
  uid: string,
  patch: Record<string, unknown>
): Promise<void> {
  await db.collection("users").doc(uid).set(patch, { merge: true });
}
