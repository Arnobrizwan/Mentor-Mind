import * as admin from "firebase-admin";
import { db } from "./admin";
import { setPremiumClaim } from "./claims";

export type SubscriptionTier = "free" | "premium";
export type SubscriptionStatus =
  | "active"
  | "cancelled"
  | "past_due"
  | "trialing"
  | "inactive";

export type SubscriptionDoc = {
  userId: string;
  tier: SubscriptionTier;
  status: SubscriptionStatus;
  currentPeriodStart?: admin.firestore.Timestamp;
  currentPeriodEnd?: admin.firestore.Timestamp;
  provider: "stripe" | "manual";
  providerSubscriptionId?: string;
  providerCustomerId?: string;
  cancelAtPeriodEnd?: boolean;
  metadata?: { grantedBy?: string };
  updatedAt: admin.firestore.Timestamp;
};

export async function upsertSubscription(
  uid: string,
  patch: Partial<SubscriptionDoc>
): Promise<void> {
  const ref = db.collection("subscriptions").doc(uid);
  const now = admin.firestore.Timestamp.now();
  const base: SubscriptionDoc = {
    userId: uid,
    tier: "free",
    status: "inactive",
    provider: "manual",
    updatedAt: now,
    ...patch,
  };
  await ref.set(
    {
      ...base,
      updatedAt: now,
    },
    { merge: true }
  );

  const tier = base.tier;
  const isActive =
    tier === "premium" &&
    (base.status === "active" || base.status === "trialing");

  await db.collection("users").doc(uid).set(
    {
      subscriptionType: isActive ? "premium" : "free",
    },
    { merge: true }
  );

  await setPremiumClaim(uid, isActive);
}

export async function applyManualPremium(
  uid: string,
  isPremium: boolean,
  grantedBy: string
): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  if (isPremium) {
    const end = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + 30 * 24 * 60 * 60 * 1000
    );
    await upsertSubscription(uid, {
      tier: "premium",
      status: "active",
      provider: "manual",
      currentPeriodStart: now,
      currentPeriodEnd: end,
      cancelAtPeriodEnd: false,
      metadata: { grantedBy },
    });
  } else {
    await upsertSubscription(uid, {
      tier: "free",
      status: "cancelled",
      provider: "manual",
      cancelAtPeriodEnd: false,
      metadata: { grantedBy },
    });
  }
}

export async function getStripeCustomerId(uid: string): Promise<string | null> {
  const snap = await db.collection("subscriptions").doc(uid).get();
  const id = snap.data()?.["providerCustomerId"];
  return typeof id === "string" ? id : null;
}

export async function saveStripeCustomerId(
  uid: string,
  customerId: string
): Promise<void> {
  await db.collection("subscriptions").doc(uid).set(
    {
      userId: uid,
      providerCustomerId: customerId,
      provider: "stripe",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}
