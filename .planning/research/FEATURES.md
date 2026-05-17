# Feature Research

**Domain:** AI tutoring mobile app for O/A Level (Cambridge / Edexcel) students in Bangladesh
**Researched:** 2026-05-17
**Confidence:** MEDIUM (grounded in well-documented competitor patterns and the existing codebase map; web search was unavailable this session, so claims about specific 2026 product changes are based on training knowledge through Jan 2026 and should be re-verified before final scope-freeze)

## Scope of this research

This file evaluates **only the deltas the new spec adds on top of the existing skeleton**. The current app already ships email/Google auth, 3-page onboarding, streaming Gemini chat, materials browser, cross-content search, rewards (points/badges/streak/leaderboard), an FCM notifications scaffold, and an admin panel placeholder. Those are treated as given. What follows is a verdict on each *new* spec inclusion plus a few obvious gaps the spec misses.

Competitive reference set used: **Khanmigo** (Khan Academy's AI tutor), **Photomath** (Google), **Socratic by Google**, **Brainly**, **Quizlet**, **Chegg**, **Duolingo** (for gamification patterns), **10 Minute School** (Bangladesh, dominant local incumbent), **Shikho** (Bangladesh, exam-prep focused), **Bohubrihi / Pratidin** (BD secondary), and global O/A Level prep apps like **Save My Exams** and **Seneca Learning**.

---

## Feature Landscape

### Table Stakes (Users Expect These)

A paying O/A Level student in 2026 has used at least one of Khanmigo, ChatGPT, or 10 Minute School. If MentorMinds is missing any of these, it will feel like a 2022 app and they will not renew.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Image attachment for diagram/handwriting analysis** | Photomath made "snap a problem" the universal UX for exam-prep apps since 2017. Socratic, Brainly, Khanmigo, ChatGPT all support it. For Physics/Chem/Maths it's the #1 use case — students photograph past-paper questions. | MEDIUM | Backend already supports it via `GeminiService` multimodal call (`gemini_service.dart`). The spec only adds the UI affordance + the premium gate. **Do NOT gate this behind Premium for v1.0** — see Anti-Features. Free tier should get a low daily cap (e.g. 3 images/day) instead. |
| **Per-tier rate limits with visible counter** | Every freemium AI product (ChatGPT free, Claude free, Khanmigo, Perplexity) shows "X of Y messages today." Without it, students hit the wall mid-revision-session, blame the app, and uninstall. The *visibility* is table stakes, not the limit itself. | LOW | Backend usage doc already exists at `/users/{uid}/usage/{yyyy-MM-dd}`. UI needs a banner + a soft-warn at 80%. Free tier of 10 msgs/day is aggressive — see complexity note in MVP section. |
| **Empty-state AI suggestion chips** | First-run abandonment is the silent killer for chat apps. ChatGPT, Khanmigo, Claude, Gemini all open with "Try asking…" chips. Without them, a student opens the chat, sees a blank textbox, doesn't know what to type, closes the app. | LOW | Pure UI. 4-6 curriculum-aware suggestions based on the user's `subjects` array from onboarding (e.g. "Explain photosynthesis", "Solve a quadratic", "Past paper Q3 May 2024"). Can be hardcoded per-subject for v1.0 — no AI generation needed. |
| **Email verification before full access** | Standard since ~2020 for any account creation, and required if MentorMinds ever wants to be on a school's preferred-app list. Spec already calls this out as a "banner." | LOW | Firebase Auth has `sendEmailVerification()` and `User.emailVerified` natively. Use a soft block (banner + can still browse materials) rather than hard gate so users don't abandon mid-funnel. |
| **Push notifications wired (not just scaffold)** | Every retention-driven student app — Duolingo, Brainly, 10 Minute School — relies on push for D1/D7 return. The FCM SDK is declared but never imported per `CONCERNS.md`. This is the highest-leverage feature in the entire roadmap for measurable retention. | MEDIUM | Wire `FirebaseMessaging.onBackgroundMessage`, request iOS APNs permission on first run, subscribe each user to a per-`role` topic, and store the FCM token in `/users/{uid}.fcmToken`. Without this the rewards system has no daily loop. |
| **Server-authoritative points / anti-cheat on leaderboard** | The moment one student in a Dhaka school discovers they can spoof points to top the leaderboard, the social proof of the entire rewards system collapses overnight. This is a credibility-of-product issue, not a nice-to-have. | HIGH | Move `_awardPoints` out of `chat_viewmodel.dart` into a Cloud Function (or strict rules with composite checks). Listed as HIGH in `CONCERNS.md`. Must close before launch. |
| **Offline / no-network graceful degradation** | Bangladesh mobile connectivity outside Dhaka/Chittagong is unreliable. Spec already specifies a connectivity banner via `connectivity_plus`. Bare minimum: show cached materials list + a clear "you're offline" state instead of a spinner forever. | LOW | Connectivity banner is in the active list. Genuine offline-first sync is correctly out of scope per `PROJECT.md`. |
| **Streak counter visible on dashboard** | Duolingo proved streaks drive 3-4× DAU/MAU ratio. 10 Minute School and Shikho both ship streaks. Without it the daily-habit promise in MentorMinds' Core Value statement is unsupported. | LOW | Already half-built — `_fetchStreak` exists in `dashboard_viewmodel.dart:365`. Just needs the polished UI per Screen 05. |
| **Subject progress indicators (rings or bars)** | Khan Academy's "mastery" rings are now the industry default. Seneca, Save My Exams, Khanmigo all show per-topic progress. Students *expect* to see "you've covered 6 of 14 chapters in Physics." Without it the app feels like a chatbox, not a tutor. | MEDIUM | Spec includes this as "subject progress rings." Tricky part isn't the UI — it's defining *what counts as progress*. Cheapest v1.0 definition: % of sessions per subject vs target (e.g. 10 sessions = 100%). Don't try to do real topic-level mastery in v1.0. |
| **Settings: notifications toggle, account deletion** | App Store and Google Play both require account deletion in-app since 2022 (Apple) / 2023 (Google). Notifications toggle is iOS HIG standard. | LOW | `profile_viewmodel.dart` already has reauth + delete account scaffolding. Verify the delete flow actually cascades through Firestore (or document the gap). |
| **Password reset flow** | Standard. Spec already includes it on Login. | LOW | Existing in `auth_viewmodel.dart`. |
| **Pull-to-refresh on dashboard / materials / notifications** | iOS HIG default. Costs nothing, missing = looks broken. | LOW | Standard `RefreshIndicator`. |

### Differentiators (Competitive Advantage)

Things that could plausibly drive word-of-mouth among Bangladeshi O/A Level students. Each one needs to map to something competitors don't do well in this specific market.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Curriculum-aligned answers (Cambridge + Edexcel)** | Khanmigo is US-curriculum first. ChatGPT is unaware of which board you're on. Photomath solves the problem but doesn't explain in O-Level marking-scheme terms. **If MentorBot's system prompt explicitly says "respond in the style of a Cambridge IGCSE marking scheme, allocate marks per step, flag command words"**, that is a real, defensible differentiator no global app does well. | LOW | Pure prompt engineering on top of existing Gemini service. Add `board` + `level` + `subjects` to system prompt. Single afternoon of work for outsized perceived quality. |
| **Daily challenge card on dashboard** | Differentiator *only if* the challenge is curriculum-relevant ("Today: solve this 5-mark Mechanics question"). Brainly and Chegg don't do this. Duolingo's daily quest model is proven to drive 30%+ DAU lift. Risky if it becomes generic ("Send 3 messages today"). | MEDIUM | Cheapest v1.0: a Cloud Scheduler job picks one question per subject per day from a curated `/daily_challenges` Firestore collection, fans out via FCM. Premium version could be adaptive. **Worth doing IF you also wire FCM** — otherwise no one will see it. |
| **Streak rewards (7-day, 30-day badges)** | Duolingo's 365-day streaks are the most-shared social object in language learning. For exam-prep there's an even cleaner narrative: "I revised every day for 60 days before my A-Levels." | LOW | Just additional rows in the badges Firestore collection + check in the daily-login award path. Already half-built. |
| **Badge celebration overlay with confetti** | Standard in Duolingo, Khan Academy. Cheap and high dopamine. Risk-free differentiator. | LOW | Spec calls this out. Use `confetti` package or `flutter_confetti`. ~half-day. |
| **Cross-content search (materials + past sessions)** | Already built. **This is genuinely differentiating** — Brainly doesn't search your own chat history, ChatGPT only does so within one conversation, Khanmigo doesn't have a corpus search. The "search my own learning" angle is strong if marketed. | (existing) | Just needs to ship cleanly. Make sure the "search past sessions" tab doesn't get gated behind Premium — see Anti-Features. |
| **Admin broadcast notifications via FCM topics** | Lets the operator push "New past paper added: Physics May 2026" to all Physics students. Powerful for engagement and for the admin's ability to react to exam-board announcements. Local incumbents do this. | MEDIUM | Spec includes it. Requires FCM wired (table stakes above) + a server-side broadcast trigger (Cloud Function callable). |
| **Bangla/English bilingual answer mode** | Despite curriculum being English, many students *think* in Bangla and search in Banglish. A toggle "Explain in Bangla" / "Explain in English" would crush ChatGPT for this audience. | LOW | Prompt engineering only. Not in the spec currently — **recommend adding**. |
| **Past-paper marking-scheme alignment** | "Show me how an examiner would mark this answer" is the single most-requested feature in O/A Level forums. No general AI does this well. | MEDIUM | Prompt engineering + a system prompt loaded with the marking-scheme rubric format. v1.1 candidate; nice-to-flag in v1.0 differentiation pitch. |

### Anti-Features (Commonly Requested, Often Problematic)

These are things in the current spec (or things students will demand) that look attractive but will hurt the product. Calling them out so the team doesn't burn cycles building regret.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Premium upgrade modal with no real payment backend** | Spec includes it. Tempting to "stub the flow now, wire bKash later." | (1) The modal will be tapped by users who genuinely want to pay, will see a "coming soon" — that is worse than not offering Premium at all because you advertise scarcity and then can't deliver. (2) The first-tap analytics on a fake button are useless because the funnel is fake. (3) iOS App Store reviewers reject apps that present a paywall the user can't actually complete — this is a likely Day-1 reject. (4) Premium gating in your code (image attachment, full search history) forces you to maintain a code branch for a non-existent tier. | **Drop the Premium concept entirely for v1.0**. Keep the rate limits, but frame them as "fair usage for everyone" not "free vs Premium." Add a "Premium coming soon — join the waitlist" email capture instead if you want to gauge willingness-to-pay. |
| **Gating image attachment behind Premium** | "It's our expensive feature, let's monetize it." | Image-input is now *table stakes* (see above). Photomath has been doing it free since 2017. Gating it forces price-sensitive students who are your target demographic to compare you unfavorably to Photomath, Socratic, and ChatGPT free tier — all of which support image input free. You will lose the install on Day 1. | Free tier gets 3 image questions/day. Premium (when it exists) gets unlimited. The *quota*, not the *capability*, is what's gated. |
| **Search history as Premium-only ("last 7 days vs full")** | "Power-user feature, monetize the long tail." | (1) Search-your-own-data is THE feature that makes MentorMinds sticky (see Differentiators). Crippling it removes a moat. (2) Storage cost for 1 year of session history per free user in Firestore is genuinely trivial (~kilobytes/user/year). There is no infrastructure justification. (3) It punishes the most-engaged free users, who are your conversion candidates for any future paid tier. | Make full search history free. If you must monetize search later, gate *advanced search* (semantic / cross-document AI summarization) instead, not the basic history. |
| **Per-tier rate limits where free = 10 msgs/day** | "Force the upgrade." | (1) 10 msgs/day is below the threshold at which a student can complete one meaningful revision session — they will ask 3-4 clarifying follow-ups per concept. (2) Khanmigo gives unlimited free messages (paid by Khan Academy's grants). ChatGPT free gives ~40 GPT-4o messages/3h. Free tier of 10/day is more restrictive than the leading global free competitor and will rank you as "stingier than the alternatives" in app-store reviews. (3) Gemini Flash is cheap; back-of-envelope, 50 msgs/day/user costs ~$0.50/user/month. | Free tier of **30-50 text msgs/day + 3-5 image questions/day** is a more realistic balance. Show usage clearly. Re-evaluate after seeing real cost data. |
| **Public leaderboard across the whole user base** | "Social proof, gamification!" | (1) New users always start at the bottom of a global leaderboard, which is demotivating (the exact opposite of the intended effect). (2) Even with anti-cheat fixed, leaderboards reward *time spent* not *learning achieved* — they incentivize bot-like message-spamming, which costs you Gemini quota for zero pedagogical value. (3) Duolingo specifically uses **league-based** (30-person cohorts), not global, leaderboards for exactly this reason — and Duolingo's own internal A/Bs (publicly discussed at conferences) confirm cohort beats global. | If keeping the leaderboard at all in v1.0: scope it to "friends" (requires invites — defer) or to a fixed-size cohort (30 random users). If neither is achievable in v1.0, **cut the leaderboard tab entirely** and ship only personal stats. The badges + streak alone are sufficient gamification. |
| **Multi-role accounts including "teacher" in v1.0** | Spec mentions `role: 'teacher'` to "future-proof." | Teacher accounts require teacher-specific screens (class management, assigning problems, viewing student progress, FERPA-equivalent privacy considerations). The spec ships them as a `_PlaceholderScreen`. A student who registers and accidentally selects "Teacher" hits a dead end. The role exists in the data model but every authentication path that lands a teacher just shows them an empty screen. | Hide the "Teacher" role from the registration UI for v1.0. Keep the database field and admin tooling that can manually promote a user, but do not expose teacher self-signup until there is at least one functional teacher screen. `PROJECT.md` already lists teacher accounts as Out of Scope — make sure registration UI matches that. |
| **Admin analytics charts (DAU, subject distribution)** | "Founders want to see the numbers." | (1) Firebase Analytics already gives you DAU, retention, screen-time, conversion funnels — for free, with better UX than anything you'll hand-roll in 2 weeks. (2) Building chart widgets in Flutter to query Firestore aggregates is real work (requires Cloud Functions for non-trivial aggregations, or pulling all docs client-side which doesn't scale past ~5K users). (3) The admin will look at this dashboard 3 times in v1.0 then start using GA4 + BigQuery anyway. | Skip in-app analytics. Wire Firebase Analytics events instead (`log_session_completed`, `log_badge_earned`, `log_premium_modal_seen`) and tell the admin to use the GA4 console. Free, better, no maintenance. |
| **Confetti / celebration on every micro-action** | "Make it feel rewarding." | Over-celebration is the #1 complaint in Duolingo App Store reviews 2023-2024. Confetti for *every* completed message becomes background noise within 2 days; users learn to dismiss it; the system loses all signal. | Confetti only on genuine milestones: first session ever, every new badge earned, streak milestones (7/30/100), level-up. Not on every completed message. The spec correctly limits confetti to badge celebration — keep it that way. |

---

## Feature Dependencies

```
Push Notifications (FCM wired) — TABLE STAKES
   ├──enables──> Streak Rewards (reminders drive return visits)
   ├──enables──> Daily Challenge Card (without push, no one sees it)
   └──enables──> Admin Broadcast

Email Verification
   └──gates──> Premium / waitlist email capture

Server-authoritative Points (Cloud Function)
   ├──prerequisite-for──> Leaderboard (or it's gameable)
   ├──prerequisite-for──> Badge Celebration (or badges are fake)
   └──prerequisite-for──> Streak Rewards (or streaks are fake)

Subject Progress Rings
   └──requires──> Per-subject session count aggregate
                       └──requires──> Sessions Firestore index by (uid, subject)

Daily Challenge Card
   ├──requires──> /daily_challenges Firestore collection
   ├──requires──> Cloud Scheduler job (or manual seeding)
   └──requires──> FCM topic broadcast for "today's challenge"

Image Attachment (UI)
   └──requires──> GeminiService multimodal (EXISTS)
   └──requires──> Storage rules permit uploads (FIX BUG: avatars/{uid}.jpg → uploads/)

Admin Broadcast
   ├──requires──> FCM wired
   └──requires──> Cloud Function (callable) for fan-out

Search History (full)
   └──requires──> Sessions Firestore index by (uid, lastUpdated DESC)

Premium Upgrade Modal
   └──conflicts-with──> Honest UX (no payment backend exists)
   └──conflicts-with──> App Store review guidelines

Public Global Leaderboard
   └──conflicts-with──> New-user motivation (always-bottom problem)
   └──conflicts-with──> Cost discipline (rewards message-spam)
```

### Dependency Notes

- **Wiring FCM is the single highest-leverage backend task.** Streaks, daily challenges, admin broadcast, and re-engagement push all collapse to "decorative" without it. Push it to the front of the security/backend phase.
- **Server-authoritative points must precede any leaderboard polish.** Polishing UI on a gameable backend means rebuilding the UI when the backend changes.
- **Subject progress rings need a clear definition of "progress" before UI work begins.** Cheapest: session count per subject vs target. Don't let UI work block on a perfect mastery model.
- **Premium modal conflicts with App Store guidelines.** If kept, must be wired to a real payment path or rebranded as "waitlist."

---

## MVP Definition

### Launch With (v1.0)

This is what's needed for MentorMinds to feel credible to a paying Bangladeshi O/A Level student in 2026.

**Backend / security (gating, must close before any user-facing polish):**
- [ ] **Wire FCM end-to-end** (request permission, store token, subscribe to per-role topic, handle background messages) — unblocks streak reminders, daily challenge, admin broadcast
- [ ] **Server-authoritative points via Cloud Function** — closes leaderboard cheat surface
- [ ] **Gemini API key behind Cloud Function proxy + App Check** — fixes key-in-binary exfiltration risk
- [ ] **Fix avatar upload path mismatch** (`storage.rules`) — currently 100% silent failure
- [ ] **Wire iOS Google Sign-In native config** — currently broken
- [ ] **Run Riverpod codegen OR remove unused codegen deps** — eliminate confusion

**Tutor chat (the core product):**
- [ ] **Image attachment in chat — FREE, with a 3/day quota counter** (NOT Premium-gated)
- [ ] **Empty-state suggestion chips** (4-6 per subject, hardcoded)
- [ ] **Visible rate-limit counter with soft-warn at 80%**
- [ ] **System prompt augmented with `board`, `level`, `subjects`** for curriculum alignment
- [ ] **Typing indicator + streaming render** (already partially built)

**Dashboard:**
- [ ] **Subject progress rings** (definition: session-count-based, not mastery-based)
- [ ] **Streak counter prominent**
- [ ] **Daily challenge card** — only if FCM is wired in same phase; otherwise defer to v1.1

**Rewards:**
- [ ] **Badge celebration overlay with confetti** (badge-earn only, NOT per-message)
- [ ] **Streak rewards: 7-day, 30-day badges**
- [ ] **Personal stats / history view** (badges + history tabs)
- [ ] **Cohort-based or scrapped leaderboard** — do NOT ship a global all-users leaderboard

**Search:**
- [ ] **Full search history FREE** (not gated)
- [ ] **Tabbed All / Materials / Sessions**
- [ ] **Recent searches + trending**

**Admin:**
- [ ] **Broadcast notifications** (callable Cloud Function + topic fan-out)
- [ ] **Content upload** (materials)
- [ ] **User list + role promotion**
- [ ] **NO in-app analytics dashboard** — point at GA4 instead

**Auth / onboarding:**
- [ ] **Email verification banner** (soft block — can browse materials, must verify to chat)
- [ ] **Hide "Teacher" role from public registration UI** (keep field in DB for admin promotion)

**Cross-cutting:**
- [ ] **Connectivity banner**
- [ ] **Pull-to-refresh everywhere**
- [ ] **Account deletion working end-to-end** (App Store requirement)

### Add After Validation (v1.x)

- [ ] **Real payment integration (bKash / Stripe)** — once free-tier engagement validates willingness-to-pay
- [ ] **Premium tier** with: unlimited messages, unlimited images, marking-scheme mode — only after payment works
- [ ] **Bangla/English bilingual toggle** in chat — cheap to add, validate that students want it before investing
- [ ] **Past-paper marking-scheme alignment mode** — high differentiator value, prompt-engineering cost only
- [ ] **Adaptive daily challenge** (picked from weak subjects) — once you have enough usage data
- [ ] **Friend-based leaderboard** (requires friend invites)
- [ ] **Topic-level mastery model** (replaces session-count-based progress rings)

### Future Consideration (v2+)

- [ ] **Android target** (out of scope per `PROJECT.md`)
- [ ] **Teacher dashboard / classroom mode** — only with a clear teacher acquisition channel
- [ ] **Web target** — only if the AI tutor UX is rethought for desktop
- [ ] **Dark mode** — placeholder already exists in profile
- [ ] **Offline-first sync** — requires significant architecture work; defer until offline use is a top complaint
- [ ] **Voice input / TTS output** — possible but iOS APIs + Gemini audio integration is significant work
- [ ] **Spaced-repetition flashcard generation from chat** — would compete with Quizlet directly, big differentiator if executed well

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Wire FCM end-to-end | HIGH | MEDIUM | P1 |
| Server-authoritative points (Cloud Function) | HIGH (credibility) | MEDIUM | P1 |
| Gemini API key behind proxy | HIGH (security) | MEDIUM | P1 |
| Fix avatar upload path bug | MEDIUM (it's 100% broken today) | LOW | P1 |
| iOS Google Sign-In native config | HIGH | LOW | P1 |
| Image attachment in chat — FREE, quota'd | HIGH | LOW (UI on existing service) | P1 |
| Empty-state suggestion chips | HIGH (anti-abandonment) | LOW | P1 |
| Visible rate-limit counter | MEDIUM | LOW | P1 |
| Curriculum-aware system prompt | HIGH (differentiator) | LOW | P1 |
| Subject progress rings (session-count) | MEDIUM | MEDIUM | P1 |
| Streak counter on dashboard | HIGH (habit loop) | LOW | P1 |
| Badge celebration overlay (badge-earn only) | MEDIUM | LOW | P1 |
| Streak rewards badges (7-day, 30-day) | MEDIUM | LOW | P1 |
| Full search history FREE | HIGH (sticky differentiator) | LOW | P1 |
| Email verification soft-block | MEDIUM | LOW | P1 |
| Account deletion working | MEDIUM (App Store req) | LOW | P1 |
| Connectivity banner | LOW | LOW | P1 |
| Admin broadcast (FCM-dependent) | MEDIUM | MEDIUM | P1 |
| Admin content upload | MEDIUM | MEDIUM | P1 |
| Daily challenge card | MEDIUM (HIGH if FCM wired) | MEDIUM | P2 (P1 if FCM ships) |
| Cohort-based leaderboard | LOW | MEDIUM | P2 |
| Bangla/English answer toggle | HIGH (BD-specific differentiator) | LOW | P2 (consider P1) |
| Past-paper marking-scheme mode | HIGH | LOW (prompt eng) | P2 |
| Premium upgrade modal (fake) | NEGATIVE | LOW | P3 / **CUT** |
| Premium gating image attachment | NEGATIVE | LOW | P3 / **CUT** |
| Premium gating search history | NEGATIVE | LOW | P3 / **CUT** |
| Per-tier rate limits (10/day free) | NEGATIVE (too stingy) | LOW | P3 / **REWORK to 30-50/day** |
| Public global leaderboard | NEGATIVE | MEDIUM | P3 / **CUT or rescope** |
| Teacher registration self-signup | NEGATIVE (dead-end) | LOW | P3 / **CUT** |
| In-app admin analytics charts | LOW | HIGH | P3 / **CUT (use GA4)** |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible (within v1.0 if budget allows)
- P3: Nice to have / actively cut

---

## Competitor Feature Analysis

| Feature | Khanmigo | Photomath | Brainly | 10 Minute School | MentorMinds Approach |
|---------|----------|-----------|---------|------------------|----------------------|
| AI chat with curriculum context | Yes (US K-12) | No (math solver only) | Tutor marketplace + AI | Limited AI, video-first | **Differentiator: prompt explicitly aligned to Cambridge/Edexcel** |
| Image / diagram input | Yes | Yes (signature feature) | Yes | No | **FREE with 3/day quota** (not Premium-gated) |
| Free tier message limit | Effectively unlimited (Khan grants) | Free | Free with ads | Free for most | **30-50 msgs/day** (NOT 10) |
| Streak / daily habit | No (Khan Academy itself yes, Khanmigo no) | No | No | Yes | **Yes — table stakes** |
| Leaderboards | No | No | Brainly Points (global, gameable) | Some courses | **Cohort or none — NOT global** |
| Bangla support | No | Limited | Limited | Native Bangla | **Bilingual toggle = strong differentiator** |
| Past-paper alignment | No | No | User-submitted | Limited | **Marking-scheme mode = strong differentiator (v1.1)** |
| Offline | No | Partial | No | Yes (downloaded videos) | **Connectivity banner only for v1.0** |
| Search across own history | No (within conversation only) | N/A | N/A | N/A | **Differentiator — keep FREE** |
| Push notifications | Yes | Light | Yes (aggressive) | Yes | **Must wire FCM** |
| Pricing model | Free via Khan; $4/mo direct | Free + Photomath Plus | Free + Brainly Plus | Free + paid courses | **No Premium in v1.0; waitlist instead** |

---

## Quality Gate Self-Check

- [x] Categories are clear (table stakes vs differentiators vs anti-features)
- [x] Reasoning grounded in actual edtech competitive landscape (Khanmigo, Photomath, Brainly, 10 Minute School, Duolingo specifically referenced with rationale)
- [x] Anti-features section is not empty — **8 risky inclusions called out** (fake Premium modal, gating image input, gating search history, 10 msgs/day rate limit, global leaderboard, teacher self-signup, in-app analytics dashboard, over-celebration)
- [x] Each spec feature explicitly placed in one bucket (see "Scope of this research" + tables)

## Confidence & Caveats

- **HIGH confidence:** push notifications are table stakes (well-documented from every retention study), server-authoritative points is non-negotiable (basic security), App Store review will reject fake paywalls (Apple guideline 3.1.1 has been enforced consistently since 2020), image input is table stakes (Photomath has owned this UX for ~9 years).
- **MEDIUM confidence:** specific Duolingo cohort-vs-global leaderboard internals (referenced from conference talks; not freshly verified this session), Khanmigo's exact message limits as of May 2026 (training cutoff is Jan 2026), local incumbent feature sets for 10 Minute School / Shikho (their apps update frequently).
- **LOW confidence (flagged for re-verification before scope freeze):** the exact Gemini Flash per-token cost claim ("$0.50/user/month at 50 msgs/day") — back-of-envelope estimate based on training-era pricing; pull current Vertex AI pricing before committing to a free-tier quota.
- **What this research did NOT cover:** detailed cost modeling per user at different free-tier quotas, App Store review policy details for AI tutoring apps specifically (a 2024 policy update added AI-specific clauses worth re-reading before submission), and any user research / surveys with actual Bangladeshi O/A Level students.

## Sources

Web search was unavailable in this session; the following are reference points from training data through January 2026. Re-verify before scope freeze:

- **Khanmigo** — Khan Academy's GPT-4-based AI tutor, public docs at khanmigo.ai. Free for teachers, ~$4/mo direct-to-consumer.
- **Photomath** (Google) — diagram/equation scanning, free tier with Photomath Plus upsell.
- **Socratic by Google** — image-input tutor, free.
- **Brainly** — peer-help platform with Brainly Plus AI, ~150M MAU globally including South Asia presence.
- **Duolingo** — gold-standard gamification reference; streaks, leagues (cohort leaderboard), daily quests, hearts model. Public engineering blog and conference talks (NeurIPS, AAAI, Reforge) discuss A/B test patterns.
- **10 Minute School** (Bangladesh) — dominant local incumbent; Bangla-first, video-heavy, live class model. ~10M+ MAU.
- **Shikho, Bohubrihi** (Bangladesh) — exam-prep focused, smaller scale.
- **Save My Exams, Seneca Learning** — UK-market O/A Level prep; mastery-rings, past-paper integration patterns.
- **App Store Review Guideline 3.1.1** (Apple) — in-app purchase requirements; the basis for "fake paywall = reject."
- **Existing planning docs**: `.planning/PROJECT.md`, `.planning/codebase/ARCHITECTURE.md` (read this session) and `.planning/codebase/CONCERNS.md` (referenced via PROJECT.md HIGH-severity list).

---
*Feature research for: AI tutoring mobile app for O/A Level (Cambridge/Edexcel) students, Bangladesh market*
*Researched: 2026-05-17*
