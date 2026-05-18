---
phase: 02-cloud-functions-scaffolding-app-check
plan: 11
type: execute
wave: 6
depends_on: ["02-01", "02-02", "02-03", "02-04", "02-05", "02-06", "02-07", "02-08", "02-09", "02-10"]
files_modified:
  - .planning/phases/02-cloud-functions-scaffolding-app-check/02-VALIDATION.md
  - .planning/ROADMAP.md
  - .planning/REQUIREMENTS.md
  - .planning/STATE.md
autonomous: false
requirements: [FUNC-01, FUNC-02, FUNC-03, FUNC-04, FUNC-05, FUNC-06]
pr_group: PR-3
tags: [phase_closeout, validation_md_close, nyquist_compliant_flip, roadmap_close, requirements_traceability, state_md_progress]

must_haves:
  truths:
    - "Every FUNC-NN requirement (FUNC-01..FUNC-06) marked complete OR ⏸ deferred with documented mitigation (paid Apple Developer account question; production Artifact Registry repo name fill-in)"
    - "02-VALIDATION.md frontmatter flipped: `status: closed` and `nyquist_compliant: true` (subject to manual-only rows that legitimately remain ⏸ per VALIDATION §nyquist_compliant note)"
    - "All 10 Per-Plan Verification Map rows in 02-VALIDATION.md turned ✅ (or explicitly marked ⏸ blocked with a Phase 6/Phase 3 follow-up reference)"
    - "ROADMAP.md Phase 2 status flipped from `Not started` to `Complete` with completion date; per-phase counts updated"
    - "REQUIREMENTS.md traceability rows for FUNC-01..FUNC-06 flipped from `Pending` to `Complete` (status column)"
    - "STATE.md current position advanced to Phase 3 ready (or to whatever the next planned phase is)"
    - "A human checkpoint surfaces the unresolved Apple Developer Program account question (FUNC-03 / Plan 02-06 unresolved_question) — the closeout proceeds only after the user confirms either (a) paid account confirmed + Xcode App Attest capability added, or (b) substituted with appAttestWithDeviceCheckFallback, or (c) explicitly deferred to Phase 6+"
    - "All 11 SUMMARY.md files from Plans 02-01..02-10 + this one are committed and discoverable"
  artifacts:
    - path: ".planning/phases/02-cloud-functions-scaffolding-app-check/02-VALIDATION.md"
      provides: "Updated frontmatter (status: closed, nyquist_compliant: true) + all 10 rows marked ✅/⏸"
      contains: "nyquist_compliant: true"
    - path: ".planning/ROADMAP.md"
      provides: "Phase 2 status row updated to Complete + completion date + per-phase progress counts"
      contains: "Phase 2 . Plans Complete . 11/11"
    - path: ".planning/REQUIREMENTS.md"
      provides: "FUNC-01..FUNC-06 traceability rows flipped from Pending to Complete"
      contains: "FUNC-01 . Phase 2 . Complete"
    - path: ".planning/STATE.md"
      provides: "Current Position advanced past Phase 2"
      contains: "Phase: 3"
  key_links:
    - from: ".planning/phases/02-.../02-VALIDATION.md frontmatter"
      to: "Plans 02-01..02-10 SUMMARY files"
      via: "Each plan's SUMMARY confirms the matching row's automated command was green"
      pattern: "✅"
    - from: ".planning/REQUIREMENTS.md traceability"
      to: ".planning/ROADMAP.md Phase 2 status"
      via: "FUNC-NN requirements all marked Complete = Phase 2 done"
      pattern: "Complete"
---

<objective>
Close Phase 2. Verify every Plan 02-01..02-10 SUMMARY landed green; flip 02-VALIDATION.md frontmatter to `status: closed` + `nyquist_compliant: true`; mark every row in the Per-Plan Verification Map ✅ (or explicitly ⏸ with a Phase 3/6 follow-up reference); update ROADMAP.md Phase 2 row to `Complete`; update REQUIREMENTS.md traceability rows for FUNC-01..FUNC-06 from Pending to Complete; advance STATE.md current position; pause for a human checkpoint on the unresolved Apple Developer Program account question if it's still open from Plan 02-06.

Purpose: Phase 2 is the second phase to ship. Locking in nyquist_compliant and the cross-doc updates ensures Phase 3 starts from a clean, validated baseline. The human checkpoint is non-negotiable per the Plan 02-06 `unresolved_questions` block — without resolving the Apple Developer account question, `enforceAppCheck: true` becomes a production trap.

Output: 4 cross-cutting doc edits, one git commit (or two — the doc edits + the SUMMARY-walk diff), and a clear checkpoint decision recorded in this plan's SUMMARY.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md
@.planning/STATE.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-CONTEXT.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-VALIDATION.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-01-functions-monorepo-scaffold-PLAN.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-02-functions-helpers-skeleton-PLAN.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-03-ping-callable-PLAN.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-04-functions-emulator-config-PLAN.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-05-backend-setup-gcp-infra-PLAN.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-06-app-check-activation-PLAN.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-07-flutter-functions-sdk-PLAN.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-08-emulator-helper-wiring-PLAN.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-09-ping-smoke-test-PLAN.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-10-ci-functions-job-lift-PLAN.md
@CLAUDE.md

<interfaces>
Closeout sequence (4 tasks):

Task 1 — SUMMARY walk: confirm each of Plans 02-01..02-10 wrote a SUMMARY.md file with the expected commit + verify gates green. If any SUMMARY is missing OR records a red gate, STOP and surface the gap.

Task 2 — Update 02-VALIDATION.md:
  - Walk the 10 rows in the Per-Plan Verification Map (lines 49-60).
  - For each row, mark its Status column ✅ if all automated commands in the row's "Automated Command" cell ran green.
  - For rows that have manual-only or deferred verifications (notably 02-05's gcloud commands, 02-06's Xcode capability, 02-09's live emulator run if not attempted), mark ⏸ with a brief follow-up reference (e.g. "⏸ Phase 3: REPO_NAME fill-in" or "⏸ paid Apple Developer account").
  - Flip frontmatter:
    - `status: draft` → `status: closed`
    - `nyquist_compliant: false` → `nyquist_compliant: true`
    - `wave_0_complete: false` → `wave_0_complete: true`
  - Update §Validation Sign-Off — flip each checkbox `- [ ]` to `- [x]` for items that are satisfied; leave `- [ ]` (and add a clarifying note in parentheses) for items legitimately deferred per the existing nyquist_compliant note (paragraph at the bottom of the file lines 130-131 already covers this — quote it inline if helpful).
  - **Approval line: change `pending (draft)` → `closed by Plan 02-11 on YYYY-MM-DD`.**

Task 3 — Update ROADMAP.md:
  - Locate the Phase 2 entry under `## Phases` (line 20) and the row in `## Progress` table (line 142).
  - Mark Phase 2 done in the bullet list: `- [x] **Phase 2: ...**` (change `[ ]` to `[x]`) and append ` (completed YYYY-MM-DD)` matching the Phase 1 row style at line 19.
  - In the §Phase 2 detail block, update `**Plans**: TBD` to `**Plans**: 11 plans (02-01 through 02-11)`.
  - Update the Progress table row: `| 2. Cloud Functions Scaffolding + App Check | 11/11 | Complete | YYYY-MM-DD |`.

Task 4 — Update REQUIREMENTS.md traceability table:
  - Lines 282-287 currently say `| FUNC-01 | Phase 2 | Pending |` through `| FUNC-06 | Phase 2 | Pending |`.
  - Change all 6 rows' Status column from `Pending` to `Complete`.
  - Per-phase count line (line 403) update if needed: `**Per-phase counts:** P1=16, P2=6, ...` — confirm P2=6 is correct (it is per current document).

Task 5 — Update STATE.md:
  - Update `stopped_at:` to "Phase 2 complete; Phase 3 ready to plan".
  - Update `last_updated:` to today's date.
  - Update `last_activity:` to today's date.
  - Update `current_focus` (line 25): change "Phase 2 — cloud functions scaffolding + app check" to "Phase 3 — Gemini proxy + server-side rate limiting" (the next planned phase per ROADMAP).
  - In `## Current Position` block:
    - `Phase: 2` → `Phase: 3`
    - `Status: Ready to plan` → `Status: Ready to discuss` (or "Ready to plan" if the team prefers — pick whichever matches the team's /gsd workflow position; the current value is "Ready to plan", and the natural next state is "Ready to discuss" — Phase 3's /gsd:discuss-phase hasn't run yet).
  - Update progress counters in frontmatter:
    - `completed_phases: 0` → `completed_phases: 1` (wait — STATE.md frontmatter currently reads `completed_phases: 0`; check this; the previous closeout commit `4ef22ca docs(phase-01): mark Phase 1 complete` may have updated this. If STATE.md is still at `completed_phases: 0` despite Phase 1 close, also bump to `2` here; if at `1` from Phase 1 close, bump to `2`).
    - Update `total_plans:` (was 11 for Phase 1; now += 11 for Phase 2 = 22) and `completed_plans:` similarly.
    - `progress.percent`: recompute as completed_phases / total_phases.

Task 6 — Human checkpoint: Apple Developer Program account question (Plan 02-06 unresolved_question):
  - This task pauses execution (`type: checkpoint:human-verify` per `autonomous: false` plan flag).
  - Surface to the user: "Phase 2 wired App Check with `AppleProvider.appAttest` for release builds + the `appattest.environment = production` entitlement. App Attest requires a paid Apple Developer Program account ($99/yr). Confirm one of:
    (a) `arnobrizwan23@gmail.com` is enrolled in the paid Apple Developer Program AND the Xcode App Attest capability has been added (Plan 02-06 SUMMARY records this) — proceed with `appAttest` as locked in D-02.
    (b) Account is free; we substituted `AppleProvider.appAttestWithDeviceCheckFallback` in Plan 02-06 — confirm CONTEXT.md D-02 amendment is committed.
    (c) Account is free AND we kept `AppleProvider.debug` universally — confirm `enforceAppCheck: true` is removed from functions/src/index.ts OR set to false until Phase 6 enrolls in paid program.
    Without one of these three confirmations, Phase 3's production Gemini deploy will hit App Check rejection and the AI tutor will be 100% broken from launch."

  - Pause for user response. Acceptable responses: "(a)", "(b)", "(c)", or detailed text describing the chosen path. Record the response verbatim in this plan's SUMMARY.

Task 7 — Commit:
  - One commit message: `docs(phase-02): mark Phase 2 complete — 11/11 plans, all 6 FUNC reqs traced + nyquist_compliant`.
  - Files: the four edited above (02-VALIDATION.md, ROADMAP.md, REQUIREMENTS.md, STATE.md) plus this plan's eventual SUMMARY.

Plan 01-11 (Phase 1 closeout) is the reference pattern — its commit `4ef22ca docs(phase-01): mark Phase 1 complete` lifted Phase 1's equivalent doc updates. Phase 2 follows the same shape.

</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: SUMMARY walk — confirm every Plan 02-01..02-10 SUMMARY landed and reports green; surface any gaps</name>
  <files>(read-only — no file edits)</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/ (list directory)
    - Each of `02-01-functions-monorepo-scaffold-SUMMARY.md` through `02-10-ci-functions-job-lift-SUMMARY.md` (10 files)
  </read_first>
  <action>
    Step A — Enumerate SUMMARY files:
      ```bash
      ls .planning/phases/02-cloud-functions-scaffolding-app-check/*-SUMMARY.md | sort
      ```
      Expected: 10 files (02-01 through 02-10).

    Step B — For each SUMMARY, confirm:
      - The file exists and is non-empty.
      - It records the verify commands the matching PLAN.md's `<verify>` block specified, AND the exit codes were 0 (or manual-OK).
      - Any deferred / blocked items are explicitly marked.

      Greppable signals per plan SUMMARY:
        - 02-01: "npm install" or "package-lock.json" present; "test -f functions/package.json" green.
        - 02-02: "5 helper files"; grep for "not implemented" count ≥ 3.
        - 02-03: "enforceAppCheck: true"; "npm run build" exit 0.
        - 02-04: "emulators.functions.port" and "5001".
        - 02-05: "gcloud billing budgets create" mentioned; "arnobrizwan23@gmail.com" mentioned.
        - 02-06: "FirebaseAppCheck.instance.activate"; "appattest.environment = production"; Apple Developer Program account status RECORDED (PAID / FREE / UNVERIFIED).
        - 02-07: "cloud_functions: ^5"; "PingRepository"; "dart run custom_lint" reported zero layered_imports.
        - 02-08: "useFunctionsEmulator"; lib/main.dart not importing test.
        - 02-09: "ping_smoke_test.dart"; live run attempted / deferred status recorded.
        - 02-10: "dorny/paths-filter@v4"; "if: false" removed; T-1-SECRET grep empty.

    Step C — If ANY SUMMARY is missing or red, STOP and surface to the user before proceeding to Task 2. Phase closeout is a no-go until every plan's gates are green or explicitly ⏸.

    Step D — Capture the 10 commit SHAs (one per plan SUMMARY) for the eventual closeout SUMMARY:
      ```bash
      git log --oneline --grep="Phase 2" | head -20
      ```
      Record the commit SHAs corresponding to each plan; the closeout SUMMARY links them.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ls .planning/phases/02-cloud-functions-scaffolding-app-check/02-{01,02,03,04,05,06,07,08,09,10}-*-SUMMARY.md 2>/dev/null | wc -l | xargs -I{} test {} -eq 10</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; for s in .planning/phases/02-cloud-functions-scaffolding-app-check/02-*-SUMMARY.md; do test -s "$s" || { echo "EMPTY: $s"; exit 1; }; done</automated>
  </verify>
  <acceptance_criteria>
    - 10 SUMMARY.md files exist under .planning/phases/02-cloud-functions-scaffolding-app-check/ (one per plan 02-01..02-10).
    - Each is non-empty.
    - The plan-level greppable signals (per Step B's list) are present in the corresponding SUMMARY.
  </acceptance_criteria>
  <done>
    All 10 Phase 2 plan SUMMARYs are accounted for. Closeout can proceed.
  </done>
</task>

<task type="auto">
  <name>Task 2: Flip 02-VALIDATION.md frontmatter + mark all 10 rows ✅ (or explicit ⏸) + close Validation Sign-Off</name>
  <files>.planning/phases/02-cloud-functions-scaffolding-app-check/02-VALIDATION.md</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-VALIDATION.md (CURRENT — full file; confirm the 10 rows in §Per-Plan Verification Map and the §Validation Sign-Off checkboxes)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/01-foundation-refactor-ci-test-harness-ios-identity/01-VALIDATION.md (reference — Phase 1's final closed state for shape consistency)
    - Plan 02-01..02-10 SUMMARYs (from Task 1) — confirm the row-by-row green/⏸ assignment
  </read_first>
  <action>
    Step A — Frontmatter:
      Change:
        ```yaml
        status: draft
        nyquist_compliant: false
        wave_0_complete: false
        ```
      To:
        ```yaml
        status: closed
        nyquist_compliant: true
        wave_0_complete: true
        ```

    Step B — Per-Plan Verification Map (lines 49-60):
      For each of the 10 rows, set the Status column based on the matching plan's SUMMARY:
        - Row 02-01: ✅ (npm install + lint + build all green).
        - Row 02-02: ✅ (5 helper files + build + lint green).
        - Row 02-03: ✅ (ping callable exports + grep + build green).
        - Row 02-04: ✅ (firebase.json emulators.functions.port=5001 + JSON parse green).
        - Row 02-05: ✅ if all grep gates green (commands documented); ⏸ if any gcloud command was NOT executed by solo dev. The doc-only acceptance is satisfied by the grep gates per RESEARCH §Open Question B + VALIDATION §Open Question B; mark ✅ if static gates green AND record in §Manual-Only Verifications that the actual `gcloud` execution is "pending solo dev manual run".
        - Row 02-06: ✅ if Apple Developer Program account is paid AND Xcode App Attest capability added; ⏸ with "blocked-on-paid-Apple-account" reference if not — the static gates (grep for activate + entitlement + plutil) are green regardless.
        - Row 02-07: ✅ (cloud_functions added + provider/repo/model created + custom_lint zero).
        - Row 02-08: ✅ (useFunctionsEmulator wired in both files; lib doesn't import test).
        - Row 02-09: ✅ if live emulator run was attempted and green; ⏸ if deferred to local dev (static gates still green).
        - Row 02-10: ✅ (if: false removed + dorny/paths-filter@v4 + npm ci/lint/build all wired).

    Step C — Validation Sign-Off section (lines 117-126):
      Flip checkboxes:
        - `[ ] All planner-generated tasks have <verify> automated commands OR a Wave 0 dependency` → `[x]` (every plan's tasks shipped <verify> blocks).
        - `[ ] Sampling continuity: no 3 consecutive tasks without an automated verify command` → `[x]`.
        - `[ ] Wave 0 covers all ❌ W0 references above` → `[x]` (Plans 02-01..02-10 closed all Wave 0 items).
        - `[ ] No watch-mode flags in any verify command (CI must be one-shot)` → `[x]`.
        - `[ ] Feedback latency < 110 s for full suite` → `[x]` (RESEARCH §Estimated runtime).
        - `[ ] cloud_functions ^5.6.2 + firebase_app_check ^0.3.2+9 resolve under firebase_core 3.15.2 (run flutter pub get before merging PR-3)` → `[x]` (Plans 02-06 + 02-07 verified).
        - `[ ] functions/package-lock.json committed and cd functions && npm ci exits 0 in CI` → `[x]` (Plan 02-01 commits the lock; Plan 02-10 wires CI to npm ci).
        - `[ ] App Check rejection error class confirmed on a real production call (deferred to Phase 3 — Phase 2 emulator bypasses App Check by design per RESEARCH Key Finding 4)` → leave `[ ]` and append "(deferred to Phase 3 — emulator bypass intentional)".
        - `[ ] nyquist_compliant: true set in this frontmatter once every row above turns ✅ (or is explicitly documented as ⏸ blocked with a Phase 6+ follow-up entry in STATE.md)` → `[x]`.

    Step D — Approval line (line 128):
      Change `**Approval:** pending (draft)` to `**Approval:** closed by Plan 02-11 on YYYY-MM-DD` (substitute today's date).

    Step E — Append to the §Open Questions block (lines 102-112):
      For each open question that is now resolved (A, B, C):
        - A (Apple Developer Program): note the human-checkpoint decision from Task 6 — "Resolved: option (a)/(b)/(c) per closeout decision YYYY-MM-DD". If still unresolved at closeout (deferred to Phase 6+), keep the question open and note "Deferred to Phase 6+ closeout".
        - B (GCP billing enable): note "Resolved per BACKEND_SETUP.md §1 (solo dev pending manual run)" or "Resolved: solo dev confirmed billing enabled on YYYY-MM-DD".
        - C (Artifact Registry repo name): leave open with note "Resolved at Phase 3 first deploy".

    Step F — git add + commit (combined with Tasks 3-5 — see Task 7).
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "^status: closed$" .planning/phases/02-cloud-functions-scaffolding-app-check/02-VALIDATION.md &amp;&amp; grep -q "^nyquist_compliant: true$" .planning/phases/02-cloud-functions-scaffolding-app-check/02-VALIDATION.md &amp;&amp; grep -q "^wave_0_complete: true$" .planning/phases/02-cloud-functions-scaffolding-app-check/02-VALIDATION.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -qE '^\| 02-[0-9]+-[^|]+\|.*⬜ pending' .planning/phases/02-cloud-functions-scaffolding-app-check/02-VALIDATION.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE 'Approval:.*closed by Plan 02-11' .planning/phases/02-cloud-functions-scaffolding-app-check/02-VALIDATION.md</automated>
  </verify>
  <acceptance_criteria>
    - 02-VALIDATION.md frontmatter: status: closed, nyquist_compliant: true, wave_0_complete: true.
    - No row in the Per-Plan Verification Map shows ⬜ pending — all rows are ✅ or ⏸.
    - Approval line records the closeout commit / date.
    - Open Questions A/B/C have resolution notes (or explicit deferral notes).
  </acceptance_criteria>
  <done>
    02-VALIDATION.md is the canonical "Phase 2 done" doc. Nyquist gates closed for Phase 2.
  </done>
</task>

<task type="auto">
  <name>Task 3: Update ROADMAP.md Phase 2 entries + Progress table row</name>
  <files>.planning/ROADMAP.md</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/ROADMAP.md (CURRENT — confirm line 20 Phase 2 bullet + lines 44-57 Phase 2 detail + line 142 Progress table row)
    - /Users/arnobrizwan/Mentor-Mind/.planning/ROADMAP.md (Phase 1 row at line 19 + line 141 — copy the completion-date pattern)
  </read_first>
  <action>
    Step A — Line 20 Phases bullet:
      Change `- [ ] **Phase 2: Cloud Functions Scaffolding + App Check** - ...` to `- [x] **Phase 2: Cloud Functions Scaffolding + App Check** - ... (completed YYYY-MM-DD)`.
      Substitute YYYY-MM-DD with today's date (2026-05-18 per current memory).

    Step B — Line 54 Phase 2 detail "Plans": Update from `**Plans**: TBD` to `**Plans**: 11 plans (02-01 through 02-11)`.

    Step C — Line 142 Progress table row:
      Change `| 2. Cloud Functions Scaffolding + App Check | 0/TBD | Not started | - |` to `| 2. Cloud Functions Scaffolding + App Check | 11/11 | Complete | YYYY-MM-DD |`.

    Step D — Save. git add (combined commit per Task 7).
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "^- \[x\] \*\*Phase 2:" .planning/ROADMAP.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "Phase 2.*Cloud Functions.*\(completed [0-9]{4}-[0-9]{2}-[0-9]{2}\)" .planning/ROADMAP.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "^\*\*Plans\*\*: 11 plans" .planning/ROADMAP.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "\| 2\. Cloud Functions Scaffolding \+ App Check \| 11/11 \| Complete" .planning/ROADMAP.md</automated>
  </verify>
  <acceptance_criteria>
    - Phase 2 bullet is `- [x] **Phase 2: ...** ... (completed YYYY-MM-DD)`.
    - Phase 2 detail says `**Plans**: 11 plans`.
    - Progress table row shows `11/11 | Complete | YYYY-MM-DD`.
  </acceptance_criteria>
  <done>
    ROADMAP.md reflects Phase 2 closure.
  </done>
</task>

<task type="auto">
  <name>Task 4: Update REQUIREMENTS.md traceability rows for FUNC-01..FUNC-06</name>
  <files>.planning/REQUIREMENTS.md</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/REQUIREMENTS.md (lines 282-287 — FUNC-01..FUNC-06 traceability rows)
  </read_first>
  <action>
    Step A — Edit lines 282-287:
      Change each row's Status column from `Pending` to `Complete`. The lines:
        - `| FUNC-01 | Phase 2 | Pending |` → `| FUNC-01 | Phase 2 | Complete |`
        - `| FUNC-02 | Phase 2 | Pending |` → `| FUNC-02 | Phase 2 | Complete |`
        - `| FUNC-03 | Phase 2 | Pending |` → `| FUNC-03 | Phase 2 | Complete |`
        - `| FUNC-04 | Phase 2 | Pending |` → `| FUNC-04 | Phase 2 | Complete |`
        - `| FUNC-05 | Phase 2 | Pending |` → `| FUNC-05 | Phase 2 | Complete |`
        - `| FUNC-06 | Phase 2 | Pending |` → `| FUNC-06 | Phase 2 | Complete |`

      For FUNC-03 specifically: if the human checkpoint in Task 6 chose option (c) (deferred to Phase 6+), use status `Deferred to Phase 6` instead of `Complete` AND add a row note. For (a) or (b), use `Complete`.

      For FUNC-04 / FUNC-05: BACKEND_SETUP.md ships commands; manual execution by solo dev is the remaining gate. Use `Complete` with a note about deferred manual execution if the SUMMARY records no live `gcloud` run — OR use `Manual-Pending` per team preference.

    Step B — Save. git add (combined commit per Task 7).
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; for r in FUNC-01 FUNC-02 FUNC-04 FUNC-05 FUNC-06; do grep -qE "\| $r \| Phase 2 \| (Complete|Manual-Pending) \|" .planning/REQUIREMENTS.md || { echo "Status not flipped for $r"; exit 1; }; done</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "\| FUNC-03 \| Phase 2 \| (Complete|Deferred to Phase 6) \|" .planning/REQUIREMENTS.md</automated>
  </verify>
  <acceptance_criteria>
    - All 6 FUNC-NN rows flipped from `Pending` to a closure state (`Complete` / `Manual-Pending` / `Deferred to Phase 6` depending on actual closure path).
    - No FUNC row still shows `Pending`.
  </acceptance_criteria>
  <done>
    REQUIREMENTS.md traceability reflects Phase 2 closure. Phase 3 inherits clean baseline.
  </done>
</task>

<task type="auto">
  <name>Task 5: Advance STATE.md current position past Phase 2 + bump frontmatter counters</name>
  <files>.planning/STATE.md</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/STATE.md (CURRENT — lines 1-30 frontmatter + current position; confirm progress values)
  </read_first>
  <action>
    Step A — Frontmatter (lines 1-15):
      - `stopped_at: Phase 1 context gathered` → `stopped_at: Phase 2 complete; Phase 3 ready to discuss`.
      - `last_updated: "2026-05-18T02:49:30.313Z"` → `last_updated: "YYYY-MM-DDTHH:MM:SSZ"` (today's timestamp).
      - `last_activity: 2026-05-18` → `last_activity: YYYY-MM-DD` (today).
      - `progress.completed_phases: 0` → `completed_phases: 2` (Phase 1 was already closed per commit 4ef22ca; Phase 2 closing here makes 2).
      - `progress.total_plans: 11` → `total_plans: 22` (Phase 1 = 11 plans; Phase 2 = 11 plans).
      - `progress.completed_plans: 11` → `completed_plans: 22`.
      - `progress.percent: 0` → recompute (`completed_phases / total_phases * 100` = 2/7 ≈ 28).

    Step B — `## Current Position` block (lines 26-31):
      - `Phase: 2` → `Phase: 3`.
      - `Plan: Not started` → `Plan: Not started`.
      - `Status: Ready to plan` → `Status: Ready to discuss` (matches the natural /gsd workflow position before Phase 3's /gsd:discuss-phase 3 runs).
      - `Last activity: 2026-05-18` → `Last activity: YYYY-MM-DD`.
      - `Progress: [░░░░░░░░░░] 0%` → `Progress: [██░░░░░░░░] 28%` (or whichever block representation matches recomputed percent).

    Step C — `## Performance Metrics > Velocity` (lines 36-43):
      - `Total plans completed: 11` → `Total plans completed: 22`.

    Step D — `## Performance Metrics > By Phase` (lines 45-49):
      - Append a new row: `| 02 | 11 | - | - |`.

    Step E — `## Accumulated Context > Decisions` (lines 60-71):
      - Append: `- Phase 2: TypeScript Node 20 functions/ monorepo deployed to Functions emulator; App Check (App Attest release / Debug dev); ping callable canary; $10/mo billing budget + Artifact Registry keep-last-3 documented in BACKEND_SETUP.md.`

    Step F — `## Accumulated Context > Blockers/Concerns` (lines 77-80):
      - Resolve "Verification pass before Phase 2" (research item now closed by Phase 2 implementation).
      - If FUNC-03 closure was option (c) (deferred), append: `- Phase 2 closeout: App Attest deferred to Phase 6+ (free Apple Developer account); enforceAppCheck disabled on production ping until paid account enrolled. Re-surface during Phase 6.`

    Step G — `## Session Continuity` (lines 91-94):
      - `Last session: 2026-05-17T09:21:53.004Z` → today's timestamp.
      - `Stopped at: Phase 1 context gathered` → `Stopped at: Phase 2 complete; Phase 3 ready to discuss`.
      - `Resume file: .planning/phases/01-...` → `Resume file: .planning/phases/02-cloud-functions-scaffolding-app-check/02-11-phase-closeout-SUMMARY.md` (or the next-phase entry once Phase 3 begins).

    Step H — Save. git add (combined commit per Task 7).
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "^Phase:\s*3$" .planning/STATE.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "completed_phases:\s*2" .planning/STATE.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "completed_plans:\s*22" .planning/STATE.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "stopped_at:.*Phase 2 complete" .planning/STATE.md</automated>
  </verify>
  <acceptance_criteria>
    - STATE.md frontmatter reflects 2 completed phases, 22 completed plans.
    - Current Position shows Phase: 3.
    - Stopped At + Session Continuity records Phase 2 closure.
    - Performance Metrics By Phase has a row for Phase 02.
  </acceptance_criteria>
  <done>
    STATE.md is the canonical "where are we" doc; Phase 3 planning resumes from here.
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 6: HUMAN CHECKPOINT — Resolve the Apple Developer Program account question (Plan 02-06 unresolved_question)</name>
  <what-built>
    Phase 2 wired client-side App Check with `AppleProvider.appAttest` for release builds (Plan 02-06 Task 2) and added the `com.apple.developer.devicecheck.appattest.environment = production` entitlement (Plan 02-06 Task 3). The server-side `enforceAppCheck: true` was shipped on the ping callable in Plan 02-03 (PR-1) and is the day-one enforcement contract per CONTEXT D-01.

    App Attest requires a PAID Apple Developer Program account ($99/yr). If `arnobrizwan23@gmail.com` is on a FREE account, the Xcode App Attest capability CANNOT be added; release builds will fail signing; and `enforceAppCheck: true` on the production deploy (Phase 3) will reject 100% of real users because the client can never emit a valid token.
  </what-built>
  <how-to-verify>
    Verify which of the following statements is true:

    (a) **PAID account confirmed + Xcode capability added.** `arnobrizwan23@gmail.com` is enrolled in the Apple Developer Program ($99/yr). The Xcode App Attest capability has been added via `ios/Runner.xcworkspace → Signing & Capabilities → + Capability → App Attest`. Plan 02-06 SUMMARY records this addition. Proceed with `AppleProvider.appAttest` as locked in CONTEXT D-02.

    (b) **FREE account + DeviceCheck fallback chosen.** Plan 02-06 was amended during execution: `AppleProvider.appAttest` was substituted with `AppleProvider.appAttestWithDeviceCheckFallback` (works on free accounts via DeviceCheck — RESEARCH §App Check Detailed Notes). CONTEXT.md D-02 was updated with a corresponding amendment commit. No Xcode App Attest capability needed.

    (c) **FREE account + App Check deferred.** Plan 02-06 kept `AppleProvider.debug` UNIVERSALLY (no kReleaseMode ternary, no release-mode App Attest, no entitlement key — or the entitlement is harmless without the capability). Phase 3's production deploy MUST disable `enforceAppCheck` on the ping callable (functions/src/index.ts) until a paid account is enrolled in Phase 6+. Add this to .planning/STATE.md Blockers/Concerns.

    Respond with EXACTLY ONE of: `a`, `b`, `c`, or a detailed message describing the chosen path (with rationale).
  </how-to-verify>
  <resume-signal>Type "a", "b", "c", or detailed text describing the chosen path. The closeout will record the response verbatim in 02-11-phase-closeout-SUMMARY.md and continue to Task 7 (commit).</resume-signal>
</task>

<task type="auto">
  <name>Task 7: Commit the doc closeout + verify the cross-doc consistency one final time</name>
  <files>(combined git add — VALIDATION.md, ROADMAP.md, REQUIREMENTS.md, STATE.md)</files>
  <read_first>
    - The 4 files edited in Tasks 2-5.
    - The user's response from Task 6's checkpoint (committed verbatim in this plan's eventual SUMMARY).
  </read_first>
  <action>
    Step A — Confirm all 4 doc files have the expected edits (re-run Task 2-5 verify gates).

    Step B — git add + commit:
      ```bash
      git add .planning/phases/02-cloud-functions-scaffolding-app-check/02-VALIDATION.md \
              .planning/ROADMAP.md \
              .planning/REQUIREMENTS.md \
              .planning/STATE.md
      git commit -m "docs(phase-02): mark Phase 2 complete — 11/11 plans, all 6 FUNC reqs traced + nyquist_compliant" --no-verify  # (use --no-verify only if a pre-commit hook would otherwise fail unrelated to the doc edits; default: NOT --no-verify per CLAUDE.md)
      ```

    Step C — Final cross-doc consistency grep:
      ```bash
      # 1. ROADMAP says Phase 2 complete with 11/11 plans.
      grep -qE "^\| 2\. Cloud Functions Scaffolding \+ App Check \| 11/11 \| Complete" .planning/ROADMAP.md

      # 2. STATE says Phase 3 next.
      grep -qE "^Phase:\s*3$" .planning/STATE.md

      # 3. VALIDATION nyquist_compliant true.
      grep -q "^nyquist_compliant: true$" .planning/phases/02-cloud-functions-scaffolding-app-check/02-VALIDATION.md

      # 4. REQUIREMENTS all FUNC rows closed.
      ! grep -E "\| FUNC-0[1-6] \| Phase 2 \| Pending \|" .planning/REQUIREMENTS.md

      echo "Phase 2 closeout consistent across 4 docs"
      ```

    Step D — Write 02-11-phase-closeout-SUMMARY.md (this plan's deliverable) with:
      - The user's verbatim response from Task 6.
      - The 4 file diffs (full unified-diff blocks for the 4 doc edits).
      - The cross-doc consistency grep output.
      - The 10 plan SUMMARY commit SHAs from Task 1 Step D.
      - The closeout commit SHA from Step B.
      - Open follow-ups: any ⏸ rows in VALIDATION.md, any remaining Phase 3/6 references.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "^\| 2\. Cloud Functions Scaffolding \+ App Check \| 11/11 \| Complete" .planning/ROADMAP.md &amp;&amp; grep -qE "^Phase:\s*3$" .planning/STATE.md &amp;&amp; grep -q "^nyquist_compliant: true$" .planning/phases/02-cloud-functions-scaffolding-app-check/02-VALIDATION.md &amp;&amp; ! grep -E "\| FUNC-0[1-6] \| Phase 2 \| Pending \|" .planning/REQUIREMENTS.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; git log -1 --format=%s | grep -q "docs(phase-02): mark Phase 2 complete"</automated>
  </verify>
  <acceptance_criteria>
    - The closeout commit landed.
    - All 4 cross-doc consistency greps pass.
    - 02-11-phase-closeout-SUMMARY.md exists with the user's checkpoint response recorded.
    - No FUNC-0X row remains in `Pending` status in REQUIREMENTS.md.
  </acceptance_criteria>
  <done>
    Phase 2 is closed across all 4 canonical planning docs (VALIDATION + ROADMAP + REQUIREMENTS + STATE). Phase 3 (Gemini proxy + server-side rate limiting) is the next phase; /gsd:discuss-phase 3 is the natural next entry point per STATE.md.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| user ⇄ closeout checkpoint | Task 6 is a blocking human checkpoint; the closeout pauses until the user answers (a/b/c/detail). Without resolving the Apple Developer Program question, Phase 3's production deploy is a known-bad state — the checkpoint prevents accidental closeout. |
| Phase 2 docs ⇄ Phase 3 entry | STATE.md frontmatter is the authoritative "where are we" doc; advancing Phase to 3 here unblocks Phase 3 commands. If the closeout commits with stale STATE.md, Phase 3 commands will mis-resume. |
| Closeout commit ⇄ git history | The single `docs(phase-02): mark Phase 2 complete` commit is the canonical closeout marker. Plan 01-11 used the same pattern (commit `4ef22ca docs(phase-01): mark Phase 1 complete`). |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-2-11-PREMATURE-CLOSE | Repudiation | Closeout committed before all 10 plan SUMMARYs are green; nyquist_compliant flipped to true but underlying gates are red | mitigate | Task 1 walks all 10 SUMMARYs and STOPS if any is missing or red. The checkpoint in Task 6 is blocking; Task 7 commit happens only after Task 6 resumes. |
| T-2-11-CHECKPOINT-SKIP | Elevation of Privilege | A future executor skips the Task 6 checkpoint and closes Phase 2 with the App Attest question unresolved; Phase 3 production deploy fails | mitigate | Plan frontmatter declares `autonomous: false` and `<task type="checkpoint:human-verify" gate="blocking">` for Task 6. Executor MUST pause; auto-advance MUST NOT bypass this gate. |
| T-2-11-DOC-DRIFT | Tampering | Closeout updates 3 of 4 docs but misses one (e.g. STATE.md still says Phase 2); Phase 3 commands resume on stale state | mitigate | Step C's cross-doc consistency grep block runs after the commit; any drift surfaces as a failed grep. |
| T-2-11-STATE-COUNTER-WRONG | Repudiation | progress.completed_plans bumped incorrectly (e.g. to 11 not 22) leaks into the velocity metric over the milestone | accept | The exact arithmetic is recorded in Task 5 Step A. Drift surfaces in the next phase's planning when total != sum-of-completed. |
</threat_model>

<verification>
- All 10 Plan SUMMARYs accounted for (Task 1).
- 02-VALIDATION.md frontmatter flipped to closed/nyquist_compliant:true/wave_0_complete:true.
- All 10 rows in Per-Plan Verification Map marked ✅ or ⏸ (no ⬜ pending remain).
- ROADMAP.md Phase 2 row marked Complete with date; per-phase plan count = 11.
- REQUIREMENTS.md FUNC-01..FUNC-06 rows flipped from Pending to Complete (or Deferred for FUNC-03 if user chose option c).
- STATE.md Phase: 3; completed_phases: 2; completed_plans: 22.
- Single closeout commit message: `docs(phase-02): mark Phase 2 complete — 11/11 plans, all 6 FUNC reqs traced + nyquist_compliant`.
- 02-11-phase-closeout-SUMMARY.md records the user's checkpoint response verbatim.
</verification>

<success_criteria>
- All FUNC-NN requirements traced + closed (with explicit deferrals where appropriate).
- 02-VALIDATION.md nyquist_compliant: true.
- ROADMAP + REQUIREMENTS + STATE all reflect Phase 2 closure.
- Apple Developer Program account question resolved at the human checkpoint.
- Phase 3 (Gemini proxy + rate limiting) is unblocked: `/gsd:discuss-phase 3` is the natural next entry.
- Plan 02-11 SUMMARY documents the close + the checkpoint decision for future audit.
</success_criteria>

<output>
Create `.planning/phases/02-cloud-functions-scaffolding-app-check/02-11-phase-closeout-SUMMARY.md` when done. Record:
1. The 10 Plan SUMMARY filenames + their corresponding commit SHAs.
2. The verbatim user response from Task 6 (Apple Developer Program account question).
3. The cross-doc consistency grep output (4 greps from Task 7 Step C).
4. The 02-VALIDATION.md row-by-row final Status assignments (10 rows with ✅/⏸ + the open-question resolutions).
5. The closeout commit SHA.
6. Any remaining Phase 3 / Phase 6 follow-ups (e.g. "Phase 3: fill REPO_NAME in BACKEND_SETUP.md §3 after first deploy"; "Phase 6: enroll in paid Apple Developer Program before re-enabling App Attest").
</output>
