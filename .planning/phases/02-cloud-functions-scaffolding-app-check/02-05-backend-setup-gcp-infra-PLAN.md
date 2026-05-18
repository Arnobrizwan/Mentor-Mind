---
phase: 02-cloud-functions-scaffolding-app-check
plan: 05
type: execute
wave: 3
depends_on: []
files_modified:
  - BACKEND_SETUP.md
autonomous: true
requirements: [FUNC-04, FUNC-05]
pr_group: PR-2
tags: [backend_setup_docs, gcloud_billing, artifact_registry_cleanup, app_check_kill_switch, debug_token, ci_secret_boundary, region_pin]

must_haves:
  truths:
    - "D-14 honored: gcloud CLI commands documented in BACKEND_SETUP.md (NOT Terraform — solo dev, single env)"
    - "D-15 honored: $10/mo budget; thresholds 50%/90%/100%; recipient `arnobrizwan23@gmail.com`; project `mentor-mind-aa765`"
    - "D-16 honored: Artifact Registry cleanup keeps last 3 versions; concrete `gcloud artifacts repositories set-cleanup-policies` command + JSON policy"
    - "D-17 honored: region pin verification command `gcloud functions list --regions=asia-south1 --v2 --project=mentor-mind-aa765` + DO NOT us-central1 warning"
    - "D-08 honored: BACKEND_SETUP.md §6 documents per-developer simulator debug tokens (registered by each dev in Firebase Console after `flutter run` surfaces the token in Xcode console) + a single shared CI token stored as the `APP_CHECK_DEBUG_TOKEN` GitHub Actions secret"
    - "D-09 honored: BACKEND_SETUP.md §6 documents the rotation cadence — dev tokens never auto-expire (devs self-manage); CI token rotated quarterly per calendar reminder; revocation = Firebase Console → App Check → Apps → MentorMinds iOS → Debug tokens → delete"
    - "D-10 + D-13 honored: debug token registration steps + CI secret `APP_CHECK_DEBUG_TOKEN` boundary note (NOT used by Phase 2 emulator test; reserved for Phase 3+)"
    - "App Check kill-switch URL documented: https://console.firebase.google.com/project/mentor-mind-aa765/appcheck (RESEARCH Assumption A2 — verified URL path conventional)"
    - "Billing-enable command included as Step 1 (RESEARCH Pitfall 7 — `billingEnabled: false` on the project today)"
    - "Plan is DOCS-ONLY — solo dev executes the gcloud commands manually post-merge; verify gates are `grep` against the markdown, NOT `gcloud` execution"
    - "D-19 honored: this is PR-2 in the 3-PR sequence; merges as a doc-only PR"
  artifacts:
    - path: "BACKEND_SETUP.md"
      provides: "New top-level section `## Phase 2 — Cloud Functions + App Check Setup` with 7 subsections covering billing-enable, budget, Artifact Registry, region pin, kill-switch, debug tokens, CI secret"
      contains: "gcloud billing budgets create"
  key_links:
    - from: "BACKEND_SETUP.md Phase 2 §2 (Billing budget)"
      to: "billing account 0121EC-5D572E-57FEE1"
      via: "gcloud billing budgets create --billing-account=..."
      pattern: "0121EC-5D572E-57FEE1"
    - from: "BACKEND_SETUP.md Phase 2 §3 (Artifact Registry)"
      to: "keep-last-3.json policy file"
      via: "set-cleanup-policies --policy=..."
      pattern: "keepCount.*3"
---

<objective>
Append a `## Phase 2 — Cloud Functions + App Check Setup` section to `BACKEND_SETUP.md` with 7 subsections covering: (1) enable billing (prerequisite per RESEARCH Pitfall 7); (2) $10/mo budget alert; (3) Artifact Registry cleanup-policy keeping last 3 versions; (4) region pin verification + DO NOT us-central1 warning; (5) App Check kill-switch URL; (6) debug token registration steps with Xcode console log line pattern; (7) CI secret `APP_CHECK_DEBUG_TOKEN` boundary note (Phase 2 emulator does NOT consume it; reserved for Phase 3+ production paths).

Purpose: D-14 chose gcloud CLI + markdown over Terraform for v1.0 (solo dev, single env). Solo dev runs each command once post-merge; this PR locks the canonical commands and the recipient email so they don't drift. CRITICALLY: this plan does NOT execute any gcloud command — the markdown is the deliverable. Verify gates are grep against the markdown, not gcloud execution (the solo dev runs gcloud once on their own machine post-merge per RESEARCH §Open Question B). Plan 02-11 (phase-closeout) tracks whether the commands actually ran by recording manual evidence in the SUMMARY.

Output: One file modified — `BACKEND_SETUP.md`. After commit, the doc contains all 7 canonical commands; solo dev runs them once. PR-2 ships independently of PR-1 (no code dependency) and PR-3 (no test dependency).
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-CONTEXT.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-RESEARCH.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-PATTERNS.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-VALIDATION.md
@BACKEND_SETUP.md
@CLAUDE.md

<interfaces>
<!-- BACKEND_SETUP.md is the existing doc file (186 lines). The Phase 2 section is appended at the end. -->
<!-- All commands below come VERBATIM from 02-RESEARCH.md §GCP CLI Commands (lines 717-787) and §App Check Detailed Notes (lines 794-842). -->

Existing BACKEND_SETUP.md heading structure (read the actual file to confirm; from 02-PATTERNS.md Group 9):
  - ## 1. Prerequisites
  - ## 2. Create the Firebase project
  - ## 3. Enable the products the app uses
  - ## 4. Wire the app
  - ## 5. Deploy security rules + indexes

Append the new section AT THE END with this exact heading: `## Phase 2 — Cloud Functions + App Check Setup`

Subsections to add (7 in order):

### §1 — Enable billing (prerequisite — RESEARCH Pitfall 7)
  ```bash
  # PREREQUISITE: project billing is currently DISABLED.
  # Enable billing on mentor-mind-aa765 against billing account 0121EC-5D572E-57FEE1.
  gcloud billing projects link mentor-mind-aa765 \
    --billing-account=0121EC-5D572E-57FEE1
  ```
  Notes:
  - Billing must be enabled before Phase 3's `firebase deploy --only functions` will succeed.
  - Phase 2's emulator-only work is unblocked regardless — emulator does not require billing.
  - Verify: `gcloud billing projects describe mentor-mind-aa765` should show `billingEnabled: true` after this command.

### §2 — Billing budget alert ($10/mo, recipient arnobrizwan23@gmail.com)
  ```bash
  # Concrete command from RESEARCH §FUNC-04.
  # NOTE: this command is NOT idempotent — re-running creates a duplicate budget.
  # Verify with `gcloud billing budgets list --billing-account=0121EC-5D572E-57FEE1` first.
  gcloud billing budgets create \
    --billing-account=0121EC-5D572E-57FEE1 \
    --display-name="MentorMinds Phase 2 Guardrail" \
    --budget-amount=10USD \
    --filter-projects="projects/mentor-mind-aa765" \
    --threshold-rule=percent=0.5 \
    --threshold-rule=percent=0.9 \
    --threshold-rule=percent=1.0
  ```
  Recipient note:
  - The budget alert sends to BILLING ADMINISTRATORS on account `0121EC-5D572E-57FEE1`. Ensure `arnobrizwan23@gmail.com` is a billing administrator (Cloud Console → Billing → Account management → IAM).
  - If granular per-channel routing is needed, pre-create a Cloud Monitoring notification channel and add `--notifications-rule-monitoring-notification-channels=<channel-id>`. Out of scope for v1.0.

### §3 — Artifact Registry cleanup policy (keep last 3 versions per image)
  ```bash
  # STEP 1 — discover the auto-created repository name after the first Phase 3 deploy:
  gcloud artifacts repositories list --project=mentor-mind-aa765 --location=asia-south1

  # Cloud Functions v2 creates the repo on first deploy (RESEARCH Open Question 3).
  # The name is typically `gcf-artifacts` or similar.
  # Plan 02 SHIPS this command as a template; Phase 3 SUMMARY fills in REPO_NAME.

  # STEP 2 — create policy file keep-last-3.json:
  cat > /tmp/keep-last-3.json << 'EOF'
  [{
    "name": "keep-last-3-versions",
    "action": {"type": "Keep"},
    "mostRecentVersions": {
      "keepCount": 3
    }
  }]
  EOF

  # STEP 3 — apply the cleanup policy (replace REPO_NAME after Phase 3 deploy):
  gcloud artifacts repositories set-cleanup-policies REPO_NAME \
    --project=mentor-mind-aa765 \
    --location=asia-south1 \
    --policy=/tmp/keep-last-3.json \
    --no-dry-run
  ```

### §4 — Region pin verification + DO NOT us-central1 warning
  ```bash
  # Confirm every v2 callable deploys to asia-south1 (non-negotiable for Bangladesh users).
  gcloud functions list --regions=asia-south1 --v2 --project=mentor-mind-aa765
  ```
  > ⚠️ DO NOT deploy to `us-central1` (the firebase-tools default region). Cross-region latency between Asia and us-central1 is +200ms, which destroys the "useful answer in <10s" core value promise. The `region: 'asia-south1'` pin in `functions/src/index.ts` (Plan 02-03) is the source of truth; this verification command confirms the live state matches.

### §5 — App Check kill-switch URL
  - Open the Firebase Console at this URL: https://console.firebase.google.com/project/mentor-mind-aa765/appcheck
  - Navigate to **Build → App Check → Apps → MentorMinds iOS**.
  - The **Enforcement mode** toggle per service (Cloud Functions, Cloud Firestore, etc.) is the kill switch.
  - Toggling **OFF** takes effect IMMEDIATELY without a function redeploy.
  - Use this if `enforceAppCheck: true` rejects legitimate users in production (Phase 3+).
  - RESEARCH Assumption A2: the URL path is conventional and verified via Firebase Console sidebar navigation.

### §6 — Debug token registration steps (CONTEXT D-08, D-10)
  1. Build and run a DEV iOS build:
     ```bash
     flutter run -d <iOS simulator UDID>
     # AppleProvider.debug auto-generates a token on first call (Plan 02-06 wires this).
     ```
  2. Watch the Xcode Debug console (NOT the system log) for a line matching:
     `[Firebase/AppCheck][I-FAC...] Debug App Check token: <UUID>`
     (Exact prefix may vary slightly across firebase_app_check versions; the substring `Debug App Check token` is stable.)
  3. Copy the UUID.
  4. In Firebase Console, navigate to:
     **Build → App Check → Apps → MentorMinds iOS → overflow menu (⋮) → Manage debug tokens → Add debug token**
  5. Paste the UUID. Give it a name like `arnob-laptop-simulator-2026-05`. Save. Token is immediately valid.
  6. Confirm: on the next run of the dev simulator, calls to the EMULATOR continue to work unchanged (emulator bypasses App Check per RESEARCH Pitfall 6); calls to the PRODUCTION callable (Phase 3+) succeed with the registered token.

  > **Rotation cadence (D-09):** Dev tokens never auto-expire — devs manage their own. CI token rotated quarterly (calendar reminder). Revocation: Firebase Console → App Check → Apps → MentorMinds iOS → Debug tokens → delete by name.

### §7 — CI secret `APP_CHECK_DEBUG_TOKEN` boundary note (CONTEXT D-13)
  - Stored at: GitHub Actions → Settings → Secrets and Variables → Actions → `APP_CHECK_DEBUG_TOKEN`.
  - Value: a debug token registered in Firebase Console (same flow as §6, just named differently — `ci-shared-2026-Q2` or similar).
  - **Phase 2 emulator test (`ping_smoke_test.dart`) does NOT consume this secret** — the Functions emulator bypasses App Check (RESEARCH Pitfall 6). The secret + env-var plumbing is shipped here so Phase 3 (when CI calls production-path enforcement) has zero CI setup overhead.
  - CI consumes it via `--dart-define=APP_CHECK_DEBUG_TOKEN=${{ secrets.APP_CHECK_DEBUG_TOKEN }}` in workflow steps that run against real Firebase. Phase 2 ships this name as a placeholder; Plan 02-10 does NOT add this dart-define yet (the functions job only lints + builds TypeScript; no Flutter integration call against real Firebase from CI in Phase 2).
  - Rotation: quarterly per D-09.

Append marker:
  - Place the new section at the end of BACKEND_SETUP.md, separated from the existing §5 by a horizontal rule:
    ```markdown
    ---

    ## Phase 2 — Cloud Functions + App Check Setup
    ```

What this plan does NOT do:
  - Does NOT EXECUTE any gcloud command (solo dev runs them once post-merge per RESEARCH Open Question B).
  - Does NOT modify firestore.rules / storage.rules — those are out of scope for Phase 2.
  - Does NOT add a Terraform plan — D-14 explicitly rejects Terraform.
  - Does NOT register debug tokens in Firebase Console — that's a manual step solo dev does once.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Append Phase 2 section to BACKEND_SETUP.md with all 7 subsections + literal gcloud commands + URLs</name>
  <files>BACKEND_SETUP.md</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/BACKEND_SETUP.md (CURRENT content; 186 lines per repo state — confirm existing heading structure §1–§5 before appending)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-RESEARCH.md (§GCP CLI Commands lines 717-787 — billing-enable, budget, Artifact Registry, region pin commands VERBATIM; §App Check Detailed Notes lines 794-842 — debug token lifecycle + kill-switch URL)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-PATTERNS.md (§Group 9 — BACKEND_SETUP.md heading pattern + 7-subsection structure lines 704-727)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-CONTEXT.md (D-10, D-13, D-14, D-15, D-16, D-17 — exact values for budget amount, recipient, billing account, region, debug token boundary)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-VALIDATION.md (§Open Question B — billing must be enabled first; Open Question C — REPO_NAME placeholder)
  </read_first>
  <action>
    Step A — Read BACKEND_SETUP.md and capture the last existing section + its concluding lines. The append point is the end of the file.

    Step B — Append the new section literally as specified in `<interfaces>` above:
      Top-level heading: `## Phase 2 — Cloud Functions + App Check Setup`
      Preceded by `---` horizontal rule (separator from §5).

      Seven subsections in order:
      1. `### 1. Enable billing (prerequisite)` — `gcloud billing projects link mentor-mind-aa765 --billing-account=0121EC-5D572E-57FEE1` (Step B copies the literal command from `<interfaces>` §1)
      2. `### 2. Billing budget alert ($10/mo)` — the full `gcloud billing budgets create` command from `<interfaces>` §2 with the 3 threshold-rule lines, recipient email `arnobrizwan23@gmail.com`, idempotency warning
      3. `### 3. Artifact Registry cleanup (keep last 3 versions)` — 3-step command block from `<interfaces>` §3 (list → write keep-last-3.json → set-cleanup-policies); REPO_NAME stays as template placeholder per RESEARCH Open Question C
      4. `### 4. Region pin verification` — `gcloud functions list --regions=asia-south1 --v2 --project=mentor-mind-aa765` + DO NOT us-central1 warning callout
      5. `### 5. App Check kill-switch URL` — the literal URL `https://console.firebase.google.com/project/mentor-mind-aa765/appcheck` + the toggle navigation steps
      6. `### 6. Debug token registration steps` — 6-step numbered list from `<interfaces>` §6 (flutter run → watch Xcode console → copy UUID → Firebase Console add → paste → verify) + rotation cadence note
      7. `### 7. CI secret APP_CHECK_DEBUG_TOKEN boundary note` — the path under GitHub Actions Settings + the Phase 2 / Phase 3 boundary explanation

      Every command block uses fenced ```` ```bash ```` blocks. Every URL is a literal hyperlink in markdown format `[Firebase Console](URL)` or a bare URL.

    Step C — Local validation:
      `node -e "const md=require('fs').readFileSync('BACKEND_SETUP.md','utf8'); const checks={'enable':md.includes('gcloud billing projects link mentor-mind-aa765'),'budget':md.includes('gcloud billing budgets create'),'budget_amount':md.includes('10USD'),'recipient':md.includes('arnobrizwan23@gmail.com'),'artifact':md.includes('set-cleanup-policies'),'keep3':md.includes('keepCount') &amp;&amp; md.includes('3'),'region':md.includes('--regions=asia-south1'),'no_uscentral':md.includes('us-central1') &amp;&amp; md.includes('DO NOT'),'killswitch':md.includes('console.firebase.google.com/project/mentor-mind-aa765/appcheck'),'debug_token':md.includes('Debug App Check token') || md.includes('Debug token'),'ci_secret':md.includes('APP_CHECK_DEBUG_TOKEN')}; const missing=Object.entries(checks).filter(([_,v])=>!v).map(([k])=>k); if(missing.length) throw new Error('missing: '+missing.join(',')); console.log('all 11 checks ok');"`

    Step D — Commit:
      `git add BACKEND_SETUP.md`
      Commit message: `docs(backend): document Phase 2 GCP infra commands — billing, budget, Artifact Registry, region pin, App Check kill switch, debug tokens (Phase 2 PR-2 / FUNC-04, FUNC-05; CONTEXT D-14, D-15, D-16, D-17)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "^## Phase 2 — Cloud Functions" BACKEND_SETUP.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "gcloud billing projects link mentor-mind-aa765" BACKEND_SETUP.md &amp;&amp; grep -q "0121EC-5D572E-57FEE1" BACKEND_SETUP.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "gcloud billing budgets create" BACKEND_SETUP.md &amp;&amp; grep -q "10USD" BACKEND_SETUP.md &amp;&amp; grep -q "arnobrizwan23@gmail.com" BACKEND_SETUP.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "set-cleanup-policies" BACKEND_SETUP.md &amp;&amp; grep -q "keepCount" BACKEND_SETUP.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "gcloud functions list --regions=asia-south1" BACKEND_SETUP.md &amp;&amp; grep -q "us-central1" BACKEND_SETUP.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "console.firebase.google.com/project/mentor-mind-aa765/appcheck" BACKEND_SETUP.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "APP_CHECK_DEBUG_TOKEN" BACKEND_SETUP.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qiE "debug.*token|debug app check token" BACKEND_SETUP.md &amp;&amp; grep -q "Firebase Console" BACKEND_SETUP.md</automated>
  </verify>
  <acceptance_criteria>
    - BACKEND_SETUP.md contains the heading `## Phase 2 — Cloud Functions + App Check Setup`.
    - The literal command `gcloud billing projects link mentor-mind-aa765 --billing-account=0121EC-5D572E-57FEE1` appears.
    - The literal command `gcloud billing budgets create` appears with `10USD` and `arnobrizwan23@gmail.com`.
    - The literal command `set-cleanup-policies` appears with `keepCount` (3).
    - The literal command `gcloud functions list --regions=asia-south1` appears alongside a `us-central1` warning.
    - The literal URL `console.firebase.google.com/project/mentor-mind-aa765/appcheck` appears (App Check kill switch).
    - The literal string `APP_CHECK_DEBUG_TOKEN` appears (CI secret boundary).
    - The literal string `Debug` + `token` appears in the debug token registration subsection (case-insensitive grep).
  </acceptance_criteria>
  <done>
    BACKEND_SETUP.md now contains 7 canonical commands + URLs for Phase 2 GCP infra. Solo dev runs them once post-merge. Plan 02-11 (phase-closeout) records execution evidence (or marks them ⏸ deferred to Phase 3 where deploy actually happens).
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| solo dev local CLI ⇄ GCP API | The documented gcloud commands run with the dev's gcloud auth (`gcloud auth login` / `gcloud auth application-default login`). Phase 2 doc-only plan does not execute them — execution happens manually post-merge. |
| committed BACKEND_SETUP.md ⇄ git history | The doc records the billing account ID `0121EC-5D572E-57FEE1` and the admin email `arnobrizwan23@gmail.com`. These are not secrets (a billing account ID is metadata; the email is in the repo's git author already). No GCP service-account credentials are committed. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-2-COST-RUNAWAY | Resource exhaustion / Repudiation | Cloud Functions cold deploys + retained images bloat the bill (Phase 3 first deploy with `minInstances: 1` would cost ~$25/mo at zero traffic per RESEARCH §FUNC-05) | mitigate | BACKEND_SETUP.md §2 commits the $10/mo budget alert (50/90/100% thresholds) + §3 commits the Artifact Registry keep-last-3 cleanup. Solo dev runs both before Phase 3 deploy. Verify: grep both commands in BACKEND_SETUP.md. |
| T-2-05-BILLING-ACCOUNT-LEAK | Information Disclosure | Billing account ID `0121EC-5D572E-57FEE1` committed to repo | accept | Billing account IDs are not secrets — they are routing identifiers visible to anyone with `billing.accounts.get` permission on the account; not credentials. Compromise of the ID alone does not enable charges. (Comparison: this is analogous to committing an AWS account number, which is also non-sensitive metadata.) |
| T-2-05-DEBUG-TOKEN-LEAK | Information Disclosure | A developer pastes a real debug token UUID into BACKEND_SETUP.md as an example | mitigate | The doc shows the FORMAT (`<UUID>` placeholder) and the EXACT Xcode console log line PATTERN, never a real token value. The CI secret is stored in GitHub Actions Secrets, not in the doc. Verify by inspection. |
| T-2-05-REPO-NAME-PLACEHOLDER | Repudiation | Solo dev runs `set-cleanup-policies REPO_NAME` with the literal text `REPO_NAME` instead of the actual repo name; command 404s | accept | RESEARCH Open Question C documents this as a Phase 3 follow-up (the repo is auto-created on first deploy; name is `gcf-artifacts` or similar). BACKEND_SETUP.md §3 explicitly notes the placeholder. Plan 02-11 SUMMARY records "Phase 3 fills REPO_NAME". |
| T-2-05-WRONG-RECIPIENT | Information Disclosure / Repudiation | Budget alerts route to billing admins on account `0121EC-5D572E-57FEE1` rather than the listed `arnobrizwan23@gmail.com` because the email is not a billing admin | mitigate | BACKEND_SETUP.md §2 explicitly notes: "ensure arnobrizwan23@gmail.com is a billing administrator (Cloud Console → Billing → Account management → IAM)". Solo dev verifies before running the command. |
</threat_model>

<verification>
- BACKEND_SETUP.md ends with the new `## Phase 2 — Cloud Functions + App Check Setup` section.
- All 7 subsection markers present (the 8 grep gates cover billing-enable, budget, recipient, Artifact Registry, region pin, kill switch, debug token, CI secret).
- Commands match VERBATIM what RESEARCH §GCP CLI Commands specifies (no paraphrase).
</verification>

<success_criteria>
- D-14, D-15, D-16, D-17 honored: gcloud commands documented; $10/mo budget; recipient pinned; Artifact Registry keep-last-3; region asia-south1 verified.
- D-10, D-13 honored: debug token registration steps + CI secret boundary documented.
- T-2-COST-RUNAWAY mitigated via documented (not yet executed) budget + cleanup commands.
- FUNC-04 + FUNC-05 partially met (commands documented; manual execution by solo dev is the closing step recorded in Plan 02-11 SUMMARY).
- PR-2 ships independently: zero code deps; merge order PR-1 → PR-2 → PR-3 is locked by D-19 but technically PR-2 could merge first.
</success_criteria>

<output>
Create `.planning/phases/02-cloud-functions-scaffolding-app-check/02-05-backend-setup-gcp-infra-SUMMARY.md` when done. Record: the full text of the appended Phase 2 section (so future maintainers can re-derive the commands without re-reading RESEARCH.md), the 8 grep results from the verify block, and an explicit note that NO gcloud command was executed during plan execution (per D-14 + RESEARCH §Open Question B).
</output>
