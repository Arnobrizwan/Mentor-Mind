---
phase: 03-gemini-proxy-server-side-rate-limiting
plan: 08
type: execute
wave: 4
depends_on: []
files_modified:
  - BACKEND_SETUP.md
autonomous: true
requirements: [AI-02]
pr_group: PR-2
tags: [backend_setup_doc, vertex_ai_iam_grant, leaked_key_rotation, budget_alert_raise, monthly_call_ceiling_env, solo_dev_manual_runbook, ai_02, t_3_key_leak]

must_haves:
  truths:
    - "AI-02 honored: BACKEND_SETUP.md `## Phase 3 — Vertex AI + Key Rotation` section documents the leaked Google AI Studio key revocation step (manual, BEFORE PR-3 merges)"
    - "D-02 honored: section documents `gcloud services enable aiplatform.googleapis.com` + `gcloud projects add-iam-policy-binding ... --role=roles/aiplatform.user` for the Functions service account (no API key path used)"
    - "D-22 honored: leaked-key rotation is MANUAL via https://aistudio.google.com/apikey — Phase 3 does not auto-revoke; git-history-scrub is explicitly NOT performed (rejected per D-22)"
    - "CONTEXT §Open Considerations path (a) honored: Phase 2 D-15 budget alert raised pre-emptively to $75/mo (researcher revised cost up from initial $50; pro-tier × 10000 calls/month at $1.25 input / $5 output per million tokens ≈ $52-75/mo budget headroom)"
    - "D-10 / §Specifics honored: `MONTHLY_CALL_CEILING` env-var tunable via gcloud + firebase-functions v2 params runtime config — section documents the override command"
    - "Section mirrors Phase 2 D-CONTEXT §3 (BACKEND_SETUP.md §Phase 2) format: H2 section header, numbered subsections, bash code blocks with exact commands"
    - "Cloud Logging filter recipe included so solo dev can verify per-call telemetry (`event=\"gemini_call\"`) from plan 03-07 — paste-and-run command"
    - "Plan 03-04 model-availability resolution recorded inline (the resolved model ID from the checkpoint OR a placeholder `<resolved by Plan 03-04>` if Phase 3 PR-2 lands before PR-1)"
    - "T-3-KEY-LEAK mitigated: rotation step is the documented gate before PR-3 merges; PR-3 description checkbox surfaces it to the user"
  artifacts:
    - path: "BACKEND_SETUP.md"
      provides: "APPENDED `## Phase 3 — Vertex AI + Key Rotation` section with 6 subsections (enable API, grant IAM, raise budget, MONTHLY_CALL_CEILING runtime config, leaked-key rotation, Cloud Logging filter)"
      contains: "Phase 3 — Vertex AI + Key Rotation"
  key_links:
    - from: "BACKEND_SETUP.md §Phase 3 §1"
      to: "Vertex AI API + Cloud Functions service account"
      via: "gcloud services enable + gcloud projects add-iam-policy-binding"
      pattern: "aiplatform.user"
    - from: "BACKEND_SETUP.md §Phase 3 §5"
      to: "https://aistudio.google.com/apikey"
      via: "manual revoke link (solo dev clicks, recorded in PR-3 checkbox)"
      pattern: "aistudio.google.com/apikey"
    - from: "BACKEND_SETUP.md §Phase 3 §3"
      to: "Phase 2 D-15 budget alert"
      via: "gcloud billing budgets update --budget-amount=75USD"
      pattern: "75USD"
---

<objective>
Append a `## Phase 3 — Vertex AI + Key Rotation` section to `BACKEND_SETUP.md` covering six subsections that the solo dev will execute manually before / during Phase 3 PR merges:
  1. Enable the Vertex AI API in `mentor-mind-aa765`.
  2. Grant `roles/aiplatform.user` to the Cloud Functions service account.
  3. Raise the Phase 2 D-15 budget alert from $10/mo to $75/mo.
  4. (Optional) Override the `MONTHLY_CALL_CEILING` env-var via firebase-functions v2 params.
  5. Revoke the leaked Google AI Studio API key (MANUAL — BEFORE PR-3 merges).
  6. Cloud Logging filter recipe for `event="gemini_call"` (plan 03-07 telemetry).

Each subsection ships a copy-paste bash command (or a click-and-confirm URL for the manual revoke). The model ID resolved by plan 03-04's checkpoint is recorded inline.

Purpose: Phase 3 introduces multiple human-only operations: enabling APIs, granting IAM, raising billing thresholds, revoking a leaked key. These cannot be automated. BACKEND_SETUP.md becomes the runbook — the solo dev opens it once per Phase 3 PR sequence and ticks each command off. The PR-3 description references this section's §5 as the leaked-key rotation gate.

Output: One file modified — `BACKEND_SETUP.md` (APPEND ~120 lines). One commit. Static grep gates verify all 6 subsections + the key strings (`aiplatform.user`, `aistudio.google.com/apikey`, `75`, `MONTHLY_CALL_CEILING`).
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-CONTEXT.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-RESEARCH.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-PATTERNS.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-04-model-availability-checkpoint-PLAN.md
@BACKEND_SETUP.md
@CLAUDE.md

<interfaces>
<!-- Mirror the Phase 2 §3 BACKEND_SETUP.md structure exactly. The Phase 2 H2 header is `## Phase 2 — Cloud Functions + App Check Setup`; the Phase 3 header MUST be `## Phase 3 — Vertex AI + Key Rotation`. -->

Section to APPEND to BACKEND_SETUP.md (after the existing Phase 2 section):

```markdown

## Phase 3 — Vertex AI + Key Rotation

> Run these once, in this order, BEFORE merging the corresponding Phase 3 PR.
> Owner: solo dev (`arnobrizwan23@gmail.com`). Project: `mentor-mind-aa765`.

### 1. Enable the Vertex AI API (BEFORE PR-1 merges)

Phase 3's `mentorBotChat` callable calls Vertex AI via the `@google-cloud/vertexai`
Node SDK using Application Default Credentials (no API key). The Vertex AI API
must be enabled at the project level.

```bash
gcloud config set project mentor-mind-aa765
gcloud services enable aiplatform.googleapis.com
# Wait ~30-60s for the API enablement to propagate.
gcloud services list --enabled --filter="name:aiplatform.googleapis.com" --format="value(name)"
# Expected output: aiplatform.googleapis.com
```

### 2. Grant `roles/aiplatform.user` to the Cloud Functions service account (BEFORE PR-1 merges)

The Functions v2 runtime auto-injects Application Default Credentials for the
service account `<projectId>@appspot.gserviceaccount.com`. That SA must have
permission to invoke Vertex AI.

```bash
# Find the SA (Functions v2 default).
FUNCTIONS_SA="mentor-mind-aa765@appspot.gserviceaccount.com"

gcloud projects add-iam-policy-binding mentor-mind-aa765 \
  --member="serviceAccount:${FUNCTIONS_SA}" \
  --role="roles/aiplatform.user"

# Verify.
gcloud projects get-iam-policy mentor-mind-aa765 \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${FUNCTIONS_SA} AND bindings.role:roles/aiplatform.user" \
  --format="value(bindings.role)"
# Expected output: roles/aiplatform.user
```

> **Why this is the right granularity:** `roles/aiplatform.user` covers
> `aiplatform.endpoints.predict` (Gemini generateContent) without granting
> dataset / pipeline write permissions. Principle of least privilege.

### 3. Raise the Phase 2 budget alert from $10/mo to $75/mo (BEFORE PR-1 merges)

Phase 2 D-15 wired a `$10/mo` GCP budget alert. Phase 3's Pro-tier Gemini cost
projection (10,000 calls/mo × ~$0.0055/call ≈ $55/mo at average prompt sizes)
breaches that. Raise the alert pre-emptively (CONTEXT §Open Considerations path
`a`) so the alert continues to function as a 50%/90%/100% warning instead of
firing on day 1.

```bash
# Find the existing budget ID.
gcloud billing budgets list \
  --billing-account=$(gcloud beta billing projects describe mentor-mind-aa765 --format="value(billingAccountName)" | sed 's|billingAccounts/||')

# Update to $75/mo (the budget name + ID came from Phase 2 BACKEND_SETUP.md §3).
gcloud billing budgets update \
  projects/mentor-mind-aa765/billingBudgets/<BUDGET_ID> \
  --budget-amount=75USD
```

> **Why $75/mo (revised from initial $50):** Researcher pricing per RESEARCH.md
> §Cost confirmed `$1.25/M input` + `$5/M output` for all Pro-tier models
> (3.1, 2.5, 1.5). At 10,000 calls/mo, average 500 input + 1000 output tokens,
> the projected spend lands at $52-$60/mo. $75/mo gives ~25% headroom for spikes.

### 4. (Optional) Override the MONTHLY_CALL_CEILING env-var

The monthly app-wide ceiling defaults to 10,000 calls (Plan 03-05 D-10). To
raise / lower without redeploying logic, set the param via firebase-functions
v2 params runtime config:

```bash
# Set (example: raise to 20000).
firebase functions:config:set monthly_call_ceiling=20000 --project mentor-mind-aa765

# Or via the v2 params API (preferred):
echo "MONTHLY_CALL_CEILING=20000" > functions/.env.mentor-mind-aa765
# Then `firebase deploy --only functions:mentorBotChat` to push the new value.
```

> Plan 03-05 reads the value via `defineString('MONTHLY_CALL_CEILING', { default: '10000' })`.
> The default `10000` is what ships in source — overrides are purely operational.

### 5. Revoke the leaked Google AI Studio API key (MANUAL — BEFORE PR-3 merges)

The legacy `--dart-define=GEMINI_API_KEY=<key>` path was used pre-Phase-3 and
the key landed in the compiled iOS binary (AI-02 — the binary-scrub plus
rotation is Phase 3's resolution). The Vertex AI path doesn't use a key at
all, so this step is purely about killing the dead key.

1. Open https://aistudio.google.com/apikey
2. Sign in as `arnobrizwan23@gmail.com`
3. Find the API key currently in the iOS binary / your local env files.
   - If you have the key file at hand: match the last 4 characters to the
     entry in Studio.
   - If not: revoke the most recent key created before 2026-05-01 (the
     pre-Phase-3 baseline).
4. Click **Revoke**. Confirm.

> **Git history scrub is NOT performed (D-22).** The key was committed in
> the iOS binary builds, not in plaintext to git. Revoked = dead. Force-pushing
> to main would destroy unrelated history; not worth the destructive trade.

PR-3 description includes the checkbox:
```
- [ ] Leaked Google AI Studio key revoked in https://aistudio.google.com/apikey BEFORE merging
```

### 6. Cloud Logging — verify per-call telemetry (post-PR-1 deploy)

Plan 03-07 emits structured logs at `event="gemini_call"` (success) and
`event="gemini_call_idempotent_hit"` (dedupe). The aggregate doc lives at
`/system/usage_log_{YYYY-MM-DD}`.

Cloud Logging filter (paste into https://console.cloud.google.com/logs/query):

```
resource.type="cloud_run_revision"
resource.labels.service_name="mentorbotchat"
jsonPayload.event="gemini_call"
```

For aggregate inspection (Cloud Firestore):
```bash
# After a few calls have run, read the day's aggregate doc.
gcloud firestore documents read system/usage_log_$(TZ=Asia/Dhaka date +%Y-%m-%d) \
  --project=mentor-mind-aa765 --format=json
# Expect: { calls: <n>, promptTokens: <n>, completionTokens: <n>, estimatedCostUsd: <n>, dateLabel: "..." }
```

### 7. Model resolution record (filled by Plan 03-04 checkpoint)

The exact Gemini model ID pinned in `functions/src/lib/gemini.ts MODEL_CONFIG.modelId`
was resolved by Plan 03-04 against the live Vertex API in `asia-south1`. The
fallback chain is `gemini-3.1-pro` → `gemini-2.5-pro` → `gemini-1.5-pro`.

- **Resolved model:** `<gemini-X.Y-pro — fill from Plan 03-04 checkpoint resolution>`
- **Resolution date:** `<YYYY-MM-DD>`
- **Re-verify command:** `node functions/tool/verify-model-availability.js`
```

---

Why this section structure:
  - Mirrors the Phase 2 §3 BACKEND_SETUP.md format (numbered subsections under a single H2; each subsection is one human-only operation).
  - Each subsection states its WHEN clause (`BEFORE PR-1 merges` / `BEFORE PR-3 merges` / post-deploy) so the solo dev never executes the wrong step at the wrong time.
  - All bash blocks use real commands with real flags; the executor can copy-paste without modification (except for `<BUDGET_ID>` in §3 which is filled at execute time).
  - The §5 revoke step is the only one that cannot be a CLI command — it's a click-through UI flow. The instruction is precise (which account, which key, what to click).
  - §7 records the model resolution AFTER plan 03-04 lands; this plan ships the section with a placeholder so PR-2 is not blocked on PR-1.

What this plan does NOT do:
  - Does NOT execute any of the gcloud / firebase commands. Plan-time is documentation-only; the solo dev runs them manually.
  - Does NOT remove the existing Phase 2 §3 section (it's preserved verbatim — the $10/mo budget reference in §3 is left in place; the Phase 3 §3 explicitly notes the raise).
  - Does NOT modify firestore.rules — plan 03-09 owns that.
  - Does NOT modify any code — purely a documentation update.
  - Does NOT change README.md run instructions — plan 03-12 owns removing `--dart-define=GEMINI_API_KEY` from there.
  - Does NOT add a key rotation script — D-22 explicitly mandates manual rotation; auto-revoke would require a Google Cloud OAuth flow that doesn't pay back the complexity.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: APPEND `## Phase 3 — Vertex AI + Key Rotation` section to BACKEND_SETUP.md with 7 subsections; verify all required strings present + Markdown well-formed</name>
  <files>BACKEND_SETUP.md</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/BACKEND_SETUP.md (CURRENT — confirm Phase 2 §3 header is `## Phase 2 — Cloud Functions + App Check Setup` and locate its position)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-CONTEXT.md (D-02, D-10, D-22, §Open Considerations a — $75/mo budget)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-RESEARCH.md (§Cost — confirm $1.25 input / $5 output / $52-60 monthly projection)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md (row `03-08-backend-setup-vertex-keyrotation` line 61 — Automated Command verbatim)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-05-backend-setup-gcp-infra-PLAN.md (Phase 2 BACKEND_SETUP §3 — match the section structure)
  </read_first>
  <action>
    Step A — Read `BACKEND_SETUP.md` to confirm:
      - The Phase 2 §3 (`## Phase 2 — Cloud Functions + App Check Setup`) section exists and is the LAST H2 section in the file.
      - The project ID `mentor-mind-aa765` is the canonical reference (already in the Phase 2 section).
      - The solo dev email `arnobrizwan23@gmail.com` is referenced.

    Step B — APPEND the new section from the `<interfaces>` block above. Specifically:
      - Insert immediately after the Phase 2 §3 section (typically the last block in the file).
      - Use the EXACT H2 header `## Phase 3 — Vertex AI + Key Rotation`.
      - Use 7 numbered H3 subsections (`### 1. ...` through `### 7. ...`).
      - Preserve all bash code fences (triple backtick with `bash` language hint).

    Step C — For §3 — the budget update command references `<BUDGET_ID>`. Leave this as a placeholder for the solo dev to fill in at execute time. The PR-2 SUMMARY records the actual budget ID after the gcloud command runs.

    Step D — For §7 — the model resolution record. Two cases:
      - If plan 03-04 has ALREADY resolved (its SUMMARY exists with a verbatim `Resolved model: <id>` line): fill the placeholder with that exact model ID and resolution date.
      - If plan 03-04 has NOT yet resolved at the time this plan executes (PR-2 may land before PR-1): leave the placeholder text `<gemini-X.Y-pro — fill from Plan 03-04 checkpoint resolution>` literally. The plan 03-15 closeout updates it then.

    Step E — Markdown lint smoke check:
      ```bash
      # Confirm the file still parses cleanly (no broken code fences, no
      # un-terminated lists). A simple line-count + trailing-newline check.
      tail -1 /Users/arnobrizwan/Mentor-Mind/BACKEND_SETUP.md | wc -c
      # Expect: > 0 (final newline present).
      # Confirm balanced ``` fences across the entire file:
      grep -c '^```' /Users/arnobrizwan/Mentor-Mind/BACKEND_SETUP.md
      # Expect: an EVEN number.
      ```

    Step F — Required-content greps (all must FIND matches):
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      grep -q "## Phase 3 — Vertex AI + Key Rotation" BACKEND_SETUP.md
      grep -q "aiplatform.googleapis.com" BACKEND_SETUP.md
      grep -q "roles/aiplatform.user" BACKEND_SETUP.md
      grep -q "@appspot.gserviceaccount.com" BACKEND_SETUP.md
      grep -q "75USD" BACKEND_SETUP.md  # budget raise
      grep -q "75" BACKEND_SETUP.md     # general budget mention
      grep -q "MONTHLY_CALL_CEILING" BACKEND_SETUP.md
      grep -q "aistudio.google.com/apikey" BACKEND_SETUP.md
      grep -q "Cloud Logging" BACKEND_SETUP.md
      grep -q "event=\"gemini_call\"" BACKEND_SETUP.md
      grep -q "system/usage_log_" BACKEND_SETUP.md
      grep -q "Plan 03-04" BACKEND_SETUP.md
      grep -q "mentor-mind-aa765" BACKEND_SETUP.md
      # Phase 2 section preserved (no accidental delete):
      grep -q "## Phase 2 — Cloud Functions + App Check Setup" BACKEND_SETUP.md
      ```

    Step G — Anti-pattern guards (all must NOT find matches):
      ```bash
      # D-22: NO automated git history scrub
      ! grep -E 'git filter-branch|BFG' BACKEND_SETUP.md
      # NO suggestion to use --dart-define=GEMINI_API_KEY in Phase 3
      ! grep -E '\-\-dart-define=GEMINI_API_KEY' BACKEND_SETUP.md
      # NO suggestion to store the Gemini key in Secret Manager (D-02 — Vertex via ADC, no key)
      ! grep -E 'gcloud secrets|Secret Manager' BACKEND_SETUP.md
      ```

    Step H — Commit:
      ```bash
      git add BACKEND_SETUP.md
      git commit -m "docs(backend-setup): add Phase 3 — Vertex AI + Key Rotation section (Phase 3 PR-2; AI-02; D-02/D-10/D-15/D-22)"
      ```
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "## Phase 3 — Vertex AI + Key Rotation" BACKEND_SETUP.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "aiplatform.googleapis.com" BACKEND_SETUP.md &amp;&amp; grep -q "roles/aiplatform.user" BACKEND_SETUP.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "aistudio.google.com/apikey" BACKEND_SETUP.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "75" BACKEND_SETUP.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "MONTHLY_CALL_CEILING" BACKEND_SETUP.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "## Phase 2 — Cloud Functions + App Check Setup" BACKEND_SETUP.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "Cloud Logging" BACKEND_SETUP.md &amp;&amp; grep -q "gemini_call" BACKEND_SETUP.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "system/usage_log_" BACKEND_SETUP.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -E 'git filter-branch|BFG' BACKEND_SETUP.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -E '\-\-dart-define=GEMINI_API_KEY' BACKEND_SETUP.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -E 'Secret Manager|gcloud secrets' BACKEND_SETUP.md</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; FENCE_COUNT=$(grep -c '^```' BACKEND_SETUP.md); test $((FENCE_COUNT % 2)) -eq 0</automated>
  </verify>
  <acceptance_criteria>
    - `BACKEND_SETUP.md` has the new H2 header `## Phase 3 — Vertex AI + Key Rotation`.
    - All 7 numbered subsections present.
    - Every required string present: `aiplatform.googleapis.com`, `roles/aiplatform.user`, `75`, `MONTHLY_CALL_CEILING`, `aistudio.google.com/apikey`, `Cloud Logging`, `gemini_call`, `system/usage_log_`, `Plan 03-04`, `mentor-mind-aa765`.
    - Phase 2 §3 section is preserved (no accidental delete).
    - Anti-patterns absent: no `git filter-branch` / `BFG` (D-22 — manual revoke), no `--dart-define=GEMINI_API_KEY` (Phase 3 removes it), no `Secret Manager` references (D-02 — Vertex via ADC).
    - Code fences are balanced (even count of triple-backticks).
  </acceptance_criteria>
  <done>
    BACKEND_SETUP.md is the runbook. The solo dev opens the §Phase 3 section, executes §1 → §6 in order, and ticks the PR-3 checkbox before merging. Plan 03-15 closeout fills the §7 model-resolution placeholder if it wasn't filled by plan 03-04's checkpoint output.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| BACKEND_SETUP.md ⇄ solo dev gcloud session | The doc lists exact commands; the solo dev runs them on their workstation with their own gcloud identity. No service-account credentials are committed. |
| §5 manual revoke ⇄ Studio dashboard | The leaked-key rotation is a click-through UI; the doc precisely identifies which account, which key, and what to click. T-3-KEY-LEAK closure depends on the solo dev actually performing this step. |
| §2 IAM grant ⇄ Functions service account | The grant elevates the Functions SA from default (no Vertex access) to `roles/aiplatform.user`. PoLP applied — no broader role. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-3-KEY-LEAK | Information Disclosure | The leaked Google AI Studio key remains valid post-Phase-3; a future attacker scanning iOS binaries for `AIza`-prefixed strings finds it and uses it to run up the user's bill | mitigate | §5 documents the manual revoke. PR-3 description checkbox is the gate. Plan 03-15 phase-closeout includes a blocking human checkpoint that re-confirms the key is revoked before flipping `nyquist_compliant: true`. |
| T-3-08-DOC-IGNORED | Repudiation | A future executor reads BACKEND_SETUP.md but skips the manual steps; PR-1 deploys without the IAM grant; production fails 100% of calls | mitigate | Plan 03-04's checkpoint EXERCISES the IAM grant indirectly (the probe script uses the solo dev's ADC, not the Functions SA, so it doesn't catch a missing SA grant — but a green probe at least confirms Vertex API enablement). Phase 7 polish: add a post-deploy smoke test that calls mentorBotChat from a live device. |
| T-3-08-BUDGET-STALE | Repudiation | Solo dev runs §3 but doesn't update the actual budget ID — only documents are updated | accept | §3 includes the `gcloud billing budgets list` command to find the ID, and the update command references it. The PR-2 SUMMARY captures the actual budget ID. |
| T-3-08-IAM-OVERREACH | Elevation of Privilege | Future contributor uses `roles/editor` or `roles/owner` instead of `roles/aiplatform.user`, granting the Functions SA write access to everything | mitigate | §2 explicitly states "Principle of least privilege" and pins the role. The grep gate `grep -q "roles/aiplatform.user"` runs every verify. Plan 03-15 closeout re-confirms. |
| T-3-08-STUDIO-WRONG-KEY | Repudiation | Solo dev revokes a different key by mistake (multiple keys in Studio); the leaked one stays valid | accept | §5 instructs to match the last 4 characters, or revoke the most recent pre-Phase-3 key. Imperfect but the best signal we have without storing the key's value (which would itself be a leak). |
</threat_model>

<verification>
- BACKEND_SETUP.md has `## Phase 3 — Vertex AI + Key Rotation` with 7 subsections.
- §1 documents `gcloud services enable aiplatform.googleapis.com`.
- §2 documents `roles/aiplatform.user` grant to Functions SA.
- §3 documents the budget raise to $75/mo.
- §4 documents the MONTHLY_CALL_CEILING override.
- §5 documents the manual key revoke at aistudio.google.com/apikey.
- §6 documents the Cloud Logging filter for `event="gemini_call"`.
- §7 has a placeholder for the Plan 03-04 model resolution.
- Phase 2 §3 preserved.
- No git-history-scrub commands.
- No --dart-define=GEMINI_API_KEY suggestions.
- No Secret Manager references.
</verification>

<success_criteria>
- AI-02 + D-22 documentation runbook ready for solo dev manual execution.
- Phase 2 D-15 budget alert tension surfaced and raised path (a) documented.
- T-3-KEY-LEAK has a clear closure path before PR-3 merges.
- Plan 03-15 closeout can verify the manual steps were performed.
</success_criteria>

<output>
Create `.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-08-backend-setup-vertex-keyrotation-SUMMARY.md` when done. Record:
1. The FULL appended `## Phase 3 — Vertex AI + Key Rotation` section content.
2. The required-content grep results (all 13+ greps from Step F).
3. The anti-pattern grep results (3 negative greps — all empty).
4. The fence-count check result.
5. Commit SHA.
6. Forward-pointer to the solo dev: "Run §1 + §2 + §3 BEFORE merging PR-1; §5 BEFORE merging PR-3; §6 after PR-1 deploy."
7. Plan 03-15 closeout follow-up: fill §7 model resolution if not already filled.
</output>
</content>
