---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
stopped_at: Phase 3 PR-1 pre-billing subset complete (4/15) — paused at 03-04 live Vertex checkpoint pending GCP billing enable
last_updated: "2026-05-19T09:30:00.000Z"
last_activity: 2026-05-19 -- Phase 03 plans 03-01, 03-02, 03-03, 03-05 executed (PR-1 pre-billing safe subset)
progress:
  total_phases: 7
  completed_phases: 2
  total_plans: 52
  completed_plans: 26
  percent: 50
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-17)

**Core value:** A student preparing for O/A Levels can ask MentorBot a subject question and get a useful, curriculum-aligned answer in under 10 seconds — every single day, on a free tier that still feels usable.
**Current focus:** Phase 03 — Gemini proxy + server-side rate limiting (4/15 plans landed; blocked on GCP billing)

## Current Position

Phase: 3
Plan: 03-04 (blocking-human checkpoint — live Vertex AI model availability probe)
Status: Paused — billing prerequisite outstanding
Last activity: 2026-05-19 -- Plans 03-01, 03-02, 03-03, 03-05 committed to main (28/28 jest tests green; build + lint clean)

Progress: [███░░░░░░░] 27% (4/15 phase-3 plans)

## Phase 03 Resume Gate (BLOCKING)

Plans 03-04, 03-06, 03-07, 03-08, 03-09, 03-10, 03-11, 03-12, 03-13, 03-14, 03-15 are paused pending the following human actions on `mentor-mind-aa765`:

1. **Enable GCP billing** (`gcloud billing projects describe mentor-mind-aa765 --format='value(billingEnabled)'` returns `False` as of 2026-05-19T08:54Z):
   ```bash
   gcloud billing projects link mentor-mind-aa765 --billing-account=0121EC-5D572E-57FEE1
   ```
2. **Enable Vertex AI API**:
   ```bash
   gcloud config set project mentor-mind-aa765
   gcloud services enable aiplatform.googleapis.com
   ```
3. **Set up Application Default Credentials** for the 03-04 probe:
   ```bash
   gcloud auth application-default login
   ```
4. **Run the model availability probe** (created in 03-04 Task 1, not yet executed):
   ```bash
   node functions/tool/verify-model-availability.js
   ```
   Report back `a` / `b` / `c` / `d` per 03-04-model-availability-checkpoint-PLAN.md §Task 2.

Resume command (once billing is on): `/gsd-execute-phase 03 --wave 2` — picks up at 03-04, then proceeds through 03-06, 03-07 (Wave 3), Wave 4 (PR-2: backend setup + firestore rules), Wave 5-6 (PR-3: Dart-side swap), Wave 7 (closeout).

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

Last session: 2026-05-19T09:30:00Z
Stopped at: Phase 3 PR-1 pre-billing subset complete (4/15) — paused at 03-04 live-Vertex checkpoint
Resume file: .planning/phases/03-gemini-proxy-server-side-rate-limiting/03-04-model-availability-checkpoint-PLAN.md
Last 4 commits on main:
- 3e0182f docs(03-05): complete rate-limit-transaction plan summary
- fa8229a feat(functions): fill rate_limit.ts — transactional daily + burst + monthly + premium bypass
- a8bd02e docs(03-03): complete vertex-gemini-client plan summary
- 5d6d5c9 feat(functions): replace gemini.ts stub with Vertex AI client + GeminiClient seam + fake
Test suite: 28/28 green (quota 7 + gemini 8 + rate_limit 13). Build + lint clean.
