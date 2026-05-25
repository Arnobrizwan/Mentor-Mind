# Phase 5 — Stripe Subscriptions + Premium Claims + Admin Panel

**Status:** Complete (2026-05-25)  
**Depends on:** Phase 4

## Delivered

### Backend (`functions/`)
- `lib/subscriptions.ts` — v2-ready `/subscriptions/{uid}` upsert + manual grant
- `lib/stripe_client.ts`, `lib/claims.ts` — `setPremiumClaim`, `setUserRoleClaim`
- `lib/admin_guard.ts` — `requireAdmin` (claim + Firestore role)
- Callables: `createCheckoutSession`, `createPortalSession`, `setPremium`, `sendBroadcast`
- HTTP: `stripeWebhook` — `customer.subscription.created|updated|deleted`
- Rules: `/subscriptions/{uid}` read owner/admin, write false

### Client (`lib/`)
- `SubscriptionsRepository`, `BillingRepository`, `AdminRepository`
- Profile: Stripe Checkout + Portal via `url_launcher` (external Safari)
- `ChatViewModel`: premium from `/subscriptions` stream + token refresh
- Image attach: free for all (3/day server cap); search: full history for all (PAY-10)
- `AdminScreen`: 5-tab shell (Users grant/revoke premium, Notifications broadcast)

## Deferred to Phase 6/7
- ADMN-02 full stats grid + recent activity feed
- ADMN-04/05 material upload + Storage + FCM on upload (Phase 6 FCM)
- `invoice.paid` / `invoice.payment_failed` webhook handlers (PAY-02 partial)
- Yearly Stripe price (monthly only in v1.0)

## Deploy

```bash
firebase functions:secrets:set STRIPE_SECRET_KEY --project mentor-mind-aa765
firebase functions:config:set stripe.price_monthly=price_xxx  # or params in Firebase console
firebase deploy --only firestore:rules,functions --project mentor-mind-aa765
```

Configure Stripe webhook endpoint → `stripeWebhook` URL (see BACKEND_SETUP.md §Phase 5).
