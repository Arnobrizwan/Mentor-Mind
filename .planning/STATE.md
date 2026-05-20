---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
stopped_at: Phase 3 — 13/15 plans complete; 03-04 + 03-15 deferred on closed GCP billing account
last_updated: "2026-05-20T00:45:00.000Z"
last_activity: 2026-05-20 -- Phase 03 plans 03-06..03-14 executed (PR-2 + PR-3 local-code subset)
progress:
  total_phases: 7
  completed_phases: 2
  total_plans: 52
  completed_plans: 35
  percent: 67
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-17)

**Core value:** A student preparing for O/A Levels can ask MentorBot a subject question and get a useful, curriculum-aligned answer in under 10 seconds — every single day, on a free tier that still feels usable.
**Current focus:** Phase 03 — Gemini proxy + server-side rate limiting (13/15 plans landed; 2 deferred on GCP billing)

## Current Position

Phase: 3
Plan: 03-04 (blocking-human checkpoint — live Vertex AI model availability probe) + 03-15 (closeout)
Status: 13/15 complete — both remaining plans deferred on a closed GCP billing account
Last activity: 2026-05-20 -- Plans 03-06..03-14 committed to main. functions 45 tests green (38 unit + 7 rules); Flutter 47 tests green; build + lint clean.

Progress: [█████████░] 87% (13/15 phase-3 plans)

## Phase 03 Resume Gate (BLOCKING — 2 plans only)

13 of 15 Phase 3 plans are complete and on `main`. **03-04 (live Vertex model probe) and 03-15 (closeout) remain.** Both are blocked because **all 10 gcloud billing accounts on `arnobrizwan23@gmail.com` are closed** (`open: false`) as of 2026-05-20. `gcloud billing projects link` rejects closed accounts.

**Step 1 — reopen a billing account (human, GCP Console):**
Open https://console.cloud.google.com/billing, click into a closed "Firebase Payment" account (e.g. `0121EC-5D572E-57FEE1`), hit Reactivate, and re-verify the payment method (likely an expired card). Status must flip to Active.

**Step 2 — link + enable (run after Step 1):**
```bash
gcloud billing projects link mentor-mind-aa765 --billing-account=<REOPENED_ACCOUNT_ID>
gcloud config set project mentor-mind-aa765
gcloud services enable aiplatform.googleapis.com
gcloud auth application-default login
```

**Step 3 — run the 03-04 model probe** (the script `functions/tool/verify-model-availability.js` is created BY plan 03-04, which has not run yet):
Resume with `/gsd-execute-phase 03` — it picks up 03-04 (creates + runs the probe, records the resolved model in `functions/src/lib/gemini.ts` `MODEL_CONFIG.modelId`) then 03-15 (closeout: VALIDATION.md, requirements traceability, leaked-key rotation confirm, ROADMAP close).

**Also outstanding before Phase 3 can truly ship (documented in BACKEND_SETUP.md §Phase 3):**
- `firebase deploy --only firestore:rules,functions` — deploys the rules lockdown + mentorBotChat (needs billing).
- Revoke the leaked Google AI Studio API key at https://aistudio.google.com/apikey (manual; BACKEND_SETUP.md §5).
- Fill the Artifact Registry `REPO_NAME` placeholder after first functions deploy.
- Run the `integration_test/mentor_bot_smoke_test.dart` smoke locally (emulator + iOS simulator, `GEMINI_CLIENT_MODE=fake`).

## Performance Metrics

**Velocity:**

- Total plans completed: 22
- Average duration: —
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 11 | - | - |
| 02 | 11 | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: — (pre-execution)

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Roadmap: 7 phases, Horizontal Layers, dependency-ordered (P1 Foundation → P2 Functions+AppCheck → P3 Gemini Proxy → P4 Server Rewards → P5 Stripe+Admin → P6 FCM+Daily Challenge → P7 UI Polish+Observability+Lint).
- Stripe-only payment for v1.0 with external Safari Checkout (App Store 3.1.1 mitigation); Apple IAP deferred to v1.1.
- Global leaderboard CUT from v1.0 (both cohort + global deferred to v2).
- Daily Challenge SHIPS in v1.0 (Phase 6, depends on FCM).
- Email verification is a HARD block on Tutor + Sessions (banner elsewhere is informational).
- iOS deployment target bumped 13→14 in Phase 1 to unlock App Attest as primary App Check provider.
- Bundle ID aligned to `com.mentorminds.mentorMinds` in Phase 1 (requires Xcode + Firebase iOS app re-registration + APNs re-association).
- Free-tier cap locked at 30 text + 3 image messages per UTC+6 day.
- Phase 2: TypeScript Node 20 functions/ monorepo in asia-south1; App Check (appAttestWithDeviceCheckFallback release / Debug dev — free Apple Developer account); ping callable canary with enforceAppCheck:true; $10/mo billing budget + Artifact Registry keep-last-3 documented in BACKEND_SETUP.md; cloud_functions ^5.6.2 + PingRepository wired in Flutter data layer; emulator + CI integration complete.

### Pending Todos

None yet.

### Blockers/Concerns

- **App Store 3.1.1 risk** (Phase 5): Stripe-only digital subscription may be rejected; mitigation is external Safari flow. Fallback path = Apple IAP in v1.1 before App Store submission. Re-surface during Phase 5 planning.
- **PR sequencing** (Phase 1 → Phase 7): refactor MUST be pure `git mv` (PR A); lint/`withOpacity` burndown is PR B in Phase 7. Mixing destroys `git log --follow`.
- **Phase 3 prerequisite: GCP billing enable** — `gcloud billing projects link mentor-mind-aa765 --billing-account=0121EC-5D572E-57FEE1` must be run by solo dev before Phase 3 first deploy. Commands documented in BACKEND_SETUP.md §1. billingEnabled was false at Phase 2 close.
- **Phase 3 prerequisite: Artifact Registry REPO_NAME fill-in** — BACKEND_SETUP.md §3 `set-cleanup-policies` command has a `REPO_NAME` placeholder; fill in after first Phase 3 deploy creates the auto-named repo.
- **Phase 6: App Attest (paid Apple Developer account)** — Phase 2 uses `appAttestWithDeviceCheckFallback` (DeviceCheck, works on free accounts). If/when paid Apple Developer Program enrollment occurs in Phase 6+, switch back to bare `AppleProvider.appAttest` + add Xcode App Attest capability + restore entitlement key. No action needed for Phases 3-5.

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| *(none — first milestone)* | | | |

## Session Continuity

Last session: 2026-05-20T00:45:00Z
Stopped at: Phase 3 — 13/15 plans complete; 03-04 + 03-15 deferred on closed GCP billing account
Resume file: .planning/phases/03-gemini-proxy-server-side-rate-limiting/03-04-model-availability-checkpoint-PLAN.md

Phase 3 plans complete (13/15): 03-01, 03-02, 03-03, 03-05, 03-06, 03-07, 03-08, 03-09, 03-10, 03-11, 03-12, 03-13, 03-14.
Deferred (2/15): 03-04 (live Vertex probe), 03-15 (closeout) — see Resume Gate above.

Test state on main:
- functions: 45 jest tests green — quota 7, gemini 8, rate_limit 13, idempotency 6, usage_log 4 (38 unit) + rules 7 (emulator).
- Flutter: 47 tests green. `flutter analyze`: 0 errors / 0 warnings, 150 pre-existing info-level (Phase 7 lint burndown owns those).
- `npm run build` + `npm run lint` clean.

Wiring delivered: mentorBotChat callable (functions/src/index.ts) → Vertex client seam (gemini.ts) → rate-limit txn (rate_limit.ts) → firestore.rules lockdown. Flutter: MentorBotRepository + chat_viewmodel swapped off the in-binary GEMINI_API_KEY path; google_generative_ai removed from pubspec.
