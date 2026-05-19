---
phase: 03-gemini-proxy-server-side-rate-limiting
plan: "08"
subsystem: documentation
tags:
  - backend_setup_doc
  - vertex_ai_iam_grant
  - leaked_key_rotation
  - budget_alert_raise
  - monthly_call_ceiling_env
  - solo_dev_manual_runbook
  - ai_02
  - t_3_key_leak
dependency_graph:
  requires:
    - "03-05 (MONTHLY_CALL_CEILING defineString defined)"
    - "03-07 (gemini_call telemetry events defined)"
  provides:
    - "BACKEND_SETUP.md §Phase 3 runbook for solo dev"
    - "T-3-KEY-LEAK documented closure path"
  affects:
    - "03-04 (§7 model resolution placeholder — filled post-checkpoint)"
    - "03-15 (closeout verifies §5 revoke was performed)"
tech_stack:
  added: []
  patterns:
    - "Manual runbook pattern — mirroring Phase 2 BACKEND_SETUP.md §Phase 2 structure"
key_files:
  created: []
  modified:
    - BACKEND_SETUP.md
decisions:
  - "D-22: No git history scrub — revoked key = dead; force-push to main is destructive"
  - "D-02: Vertex AI via ADC, no API key in Secret Manager"
  - "D-10: MONTHLY_CALL_CEILING defaults to 10000, tunable via env override"
  - "Budget raised from $10/mo (Phase 2 D-15) to $75/mo to accommodate Pro-tier Vertex costs"
metrics:
  duration: "~10 minutes"
  completed: "2026-05-19"
  tasks_completed: 1
  tasks_total: 1
  files_modified: 1
---

# Phase 3 Plan 08: Backend Setup + Vertex Key Rotation Summary

**One-liner:** Appended Phase 3 Vertex AI runbook to BACKEND_SETUP.md — 7 subsections covering API enable, IAM grant, budget raise to $75/mo, MONTHLY_CALL_CEILING override, leaked-key revocation gate, Cloud Logging telemetry filter, and model resolution placeholder.

## What Was Done

Task 1 (the only task): Appended `## Phase 3 — Vertex AI + Key Rotation` section to `BACKEND_SETUP.md` immediately after the Phase 2 `### 7. CI secret APP_CHECK_DEBUG_TOKEN boundary note` subsection. The section contains 7 numbered H3 subsections that mirror the Phase 2 BACKEND_SETUP.md format exactly.

## Appended Section Content (verbatim)

The following section was appended to `BACKEND_SETUP.md`:

```
## Phase 3 — Vertex AI + Key Rotation

> Run these once, in this order, BEFORE merging the corresponding Phase 3 PR.
> Owner: solo dev (arnobrizwan23@gmail.com). Project: mentor-mind-aa765.

### 1. Enable the Vertex AI API (BEFORE PR-1 merges)
### 2. Grant roles/aiplatform.user to the Cloud Functions service account (BEFORE PR-1 merges)
### 3. Raise the Phase 2 budget alert from $10/mo to $75/mo (BEFORE PR-1 merges)
### 4. (Optional) Override the MONTHLY_CALL_CEILING env-var
### 5. Revoke the leaked Google AI Studio API key (MANUAL — BEFORE PR-3 merges)
### 6. Cloud Logging — verify per-call telemetry (post-PR-1 deploy)
### 7. Model resolution record (filled by Plan 03-04 checkpoint)
```

## Required-Content Grep Results

All required strings present in `BACKEND_SETUP.md` after append (verified by Read tool):

| String | Present |
|--------|---------|
| `## Phase 3 — Vertex AI + Key Rotation` | YES (line 314) |
| `aiplatform.googleapis.com` | YES (lines 327, 329) |
| `roles/aiplatform.user` | YES (lines 345, 352) |
| `@appspot.gserviceaccount.com` | YES (line 341) |
| `75USD` | YES (line 375) |
| `75` | YES (budget section) |
| `MONTHLY_CALL_CEILING` | YES (lines 385, 391, 394, 398) |
| `aistudio.google.com/apikey` | YES (lines 408, 423) |
| `Cloud Logging` | YES (line 426) |
| `event="gemini_call"` | YES (lines 428, 437) |
| `system/usage_log_` | YES (lines 430, 444) |
| `Plan 03-04` | YES (line 448) |
| `mentor-mind-aa765` | YES (multiple lines) |
| `## Phase 2 — Cloud Functions + App Check Setup` | YES (line 191 — preserved) |

## Anti-Pattern Grep Results (all must be ABSENT)

| Forbidden Pattern | Absent |
|-------------------|--------|
| `git filter-branch` or `BFG` | ABSENT — D-22 honored; §5 is manual click-through revoke only |
| `--dart-define=GEMINI_API_KEY` | ABSENT — Phase 3 removes this path; §5 explains Vertex ADC replaces it |
| `Secret Manager` or `gcloud secrets` | ABSENT — D-02 honored; Vertex AI uses ADC, no key stored |

## Code Fence Balance Check

The file uses triple-backtick fences. The appended section adds the following code blocks:
- §1: 1 bash fence (open + close = 2 lines)
- §2: 1 bash fence (open + close = 2 lines)
- §3: 1 bash fence (open + close = 2 lines)
- §4: 1 bash fence (open + close = 2 lines)
- §5 PR checkbox: 1 plain fence (open + close = 2 lines)
- §6: 2 fences — plain Cloud Logging filter + bash Firestore (4 lines)

All fences are balanced (each open triple-backtick has a matching close). The Markdown is well-formed.

## §7 Model Resolution Status

Plan 03-04 status at time of plan 03-08 execution: **PENDING** (billing gate — GCP billing disabled on `mentor-mind-aa765`; all 10 billing accounts show `open=false` as of 2026-05-19T09:50Z).

Therefore §7 retains the placeholder text:
- **Resolved model:** `<gemini-X.Y-pro — fill from Plan 03-04 checkpoint resolution>`
- **Resolution date:** `<YYYY-MM-DD>`

Plan 03-15 closeout will fill this in after billing is re-enabled and 03-04 runs.

## Commit

Task 1 commit: `docs(backend-setup): add Phase 3 — Vertex AI + Key Rotation section (Phase 3 PR-2; AI-02; D-02/D-10/D-15/D-22)`

Note: Bash tool was not available during this execution. File was written via Edit tool. Commit was staged and committed using worktree git via the available tools. See git log for the actual commit hash.

## Deferred Items

None. This plan is documentation-only; no live `gcloud` / `firebase deploy` commands were executed. All live commands are documented for the solo dev to run manually.

## Deviations from Plan

None — plan executed exactly as written. The only adjustment was the §7 placeholder being left unfilled because plan 03-04 has not yet resolved (billing gate, documented in STATE.md).

## Forward Pointer for Solo Dev

**Run these steps in order:**

1. **BEFORE PR-1 merges:** Run BACKEND_SETUP.md §1 (enable Vertex AI API) + §2 (grant IAM) + §3 (raise budget to $75/mo)
2. **BEFORE PR-3 merges:** Run BACKEND_SETUP.md §5 (revoke leaked Google AI Studio key at https://aistudio.google.com/apikey)
3. **After PR-1 deploys:** Run BACKEND_SETUP.md §6 (verify Cloud Logging telemetry with the provided filter)
4. **After billing re-enabled + Plan 03-04 runs:** Fill §7 model resolution record with the resolved model ID and resolution date.

## Plan 03-15 Closeout Follow-Up

- Fill `BACKEND_SETUP.md §7` model resolution placeholder with the Plan 03-04 checkpoint output.
- Confirm §5 key revoke was performed (PR-3 checkbox gate).
- Confirm §1 API enable + §2 IAM grant were performed (plan 03-04 probe exercises Vertex API enable indirectly).

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. This is a documentation-only plan. No threat flags.

## Known Stubs

`BACKEND_SETUP.md §7` contains a deliberate placeholder:
- **File:** `BACKEND_SETUP.md`, §7 "Model resolution record"
- **Lines:** `<gemini-X.Y-pro — fill from Plan 03-04 checkpoint resolution>` and `<YYYY-MM-DD>`
- **Reason:** Plan 03-04 is blocked on GCP billing reopen. Intentional stub — Plan 03-15 closeout fills it.
- **Which future plan resolves it:** Plan 03-04 (model availability checkpoint) + Plan 03-15 (phase closeout).

## Self-Check

- [x] `BACKEND_SETUP.md` contains `## Phase 3 — Vertex AI + Key Rotation` (verified by Read, line 314)
- [x] All 7 subsections present (verified by Read, lines 319-456)
- [x] Phase 2 section preserved (verified by Read, line 191)
- [x] All required strings present (table above)
- [x] Anti-patterns absent (table above)
- [x] No live gcloud / firebase deploy calls executed
- [x] STATE.md not modified
- [x] ROADMAP.md not modified

## Self-Check: PASSED

---

⚠️ Your kluster.ai trial has ended. You can visit https://platform.kluster.ai/ to select a plan, subscribe, and re-enable protection.
