---
phase: 02-cloud-functions-scaffolding-app-check
plan: "05"
subsystem: infra
tags: [gcloud, billing, artifact_registry, app_check, debug_token, ci_secret, region_pin, backend_docs]

requires:
  - phase: 02-cloud-functions-scaffolding-app-check (plans 01-04)
    provides: functions/ monorepo + ping callable + emulator config — the infra these commands guard

provides:
  - BACKEND_SETUP.md Phase 2 section with 7 canonical gcloud/Firebase commands the solo dev runs post-merge
  - Billing-enable command (prerequisite for Phase 3 deploy)
  - $10/mo budget alert command with 50/90/100% thresholds wired to arnobrizwan23@gmail.com
  - Artifact Registry keep-last-3 cleanup-policy command + keep-last-3.json inline
  - Region pin verification command + DO NOT us-central1 warning
  - App Check kill-switch URL (console.firebase.google.com/project/mentor-mind-aa765/appcheck)
  - Debug token registration 6-step guide + rotation cadence (D-09)
  - CI secret APP_CHECK_DEBUG_TOKEN boundary note (Phase 2 emulator does NOT consume it)

affects:
  - 02-06-app-check-activation (references §6 debug token steps)
  - 02-10-ci-functions-job-lift (references APP_CHECK_DEBUG_TOKEN boundary note)
  - 02-11-phase-closeout (records manual execution evidence for these commands)
  - Phase 3 (billing-enable + Artifact Registry REPO_NAME fill-in are Phase 3 prerequisites)

tech-stack:
  added: []
  patterns:
    - "Doc-only plan: gcloud commands locked in markdown, solo dev runs once post-merge (D-14)"
    - "Grep-based verification: plan verify gates check markdown content, NOT gcloud execution"

key-files:
  created: []
  modified:
    - BACKEND_SETUP.md

key-decisions:
  - "D-14 honored: gcloud CLI commands in BACKEND_SETUP.md, NOT Terraform (solo dev, single env)"
  - "D-15 honored: $10/mo budget; thresholds 50%/90%/100%; recipient arnobrizwan23@gmail.com; project mentor-mind-aa765; billing account 0121EC-5D572E-57FEE1"
  - "D-16 honored: Artifact Registry keep-last-3 cleanup policy with keepCount: 3; REPO_NAME left as placeholder for Phase 3 (repo auto-created on first deploy)"
  - "D-17 honored: gcloud functions list --regions=asia-south1 --v2 verification command + DO NOT us-central1 warning"
  - "D-10 + D-08 honored: 6-step debug token registration guide (flutter run → Xcode console → Firebase Console) + rotation cadence"
  - "D-13 honored: APP_CHECK_DEBUG_TOKEN CI secret boundary note — Phase 2 emulator does NOT consume it; reserved for Phase 3+"
  - "NO gcloud command executed during plan execution — markdown is the deliverable (RESEARCH Open Question B)"

patterns-established:
  - "Phase subsection pattern: BACKEND_SETUP.md grows one ## Phase N section per phase, separated by --- horizontal rule"

requirements-completed: [FUNC-04, FUNC-05]

duration: 2min
completed: "2026-05-19"
---

# Phase 2 Plan 05: Backend Setup GCP Infra Summary

**Canonical gcloud commands for billing-enable, $10/mo budget alert, Artifact Registry keep-last-3 cleanup, asia-south1 region pin verification, App Check kill-switch URL, debug token registration flow, and CI secret APP_CHECK_DEBUG_TOKEN boundary documented in BACKEND_SETUP.md — solo dev runs once post-merge**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-05-19T01:27:17Z
- **Completed:** 2026-05-19T01:28:38Z
- **Tasks:** 1 of 1
- **Files modified:** 1

## Accomplishments

- Appended `## Phase 2 — Cloud Functions + App Check Setup` section (7 subsections, 124 lines) to `BACKEND_SETUP.md` with all commands verbatim from RESEARCH §GCP CLI Commands and §App Check Detailed Notes.
- Locked billing account `0121EC-5D572E-57FEE1` as the target for both the billing-enable and budget-create commands — prevents drift across solo dev machine restarts.
- Locked recipient `arnobrizwan23@gmail.com` in the budget command note so the budget alert is correctly wired without a manual lookup.
- All 13 grep verification gates passed green (Phase 2 heading, billing-enable, billing account, budget-create, 10USD, email, set-cleanup-policies, keepCount, region-pin, us-central1-warning, kill-switch URL, APP_CHECK_DEBUG_TOKEN, debug token + Firebase Console).

## Task Commits

1. **Task 1: Append Phase 2 section to BACKEND_SETUP.md** — `2af7b65` (docs)

**Plan metadata commit:** (see final-commit below)

## Files Created/Modified

- `/Users/arnobrizwan/Mentor-Mind/BACKEND_SETUP.md` — Appended 124-line `## Phase 2 — Cloud Functions + App Check Setup` section with 7 subsections covering billing-enable (§1), budget alert (§2), Artifact Registry cleanup (§3), region pin verification (§4), App Check kill-switch URL (§5), debug token registration (§6), CI secret boundary (§7)

## Decisions Made

None beyond honoring the plan's documented decisions (D-08 through D-17). Plan executed exactly as specified — doc-only, no gcloud execution.

## Deviations from Plan

None — plan executed exactly as written.

## Verification Results (8 grep gates — all passed)

```
1. grep "^## Phase 2 — Cloud Functions"    → PASS
2. grep "gcloud billing projects link ..."  → PASS
3. grep "0121EC-5D572E-57FEE1"             → PASS
4. grep "gcloud billing budgets create"    → PASS
5. grep "10USD"                            → PASS
6. grep "arnobrizwan23@gmail.com"          → PASS
7. grep "set-cleanup-policies"             → PASS
8. grep "keepCount"                        → PASS
9. grep "gcloud functions list --regions=asia-south1" → PASS
10. grep "us-central1"                     → PASS
11. grep "console.firebase.google.com/project/mentor-mind-aa765/appcheck" → PASS
12. grep "APP_CHECK_DEBUG_TOKEN"           → PASS
13. grep -iE "debug.*token"               → PASS
```

## IMPORTANT: NO gcloud Commands Executed

This plan is documentation-only. NO `gcloud` command was executed during plan execution. The solo dev runs the following commands ONCE post-merge, in this order:

1. `gcloud billing projects link mentor-mind-aa765 --billing-account=0121EC-5D572E-57FEE1` (§1)
2. Check `gcloud billing budgets list --billing-account=0121EC-5D572E-57FEE1` first, then `gcloud billing budgets create ...` (§2)
3. After first Phase 3 deploy: discover REPO_NAME via `gcloud artifacts repositories list`, then apply `gcloud artifacts repositories set-cleanup-policies REPO_NAME ...` (§3)
4. After Phase 3 deploy: verify `gcloud functions list --regions=asia-south1 --v2 --project=mentor-mind-aa765` (§4)

Plan 02-11 (phase-closeout) records manual execution evidence for each command, or marks them ⏸ deferred to Phase 3 where the actual deploy happens.

## Known Stubs

- `REPO_NAME` in §3 Artifact Registry cleanup command — Artifact Registry repository is auto-created on first Phase 3 deploy; actual name (typically `gcf-artifacts`) is unknown until then. Phase 3 SUMMARY must fill this in and re-run the cleanup-policy command with the actual name.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. This plan only modifies BACKEND_SETUP.md (documentation). No threat flags.

## Issues Encountered

None.

## User Setup Required

**Solo dev runs these commands post-merge (one-shot, in order):**

1. Enable billing: `gcloud billing projects link mentor-mind-aa765 --billing-account=0121EC-5D572E-57FEE1`
2. Verify no existing budget, then create: `gcloud billing budgets create --billing-account=0121EC-5D572E-57FEE1 --display-name="MentorMinds Phase 2 Guardrail" --budget-amount=10USD --filter-projects="projects/mentor-mind-aa765" --threshold-rule=percent=0.5 --threshold-rule=percent=0.9 --threshold-rule=percent=1.0`
3. Ensure `arnobrizwan23@gmail.com` is a billing administrator on account `0121EC-5D572E-57FEE1`
4. After Phase 3 first deploy: find REPO_NAME and apply Artifact Registry cleanup policy (§3)
5. Register dev simulator debug token via Xcode console log + Firebase Console (§6)
6. Store `APP_CHECK_DEBUG_TOKEN` in GitHub Actions repository secrets (§7)

## Next Phase Readiness

- Phase 2 PR-2 is doc-only; it merges independently of PR-1 (functions monorepo) and PR-3 (App Check end-to-end).
- D-19 PR sequence: PR-1 → PR-2 → PR-3. PR-2 technically could merge before PR-1 (no code dependency).
- Plan 02-06 (App Check activation) references §6 debug token steps — those are now in BACKEND_SETUP.md.
- Plan 02-11 (phase-closeout) will record manual gcloud execution evidence.

## Self-Check: PASSED

- `BACKEND_SETUP.md` modified: confirmed (124 lines added)
- Commit `2af7b65` exists: confirmed (`git log --oneline -1` = `2af7b65 docs(backend): document Phase 2 GCP infra commands...`)
- All 13 grep gates: PASSED

---
*Phase: 02-cloud-functions-scaffolding-app-check*
*Completed: 2026-05-19*
