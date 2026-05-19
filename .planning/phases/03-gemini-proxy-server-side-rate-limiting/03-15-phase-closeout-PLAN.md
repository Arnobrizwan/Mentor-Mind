---
phase: 03-gemini-proxy-server-side-rate-limiting
plan: 15
type: execute
wave: 7
depends_on: ["03-01", "03-02", "03-03", "03-04", "03-05", "03-06", "03-07", "03-08", "03-09", "03-10", "03-11", "03-12", "03-13", "03-14"]
files_modified:
  - .planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md
  - .planning/ROADMAP.md
  - .planning/REQUIREMENTS.md
  - .planning/STATE.md
autonomous: false
status: pending
status_reason: "Closeout depends on 03-04 (AI-01 model availability) being closed. 03-04 is pending the GCP billing reopen. Resume after billing is enabled and 03-04 records the resolved model ID."
status_resume_command: "Run after 03-04 completes: /gsd-execute-phase 03 --wave 7"
requirements: [AI-01, AI-02, AI-03, AI-04, AI-05, AI-06, AI-07, AI-08, AI-09, AI-10]
pr_group: closeout
tags: [phase_closeout, validation_md_close, nyquist_compliant_flip, roadmap_close, requirements_traceability, state_md_progress, leaked_key_rotation_confirm, model_availability_confirm, mirror_plan_02_11, deferred_billing_gate]

must_haves:
  truths:
    - "Every AI-NN requirement (AI-01..AI-10) marked Complete OR explicitly ⏸ deferred with a documented mitigation"
    - "03-VALIDATION.md frontmatter flipped: `status: closed`, `nyquist_compliant: true`, `wave_0_complete: true` (subject to legitimate ⏸ rows per the VALIDATION nyquist_compliant note — manual gcloud runs, live Vertex device test deferred to Phase 7)"
    - "All 15 Per-Plan Verification Map rows turned ✅ (or explicitly ⏸ with a Phase 7+ follow-up reference)"
    - "ROADMAP.md Phase 3 status flipped from `Not started` to `Complete` with completion date; per-phase plan count = 15"
    - "REQUIREMENTS.md traceability rows for AI-01..AI-10 flipped from `Pending` to `Complete` (or `Deferred to Phase 6+` for AI-01 model-fallback edge case)"
    - "STATE.md current position advanced past Phase 3 (Phase 4 ready to discuss)"
    - "Two BLOCKING human checkpoints surface before closure: (a) leaked-key rotation confirmation — solo dev confirms https://aistudio.google.com/apikey revoke happened (D-22 / AI-02 closure); (b) model-availability resolution confirmation — record which model was pinned (D-01 / Q-1 closure)"
    - "All 14 SUMMARY.md files from Plans 03-01..03-14 + this one (03-15) committed and discoverable"
    - "Mirror of Phase 2 Plan 02-11 (commit `4ef22ca docs(phase-01)...` / Phase 2 close pattern) — same doc edits, same human-checkpoint structure, same commit-message style"
    - "Production deploy steps documented: `firebase deploy --only firestore:rules` (plan 03-09 rules) + `firebase deploy --only functions:mentorBotChat` (plan 03-06 callable) — solo dev executes manually in the closeout window"
  artifacts:
    - path: ".planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md"
      provides: "Updated frontmatter (status: closed, nyquist_compliant: true, wave_0_complete: true) + all 15 rows marked ✅/⏸"
      contains: "nyquist_compliant: true"
    - path: ".planning/ROADMAP.md"
      provides: "Phase 3 status row updated to Complete + completion date + per-phase progress counts (15/15)"
      contains: "Phase 3 . 15/15 . Complete"
    - path: ".planning/REQUIREMENTS.md"
      provides: "AI-01..AI-10 traceability rows flipped from Pending to Complete"
      contains: "AI-01 . Phase 3 . Complete"
    - path: ".planning/STATE.md"
      provides: "Current Position advanced past Phase 3 (Phase 4 ready)"
      contains: "Phase: 4"
  key_links:
    - from: ".planning/phases/03-.../03-VALIDATION.md frontmatter"
      to: "Plans 03-01..03-14 SUMMARY files"
      via: "Each plan's SUMMARY confirms the matching row's automated command was green"
      pattern: "✅"
    - from: ".planning/REQUIREMENTS.md traceability"
      to: ".planning/ROADMAP.md Phase 3 status"
      via: "AI-NN requirements all marked Complete = Phase 3 done"
      pattern: "Complete"
---

<objective>
Close Phase 3. Walk all 14 Plan SUMMARYs (03-01..03-14) to confirm green; surface a blocking human checkpoint for leaked-key rotation confirmation (D-22 / AI-02) AND model-availability resolution confirmation (D-01 / Q-1); flip 03-VALIDATION.md frontmatter to `status: closed` + `nyquist_compliant: true` + `wave_0_complete: true`; mark every row in the Per-Plan Verification Map ✅ (or explicitly ⏸ with a Phase 7 follow-up reference); update ROADMAP.md Phase 3 row to `Complete`; update REQUIREMENTS.md traceability rows for AI-01..AI-10 from `Pending` to `Complete`; advance STATE.md current position to Phase 4 ready-to-discuss.

Purpose: Phase 3 is the third phase to ship. Locking in nyquist_compliant and the cross-doc updates ensures Phase 4 starts from a clean, validated baseline. The two human checkpoints are non-negotiable:
  - The Apple Studio key revoke (D-22) is the canonical T-3-KEY-LEAK closure — without confirmation, Phase 3 cannot claim AI-02 complete.
  - The model-availability resolution (D-01 / Q-1) is the canonical AI-01 closure — without confirmation of which model is pinned in `MODEL_CONFIG.modelId`, deploys may break.

Output: 4 cross-cutting doc edits, two git commits (the doc edits + the SUMMARY-walk diff with the checkpoint responses), and clear checkpoint decisions recorded in this plan's SUMMARY.
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
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-CONTEXT.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-01-jest-harness-bootstrap-PLAN.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-02-quota-shared-constant-PLAN.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-03-vertex-gemini-client-PLAN.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-04-model-availability-checkpoint-PLAN.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-05-rate-limit-transaction-PLAN.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-06-mentorbot-callable-PLAN.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-07-usage-log-observability-PLAN.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-08-backend-setup-vertex-keyrotation-PLAN.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-09-firestore-rules-lockdown-PLAN.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-10-uuid-and-quota-dart-PLAN.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-11-mentor-bot-repository-PLAN.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-12-chat-viewmodel-swap-PLAN.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-13-mentor-bot-smoke-test-PLAN.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-14-ci-npm-test-step-PLAN.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-11-phase-closeout-PLAN.md
@CLAUDE.md

<interfaces>
Closeout sequence (8 tasks — mirrors Plan 02-11):

Task 1 — SUMMARY walk: confirm each of Plans 03-01..03-14 wrote a SUMMARY.md file with the expected commit + verify gates green. If any SUMMARY is missing OR records a red gate, STOP and surface the gap.

Task 2 — Update 03-VALIDATION.md:
  - Walk the 15 rows in the Per-Plan Verification Map.
  - For each row, mark its Status ✅ if all automated commands in the row's "Automated Command" cell ran green.
  - For rows that have manual-only or deferred verifications (notably 03-04 — manual checkpoint resolution; 03-08 — manual gcloud commands; 03-13 — live emulator run may have been deferred), mark ⏸ with a brief follow-up reference (e.g. "⏸ live run deferred to local dev / Phase 7").
  - Flip frontmatter:
    - `status: draft` → `status: closed`
    - `nyquist_compliant: false` → `nyquist_compliant: true`
    - `wave_0_complete: false` → `wave_0_complete: true`
  - Update §Validation Sign-Off — flip each checkbox `- [ ]` to `- [x]` for items satisfied; leave `- [ ]` (with a clarifying note) for items legitimately deferred per the existing nyquist_compliant note (paragraph at lines 142-144 of VALIDATION.md already covers this — quote it inline if helpful).
  - Approval line: `pending (draft)` → `closed by Plan 03-15 on YYYY-MM-DD`.
  - §Open Questions:
    - Q-1 (model availability): record verbatim resolution from Plan 03-04 SUMMARY + Task 5 checkpoint of THIS plan.
    - Q-2 (client-side _awardPoints removal): keep open with note "Deferred to Phase 4 (REWD-04 owns)".
    - Q-3 (client vs server sessionId): mark "Resolved: client pre-generates via Uuid().v4() per CONTEXT D-CONTEXT discretion + plan 03-12 implementation".

Task 3 — Update ROADMAP.md:
  - Phase 3 bullet: `- [ ] **Phase 3: ...**` → `- [x] **Phase 3: ...** ... (completed YYYY-MM-DD)`.
  - Phase 3 detail: `**Plans**: TBD` → `**Plans**: 15 plans (03-01 through 03-15)`.
  - Progress table row: `| 3. Gemini Proxy ... | 0/TBD | Not started | - |` → `| 3. Gemini Proxy + Server-Side Rate Limiting | 15/15 | Complete | YYYY-MM-DD |`.

Task 4 — Update REQUIREMENTS.md traceability:
  - For each of AI-01..AI-10:
    - Default: change `Pending` to `Complete`.
    - Exception (AI-01 model edge case): if Plan 03-04 checkpoint ended in path `c` (gemini-1.5-pro downgrade), append a note to the AI-01 row: `Complete — pinned gemini-1.5-pro per Plan 03-04 checkpoint; Phase 5+ may retry 2.5/3.1`.
    - Exception (AI-02 if Studio revoke deferred): if Task 5 checkpoint response is "deferred", change AI-02 to `Manual-Pending` instead of `Complete` and add a row note.
  - Per-phase counts line update if needed (P3=10 reqs per REQUIREMENTS.md current document).

Task 5 — HUMAN CHECKPOINT — Leaked Google AI Studio key rotation confirmation (D-22 / AI-02 closure):
  This is a BLOCKING checkpoint — closeout cannot proceed without resolution.
  Surface to user: "Phase 3 PR-3 atomically removed the GEMINI_API_KEY build path + scrubbed the env var from all configs + rebuilt the iOS binary (plan 03-12). The leaked Google AI Studio key still exists in Studio's account view and could be used by anyone with the key value until revoked. Confirm:
    (a) Yes — I revoked the leaked key at https://aistudio.google.com/apikey BEFORE PR-3 merged. Studio dashboard shows the key as revoked / removed. AI-02 closed.
    (b) Partially — the key was rotated in Studio but I'm not 100% sure I revoked the correct one (multiple keys exist). Recommended action: revoke ALL pre-Phase-3 keys to be safe; then return to (a).
    (c) Deferred — I haven't revoked yet. PR-3 has not merged OR I plan to revoke shortly. Mark AI-02 as Manual-Pending and re-surface at Phase 4 discuss-phase.
  Respond with EXACTLY ONE: `a`, `b`, `c`, or detailed message."

Task 6 — HUMAN CHECKPOINT — Model-availability resolution confirmation (D-01 / Q-1 closure):
  This is the second BLOCKING checkpoint.
  Surface to user: "Plan 03-04's checkpoint resolved which Gemini model is pinned in `functions/src/lib/gemini.ts MODEL_CONFIG.modelId`. The plan 03-04 SUMMARY records the resolution. Re-confirm here for the Phase 3 audit:
    (a) `gemini-3.1-pro` — Pro tier latest. Best capability, ~$5/M output tokens.
    (b) `gemini-2.5-pro` — Plan 03-03 default. Mid Pro tier, ~$5/M output tokens.
    (c) `gemini-1.5-pro` — Pro tier fallback. Older, ~$5/M output tokens. Phase 5+ retry recommended.
  Also confirm: BACKEND_SETUP.md §Phase 3 §7 has the resolved model recorded (plan 03-08 §7 placeholder). If §7 is still the placeholder, update it now.
  Respond with EXACTLY ONE: `a`, `b`, `c`, or detailed message (e.g. with the verbatim Plan 03-04 SUMMARY excerpt)."

Task 7 — Update STATE.md:
  - `stopped_at:` → "Phase 3 complete; Phase 4 ready to discuss"
  - `last_updated:`, `last_activity:` → today's timestamp / date
  - `current_focus:` → "Phase 4 — Server-Authoritative Rewards + Rules Lockdown"
  - `## Current Position` block:
    - `Phase: 3` → `Phase: 4`
    - `Status: Ready to discuss` → `Status: Ready to discuss` (next phase NOT yet discussed — `/gsd:discuss-phase 4` is the natural next entry point)
    - `Last activity:` → today
    - `Progress:` block → recompute %
  - Frontmatter counters:
    - `completed_phases: 2` → `3`
    - `completed_plans: 22` → `37` (Phase 1=11 + Phase 2=11 + Phase 3=15)
    - `progress.percent` → recompute (3/N total phases × 100)
  - `## Performance Metrics > Velocity > Total plans completed:` → `37`
  - `## Performance Metrics > By Phase` — APPEND row: `| 03 | 15 | - | - |`
  - `## Accumulated Context > Decisions` — APPEND: `- Phase 3: Vertex AI Gemini proxy + server-side rate limit (daily 30 text + 3 image, burst 5/60s, monthly 10k); leaked Google AI Studio key revoked; iOS binary scrubbed of GEMINI_API_KEY; firestore.rules locks /users/usage + /system/**.`
  - `## Accumulated Context > Blockers/Concerns` — RESOLVE: "Phase 2 D-15 budget alert tension — raised to $75/mo per Phase 3 D-08 BACKEND_SETUP.md §3"; resolve "Apple Developer Program account question carried from Phase 2 — N/A here (Phase 3 didn't touch App Check)".
  - `## Session Continuity` — update Last session + Stopped at + Resume file.
  - If Task 5 checkpoint response was `c` (Studio revoke deferred), APPEND a Blockers/Concerns entry: "Phase 3 closeout: AI-02 Manual-Pending — leaked Google AI Studio key NOT yet revoked. Re-confirm at Phase 4 /gsd:discuss-phase."

Task 8 — Production deploy + commit:
  Step A — Solo dev MANUALLY executes the production deploys (documented in SUMMARY):
    ```bash
    # Plan 03-09 rules
    firebase deploy --only firestore:rules --project mentor-mind-aa765

    # Plan 03-06 + 03-07 functions (NOT --only functions:mentorBotChat —
    # ALSO deploy the existing ping callable since both export from index.js)
    cd functions
    firebase deploy --only functions --project mentor-mind-aa765
    ```
    Record the deploy URLs + Cloud Logging console URL.

  Step B — git add + commit:
    ```bash
    cd /Users/arnobrizwan/Mentor-Mind
    git add .planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md \
            .planning/ROADMAP.md \
            .planning/REQUIREMENTS.md \
            .planning/STATE.md
    git commit -m "docs(phase-03): mark Phase 3 complete — 15/15 plans, all 10 AI reqs traced + nyquist_compliant"
    ```

  Step C — Final cross-doc consistency grep:
    ```bash
    cd /Users/arnobrizwan/Mentor-Mind
    grep -qE "^\| 3\. Gemini Proxy.*15/15 \| Complete" .planning/ROADMAP.md
    grep -qE "^Phase:\s*4$" .planning/STATE.md
    grep -q "^nyquist_compliant: true$" .planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md
    ! grep -E "\| AI-(0[1-9]|10) \| Phase 3 \| Pending \|" .planning/REQUIREMENTS.md
    echo "Phase 3 closeout consistent across 4 docs"
    ```

  Step D — Write 03-15-phase-closeout-SUMMARY.md (this plan's deliverable) with:
    - Verbatim user responses from Task 5 + Task 6.
    - The 4 file diffs (full unified-diff blocks).
    - The cross-doc consistency grep output.
    - The 14 plan SUMMARY commit SHAs from Task 1.
    - The closeout commit SHA.
    - The production deploy results (URLs + log links).
    - Open follow-ups: any ⏸ rows in VALIDATION.md.

</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: SUMMARY walk — confirm every Plan 03-01..03-14 SUMMARY landed and reports green; surface any gaps</name>
  <files>(read-only — no file edits)</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/ (list directory)
    - Each `03-01-...-SUMMARY.md` through `03-14-...-SUMMARY.md` (14 files)
  </read_first>
  <action>
    Step A — Enumerate SUMMARY files:
      ```bash
      ls .planning/phases/03-gemini-proxy-server-side-rate-limiting/*-SUMMARY.md | sort
      ```
      Expected: 14 files (03-01 through 03-14).

    Step B — For each SUMMARY, confirm:
      - The file exists and is non-empty.
      - It records the verify commands the matching PLAN.md's `<verify>` block specified, AND the exit codes were 0 (or manual-OK).
      - Any deferred / blocked items are explicitly marked.

      Greppable signals per plan SUMMARY:
        - 03-01: "jest.config.js" + "ts-jest" + "test\": \"jest\""
        - 03-02: "QUOTA_TZ" + "Asia/Dhaka" + quota.test.ts tests passed
        - 03-03: "@google-cloud/vertexai" + "SYSTEM_PROMPT_VERSION" + gemini.test.ts tests passed
        - 03-04: verbatim checkpoint response (`a`, `b`, or `c`) + resolved model ID + script run timestamp
        - 03-05: "runTransaction" + rate_limit.test.ts ≥ 13 tests passed
        - 03-06: "mentorBotChat" + "idempotencyRef" + idempotency.test.ts ≥ 6 tests passed
        - 03-07: "usage_log" + "estimateCostUsd" + usage_log.test.ts ≥ 4 tests passed
        - 03-08: "Phase 3 — Vertex AI + Key Rotation" + "aistudio.google.com/apikey" + 7 subsections
        - 03-09: "/system/{document=**}" + rules.test.ts 7 scenarios passed against emulator
        - 03-10: "uuid: ^4.5.3" + "kQuotaTimezone" + quota_test.dart 6 cases passed
        - 03-11: "MentorBotRepository" + "mentorBotRepositoryProvider" + repository test 4 cases passed + custom_lint zero
        - 03-12: "git rm gemini_service.dart" + "google_generative_ai removed" + "GEMINI_API_KEY scrubbed" + flutter build ios green
        - 03-13: "@Tags('emulator', 'integration')" + 2 testWidgets cases + (live-run result OR deferred-to-local-dev)
        - 03-14: "Run Jest tests" + npm test --testPathIgnorePatterns=rules + flutter: job unchanged

    Step C — If ANY SUMMARY is missing or red, STOP and surface to the user before proceeding to Task 2.

    Step D — Capture the 14 commit SHAs:
      ```bash
      git log --oneline --grep="Phase 3" | head -25
      ```
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ls .planning/phases/03-gemini-proxy-server-side-rate-limiting/03-{01,02,03,04,05,06,07,08,09,10,11,12,13,14}-*-SUMMARY.md 2>/dev/null | wc -l | xargs -I{} test {} -eq 14</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; for s in .planning/phases/03-gemini-proxy-server-side-rate-limiting/03-{01,02,03,04,05,06,07,08,09,10,11,12,13,14}-*-SUMMARY.md; do test -s "$s" || { echo "EMPTY: $s"; exit 1; }; done</automated>
  </verify>
  <acceptance_criteria>
    - 14 SUMMARY.md files exist under the Phase 3 directory (one per plan 03-01..03-14).
    - Each is non-empty.
    - Plan-level greppable signals (per Step B) are present in the corresponding SUMMARY.
  </acceptance_criteria>
  <done>
    All 14 Phase 3 plan SUMMARYs accounted for. Closeout can proceed.
  </done>
</task>

<task type="auto">
  <name>Task 2: Flip 03-VALIDATION.md frontmatter; mark all 15 rows ✅/⏸; close Validation Sign-Off; record Q-1/Q-2/Q-3 resolutions</name>
  <files>.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md (CURRENT — full file)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-VALIDATION.md (Phase 2 — closed reference for shape)
    - Plan 03-01..03-14 SUMMARYs (from Task 1)
  </read_first>
  <action>
    Step A — Frontmatter:
      ```yaml
      status: closed
      nyquist_compliant: true
      wave_0_complete: true
      ```

    Step B — Per-Plan Verification Map (15 rows):
      For each row, set the Status column based on the matching plan's SUMMARY.
      - Rows 01-03, 05-07, 10-12, 14: ✅ if all automated greps + tests green.
      - Row 04 (model availability checkpoint): ✅ if Plan 03-04 SUMMARY records resolution; ⏸ if path (d) was hit.
      - Row 08 (BACKEND_SETUP — manual gcloud): ✅ on static gates (grep on BACKEND_SETUP.md); record manual gcloud execution status in §Manual-Only Verifications.
      - Row 09 (rules lockdown): ✅ if rules.test.ts green against emulator.
      - Row 13 (smoke test): ✅ if live emulator run was attempted and green; ⏸ if deferred to local dev (static gates still green).
      - Row 15 (this plan): ✅ on closeout.

    Step C — Validation Sign-Off section:
      Flip checkboxes [ ] → [x] for items satisfied. The two BLOCKING manual gates (model availability + leaked-key rotation) have explicit checkboxes — flip based on Task 5 + Task 6 responses.

    Step D — Approval line: `pending (draft)` → `closed by Plan 03-15 on YYYY-MM-DD`.

    Step E — §Open Questions:
      - Q-1 (model availability): "Resolved by Plan 03-04 checkpoint + Plan 03-15 Task 6 confirmation. Pinned: `<modelId from Plan 03-04>`. Recorded in BACKEND_SETUP.md §Phase 3 §7."
      - Q-2 (client-side _awardPoints): "Deferred to Phase 4 (REWD-04 owns)."
      - Q-3 (sessionId): "Resolved: client pre-generates via `Uuid().v4()` (plan 03-12). Server treats opaque."
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "^status: closed$" .planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md &amp;&amp; grep -q "^nyquist_compliant: true$" .planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md &amp;&amp; grep -q "^wave_0_complete: true$" .planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -qE '^\| 03-[0-9]+-[^|]+\|.*⬜ pending' .planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE 'Approval:.*closed by Plan 03-15' .planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md</automated>
  </verify>
  <acceptance_criteria>
    - 03-VALIDATION.md frontmatter: status: closed, nyquist_compliant: true, wave_0_complete: true.
    - No row in Per-Plan Verification Map shows ⬜ pending.
    - Approval line records closeout date.
    - Open Questions Q-1/Q-2/Q-3 have resolution notes.
  </acceptance_criteria>
  <done>
    03-VALIDATION.md is the canonical "Phase 3 done" doc.
  </done>
</task>

<task type="auto">
  <name>Task 3: Update ROADMAP.md Phase 3 bullet + detail + Progress table row</name>
  <files>.planning/ROADMAP.md</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/ROADMAP.md (CURRENT — confirm Phase 3 bullet position + detail block + Progress table row)
  </read_first>
  <action>
    Step A — Phases bullet: `- [ ] **Phase 3: ...**` → `- [x] **Phase 3: ...** ... (completed YYYY-MM-DD)`.

    Step B — Phase 3 detail block: `**Plans**: TBD` → `**Plans**: 15 plans (03-01 through 03-15)`.

    Step C — Progress table row: `| 3. Gemini Proxy + Server-Side Rate Limiting | 0/TBD | Not started | - |` → `| 3. Gemini Proxy + Server-Side Rate Limiting | 15/15 | Complete | YYYY-MM-DD |`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "^- \[x\] \*\*Phase 3:" .planning/ROADMAP.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "Phase 3.*\(completed [0-9]{4}-[0-9]{2}-[0-9]{2}\)" .planning/ROADMAP.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "^\*\*Plans\*\*: 15 plans" .planning/ROADMAP.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "\| 3\. Gemini Proxy \+ Server-Side Rate Limiting \| 15/15 \| Complete" .planning/ROADMAP.md</automated>
  </verify>
  <acceptance_criteria>
    - Phase 3 bullet marked `[x]` with completion date.
    - Phase 3 detail says `**Plans**: 15 plans`.
    - Progress table row shows `15/15 | Complete | YYYY-MM-DD`.
  </acceptance_criteria>
  <done>
    ROADMAP.md reflects Phase 3 closure.
  </done>
</task>

<task type="auto">
  <name>Task 4: Update REQUIREMENTS.md traceability rows for AI-01..AI-10</name>
  <files>.planning/REQUIREMENTS.md</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/REQUIREMENTS.md (locate the AI-01..AI-10 traceability rows)
  </read_first>
  <action>
    Step A — Edit each AI-NN row:
      - Default: change Status from `Pending` to `Complete`.
      - AI-02 exception (if Task 5 = `c`): use `Manual-Pending` instead of `Complete`; add a note "Leaked Studio key revocation deferred — confirm at Phase 4 /gsd:discuss-phase".
      - AI-01 note (if Task 6 = `c`, gemini-1.5-pro): keep `Complete` but append a note "Pinned 1.5-pro per Plan 03-04 fallback; Phase 5+ may retry 2.5/3.1".

    Step B — Per-phase counts line: confirm `P3=10` is correct (per current REQUIREMENTS.md).
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; for r in AI-01 AI-03 AI-04 AI-05 AI-06 AI-07 AI-08 AI-09 AI-10; do grep -qE "\| $r \| Phase 3 \| (Complete|Manual-Pending) \|" .planning/REQUIREMENTS.md || { echo "Status not flipped for $r"; exit 1; }; done</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "\| AI-02 \| Phase 3 \| (Complete|Manual-Pending) \|" .planning/REQUIREMENTS.md</automated>
  </verify>
  <acceptance_criteria>
    - All 10 AI-NN rows flipped from `Pending` to `Complete` / `Manual-Pending` depending on checkpoint outcomes.
    - No AI-NN row still shows `Pending`.
  </acceptance_criteria>
  <done>
    REQUIREMENTS.md traceability reflects Phase 3 closure.
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking-human">
  <name>Task 5: HUMAN CHECKPOINT — Confirm leaked Google AI Studio key revocation (D-22 / AI-02)</name>
  <what-built>
    Plan 03-12 atomically removed the `--dart-define=GEMINI_API_KEY` build path from EVERY config file + removed `google_generative_ai` from pubspec.yaml + deleted `lib/core/services/gemini_service.dart`. The iOS binary rebuilt by `flutter build ios --no-codesign` no longer contains the literal GEMINI_API_KEY string.

    However, the LEAKED key value still exists in the Google AI Studio dashboard (the cloud-side identifier that was extracted from old iOS binaries). Without revoking it at https://aistudio.google.com/apikey, anyone who has the value can still use it. AI-02's full closure requires the manual revoke step (D-22) — plan 03-08 BACKEND_SETUP.md §5 documents the procedure.

    This is a BLOCKING checkpoint. Closeout cannot proceed without confirmation. `workflow.auto_advance: true` does NOT auto-resume this gate.
  </what-built>
  <how-to-verify>
    Solo dev:

    1. Open https://aistudio.google.com/apikey
    2. Sign in as `arnobrizwan23@gmail.com`
    3. Locate the pre-Phase-3 API key. Match by last-4 characters OR by creation date before 2026-05-01 (Phase 3's start).
    4. Confirm the key is REVOKED (red badge, "Revoked" status, or removed from the list).
    5. Confirm the BACKEND_SETUP.md §Phase 3 §5 checkbox is ticked in the PR-3 description.
    6. Respond with EXACTLY ONE:

    (a) Yes — I revoked the leaked key at https://aistudio.google.com/apikey BEFORE PR-3 merged. The Studio dashboard confirms the key is revoked/removed. AI-02 fully closed.

    (b) Partially — the key was rotated in Studio but I'm not 100% sure I revoked the correct one (multiple keys exist). Recommended action: revoke ALL pre-Phase-3 keys to be safe; then return to (a). I will do this NOW and re-respond.

    (c) Deferred — I haven't revoked yet. PR-3 has not merged OR I plan to revoke shortly. Mark AI-02 as `Manual-Pending` in REQUIREMENTS.md and add a Phase 4 follow-up entry in STATE.md Blockers/Concerns. The leaked key remains exploitable until I revoke.

    Without one of these three responses, Phase 3 cannot close. Even an `a` response that turns out to be inaccurate (e.g. you revoked the wrong key) is a real-world risk — the closeout records your verbatim response so a future audit can trace the decision.
  </how-to-verify>
  <resume-signal>Type EXACTLY one of: `a`, `b`, `c`, or detailed message describing what you did. The executor records your response verbatim in 03-15-phase-closeout-SUMMARY.md and continues to Task 6.</resume-signal>
</task>

<task type="checkpoint:human-verify" gate="blocking-human">
  <name>Task 6: HUMAN CHECKPOINT — Confirm model-availability resolution (D-01 / Q-1)</name>
  <what-built>
    Plan 03-04's checkpoint resolved which Gemini model is pinned in `functions/src/lib/gemini.ts MODEL_CONFIG.modelId` against the live Vertex AI `asia-south1` endpoint. Plan 03-04's SUMMARY records the verbatim resolution (model ID + project + run timestamp). This checkpoint REAFFIRMS the resolution for the Phase 3 audit trail and confirms that BACKEND_SETUP.md §Phase 3 §7 (plan 03-08) has been updated with the resolved value (NOT left as the placeholder).
  </what-built>
  <how-to-verify>
    1. Read `.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-04-model-availability-checkpoint-SUMMARY.md`. Find the "Resolved model" line.

    2. Read `BACKEND_SETUP.md §Phase 3 §7 — Model resolution record`. Confirm the model ID is recorded (NOT `<gemini-X.Y-pro — fill from Plan 03-04 checkpoint resolution>` placeholder).

    3. Read `functions/src/lib/gemini.ts`. Confirm `MODEL_CONFIG.modelId` matches the resolution.

    4. Respond with EXACTLY ONE:

    (a) `gemini-3.1-pro` — Plan 03-04 resolved to the latest Pro tier. BACKEND_SETUP.md §7 + gemini.ts MODEL_CONFIG.modelId both confirm.

    (b) `gemini-2.5-pro` — Plan 03-04 confirmed the Plan 03-03 default. BACKEND_SETUP.md §7 + gemini.ts both confirm.

    (c) `gemini-1.5-pro` — Plan 03-04 downgraded to the older Pro tier. BACKEND_SETUP.md §7 + gemini.ts both confirm. Phase 5+ may retry 2.5/3.1 as Vertex GA expands; add Phase 7+ follow-up entry.

    (d) Other / mismatch — Plan 03-04's resolution and the current code state disagree (e.g. SUMMARY says one model but gemini.ts has another), OR BACKEND_SETUP.md §7 still has the placeholder text. STOP — fix the drift before proceeding.

    Respond with the model ID verbatim (e.g. "a — gemini-3.1-pro") so the closeout SUMMARY has the authoritative record.
  </how-to-verify>
  <resume-signal>Type EXACTLY one of: `a` (gemini-3.1-pro), `b` (gemini-2.5-pro), `c` (gemini-1.5-pro), `d` (mismatch — fix first), or detailed message. Executor records verbatim and continues to Task 7.</resume-signal>
</task>

<task type="auto">
  <name>Task 7: Advance STATE.md current position past Phase 3 + bump frontmatter counters + record checkpoint outcomes</name>
  <files>.planning/STATE.md</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/STATE.md (CURRENT)
  </read_first>
  <action>
    Step A — Frontmatter:
      - `stopped_at` → "Phase 3 complete; Phase 4 ready to discuss"
      - `last_updated`, `last_activity` → today
      - `progress.completed_phases` → 3
      - `progress.completed_plans` → 37 (P1=11 + P2=11 + P3=15)
      - `progress.percent` → recompute
      - `current_focus` → "Phase 4 — Server-Authoritative Rewards + Rules Lockdown"

    Step B — `## Current Position`:
      - `Phase: 3` → `Phase: 4`
      - `Status:` → `Ready to discuss`
      - `Last activity:` → today

    Step C — `## Performance Metrics`:
      - `Total plans completed:` → 37
      - `By Phase` — append `| 03 | 15 | - | - |`

    Step D — `## Accumulated Context > Decisions` — append:
      - "Phase 3: Vertex AI Gemini proxy + server-side rate limit (daily 30 text + 3 image, burst 5/60s, monthly 10k); leaked Google AI Studio key revoked per Plan 03-15 Task 5 checkpoint; iOS binary scrubbed of GEMINI_API_KEY; firestore.rules locks /users/usage + /system/**."
      - "Phase 3: pinned Gemini model = `<model from Task 6>`; Vertex AI Pro tier; $75/mo budget alert per BACKEND_SETUP.md §Phase 3 §3."

    Step E — `## Accumulated Context > Blockers/Concerns`:
      - Resolve "Phase 2 D-15 budget alert tension" — raised to $75/mo.
      - If Task 5 = `c` (Studio revoke deferred): APPEND "Phase 3 closeout: AI-02 Manual-Pending — leaked Google AI Studio key NOT yet revoked. Re-confirm at Phase 4 /gsd:discuss-phase."
      - If Task 6 = `c` (gemini-1.5-pro): APPEND "Phase 3 closeout: pinned 1.5-pro; revisit at Phase 5+ to retry 2.5/3.1 once Vertex GA expands in asia-south1."

    Step F — `## Session Continuity`:
      - `Last session:` → today
      - `Stopped at:` → "Phase 3 complete; Phase 4 ready to discuss"
      - `Resume file:` → ".planning/phases/03-gemini-proxy-server-side-rate-limiting/03-15-phase-closeout-SUMMARY.md"
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "^Phase:\s*4$" .planning/STATE.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "completed_phases:\s*3" .planning/STATE.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "completed_plans:\s*37" .planning/STATE.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "stopped_at:.*Phase 3 complete" .planning/STATE.md</automated>
  </verify>
  <acceptance_criteria>
    - STATE.md frontmatter shows 3 completed phases, 37 completed plans.
    - Current Position shows Phase: 4.
    - Stopped At + Session Continuity records Phase 3 closure.
    - Performance Metrics By Phase has a row for Phase 03.
    - Blockers/Concerns reflects any Task 5/6 deferral outcomes.
  </acceptance_criteria>
  <done>
    STATE.md is the canonical "where are we" doc.
  </done>
</task>

<task type="auto">
  <name>Task 8: Production deploy (manual by solo dev) + closeout commit + cross-doc consistency verification + write 03-15-phase-closeout-SUMMARY.md</name>
  <files>(combined git add — VALIDATION.md, ROADMAP.md, REQUIREMENTS.md, STATE.md)</files>
  <read_first>
    - The 4 files edited in Tasks 2-4 + Task 7.
    - The user's responses from Task 5 + Task 6 (committed verbatim in the SUMMARY).
  </read_first>
  <action>
    Step A — Solo dev manually executes production deploys (DOCUMENTED in SUMMARY):
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      firebase deploy --only firestore:rules --project mentor-mind-aa765
      firebase deploy --only functions --project mentor-mind-aa765
      ```
      Record:
        - The CLI output URLs (Firebase Console links to the deployed rules + functions).
        - Cloud Logging filter URL: https://console.cloud.google.com/logs/query;query=resource.type%3D%22cloud_run_revision%22%20resource.labels.service_name%3D%22mentorbotchat%22?project=mentor-mind-aa765

    Step B — Confirm all 4 doc files have the expected edits (re-run Task 2-4 + Task 7 verify gates).

    Step C — git add + commit:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      git add .planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md \
              .planning/ROADMAP.md \
              .planning/REQUIREMENTS.md \
              .planning/STATE.md
      git commit -m "docs(phase-03): mark Phase 3 complete — 15/15 plans, all 10 AI reqs traced + nyquist_compliant"
      ```

    Step D — Final cross-doc consistency greps:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      grep -qE "^\| 3\. Gemini Proxy.*15/15 \| Complete" .planning/ROADMAP.md
      grep -qE "^Phase:\s*4$" .planning/STATE.md
      grep -q "^nyquist_compliant: true$" .planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md
      ! grep -E "\| AI-(0[1-9]|10) \| Phase 3 \| Pending \|" .planning/REQUIREMENTS.md
      echo "Phase 3 closeout consistent across 4 docs"
      ```

    Step E — Write `.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-15-phase-closeout-SUMMARY.md`:
      Record:
      1. The 14 plan SUMMARY filenames + commit SHAs (from Task 1 Step D).
      2. The verbatim user response from Task 5 (leaked-key revoke confirmation).
      3. The verbatim user response from Task 6 (model-availability confirmation).
      4. The pinned model ID from `functions/src/lib/gemini.ts MODEL_CONFIG.modelId`.
      5. The 4 doc diffs (full unified-diff blocks for VALIDATION + ROADMAP + REQUIREMENTS + STATE).
      6. The cross-doc consistency grep output (4 greps from Step D).
      7. The closeout commit SHA.
      8. The production deploy output (URLs + Cloud Logging filter URL).
      9. The 03-VALIDATION.md row-by-row final Status assignments (15 rows with ✅/⏸).
      10. Open follow-ups:
          - Q-2 (client _awardPoints removal) → Phase 4.
          - If Task 5 = `c`: AI-02 Manual-Pending; Phase 4 re-confirm.
          - If Task 6 = `c`: pinned 1.5-pro; Phase 5+ retry 2.5/3.1.
          - Live mentor_bot_smoke_test on real device — Phase 7.
          - rules.test.ts in CI (Firestore emulator) — Phase 7.
          - macOS-runner CI for integration tests — Phase 7.

    Step F — Re-validate everything one final time:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind

      # All 15 plan files exist
      ls .planning/phases/03-gemini-proxy-server-side-rate-limiting/03-{01,02,03,04,05,06,07,08,09,10,11,12,13,14,15}-*-PLAN.md | wc -l | xargs -I{} test {} -eq 15

      # All 14 prior plan SUMMARYs exist (15th SUMMARY is this plan's own — created above)
      ls .planning/phases/03-gemini-proxy-server-side-rate-limiting/03-{01,02,03,04,05,06,07,08,09,10,11,12,13,14}-*-SUMMARY.md | wc -l | xargs -I{} test {} -eq 14

      # The closeout SUMMARY exists
      test -f .planning/phases/03-gemini-proxy-server-side-rate-limiting/03-15-phase-closeout-SUMMARY.md
      ```
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "^\| 3\. Gemini Proxy.*15/15 \| Complete" .planning/ROADMAP.md &amp;&amp; grep -qE "^Phase:\s*4$" .planning/STATE.md &amp;&amp; grep -q "^nyquist_compliant: true$" .planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md &amp;&amp; ! grep -E "\| AI-(0[1-9]|10) \| Phase 3 \| Pending \|" .planning/REQUIREMENTS.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; git log -1 --format=%s | grep -q "docs(phase-03): mark Phase 3 complete"</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f .planning/phases/03-gemini-proxy-server-side-rate-limiting/03-15-phase-closeout-SUMMARY.md</automated>
  </verify>
  <acceptance_criteria>
    - The closeout commit landed.
    - All 4 cross-doc consistency greps pass.
    - 03-15-phase-closeout-SUMMARY.md exists with both checkpoint responses recorded verbatim.
    - No AI-NN row remains in `Pending` status.
    - Production deploys executed (firebase deploy --only firestore:rules + functions) — outputs recorded.
  </acceptance_criteria>
  <done>
    Phase 3 is closed across all 4 canonical planning docs (VALIDATION + ROADMAP + REQUIREMENTS + STATE). Phase 4 (Server-Authoritative Rewards + Rules Lockdown) is the next phase; `/gsd:discuss-phase 4` is the natural next entry point per STATE.md.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| user ⇄ closeout checkpoints (Task 5 + Task 6) | Two BLOCKING human checkpoints; the closeout pauses until the user answers each. Skipping either risks shipping with the leaked key still active OR with a mis-pinned model. |
| Phase 3 docs ⇄ Phase 4 entry | STATE.md frontmatter is the authoritative "where are we" doc; advancing Phase to 4 unblocks Phase 4 commands. Stale STATE.md = mis-resume risk. |
| Closeout commit ⇄ git history | Single `docs(phase-03): mark Phase 3 complete` commit is the canonical marker. Mirrors `4ef22ca docs(phase-01)...` + `<sha> docs(phase-02)...` patterns. |
| Production deploy ⇄ live Firebase project | The manual `firebase deploy --only firestore:rules` + `firebase deploy --only functions` from Task 8 Step A is the LAST PHASE-3 action; without it, the new rules + functions exist only in git, not production. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-3-15-PREMATURE-CLOSE | Repudiation | Closeout committed before all 14 plan SUMMARYs are green; nyquist_compliant flipped to true but underlying gates are red | mitigate | Task 1 walks all 14 SUMMARYs and STOPS if any missing/red. Tasks 5 + 6 BLOCK closeout until human confirmation. Task 8 happens only after Tasks 5+6 resume. |
| T-3-15-CHECKPOINT-SKIP | Elevation of Privilege | Future executor with `workflow.auto_advance: true` skips Tasks 5/6; closes Phase 3 with leaked key still active OR model unverified | mitigate | Plan frontmatter `autonomous: false` + Tasks 5/6 frontmatter `<task type="checkpoint:human-verify" gate="blocking-human">`. Per planner instructions: legitimacy + product-judgment checkpoints are NEVER auto-advanceable. |
| T-3-15-DEPLOY-FORGOTTEN | Repudiation | Closeout committed but `firebase deploy` never executed; production still runs Phase 2 rules/functions; the Phase 3 docs claim Complete but the production environment hasn't changed | mitigate | Task 8 Step A documents the deploy commands; SUMMARY records the deploy URLs. PR-3 description checkbox `- [ ] firebase deploy --only firestore:rules,functions executed` surfaces the gate. |
| T-3-15-STATE-COUNTER-WRONG | Repudiation | `progress.completed_plans` bumped incorrectly (e.g. 36 vs 37); affects velocity metric over the milestone | accept | Step 7A arithmetic recorded. Drift surfaces in next phase's planning. |
| T-3-15-DOC-DRIFT | Tampering | 3 of 4 docs updated but one missed (e.g. STATE.md still says Phase 3) | mitigate | Step 8D cross-doc consistency greps surface drift. Plan 03-15 verify gate runs them post-commit. |
| T-3-15-MISSING-MITIGATION-FOLLOWUP | Repudiation | Phase 7 follow-up entries not recorded in STATE.md Blockers/Concerns; future planning forgets the deferrals | mitigate | Step 7E explicitly lists the follow-ups: live mentor_bot_smoke_test on real device, rules.test.ts in CI, macOS-runner CI for integration tests, AI-02 / AI-01 conditional follow-ups. |
</threat_model>

<verification>
- All 14 Plan SUMMARYs accounted for (Task 1).
- 03-VALIDATION.md frontmatter flipped to closed/nyquist_compliant true/wave_0_complete true.
- All 15 rows in Per-Plan Verification Map ✅/⏸ (no ⬜ pending).
- ROADMAP.md Phase 3 row marked Complete with date; plans = 15.
- REQUIREMENTS.md AI-01..AI-10 flipped from Pending to Complete (or Manual-Pending per Task 5 outcome).
- STATE.md Phase: 4; completed_phases: 3; completed_plans: 37.
- Single closeout commit message.
- 03-15-phase-closeout-SUMMARY.md records both checkpoint responses verbatim + production deploy URLs.
- Production deploys executed (firebase deploy rules + functions).
</verification>

<success_criteria>
- All 10 AI requirements traced + closed.
- 03-VALIDATION.md nyquist_compliant: true.
- ROADMAP + REQUIREMENTS + STATE all reflect Phase 3 closure.
- Leaked-key rotation confirmed at the human checkpoint (Task 5).
- Model-availability resolution confirmed at the human checkpoint (Task 6).
- Production deploys executed (rules + functions).
- Phase 4 (Server-Authoritative Rewards + Rules Lockdown) is unblocked; `/gsd:discuss-phase 4` is the natural next entry.
- Plan 03-15 SUMMARY documents the close + both checkpoint decisions for future audit.
</success_criteria>

<output>
Create `.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-15-phase-closeout-SUMMARY.md` (this plan's deliverable) when done. Record everything listed in Task 8 Step E:
1. 14 plan SUMMARY filenames + commit SHAs.
2. Task 5 verbatim response (leaked-key rotation).
3. Task 6 verbatim response (model resolution).
4. Pinned MODEL_CONFIG.modelId.
5. 4 doc diffs.
6. Cross-doc consistency grep output.
7. Closeout commit SHA.
8. Production deploy URLs (firebase deploy output).
9. 15-row Status assignments.
10. Open follow-ups for Phase 4/5/7.
</output>
</content>
