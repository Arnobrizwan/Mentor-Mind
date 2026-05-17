# Pitfalls Research — MentorMinds v1.0 Hardening

**Domain:** Brownfield Flutter + Firebase iOS app adding Cloud Functions proxy, App Check, server-authoritative rewards, screen-layer refactor, FCM iOS wiring, and lint burndown.
**Researched:** 2026-05-17
**Confidence:** MEDIUM (web research tools were unavailable in this session — claims are grounded in training-cutoff knowledge of Firebase/Flutter SDKs through Jan 2026 and the actual repo at `/Users/arnobrizwan/Mentor-Mind`. Items marked LOW should be re-verified against current docs before execution.)

> **Scope contract.** This file deliberately does NOT re-list items already in `.planning/codebase/CONCERNS.md` (e.g. the bare leaked service-account, the avatar storage-rule mismatch, the Firestore client-side `FieldValue.increment` being gameable — those are *the problems we are solving*). It catalogs the **new mistakes** that are easy to make **while solving them**.

---

## Critical Pitfalls

### Pitfall 1 — App Check enforcement turned on in Console before debug tokens are registered for every active device

**What goes wrong:**
The moment "Enforce" is clicked in Firebase Console for Firestore / Storage / Functions, every running build that doesn't present a valid App Check token starts getting `403 / unauthorized` from the SDK. On iOS that means: the developer's own simulator stops being able to read `/users/{uid}`, TestFlight builds installed before the App Attest provider was wired up start failing silently, and any CI integration test that hits real Firestore breaks. Because the failure shows up as a generic `permission-denied` from the Firestore SDK (App Check rejection is reported on the *underlying* request, not as a distinct error class), the team wastes an afternoon chasing phantom rules bugs.

**Why it happens:**
The Firebase Console UI presents "Enforce" as a single toggle per service and does not surface "X of Y recent requests would fail." Devs assume enforcement is a no-op if their own client is configured — but `flutterfire configure` does not wire App Check; that's a separate `firebase_app_check` package + per-platform native setup. The iOS simulator cannot use DeviceCheck or App Attest at all and *requires* a debug token, which must be registered manually in the Console after first launch.

**How to avoid:**
1. Stage in three steps: (a) install `firebase_app_check`, initialize the **debug provider** in dev / **AppAttestProvider** in release, ship to TestFlight, wait one week; (b) in Console, view the App Check **Metrics** tab for Firestore/Storage/Functions and confirm ≥ 99% of requests are "verified" (not "unverified" or "outdated client"); (c) only then click "Enforce."
2. For the iOS simulator: on first launch in debug mode, `firebase_app_check` prints a UUID-like debug token to Xcode console. Each developer copies that token into Firebase Console → App Check → Apps → iOS app → ⋮ → "Manage debug tokens." **Tokens are per-simulator-instance** — erasing the simulator regenerates one. Document this step in `BACKEND_SETUP.md`.
3. Set `firebase_app_check` to use `AppAttestProvider` (not `DeviceCheckProvider`) for iOS release builds — DeviceCheck has been deprecated as the recommended attestor since ~2022; App Attest is the current iOS 14+ attestor.
4. In CI: use a CI-specific debug token (registered once, stored as a GitHub Actions secret), passed via `--dart-define=APP_CHECK_DEBUG_TOKEN=…`. Never enforce App Check against an environment whose CI cannot present a token.

**Warning signs:**
- Firestore reads that worked yesterday now return `permission-denied` from devices that did *not* update.
- App Check Metrics tab shows < 95% verified requests, but enforcement was already turned on.
- TestFlight crash-free sessions drop suddenly while client code hasn't changed.

**Phase to address:** Backend hardening phase (Phase 3 per CONCERNS.md numbering). Wire App Check **before** Cloud Functions, so functions are App-Check-aware from day one.

---

### Pitfall 2 — Cloud Function points/rewards endpoint is replay-vulnerable

**What goes wrong:**
The natural first cut of `awardPoints` is an HTTPS callable that takes `{reason: 'complete_session'}` and increments `users/{uid}.points` by the matching amount. A user with a debug build can call it 1000 times in a loop and earn 2000 points for one completed session. App Check stops *non-app* callers but does nothing against the legitimate app doing legitimate-looking RPCs in a tight loop. The current client (`lib/features/tutor/chat_viewmodel.dart:511-542`) does exactly the pattern that maps cleanly to this vulnerable shape.

**Why it happens:**
Devs think "I moved the increment server-side, so it's safe." But moving the *write* without moving the *trigger condition* just relocates the trust boundary by one hop. The actual question is: how does the server know the session was completed? If the answer is "the client said so," the server is no safer than the client.

**How to avoid:**
1. Make awards **event-derived**, not action-requested. Don't expose `awardPoints({reason})`. Instead, write a Firestore-triggered function on `/sessions/{sid}` documents (`onWrite` or `onUpdate`) that inspects the *delta* — when `status` flips from `active` to `completed` for the first time, award. Idempotency is enforced by checking a server-side flag (`pointsAwarded: true`) on the same document inside a transaction.
2. For per-message points (the current pattern at `chat_viewmodel.dart:521`), trigger off the message write itself, not a separate RPC. The message write *is* the proof of work.
3. Every award must write an **append-only audit row** to `/rewards/{uid}/ledger/{autoId}` with `{type, amount, sourceDocPath, sourceDocSnapshot, awardedAt: serverTimestamp(), awardedBy: 'cloudFunction:awardPoints@v1'}`. The current `history: FieldValue.arrayUnion([...])` pattern at `chat_viewmodel.dart:528-533` is unbounded array growth (Firestore document hard limit: 1 MiB) and unauditable. Replace with the ledger subcollection.
4. Tighten `firestore.rules:65-70` so `points`, `badges`, `streak`, `usage.messageCount` are immutable from client (`request.resource.data.points == resource.data.points`). The current rule explicitly notes this trade-off (`firestore.rules:9-11`) — close it.
5. For callable functions (e.g. `chatStream` from #3), embed the **session ID** and a **monotonic client message index** in the request. Server rejects if `(sessionId, msgIdx)` was seen in the last 24 h (cache in Memorystore or a tiny Firestore `/rateLimits/{uid}/seen` collection with TTL).

**Warning signs:**
- A user's `points` value can grow without a matching session/message document being written.
- The `history` array on `/rewards/{uid}` is approaching 1 MiB or > 500 entries.
- Cloud Logging shows a single uid calling `awardPoints` > 10× per minute.

**Phase to address:** Backend hardening phase (Phase 3). Must ship together with the rules tightening — do not deploy the function without simultaneously deploying rules that block the old client path, or you'll have double-writes (client + function) and inflated point totals.

---

### Pitfall 3 — Free-tier daily quota leaks across the midnight boundary because the server uses the wrong clock

**What goes wrong:**
The current quota key is `_todayKey()` (`chat_viewmodel.dart:500`), computed on the client. When the Cloud Function takes over, the natural reflex is to compute "today" on the server using `new Date()` in Functions runtime — which is **UTC**. A student in Dhaka (UTC+6) sends their 10th message at 5:45 AM local time, which is 23:45 UTC the *previous* day in the server's view. The server says "10/10 used." Twenty minutes later, at 6:05 AM local (00:05 UTC, new day), they retry and the server says "0/10 used." Quota is now ambiguously partially-rolled-over. Either the student sees the quota reset 6 hours late, or — worse — premium downgrades mid-day get refunded a "free day" they already burned.

**Why it happens:**
- Cloud Functions run in a UTC container. `Date.now()` and Firestore `serverTimestamp()` are both UTC.
- The MentorMinds user base is timezone-clustered (Bangladesh, UTC+6) but not single-zone (BD diaspora in Malaysia UTC+8, UK UTC+0/+1, US Eastern UTC-5/-4).
- The free-tier message counter (`chat_viewmodel.dart:137-139`) and the streak counter (`dashboard_viewmodel.dart:551`) both use day-keys but neither documents the timezone semantics.

**How to avoid:**
1. **Pick one rule and write it down in code as a constant:** `const QUOTA_TZ = 'Asia/Dhaka';` (or `'user-profile-tz'` if you collect that on onboarding, which v1.0 does not). Use that single source of truth in both the Cloud Function and the client banner.
2. In the Cloud Function, compute the day key with an explicit IANA timezone, e.g. (Node 20+): `new Intl.DateTimeFormat('en-CA', { timeZone: QUOTA_TZ }).format(new Date())` → `"2026-05-17"`. Do **not** rely on `toISOString().slice(0,10)`.
3. Mirror the same logic on the client `_todayKey()` so the banner ("3 of 10 messages left") matches what the server enforces — otherwise the UX drift will make support tickets unreadable.
4. For premium downgrades mid-day: when a user downgrades, **do not retroactively credit usage** — the field they downgraded from already used the API quota you paid for. Simply set their `tier: 'free'` and let the quota take effect from the next message. Document this in the upgrade modal copy ("Premium until X; free-tier limits resume X+1").
5. Streaks have the same problem. The streak math in `dashboard_viewmodel.dart:551` must use the same `QUOTA_TZ` constant, or users will lose streaks for "missing" a day they actually used.

**Warning signs:**
- Support tickets at ~6 AM Dhaka time about quota resetting late.
- A user's `usage/2026-05-17` doc has both `messageCount: 10` and a `lastMessageAt` timestamp from 2026-05-18 06:00 BDT.
- Quota analytics show suspicious "X.5 day" usage patterns.

**Phase to address:** Backend hardening phase (Phase 3), as part of the quota-enforcement Cloud Function. Define `QUOTA_TZ` as a shared constant **before** writing either the client or the function.

---

### Pitfall 4 — Hot-document contention on the quota counter when a user (or test) hammers the AI tutor

**What goes wrong:**
`/users/{uid}/usage/{dateKey}.messageCount` is the rate-limit counter. The natural Cloud Function shape is: read counter → check < 10 → call Gemini → `update({messageCount: increment(1)})`. Under burst load (test harness, double-tap, JS-side retries), the same document is touched > 1 write/sec. Firestore's per-document write ceiling is ~1 write/sec sustained before contention causes 500ms+ latency tails. The user-visible symptom is "chat hangs for 3 seconds" intermittently. Worse, the read-then-write pattern is non-atomic — two concurrent function invocations both read `messageCount: 9`, both pass the check, both write `10`, both call Gemini → the user got 11 messages for free.

**Why it happens:**
Devs forget Firestore is not a relational DB. The "transactions are easy" pitch glosses over the fact that the limit is *per-document*, not per-collection. Single-user per-day counters are fine in steady state (a human can't send 60 msg/min) but break under (a) integration tests, (b) malicious users with a script, (c) retry storms after a transient Gemini error.

**How to avoid:**
1. Use a Firestore **transaction** for the read-check-write sequence — not a plain `update({increment(1)})`. The transaction's optimistic-concurrency retry will serialize the two racing invocations and the second one will see `messageCount: 10` and reject.
2. For premium users (no limit), skip the counter entirely — don't pay the latency cost on writes you don't need to check.
3. Set a **client-side debounce** of 500ms on the send button (`tutor_screen.dart`), so a double-tap doesn't generate two requests. This is defense-in-depth, not the actual fix.
4. Add a **circuit-breaker** in the function: if `incrementUsage` throws `aborted` (transaction conflict) more than 3× in a single invocation, return `resource-exhausted` to the client with a "Try again in a moment" banner instead of swallowing the error.
5. For integration tests, use a per-test uid (`integ-test-${runId}-${testName}`) so concurrent test runs don't contend on the same `usage` doc.

**Warning signs:**
- P99 latency on `chatStream` Cloud Function > 2× P50.
- Cloud Logging shows `Code: 10 (ABORTED)` errors on the usage write.
- A user's `messageCount` for a day exceeds the configured quota.

**Phase to address:** Backend hardening phase (Phase 3). The transactional pattern needs to land in the *first version* of the function, not as a follow-up — retrofitting after deploy is high-risk because the function will already be in the hot path.

---

### Pitfall 5 — `lib/features/` → `lib/presentation/screens/` refactor done in the same PR as functional changes

**What goes wrong:**
The user's spec calls for the path move (`PROJECT.md:33` Active item). The 11 import lines in `app_router.dart:5-15` plus ~30 file moves create thousands of diff lines. If any *behavioral* change rides along (e.g. "while we're at it, replace `withOpacity` in those files"), the PR becomes un-reviewable. Git's rename detection breaks once the file body also changes — `git log --follow` loses history on the moved files. The reviewer cannot tell a benign import-path change from a semantic regression. Six weeks later someone bisects a bug and the bisect lands on the refactor commit, which "touched everything," and the actual cause is lost in the noise.

**Why it happens:**
The refactor is mechanical and boring; humans want to make it "worth the PR" by bundling other cleanups. The IDE refactor tooling makes "rename + edit" feel atomic, but the version control system does not see it that way.

**How to avoid:**
1. Refactor in **two strictly separate PRs, in this order**:
   - **PR A — Pure move.** Only `git mv` (or IDE Move-with-update-imports). Zero edits to any moved file's body. Zero new files. Update `app_router.dart` imports. `flutter analyze` and `flutter test` must produce **identical** output before and after (paste both into the PR description). No `withOpacity` fixes, no `prefer_const` fixes, no docstring edits.
   - **PR B — Lint burndown and any cleanup**, only after PR A merges.
2. Use IDE refactor (Android Studio's "Move with refactor"), not manual `mv`. This preserves Riverpod / GoRouter cross-references that `sed` would miss.
3. Run `git diff PR_A --stat` and verify it's ≈ 30 file moves with `==0` lines changed inside the moved files (only path-only renames). If any moved file shows non-zero body changes, reject the PR.
4. Pin Git rename-detection threshold high in the PR description: reviewers should set `git config diff.renames copies` and use `git log --follow lib/presentation/screens/tutor/tutor_screen.dart` to confirm history follows through.
5. Do **not** mix the refactor with the dependency upgrade (CONCERNS #2), the codegen decision (CONCERNS #9), or the large-file split (CONCERNS #12). Each is its own PR.

**Warning signs:**
- A PR titled "Move to presentation/screens" has > 1000 changed lines in the diff body (not counting renames).
- `git log --follow` on a moved file shows history starting at the move commit.
- The refactor PR's CI run shows different `flutter analyze` output count than the parent branch.

**Phase to address:** Layout & polish phase (Phase 2). PR A blocks PR B blocks the 12-screen spec polish work. Sequence matters — do not start the spec work on a half-moved tree.

---

### Pitfall 6 — `withOpacity` → `withValues(alpha:)` sed-replace introduces sRGB gamma shifts and visual regressions

**What goes wrong:**
The mechanical fix in CONCERNS.md #3 is "sed-replace `.withOpacity(X)` → `.withValues(alpha: X)`." For most call sites this is a no-op. But `withValues` operates in **wide-gamut color space** when the surrounding `Color` was originally constructed in extended sRGB (any `Color.fromARGB` with the default colorspace), and the resulting compositing math is subtly different from the legacy `withOpacity` path that always operated in sRGB. On dark backgrounds with translucent overlays — exactly the gradient + glass-morphism style the spec calls for (`PROJECT.md:98` brand: `#1A3C8F primary / #00C9A7 accent`) — the change can shift mid-tones by 1–3% lightness. The shimmer skeletons (Screen 07 in the spec) and the badge celebration overlay (Screen 10) are the most visible victims. Designers will not be able to articulate "what changed" but will flag the screens as "off-brand."

**Why it happens:**
The deprecation message frames the migration as a precision improvement (true) but doesn't warn that the precision improvement *changes* the rendered output. CONCERNS.md #3 specifically lists `lib/features/tutor/tutor_screen.dart` with 15+ hits and `lib/features/splash/splash_screen.dart` with the gradient (lines 180–226). These are the highest-risk files.

**How to avoid:**
1. Do the migration **per-file**, not repo-wide, and capture **golden screenshots before and after** each file's migration. Flutter's `golden_toolkit` package (or `flutter test --update-goldens`) is the right tool. The pre-migration goldens are the contract.
2. Restrict the regex to the simple case: `\.withOpacity\((\d+\.\d+|\d+)\)` → `.withValues(alpha: $1)`. Do **not** auto-rewrite call sites where the opacity is a variable or an expression — review those by hand.
3. For the splash gradient (`splash_screen.dart:180,211,214,220,226`) and the tutor screen heavy cluster (`tutor_screen.dart:332,486,…`), do **not** sed-replace at all. Refactor those to use `Color.fromARGB` with the alpha pre-baked, which removes the ambiguity entirely and reads more clearly.
4. Run the migration on simulator + on a real device (iPhone 14/15-class — Bangladesh student-popular devices). The wide-gamut shift is invisible on the simulator but visible on a P3-capable display.
5. Add a CI step: `flutter test --tags golden` runs the golden suite. PR cannot merge if goldens regress without an explicit update commit.

**Warning signs:**
- Designer / product owner says "the splash looks different but I can't say why."
- Golden tests fail with sub-pixel diffs in the alpha channel.
- A11y contrast checker score drops by 0.05–0.1 on previously passing screens.

**Phase to address:** Foundation cleanup (Phase 1), bundled with the lint burndown — but with the per-file golden discipline above. Do **not** ship the migration as a single repo-wide commit.

---

### Pitfall 7 — FCM iOS topic subscription called before APNs token is received (or before user grants notification permission), causing silent topic-subscribe failures

**What goes wrong:**
The natural shape of FCM init in `main.dart` is: `await FirebaseMessaging.instance.subscribeToTopic('all_users')` somewhere near `Firebase.initializeApp`. On iOS this **silently no-ops** (or queues forever) if (a) the user hasn't been prompted for notification permission yet, or (b) the APNs device token hasn't arrived from Apple's push service yet. The future returned by `subscribeToTopic` resolves successfully — there is no error — but the topic subscription never propagates to FCM's backend. Six weeks later marketing sends a topic broadcast and 30% of iOS users don't get it. There are no client-side logs because the SDK returned success.

**Why it happens:**
- iOS push permission is opt-in (`requestPermission()`) and the user can deny it. Subscribing to a topic before the user grants permission is meaningless on iOS because FCM needs the APNs token to associate the topic with a device.
- The APNs token arrives asynchronously via `FirebaseMessaging.instance.onTokenRefresh` (and the initial `getToken()` may return null on first launch even after permission grant, until APNs hands back the token — typically <1s but not guaranteed).
- Devs assume "I called `subscribeToTopic` and got no exception, therefore subscribed."

**How to avoid:**
1. Sequence is strict, never reorder: (a) `Firebase.initializeApp`, (b) `requestPermission(alert: true, badge: true, sound: true)` — show a rationale dialog **before** this so users don't blind-deny, (c) `await getToken()` and **only proceed if non-null**, (d) `await getAPNSToken()` (FlutterFire-specific, returns the underlying APNs token; null until APNs delivers it — poll with backoff up to 10s, fall back to "try again later"), (e) `subscribeToTopic(...)`.
2. Wrap topic subscription in a retry layer that re-runs on `onTokenRefresh`. APNs tokens can rotate (app reinstall, restore from backup, iOS upgrade) — the topic subscription on the *old* token does not auto-migrate.
3. For topics that should only apply to opted-in users (the spec's notification screen at Screen 11): record the intended topic set in `/users/{uid}.fcmTopics: ['announcements', 'physics_updates', …]` in Firestore, and have a Cloud Function reconcile that intent to FCM via the Admin SDK when the doc changes. This way, even if the client-side subscribe failed, the function will retry on the next reconciliation pass.
4. Validate end-to-end before claiming "FCM is wired": send a test message via Firebase Console → Cloud Messaging → "Send test message" to a real device's FCM token (not topic). If that fails, no amount of topic work matters.
5. Use **either** APNs auth keys (`.p8` file, recommended — Firebase Console → Project Settings → Cloud Messaging → Apple app configuration → APNs Authentication Key) **or** APNs certificates (`.p12` file, legacy — expires yearly). Never both. Auth keys do not expire and work across all Apple bundle IDs on the account; certificates require renewal and are per-bundle-id. Pick auth keys for v1.0.
6. Implement both `FirebaseMessaging.onMessage` (foreground) **and** `FirebaseMessaging.onBackgroundMessage` (background — must be a top-level function, not a closure; must call `Firebase.initializeApp()` itself; must be annotated `@pragma('vm:entry-point')`). Devs frequently miss the entry-point pragma in release mode → background handler is tree-shaken out of release builds → silently broken in TestFlight only.
7. For iOS, ensure the Runner target has the **Push Notifications capability** enabled and **Background Modes → Remote notifications** checked. These are in the Xcode project, not the Flutter pubspec — they will not be set by `flutter pub get`. Check `ios/Runner.xcodeproj/project.pbxproj` for `aps-environment` entitlement.

**Warning signs:**
- Sending a topic message via Firebase Console reports "Sent" but device receives nothing.
- `FirebaseMessaging.instance.getToken()` returns null on first launch even though permission was granted.
- iOS device receives notifications in development but not after TestFlight install.
- Background handler logs don't appear in release builds.

**Phase to address:** Backend hardening / messaging phase. Must coexist with the Cloud Function work so the reconciler can deploy alongside the client subscription logic.

---

### Pitfall 8 — First Cloud Functions deploy unintentionally enables Cloud Build / Artifact Registry / Cloud Run billing

**What goes wrong:**
`firebase deploy --only functions` on a fresh project requires upgrading to the **Blaze (pay-as-you-go) plan**. Gen-2 functions specifically deploy as Cloud Run services behind the scenes, consuming Cloud Build, Artifact Registry storage, and Cloud Run compute. A solo dev (`PROJECT.md:87`) on the free Spark plan thinks "Cloud Functions has a generous free tier" and is correct (2M invocations/month free) — but the *build* of the function image, the *storage* of the resulting container in Artifact Registry, and the *Cloud Run min-instances* setting all bill separately and have no free tier on the build/storage side. Setting `minInstances: 1` on the chat function (to mitigate cold starts) silently costs ~$25/month even at zero traffic. Letting Artifact Registry accumulate old container versions costs another few dollars per month per function.

**Why it happens:**
- Firebase Console's "Functions" page does not surface the underlying Cloud Run / Artifact Registry charges; they appear under "Cloud Run" and "Artifact Registry" in GCP billing.
- The migration prompt to Blaze does not warn about Artifact Registry storage.
- The `firebase-tools` CLI happily redeploys without garbage-collecting old container versions.

**How to avoid:**
1. **Before the first deploy:** in GCP Console → Billing → Budgets & Alerts, create a **$10/month budget alert** on the project. This is the canary.
2. Use **`minInstances: 0`** in v1.0 (the default). Cold start on a Node 20 function is ~1.5–3s — acceptable for a free-tier AI tutor where the first response is already gated on a Gemini API call. Only set `minInstances` ≥ 1 if real metrics show cold-start tail latency is hurting UX, and budget accordingly.
3. Set `maxInstances: 10` (or similar) on every function to cap runaway scaling under abuse — without this, a malicious user could trigger a $1000+ surprise bill in a day.
4. Enable Artifact Registry **cleanup policy**: GCP Console → Artifact Registry → repo → Cleanup policies → "Keep most recent N versions" with N=3.
5. Pick the function **region carefully and once**. For Bangladesh users, the closest GCP region is **`asia-south1` (Mumbai)** — ~50–100ms latency vs ~200–300ms from `us-central1`. The default `us-central1` looks "fine in dev" because the dev is testing from anywhere. Set explicitly: `functions.region('asia-south1').https.onCall(...)` for Gen 1, or `setGlobalOptions({region: 'asia-south1'})` for Gen 2. **Changing region later requires redeploying and updating every client `httpsCallable` reference.**
6. Set per-function `memory` low (256MiB for the proxy is plenty), `timeout` low (60s for streaming, 30s for non-streaming). Higher memory bills more per-100ms.
7. Use a **separate Firebase project** for dev/CI (`mentor-mind-dev`) vs prod, so cost overruns in test don't hit production budget.

**Warning signs:**
- GCP billing for the month shows non-zero "Cloud Build" or "Artifact Registry Standard Storage" charges with zero user traffic.
- A function's invocation count for the day is high but the chat usage analytics are low (= someone is hammering the endpoint).
- Latency for users physically in Bangladesh is consistently 200ms+ higher than what the dev sees locally.

**Phase to address:** Backend hardening (Phase 3) — must do the region + budget + cleanup-policy setup **on day zero of the Functions work**, not as a follow-up.

---

### Pitfall 9 — Premium tier data model designed for "always free for v1.0" makes adding bKash/Stripe later require a schema refactor

**What goes wrong:**
The spec defers payments (`PROJECT.md:73` Out of Scope). The path of least resistance is to store `users/{uid}.tier: 'free' | 'premium'` and gate features on that string. Six months later, bKash integration arrives. Now we need: subscription period (`startDate`, `endDate`, `autoRenew`), payment provider (`bkash`, `stripe`, `manual`), transaction history, refund/dispute tracking, grace period for failed payments, proration on upgrade mid-period, trial period flag, promo code attribution. Each of these has rules implications (who can write `endDate`? only a webhook from the payment provider — that means a Cloud Function with a specific service-account identity). Retrofitting requires a Firestore data migration on every active user, plus rewriting every "is premium?" check in the client.

**Why it happens:**
"We're not doing payments in v1.0" gets read as "we don't need to think about payment data shape." But the *gate* exists today (the upgrade modal at `PROJECT.md:53`), and the *grant mechanism* (manual admin grant for testing) will exist in v1.0. The choice today is: do you make the v1.0 grant mechanism shaped like a future webhook, or shaped like a debug toggle?

**How to avoid:**
Design the data model for v2.0, but only implement the v1.0 surface:
1. Store the gate as a **subscription record**, not a string field. New collection: `/subscriptions/{uid}` (one doc per user, doc id = uid for fast lookup, but the *concept* is "active subscription record for this user").
2. Schema (write down today, only populate the fields v1.0 uses):
   ```
   /subscriptions/{uid}
     tier: 'free' | 'premium'           // v1.0
     status: 'active' | 'cancelled' | 'past_due' | 'trialing'  // v1.0 only sets 'active' or 'cancelled'
     currentPeriodStart: Timestamp      // v1.0: set on grant
     currentPeriodEnd: Timestamp        // v1.0: set far in future for manual grants
     provider: 'manual' | 'bkash' | 'stripe' | 'apple_iap'     // v1.0: only 'manual'
     providerSubscriptionId: string?    // v1.0: null
     cancelAtPeriodEnd: boolean         // v1.0: false
     metadata: { grantedBy: 'admin:{uid}', reason: '...' }     // v1.0: populate for audit
   ```
3. Client checks `subscription.tier == 'premium' && subscription.status == 'active' && subscription.currentPeriodEnd > now()`. The check is identical whether v1.0 or v2.0.
4. Firestore rules: `/subscriptions/{uid}` is **read-own, write-server-only** from day one. Even in v1.0 with manual grants, the grant goes through an admin Cloud Function (`grantSubscription({uid, durationDays, reason})`). This means when bKash arrives, the webhook is just another caller into the same function with a different `provider` value.
5. Mirror `tier: 'premium'` onto `/users/{uid}.tier` **for query convenience only** (leaderboard filters, etc.), but treat `/subscriptions/{uid}` as the source of truth. Use a Firestore-triggered function on `/subscriptions/{uid}` writes to sync the mirror.
6. Do **not** store the IAP receipt / bKash transaction blob in Firestore. Store the provider's reference ID and re-fetch from the provider when needed (PCI / dispute audit trail belongs at the provider).

**Warning signs:**
- In v1.0 code, the only premium check is `if (user.tier == 'premium')` — no period or status check.
- The admin tool to grant premium writes directly to `/users/{uid}.tier` from the client.
- No `/subscriptions/` collection exists; payment provider integration is being discussed.

**Phase to address:** Backend hardening (Phase 3), specifically when the upgrade modal is wired. The data shape needs to be locked **before** the modal ships, because the modal's "Tap to upgrade" → grant flow defines the API shape.

---

### Pitfall 10 — Integration tests run against real production Firestore, polluting analytics, billing, and rules audit logs

**What goes wrong:**
The path of least resistance for "write an integration test for the new Cloud Function" is to point it at the real `mentor-mind-aa765` project (or worse, a future `mentor-mind-prod`). The test creates a test user, hits the function, asserts the side effects, deletes the test user. Three problems: (a) every test run consumes real Gemini quota and real Cloud Function invocations against billing; (b) test traffic shows up in Firebase Analytics, polluting funnel data; (c) if rules block the test (which they should, if rules are tight), the dev's reflex is to loosen the rules "just for tests" — which then ships to prod. The leaked service-account in `tool/seed/` (CONCERNS #4c) makes this even easier to get wrong because the JSON key for prod is already on disk.

**Why it happens:**
The Firebase Emulator Suite has a real setup cost (install Java, configure ports, write a CI step that boots emulators before tests). Real Firestore "just works." Devs choose the cheaper option until it bites.

**How to avoid:**
1. Default integration test target is the **Firebase Local Emulator Suite** (`firebase emulators:start --only auth,firestore,functions,storage`). Install via `npm install -g firebase-tools` (already a project requirement). Add `firebase.json` `emulators` block.
2. Tests use the emulator's auth bypass (`FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080)`) and a dedicated test-user creator that does **not** hit real Auth.
3. Keep one — exactly one — **smoke test** that hits a real, dedicated `mentor-mind-dev` project (never prod). Tag it `@integration_real` and exclude from default test runs. Run it once before each release on a clean test account, then delete the test account.
4. Rules must be tested against the emulator using `@firebase/rules-unit-testing` (Node-side test harness). This is the *only* way to verify rules without deploying. Make the rules-test suite a CI gate.
5. For Gemini quota: stub the Gemini call in the function under test via a mock provider (`process.env.GEMINI_PROVIDER === 'mock'`). The real-Gemini test runs only in the release smoke suite.
6. Do **not** put `service-account.json` (CONCERNS #4c) in any path the test harness reads from. Tests use the emulator, which needs no credentials.

**Warning signs:**
- CI run consumes Gemini API quota.
- Firebase Analytics for the prod project shows a daily "test_user_123" event.
- Rules were loosened ("just for the integration test") and never tightened.
- Test users persist in real Auth after test runs.

**Phase to address:** Foundation cleanup (Phase 1) for the emulator scaffolding; backend hardening (Phase 3) for the rules-test suite alongside the Cloud Functions.

---

## Technical Debt Patterns

Shortcuts that look reasonable but create long-term problems for *this specific* migration.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Keep `lib/features/` alongside new `lib/presentation/screens/` "for now" during the move | No huge PR | Two competing layouts, broken `git log --follow`, confused contributors for months | Never — finish the move in one PR or do not start |
| Set `minInstances: 1` on the chat function to "fix" cold starts before measuring them | Lower P99 latency in dev | ~$25/month per function with zero traffic; bill scales with maxInstances cap | Only after metrics show cold-start P99 > 4s sustained for real users |
| Ship App Check with the **debug** provider in release builds to "avoid breaking simulator devs" | Simulator keeps working | App Check provides zero protection in production; budget for malicious traffic | Never |
| Store the Gemini API key in a Cloud Function environment variable via `functions:config:set` (Gen 1 legacy) | Quick to set up | `functions:config` is deprecated; key visible to anyone with Editor IAM; no rotation audit trail | Never for prod — use **Google Secret Manager** with the function's runtime service account granted `Secret Accessor` |
| Use Firestore arrays (`history: arrayUnion(...)`) for the rewards ledger | One-line write | 1 MiB document limit; unbounded growth; no per-entry rules | Only for `< 50` immutable entries; switch to subcollection before that |
| Implement the `awardPoints` Cloud Function as a callable HTTPS function (client-triggered) | Easy to wire from client | Trivially replayable; security falls back on rate-limiting heuristics | Only when paired with an idempotency key + replay cache |
| Burn down all 105 `withOpacity` deprecations in a single sed-replace PR | One PR, done | Visual regressions ship un-reviewed across 12 screens | Never without per-file golden tests |
| Keep `flutter_riverpod` as transitive (the current state per CONCERNS #3) "because it works" | No pubspec edit | Will break when `hooks_riverpod` drops the re-export (Riverpod 3.x already did) | Never — add the explicit dep; it's a one-line fix |
| Wire FCM topics in `main.dart` immediately after `Firebase.initializeApp` | "FCM is set up" tick in checklist | Silent topic subscribe failure on iOS, 30% delivery rate | Never — sequence permission → token → APNs token → subscribe |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| **App Check (iOS)** | Enable enforcement in Console before debug tokens are registered for the simulator | Stage: install package → register debug tokens → watch Metrics tab → only then enforce. Use `AppAttestProvider` for release, not `DeviceCheckProvider` |
| **App Check (CI)** | Tests fail with `permission-denied` after enforcement; dev loosens rules | Generate one CI debug token, store as GitHub Actions secret, pass via `--dart-define`. Never loosen rules |
| **Cloud Functions Gemini proxy** | Stream Gemini response from the function and try to stream it back to client over HTTPS callable | Callables don't stream. Either: (a) write streaming chunks to a Firestore doc subcollection the client listens to, (b) use Cloud Run with SSE, (c) accept non-streaming for v1.0 and stream later |
| **Cloud Functions secret management** | Read `GEMINI_API_KEY` from `process.env` set via `functions:config` | Use Google Secret Manager. In Gen 2: `defineSecret('GEMINI_API_KEY')` and bind to the function. Grant the function's runtime SA `roles/secretmanager.secretAccessor` |
| **Cloud Functions cold start** | Set `minInstances: 1` reflexively | Default `0`, measure, only escalate if real users hit it. Budget alert before changing |
| **Cloud Functions region** | Default `us-central1` | Set explicitly to `asia-south1` (Mumbai) for Bangladesh users. Cannot be changed without redeploy + client update |
| **FCM iOS APNs auth** | Use APNs `.p12` certificate (expires yearly) | Use APNs `.p8` auth key (no expiry, account-wide). Upload via Firebase Console → Cloud Messaging |
| **FCM iOS background handler** | Define handler as a closure or nested function | Must be a **top-level** function with `@pragma('vm:entry-point')` and call `Firebase.initializeApp()` inside. Otherwise tree-shaken in release |
| **FCM iOS topic subscribe** | Subscribe before APNs token arrives | Wait for `getAPNSToken()` to return non-null, then subscribe. Re-subscribe on `onTokenRefresh` |
| **FCM iOS capabilities** | Forget to enable Push Notifications + Background Modes → Remote notifications in Xcode | Xcode → Runner target → Signing & Capabilities. Verify `aps-environment` entitlement in `Runner.entitlements` |
| **Firestore counter** | `update({field: increment(1)})` non-transactionally for rate-limit check | Use `runTransaction` for read-check-write. Per-doc write limit ≈ 1/sec |
| **Firestore rewards history** | `arrayUnion` into a single doc array | Subcollection with append-only ledger docs. Sortable, paginatable, scoped by rules |
| **Firestore rules + App Check** | Forget to add App Check enforcement clause to rules | Rules can use `request.appCheck` — enforce there too as defense-in-depth |
| **Premium gating** | Single `users.tier == 'premium'` string check | `/subscriptions/{uid}` doc with `status`, `currentPeriodEnd`, `provider` — designed for v2.0 from day one |
| **Integration tests** | Point at real Firestore | Firebase Emulator Suite by default; one tagged smoke test against dev project |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Hot doc on `/users/{uid}/usage/{day}.messageCount` | Chat lag, ABORTED errors, occasional double-message | Use transactions; skip counter for premium users | Burst writes > 1/sec to same doc — happens with double-tap or integration tests |
| Cloud Function cold start on first chat of session | "First message takes 5s, rest take 1s" | Accept for v1.0 (single chat session amortizes the cost). Re-evaluate with metrics | Always cold; visible when sessions are short |
| Gen 2 function deploy creating new Artifact Registry image every commit | Storage bills creeping | Set Artifact Registry cleanup policy "keep last 3 versions" | After ~50 deploys per function |
| `arrayUnion` to `/rewards/{uid}.history` | Reads of `/rewards/{uid}` get progressively slower; eventually `INVALID_ARGUMENT: document exceeds 1 MiB` | Subcollection `/rewards/{uid}/ledger/{autoId}` from day one | ~5,000 entries (~200 bytes each) hits the limit |
| Streaming Gemini response back through Firestore writes | Many small writes per response = costs scale with token count | Batch chunks every N tokens or every 250ms, not per-token | Always — even at low traffic, per-token writes are 10–100× the necessary write count |
| Notification list re-renders on every Firestore stream tick | Janky scrolling, dropped frames | Use `select` on the provider and key off message id, not the whole list | List > 50 notifications |
| Wide-region function calls (us-central1 from Bangladesh) | P95 latency 250ms higher than dev experiences | Deploy to `asia-south1` (Mumbai) | Always, but unnoticed until users complain |
| Materials browser fetches all docs and filters client-side | App startup slow on low-end devices; bandwidth bill on the user | Compound query with `where('level', ==, ...)` and Firestore index | > 100 materials |
| App Check token refresh storm at 00:00 UTC | Burst of `verifyAppCheckToken` calls; cold-starts spike | Default refresh is staggered; do not force refresh on cron | If you write a custom refresh trigger |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Cloud Function reads request body and trusts `uid` from request payload | Any authed user can pass any other user's uid | Use `context.auth.uid` (callable) or verify the ID token server-side. Never trust client-supplied uid |
| Cloud Function does not check `context.app` (App Check token presence) | API endpoint callable from non-app clients (curl + forged ID token) | Set `enforceAppCheck: true` on the callable function options. Reject if `context.app == null` |
| `awardPoints` Cloud Function accepts an `amount` parameter | User passes `amount: 1000000` | Server defines the amount table; client passes only the *event* (`'session_complete'`) |
| Rewards ledger writable by client even after server-side awards land | Inconsistent state; client can backfill fake history | Lock `/rewards/{uid}/ledger/{lid}` to server-only writes via rules |
| Cloud Functions IAM left at `Editor` role on default compute SA | Compromise of one function = compromise of project | Each function gets a dedicated runtime service account with least-privilege roles (Firestore User, Secret Accessor for its specific secrets) |
| Secret Manager secret without rotation policy | Leaked secret stays valid indefinitely | Set rotation period in Secret Manager (90 days). Function reads via `defineSecret`, picks up new version on next deploy |
| Premium grant function callable from client without admin check | Any user can grant themselves premium | Function's first line: `if (!context.auth?.token.admin) throw HttpsError('permission-denied', ...)`. Use custom claims, not Firestore role field, for admin checks |
| FCM message body contains PII | If device cache leaks (lost phone), PII leaks | Notifications send `data` payload referencing a Firestore doc id; sensitive content fetched on demand when notification opened |
| Functions log full request bodies including user messages | Cloud Logging retention = 30 days of user chat data in plaintext, indexed by Google | Redact message bodies before `console.log`. Log only metadata: uid hash, message length, subject, success/failure |
| App Check debug provider used in release builds | All "App Check" enforcement is bypassed | Wrap debug provider init in `if (kDebugMode)` or `if (Platform.environment['APP_CHECK_DEBUG_TOKEN'] != null)`. Audit release IPA for debug strings |
| Cloud Function returns Gemini's raw error to client | Error messages can leak prompt structure, model name, internal API details | Map errors to a finite set of user-facing codes; log details server-side |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Rate-limit banner appears mid-conversation with no warning | Student types out a long question, hits send, gets "10/10 used — upgrade" — feels punitive | Show counter ("3 messages left today") starting at remaining ≤ 3. Pre-warn at the *start* of the message, not after send |
| Quota resets at UTC midnight, banner says "resets tomorrow" | Student in Dhaka at 7 AM sees "resets tomorrow"; resets at 6 AM next day | Display reset time in user's local TZ explicitly ("Resets at 6:00 AM your time tomorrow") |
| Cold-start latency on first message of session shows no loading state | First message feels broken; student double-taps send | Show typing indicator immediately on send; if response > 2s, show "MentorBot is thinking…" with progress |
| App Check failure shows generic "permission-denied" | Student thinks their account is broken | Catch App Check errors specifically and show "Please update to the latest app version" with link to App Store |
| Premium upgrade modal appears every time the user hits a feature gate | Modal fatigue; user dismisses by reflex | Show once per day per gate; remember dismissals in `users/{uid}.dismissedUpgradePrompts` |
| Streak loss notification arrives at 11 PM ("Your streak ended!") | Demoralising at end of day, no time to act | Send "Don't lose your streak!" at 6 PM if user hasn't engaged that day; never send post-loss obituary |
| Notification permission asked on first launch with no rationale | High deny rate; can't re-prompt iOS | Show rationale screen ("Get reminders for daily challenges and streak protection") before calling `requestPermission`; only call after Continue tap |
| Avatar upload silently fails (currently the case per CONCERNS #5e) | User picks photo, spinner, then "permission denied" with no explanation | Pre-validate file size and type client-side; fix the storage rule (the actual concern); show specific error |
| Refactor to `presentation/screens/` lands in TestFlight with a broken deep link | Push notification taps go to wrong screen / 404 | Test every GoRouter named route after the refactor; keep route *names* identical even if file paths change |
| Lint burndown changes button corner radius by 1px | "App feels different" complaints in the next TestFlight | Run goldens before/after; surface visual diffs in PR review |

---

## "Looks Done But Isn't" Checklist

Critical pieces that are easy to forget in the v1.0 hardening scope.

- [ ] **App Check enforced:** Tokens registered for every developer's simulator AND CI AND TestFlight; Metrics tab shows ≥ 99% verified for 7 days; enforcement clicked. Verify: temporarily run a `curl` against Firestore with a forged ID token but no App Check token — it must `403`.
- [ ] **Cloud Function region pinned:** Every function declares `region('asia-south1')`. Verify: `firebase functions:list` shows non-`us-central1` for all functions.
- [ ] **Cloud Function budget alert set:** GCP Console → Billing → Budgets shows an alert for `mentor-mind-aa765` at $10/month. Verify: receive a test alert by temporarily setting threshold to $0.01.
- [ ] **Artifact Registry cleanup policy set:** Verify: GCP Console → Artifact Registry → `gcf-artifacts` → Cleanup policies shows "Keep most recent 3 versions."
- [ ] **Gemini key in Secret Manager, not env var:** Verify: `gcloud secrets list` shows `GEMINI_API_KEY`; function code uses `defineSecret`; no `GEMINI_API_KEY` in `firebase functions:config:get`.
- [ ] **Rules tightened against client points writes:** Verify: rules-unit-testing suite has a test that asserts a client cannot mutate `users/{uid}.points`, `badges`, `streak`, or `usage.messageCount`. Test must fail before rules change, pass after.
- [ ] **Server reward path replaces client path:** Verify: `git grep "FieldValue.increment" lib/` returns zero hits in viewmodels (only in models or test helpers, if anywhere). Old client paths fully removed, not just disabled.
- [ ] **Rewards ledger uses subcollection:** Verify: `/rewards/{uid}` document no longer contains `history` array; `/rewards/{uid}/ledger/{lid}` exists with at least one entry per recent award.
- [ ] **Quota timezone constant exists and is shared:** Verify: A single constant `QUOTA_TZ = 'Asia/Dhaka'` exists in both `lib/core/` and `functions/src/`. Both use it. No raw `toISOString().slice(0,10)` in either.
- [ ] **Replay cache present:** Verify: Repeated calls of the same `chatStream` request with the same `(sessionId, msgIdx)` within 24h are rejected on the second call.
- [ ] **FCM APNs auth key uploaded (not certificate):** Verify: Firebase Console → Project Settings → Cloud Messaging → Apple app configuration shows "APNs Authentication Key" filled, "APNs Certificates" empty.
- [ ] **FCM iOS capabilities enabled in Xcode:** Verify: `grep -l 'aps-environment' ios/Runner/Runner.entitlements` returns the file; `ios/Runner.xcodeproj/project.pbxproj` references `Push Notifications` capability.
- [ ] **FCM background handler is top-level + vm:entry-point:** Verify: `grep -B1 "Future<void>.*onBackgroundMessage" lib/` shows `@pragma('vm:entry-point')` immediately above; handler is at top level of file (not inside a class).
- [ ] **FCM topic subscription happens after permission + APNs token:** Verify: Code review confirms sequence; test on real iOS device with notifications denied → topic subscribe is not called.
- [ ] **Subscription data model used:** Verify: `/subscriptions/{uid}` collection exists with full schema even though only `manual` provider is wired; client checks use the subscription doc, not `users.tier`.
- [ ] **No `service-account.json` committable:** Verify: `git check-ignore tool/seed/service-account.json` returns the path; `git ls-files | grep service-account` returns empty. (This is from CONCERNS #4c — re-verify after every PR.)
- [ ] **Lint burndown shipped with goldens:** Verify: `flutter test --tags golden` exists in CI; golden suite has at least one image per affected screen; PR diff shows golden updates only when intentional.
- [ ] **Refactor PR is rename-only:** Verify: For the move PR, `git diff --stat main` shows file-pair renames with `==0` body changes; `flutter analyze` output is byte-identical before and after.
- [ ] **Emulator Suite is the default test target:** Verify: `flutter test integration_test/` defaults to emulator; `firebase.json` has `emulators` block; CI workflow boots emulators before tests.

---

## Recovery Strategies

When pitfalls happen anyway, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| App Check enforced before tokens registered → users locked out | LOW | Disable enforcement in Console (immediate), restore access. Register tokens, watch Metrics, re-enforce after 7 days. No data loss |
| Cloud Function region chosen wrong (us-central1 instead of asia-south1) | MEDIUM | Deploy new function in correct region with `-v2` suffix; update client `httpsCallable` to point to v2; wait one release cycle for old clients to update; delete v1 function. ~1 week elapsed |
| Replay attack inflated points (no idempotency key shipped) | MEDIUM-HIGH | Run Cloud Function to recompute every user's points from the ledger subcollection (assuming ledger is intact); if not, snapshot leaderboard, freeze rewards, communicate "Rewards system being recalculated" |
| Rewards ledger stored as array, doc hit 1 MiB | HIGH | One-time migration function: read each `/rewards/{uid}.history` array, write entries to `/rewards/{uid}/ledger/{autoId}`, then unset the array field. Must run during low traffic; arrays cannot be partially-deleted atomically |
| Quota counter inconsistency from timezone bug | LOW | Define `QUOTA_TZ`, redeploy. Existing usage docs become stale but expire naturally (next day's key is correct). Communicate the change in release notes |
| FCM topic subscriptions silently failed for early TestFlight users | LOW-MEDIUM | Add the reconciler Cloud Function (post-mortem fix); on next app launch every user re-syncs. Lost: any broadcasts sent in the broken window |
| Refactor PR merged with mixed body changes | HIGH | Hard to recover; `git log --follow` already broken. Options: (a) accept the loss, document the move commit in `ARCHITECTURE.md` as a history boundary; (b) revert + re-do as two PRs. (a) is usually realistic |
| `withOpacity` sed-replace shipped visual regressions | LOW-MEDIUM | Revert the migration PR, redo per-file with goldens. Cost is the lint-debt remains visible; that's acceptable until proper fix |
| Gemini API key found in IPA after Cloud Function migration | MEDIUM | Rotate the key in Google AI Studio (immediate, breaks old builds). Force a TestFlight + App Store update. Monitor billing for the orphaned-key abuse window |
| Premium grant function shipped without admin check, user granted self | HIGH | Audit `/subscriptions/` for unauthorized grants (check `metadata.grantedBy`), revoke. Patch function. Custom claim audit on every admin |
| Cold-start tail latency too high for users | LOW | Measure first. If real, set `minInstances: 1` with explicit budget approval. Or move chat to Cloud Run (better cold-start story for streaming) |

---

## Pitfall-to-Phase Mapping

How v1.0 roadmap phases prevent each pitfall.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| #1 App Check enforced too early | Backend hardening (Phase 3) | Console Metrics tab ≥ 99% verified for 7 days; `curl` without token returns 403 |
| #2 Replay-vulnerable rewards | Backend hardening (Phase 3) | Rules-test asserts client cannot mutate `points`; integration test sends duplicate `(sessionId, msgIdx)` and expects rejection |
| #3 Quota timezone drift | Backend hardening (Phase 3) | `QUOTA_TZ` constant grep in both client + functions; unit test for day-key computation at boundary times |
| #4 Hot-doc contention | Backend hardening (Phase 3) | Load test: 5 parallel requests for same uid within 1s; assert exactly one succeeds, others get `resource-exhausted` |
| #5 Layout refactor mixed with edits | Layout & polish (Phase 2) — PR A | `git diff --stat` shows file-pair renames only; `flutter analyze` output byte-identical |
| #6 `withOpacity` visual regression | Foundation cleanup (Phase 1) | Golden test suite in CI; per-file PR cadence |
| #7 FCM iOS topic silent fail | Backend hardening / messaging (Phase 3) | Real-device test: deny permission → confirm topic-subscribe is not called; grant → confirm token + topic visible in Firebase Console |
| #8 Cloud Functions billing surprise | Backend hardening (Phase 3) — day 0 | GCP budget alert created; region pinned; cleanup policy set; `maxInstances` set; `minInstances: 0` documented |
| #9 Premium data model not future-proof | Backend hardening (Phase 3) | `/subscriptions/{uid}` schema exists; client checks against it not against `users.tier`; admin grant goes through Cloud Function |
| #10 Tests pollute prod | Foundation cleanup (Phase 1) | `firebase.json` has `emulators`; CI uses emulator by default; one tagged smoke test for real-dev |

---

## Sources

Web research tools (WebSearch, WebFetch, Context7 via Bash) were unavailable in this agent session — claims below are grounded in training-cutoff knowledge (January 2026) of:

- **Firebase documentation** (`firebase.google.com/docs`) — App Check Flutter setup; Cloud Functions Gen 2 region/region pricing; FCM iOS prerequisites; Firestore quotas and per-document write limits; Storage rules; Local Emulator Suite.
- **Flutter / Dart documentation** — `Color.withOpacity` deprecation rationale (Flutter 3.27 changelog); `flutter_riverpod` vs `hooks_riverpod` package export chain; `@pragma('vm:entry-point')` and tree-shaking in release mode.
- **Google Cloud documentation** — Secret Manager + Cloud Functions integration; Artifact Registry cleanup policies; Cloud Run min-instances pricing model.
- **Apple developer documentation** — APNs Authentication Keys (`.p8`) vs Certificates (`.p12`); App Attest vs DeviceCheck differences; Push Notifications + Background Modes capabilities.
- **MentorMinds codebase** — `.planning/codebase/CONCERNS.md` (CONCERNS #2, #3, #4c, #5a, #5e, #8, #9, #12 referenced inline); `lib/features/tutor/chat_viewmodel.dart:490-542` (current client-side reward + usage logic); `lib/core/routes/app_router.dart:5-15` (router imports that change in refactor); `firestore.rules` (current rule shape with admitted MVP trade-off comments at lines 9-11, 145-147).

**Re-verify before execution:**
- Exact Firebase App Check Flutter package version and the App Attest provider class name (training: `AppleProvider.appAttest` for FlutterFire `firebase_app_check ≥ 0.2.x` — confirm current).
- Cloud Functions Gen 2 `setGlobalOptions` API (training: stable as of late 2024 — confirm not renamed).
- Artifact Registry cleanup policy UI path (training: GA in 2024 — confirm still in Console under repository settings).
- APNs `.p8` key still the recommended path (training: yes, since 2016 — extremely unlikely to have changed).
- IANA timezone `Asia/Dhaka` supported in Node 20 `Intl.DateTimeFormat` runtime (training: yes — well-established).

---

*Pitfalls research for: MentorMinds v1.0 hardening — Cloud Functions proxy + App Check + server rewards + screen-layer refactor + FCM iOS + lint burndown*
*Researched: 2026-05-17*
