import * as functions from "firebase-functions";
import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import Stripe from "stripe";
import { getStripe } from "../lib/stripe_client";
import { upsertSubscription } from "../lib/subscriptions";
import * as admin from "firebase-admin";

const stripeSecret = defineSecret("STRIPE_SECRET_KEY");
const webhookSecret = defineSecret("STRIPE_WEBHOOK_SECRET");

function uidFromSubscription(sub: Stripe.Subscription): string | null {
  const meta = sub.metadata?.["firebaseUid"];
  if (typeof meta === "string" && meta.length > 0) return meta;
  return null;
}

function mapStripeStatus(
  status: Stripe.Subscription.Status
): "active" | "cancelled" | "past_due" | "trialing" | "inactive" {
  switch (status) {
    case "active":
      return "active";
    case "trialing":
      return "trialing";
    case "past_due":
    case "unpaid":
      return "past_due";
    case "canceled":
      return "cancelled";
    default:
      return "inactive";
  }
}

async function syncSubscription(sub: Stripe.Subscription): Promise<void> {
  const uid = uidFromSubscription(sub);
  if (!uid) {
    functions.logger.warn("stripe webhook: missing firebaseUid metadata", {
      subId: sub.id,
    });
    return;
  }
  const status = mapStripeStatus(sub.status);
  const tier =
    status === "active" || status === "trialing" ? "premium" : "free";
  await upsertSubscription(uid, {
    tier,
    status,
    provider: "stripe",
    providerSubscriptionId: sub.id,
    providerCustomerId:
      typeof sub.customer === "string" ? sub.customer : sub.customer?.id,
    currentPeriodStart: admin.firestore.Timestamp.fromMillis(
      sub.current_period_start * 1000
    ),
    currentPeriodEnd: admin.firestore.Timestamp.fromMillis(
      sub.current_period_end * 1000
    ),
    cancelAtPeriodEnd: sub.cancel_at_period_end,
  });
}

/** PAY-02 — Stripe webhook (subscription lifecycle). */
export const stripeWebhook = onRequest(
  {
    region: "asia-south1",
    secrets: [stripeSecret, webhookSecret],
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }
    const sig = req.headers["stripe-signature"];
    if (!sig || typeof sig !== "string") {
      res.status(400).send("Missing stripe-signature");
      return;
    }
    const stripe = getStripe();
    let event: Stripe.Event;
    try {
      const rawBody = req.rawBody;
      event = stripe.webhooks.constructEvent(
        rawBody,
        sig,
        webhookSecret.value()
      );
    } catch (err) {
      functions.logger.error("stripe webhook signature failed", {
        err: err instanceof Error ? err.message : String(err),
      });
      res.status(400).send("Webhook Error");
      return;
    }

    try {
      switch (event.type) {
        case "customer.subscription.created":
        case "customer.subscription.updated": {
          const sub = event.data.object as Stripe.Subscription;
          await syncSubscription(sub);
          break;
        }
        case "customer.subscription.deleted": {
          const sub = event.data.object as Stripe.Subscription;
          const uid = uidFromSubscription(sub);
          if (uid) {
            await upsertSubscription(uid, {
              tier: "free",
              status: "cancelled",
              provider: "stripe",
              providerSubscriptionId: sub.id,
              cancelAtPeriodEnd: true,
            });
          }
          break;
        }
        default:
          break;
      }
      res.json({ received: true });
    } catch (err) {
      functions.logger.error("stripe webhook handler failed", {
        type: event.type,
        err: err instanceof Error ? err.message : String(err),
      });
      res.status(500).send("Handler error");
    }
  }
);
