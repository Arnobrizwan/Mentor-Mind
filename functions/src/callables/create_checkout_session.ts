import { onCall } from "firebase-functions/v2/https";
import { defineSecret, defineString } from "firebase-functions/params";
import { getStripe } from "../lib/stripe_client";
import {
  getStripeCustomerId,
  saveStripeCustomerId,
} from "../lib/subscriptions";
import { unauthenticated, internal } from "../lib/errors";
import { auth } from "../lib/admin";

const stripeSecret = defineSecret("STRIPE_SECRET_KEY");
const priceMonthly = defineString("STRIPE_PRICE_MONTHLY");
const successUrl = defineString("STRIPE_CHECKOUT_SUCCESS_URL", {
  default: "mentorminds://subscription/success",
});
const cancelUrl = defineString("STRIPE_CHECKOUT_CANCEL_URL", {
  default: "mentorminds://subscription/cancel",
});

/** PAY-06 — Stripe Checkout in external browser (returns session URL). */
export const createCheckoutSession = onCall(
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
    const user = await auth.getUser(uid);
    const email = user.email;
    if (!email) {
      throw internal("Account email required for checkout");
    }

    const stripe = getStripe();
    let customerId = await getStripeCustomerId(uid);
    if (!customerId) {
      const customer = await stripe.customers.create({
        email,
        metadata: { firebaseUid: uid },
      });
      customerId = customer.id;
      await saveStripeCustomerId(uid, customerId);
    }

    const priceId = priceMonthly.value();
    if (!priceId) {
      throw internal("STRIPE_PRICE_MONTHLY not configured");
    }

    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      customer: customerId,
      line_items: [{ price: priceId, quantity: 1 }],
      success_url: successUrl.value(),
      cancel_url: cancelUrl.value(),
      client_reference_id: uid,
      metadata: { firebaseUid: uid },
      subscription_data: {
        metadata: { firebaseUid: uid },
      },
    });

    if (!session.url) {
      throw internal("Stripe did not return a checkout URL");
    }
    return { url: session.url, sessionId: session.id };
  }
);
