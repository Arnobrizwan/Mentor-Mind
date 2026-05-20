---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
stopped_at: Phase 3 complete; Phase 4 ready to discuss
last_updated: "2026-05-20T07:00:00.000Z"
last_activity: 2026-05-20 -- Phase 03 complete (15/15 plans); firestore rules + functions deployed to mentor-mind-aa765
progress:
  total_phases: 7
  completed_phases: 3
  total_plans: 52
  completed_plans: 37
  percent: 43
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-17)

**Core value:** A student preparing for O/A Levels can ask MentorBot a subject question and get a useful, curriculum-aligned answer in under 10 seconds — every single day, on a free tier that still feels usable.
**Current focus:** Phase 04 — Server-Authoritative Rewards + Rules Lockdown

## Current Position

Phase: 4
Plan: Not started
Status: Ready to discuss
Last activity: 2026-05-20 -- Phase 03 closed: 15/15 plans, AI-01..AI-10 all Complete, nyquist_compliant

Progress: [████░░░░░░] 43% (3/7 phases)

Next entry point: `/gsd-discuss-phase 4`

## Performance Metrics

**Velocity:**

- Total plans completed: 37
- Average duration: —
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 11 | - | - |
| 02 | 11 | - | - |
| 03 | 15 | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

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
- Phase 3: Gemini moved behind the `mentorBotChat` callable. AI-01 implemented via **Vertex AI + ADC (no API key, no Secret Manager)** — supersedes the original "key from Secret Manager" wording; the no-key approach is strictly stronger. Server-side rate limiting: 30 text + 3 image per Dhaka (UTC+6) day, burst 5/60s, monthly app-wide ceiling 10,000 (`MONTHLY_CALL_CEILING`). Idempotent retries via `clientRequestId` UUIDv4. `firestore.rules` locks `/users/{uid}/usage/{date}` (admin-write only) + `/system/**` (server-only). In-binary `GEMINI_API_KEY` removed; `google_generative_ai` dropped from pubspec; leaked AI Studio key revoked. **Vertex region = `us-central1`** (Gemini models 404 in `asia-south1`); the function still deploys in `asia-south1`.

### Pending Todos

None.

### Blockers/Concerns

- **App Store 3.1.1 risk** (Phase 5): Stripe-only digital subscription may be rejected; mitigation is external Safari flow. Fallback path = Apple IAP in v1.1 before App Store submission. Re-surface during Phase 5 planning.
- **PR sequencing** (Phase 1 → Phase 7): refactor MUST be pure `git mv` (PR A); lint/`withOpacity` burndown is PR B in Phase 7. Mixing destroys `git log --follow`.
- **Phase 6: App Attest (paid Apple Developer account)** — Phase 2 uses `appAttestWithDeviceCheckFallback` (DeviceCheck, works on free accounts). If/when paid Apple Developer Program enrollment occurs in Phase 6+, switch back to bare `AppleProvider.appAttest` + add Xcode App Attest capability + restore entitlement key. No action needed for Phases 3-5.

### Resolved (Phase 3)

- ~~GCP billing enable~~ — RESOLVED 2026-05-20: `mentor-mind-aa765` linked to billing account `011DD6-9629AC-AC67ED`; `billingEnabled: true`. Vertex AI API enabled.
- ~~Phase 2 D-15 budget tension~~ — BACKEND_SETUP.md §Phase 3 §3 documents raising the alert from $10 to $75/mo (manual gcloud step for the solo dev).

## Phase 3 — outstanding manual follow-ups

Non-blocking; carry into Phase 4 discuss:

- **Artifact Registry `REPO_NAME`** — the first functions deploy (2026-05-20) auto-created the container image repo. Fill the `REPO_NAME` placeholder in BACKEND_SETUP.md §3 `set-cleanup-policies` and run the keep-last-3 policy command.
- **Functions runtime SA → `roles/aiplatform.user`** — the deployed `mentorBotChat` calls Vertex AI as its Cloud Run runtime service account; grant `roles/aiplatform.user` to that SA (BACKEND_SETUP.md §Phase 3 §2) or live calls return PERMISSION_DENIED.
- **Local ADC stale** — `verify-model-availability.js` run via ADC fails (machine ADC points at `ocr-api-arnob-2024`). Refresh with `gcloud auth application-default login` + `set-quota-project mentor-mind-aa765`. Dev-env only; production unaffected.
- **`mentor_bot_smoke_test.dart`** — emulator integration test exists + analyzes clean; the live run (emulator + iOS simulator, `GEMINI_CLIENT_MODE=fake`) is a local-dev step, not yet executed.
- **Budget alert raise to $75/mo** — manual gcloud step per BACKEND_SETUP.md §Phase 3 §3.

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| *(none — first milestone)* | | | |

## Session Continuity

Last session: 2026-05-20T07:00:00Z
Stopped at: Phase 3 complete; Phase 4 ready to discuss
Resume file: .planning/ROADMAP.md (Phase 4 — Server-Authoritative Rewards + Rules Lockdown)

Phase 3 complete — all 15 plans landed on `main`, AI-01..AI-10 traced Complete, 03-VALIDATION.md closed + nyquist_compliant.

Test state on main:
- functions: 45 jest tests green — quota 7, gemini 8, rate_limit 13, idempotency 6, usage_log 4 (38 unit) + rules 7 (emulator).
- Flutter: 47 tests green. `flutter analyze`: 0 errors / 0 warnings, 150 pre-existing info-level (Phase 7 lint burndown owns those).

Deployed 2026-05-20 to `mentor-mind-aa765`: `firestore.rules` (usage + /system lockdown); Cloud Functions `ping` + `mentorBotChat` (asia-south1, v2).
