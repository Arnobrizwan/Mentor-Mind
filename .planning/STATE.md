---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: planning
stopped_at: Phase 1 context gathered
last_updated: "2026-05-18T02:49:30.313Z"
last_activity: 2026-05-18
progress:
  total_phases: 7
  completed_phases: 0
  total_plans: 11
  completed_plans: 11
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-17)

**Core value:** A student preparing for O/A Levels can ask MentorBot a subject question and get a useful, curriculum-aligned answer in under 10 seconds — every single day, on a free tier that still feels usable.
**Current focus:** Phase 2 — cloud functions scaffolding + app check

## Current Position

Phase: 2
Plan: Not started
Status: Ready to plan
Last activity: 2026-05-18

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 11
- Average duration: —
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 11 | - | - |

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

### Pending Todos

None yet.

### Blockers/Concerns

- **App Store 3.1.1 risk** (Phase 5): Stripe-only digital subscription may be rejected; mitigation is external Safari flow. Fallback path = Apple IAP in v1.1 before App Store submission. Re-surface during Phase 5 planning.
- **Verification pass before Phase 2** (from research): re-verify `cloud_functions ^5.x` `onCallStream` support, Firestore region of `mentor-mind-aa765`, Node 22 GA on Functions v2, `firebase_app_check ^0.3.2` Apple provider class name. Run `flutter pub outdated` before pinning.
- **PR sequencing** (Phase 1 → Phase 7): refactor MUST be pure `git mv` (PR A); lint/`withOpacity` burndown is PR B in Phase 7. Mixing destroys `git log --follow`.

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| *(none — first milestone)* | | | |

## Session Continuity

Last session: 2026-05-17T09:21:53.004Z
Stopped at: Phase 1 context gathered
Resume file: .planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-CONTEXT.md
