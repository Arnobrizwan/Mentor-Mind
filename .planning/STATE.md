---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: Ready to discuss
stopped_at: Phase 2 complete; Phase 3 ready to discuss
last_updated: "2026-05-19T02:26:00.448Z"
last_activity: 2026-05-19
progress:
  total_phases: 7
  completed_phases: 2
  total_plans: 22
  completed_plans: 22
  percent: 29
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-17)

**Core value:** A student preparing for O/A Levels can ask MentorBot a subject question and get a useful, curriculum-aligned answer in under 10 seconds — every single day, on a free tier that still feels usable.
**Current focus:** Phase 03 — Gemini proxy + server-side rate limiting

## Current Position

Phase: 3
Plan: Not started
Status: Ready to discuss
Last activity: 2026-05-19

Progress: [██████████] 100%

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

Last session: 2026-05-19T00:00:00.000Z
Stopped at: Phase 2 complete; Phase 3 ready to discuss
Resume file: .planning/phases/02-cloud-functions-scaffolding-app-check/02-11-phase-closeout-SUMMARY.md
