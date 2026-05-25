import { onCall } from "firebase-functions/v2/https";
import { defineSecret, defineString } from "firebase-functions/params";
import { getStripe } from "../lib/stripe_client";
import { getStripeCustomerId } from "../lib/subscriptions";
import { unauthenticated, internal } from "../lib/errors";

const stripeSecret = defineSecret("STRIPE_SECRET_KEY");
const returnUrl = defineString("STRIPE_PORTAL_RETURN_URL", {
  default: "mentorminds://subscription/portal",
});

/** PAY-07 — Stripe Customer Portal (manage/cancel subscription). */
export const createPortalSession = onCall(
  {
    region: "asia-south1",
    enforceAppCheck: true,
    secrets: [stripeSecret],
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw unauthenticated("Authentication required");
    }
    const customerId = await getStripeCustomerId(uid);
    if (!customerId) {
      throw internal("No Stripe customer on file");
    }
    const stripe = getStripe();
    const session = await stripe.billingPortal.sessions.create({
      customer: customerId,
      return_url: returnUrl.value(),
    });
    return { url: session.url };
  }
);
