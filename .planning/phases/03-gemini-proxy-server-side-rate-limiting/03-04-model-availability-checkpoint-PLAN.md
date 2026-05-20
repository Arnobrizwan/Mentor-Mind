---
phase: 03-gemini-proxy-server-side-rate-limiting
plan: 04
type: execute
wave: 2
depends_on: ["03-03"]
files_modified:
  - functions/tool/verify-model-availability.js
  - functions/src/lib/gemini.ts
autonomous: false



requirements: [AI-01]
pr_group: PR-1
tags: [model_availability_checkpoint, vertex_live_call, fallback_chain, gemini_3_1_pro, gemini_2_5_pro, gemini_1_5_pro, blocking_human_verify, pr1_pre_merge_gate, deferred_billing_gate]

must_haves:
  truths:
    - "D-01 closed: the EXACT model ID pinned in `MODEL_CONFIG.modelId` (functions/src/lib/gemini.ts) resolves against the live Vertex AI `asia-south1` endpoint without `Model not found`"
    - "RESEARCH Q-1 closed: executor walks the fallback chain `gemini-3.1-pro` → `gemini-2.5-pro` → `gemini-1.5-pro` until one resolves; first-to-resolve wins and is committed"
    - "Plan 03-03 left `MODEL_CONFIG.modelId = 'gemini-2.5-pro'` as the conservative default; this plan may upgrade it to `gemini-3.1-pro` if Vertex confirms GA in `asia-south1`, or downgrade to `gemini-1.5-pro` if 2.5-pro is unavailable"
    - "Resolution recorded in PR-1 description verbatim: `Model resolved: <id>` + the executor's gcloud project + the run timestamp"
    - "Blocking human checkpoint (`type: checkpoint:human-verify`, `gate: blocking-human`): executor pauses for solo dev to (1) run `gcloud auth application-default login`, (2) confirm Vertex AI API is enabled in `mentor-mind-aa765`, (3) run the script, (4) report back which model resolved"
    - "If NO model in the fallback chain resolves: executor MUST stop, surface to user, and block PR-1 merge — `enforceAppCheck: true` + missing model = day-one production crash"
    - "Plan 03-03 wrote `verify-model-availability.js` patterns into RESEARCH §Pitfall P-1; this plan creates the actual `functions/tool/verify-model-availability.js` script + runs it"
    - "T-3-MODEL-NOT-FOUND mitigated: the checkpoint IS the mitigation — no auto-merge possible without a human-confirmed resolution"
    - "T-3-VERTEX-AUTH-FAIL mitigated: the live script exercises the Functions SA path (via ADC); if `roles/aiplatform.user` is missing (plan 03-08 documents the grant), the script surfaces it loudly BEFORE PR-1 merges"
  artifacts:
    - path: "functions/tool/verify-model-availability.js"
      provides: "One-shot Node script that calls Vertex AI with the pinned model ID and exits 0 on success, 1 on failure"
      contains: "VertexAI"
    - path: "functions/src/lib/gemini.ts"
      provides: "MODEL_CONFIG.modelId UPDATED to the resolved model after the checkpoint completes (may be 'gemini-3.1-pro' or unchanged at 'gemini-2.5-pro' or downgraded to 'gemini-1.5-pro')"
      contains: "modelId"
  key_links:
    - from: "functions/tool/verify-model-availability.js"
      to: "functions/src/lib/gemini.ts MODEL_CONFIG.modelId"
      via: "executor edits the `model` const in the script to match each candidate, runs the script, then back-fills the winner into MODEL_CONFIG.modelId"
      pattern: "gemini-[0-9]+\\.[0-9]+-pro"
    - from: "functions/tool/verify-model-availability.js"
      to: "Vertex AI asia-south1 regional endpoint"
      via: "`@google-cloud/vertexai` SDK with `location: 'asia-south1'` matches the function region (D-02)"
      pattern: "asia-south1"
---

<objective>
Create `functions/tool/verify-model-availability.js` — a one-shot Node script that calls Vertex AI with the pinned `MODEL_CONFIG.modelId` and reports whether it resolves in `asia-south1`. Surface a blocking human checkpoint that pauses for the solo dev to (1) authenticate ADC, (2) confirm Vertex AI API enabled in `mentor-mind-aa765`, (3) run the script with each model ID in the fallback chain, and (4) report back which model wins. After the resolution, the executor updates `functions/src/lib/gemini.ts` `MODEL_CONFIG.modelId` to the winning ID and records the decision verbatim in the PR-1 description.

Purpose: D-01 + RESEARCH §Open Question Q-1 left the exact model ID UNVERIFIED at research time. The Vertex AI model catalog changes month-to-month; `gemini-3.1-pro` GA status in `asia-south1` cannot be confirmed by static docs alone — only a live API call against the user's project resolves it. Plan 03-03 committed `'gemini-2.5-pro'` as the conservative default; this plan either upgrades it (3.1-pro available) or confirms it (2.5-pro stays) or downgrades it (only 1.5-pro available). Without this checkpoint, PR-1 merges with an unverified model ID and `enforceAppCheck: true` on production turns every real chat into `Model not found`.

Output: One new script (`functions/tool/verify-model-availability.js`) and a potential one-line edit to `functions/src/lib/gemini.ts` MODEL_CONFIG.modelId (if the resolved model differs from the plan 03-03 default). One commit. Resolution recorded in this plan's SUMMARY + the PR-1 description.
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
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-03-vertex-gemini-client-PLAN.md
@functions/src/lib/gemini.ts
@CLAUDE.md

<interfaces>
<!-- Patterns from 03-PATTERNS.md §functions/tool/verify-model-availability.js lines 557-591 + 03-RESEARCH §Pitfall P-1 -->

functions/tool/verify-model-availability.js (NEW — full file, copy verbatim):

```javascript
#!/usr/bin/env node
// Verify the pinned Gemini model is GA in asia-south1.
//
// Usage:
//   node functions/tool/verify-model-availability.js
//   node functions/tool/verify-model-availability.js gemini-3.1-pro
//   node functions/tool/verify-model-availability.js gemini-2.5-pro
//   node functions/tool/verify-model-availability.js gemini-1.5-pro
//
// Prerequisites:
//   1. `gcloud auth application-default login` (so ADC is set up).
//   2. Vertex AI API enabled in project (gcloud services enable aiplatform.googleapis.com).
//   3. The default project (env GCLOUD_PROJECT or gcloud config) must be mentor-mind-aa765
//      (or whichever project the executor is testing against).
//
// Exit codes:
//   0 = model resolves and returns content
//   1 = "Model not found" / auth error / network error
//
// This script is the closing gate for D-01 + RESEARCH §Open Question Q-1.

const { VertexAI } = require('@google-cloud/vertexai');

const FALLBACK_CHAIN = ['gemini-3.1-pro', 'gemini-2.5-pro', 'gemini-1.5-pro'];

async function tryModel(modelId, project, location) {
  const vertexAI = new VertexAI({ project, location });
  const genModel = vertexAI.getGenerativeModel({ model: modelId });
  const result = await genModel.generateContent({
    contents: [{ role: 'user', parts: [{ text: 'Say "ok".' }] }],
  });
  const text = result.response.candidates?.[0]?.content?.parts?.[0]?.text;
  return text;
}

async function main() {
  const project =
    process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    'mentor-mind-aa765';
  const location = 'asia-south1';

  // If a model ID is passed as argv[2], try only that one. Otherwise walk the chain.
  const explicit = process.argv[2];
  const candidates = explicit ? [explicit] : FALLBACK_CHAIN;

  console.log(`[verify-model] project=${project} location=${location}`);
  console.log(`[verify-model] candidates=${candidates.join(', ')}`);

  for (const modelId of candidates) {
    process.stdout.write(`[verify-model] trying ${modelId} ... `);
    try {
      const text = await tryModel(modelId, project, location);
      console.log('OK');
      console.log(`[verify-model] response: ${text?.slice(0, 80) ?? '(empty)'}`);
      console.log(`[verify-model] RESOLVED: ${modelId}`);
      process.exit(0);
    } catch (err) {
      console.log(`FAIL (${err.message?.split('\n')[0] ?? 'unknown'})`);
    }
  }

  console.error('[verify-model] NONE of the candidate models resolved.');
  console.error('[verify-model] Confirm Vertex AI API is enabled and ADC is configured.');
  process.exit(1);
}

main().catch((err) => {
  console.error('[verify-model] fatal:', err);
  process.exit(1);
});
```

Why this shape:
  - Single file, no external deps beyond `@google-cloud/vertexai` (already installed by plan 03-03).
  - Walks `FALLBACK_CHAIN` in priority order; first to resolve wins.
  - Accepts an explicit model ID via argv[2] so the executor can test a specific one without walking the chain (useful for sanity rechecks).
  - Reports project + location + each candidate's outcome so the solo dev sees exactly which one resolved.
  - Exits 0 only when a model resolves AND returns content (catches the case where the model name is valid but auth is broken — the call would throw differently).

Resolution path (4 outcomes):
  1. **`gemini-3.1-pro` resolves** → executor edits `functions/src/lib/gemini.ts` line containing `modelId: 'gemini-2.5-pro'` to `modelId: 'gemini-3.1-pro'`. Best case: latest Pro tier model.
  2. **`gemini-2.5-pro` resolves, 3.1-pro does NOT** → executor leaves `MODEL_CONFIG.modelId` as-is (plan 03-03 default). Most likely outcome at execute time.
  3. **`gemini-1.5-pro` resolves, 2.5/3.1 do NOT** → executor edits `MODEL_CONFIG.modelId` to `'gemini-1.5-pro'`. Worst case: stuck on older Pro. Surface to user — cost may be lower (RESEARCH §Cost) but quality may suffer.
  4. **None resolve** → executor STOPS, surfaces to user, blocks PR-1 merge. Likely Vertex AI API not enabled OR ADC misconfigured OR `roles/aiplatform.user` missing on the calling identity.

PR-1 description recording:
  After the script resolves, the executor MUST append to the PR-1 description (or this plan's SUMMARY if PR-1 is not yet open):
    ```
    ## Model availability resolution (Plan 03-04)
    Project: mentor-mind-aa765
    Location: asia-south1
    Resolved model: <gemini-3.1-pro | gemini-2.5-pro | gemini-1.5-pro>
    Script run: $(date -u +%Y-%m-%dT%H:%M:%SZ)
    Decision: <upgrade to 3.1 | hold at 2.5 | downgrade to 1.5> with rationale: ...
    ```

Why this is a `checkpoint:human-verify` (not `auto`):
  - The script exercises a billable Vertex API call (~$0.01-0.05 per probe at Pro pricing). Running it 3× in a row to walk the fallback chain is the worst case (~$0.15). Acceptable cost per PR-1 merge.
  - Auth setup (`gcloud auth application-default login`) MUST happen on the solo dev's machine — Claude cannot run it.
  - Vertex AI API enablement (`gcloud services enable aiplatform.googleapis.com`) is a one-shot human action documented in plan 03-08 BACKEND_SETUP.md §1.
  - `roles/aiplatform.user` IAM grant (plan 03-08 BACKEND_SETUP.md §2) is a one-shot human action.
  - The decision of "upgrade to 3.1-pro vs hold at 2.5-pro" has product implications (cost vs quality tradeoff per RESEARCH §Cost analysis) — human judgment is the right gate.

What this plan does NOT do:
  - Does NOT actually deploy `mentorBotChat` to production — the script calls Vertex directly, bypassing the function.
  - Does NOT modify package.json — `@google-cloud/vertexai` was already added by plan 03-03.
  - Does NOT update BACKEND_SETUP.md — plan 03-08 owns that file.
  - Does NOT raise the budget alert — plan 03-08 owns that.
  - Does NOT grant `roles/aiplatform.user` — plan 03-08 documents the gcloud command.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create functions/tool/verify-model-availability.js with the full one-shot Vertex probe script; verify it parses + has a shebang + is executable</name>
  <files>functions/tool/verify-model-availability.js</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-PATTERNS.md (§functions/tool/verify-model-availability.js lines 557-591 — full skeleton)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-RESEARCH.md (§Pitfall P-1 — model availability rationale; §Open Question Q-1)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-CONTEXT.md (D-01, D-02; §Open Considerations `gemini-3.1-pro` availability)
    - /Users/arnobrizwan/Mentor-Mind/functions/src/lib/gemini.ts (CURRENT — confirm plan 03-03 committed `MODEL_CONFIG.modelId: 'gemini-2.5-pro'`)
  </read_first>
  <action>
    Step A — Create the `functions/tool/` directory if it does not exist:
      ```bash
      mkdir -p /Users/arnobrizwan/Mentor-Mind/functions/tool
      ```

    Step B — Write `functions/tool/verify-model-availability.js` with the EXACT content from the `<interfaces>` block above (copy verbatim).

    Step C — Make the script executable:
      ```bash
      chmod +x /Users/arnobrizwan/Mentor-Mind/functions/tool/verify-model-availability.js
      ```

    Step D — Static syntax check (Node parse):
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      node --check functions/tool/verify-model-availability.js
      # Must print nothing and exit 0.
      ```

    Step E — Confirm `@google-cloud/vertexai` is requirable from the script's working dir (plan 03-03 installed it):
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind/functions
      node -e "require('@google-cloud/vertexai'); console.log('ok')"
      # Must print 'ok' and exit 0.
      ```

    Step F — Dry-run with `--help`-style invocation (NO real Vertex call — just confirm the script starts):
      ```bash
      # The script does not have a --help flag (KISS). Confirm it at least loads
      # by checking its first 2 lines for the shebang + a known string.
      head -2 /Users/arnobrizwan/Mentor-Mind/functions/tool/verify-model-availability.js | grep -q '#!/usr/bin/env node'
      head -20 /Users/arnobrizwan/Mentor-Mind/functions/tool/verify-model-availability.js | grep -q 'FALLBACK_CHAIN'
      ```

    Step G — Commit (without the human-checkpoint changes; those land in Task 3's commit if the script-edit is needed):
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      git add functions/tool/verify-model-availability.js
      git commit -m "feat(functions): add verify-model-availability.js script (Phase 3 PR-1; D-01 / Q-1 closing gate)"
      ```
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f functions/tool/verify-model-availability.js</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -x functions/tool/verify-model-availability.js</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; node --check functions/tool/verify-model-availability.js</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; head -1 functions/tool/verify-model-availability.js | grep -q '^#!/usr/bin/env node$'</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "FALLBACK_CHAIN" functions/tool/verify-model-availability.js</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "'gemini-3.1-pro'" functions/tool/verify-model-availability.js &amp;&amp; grep -q "'gemini-2.5-pro'" functions/tool/verify-model-availability.js &amp;&amp; grep -q "'gemini-1.5-pro'" functions/tool/verify-model-availability.js</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "location: 'asia-south1'" functions/tool/verify-model-availability.js OR grep -q "location.*asia-south1" functions/tool/verify-model-availability.js</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "VertexAI" functions/tool/verify-model-availability.js</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; node -e "require('@google-cloud/vertexai'); console.log('ok')" | grep -q '^ok$'</automated>
  </verify>
  <acceptance_criteria>
    - `functions/tool/verify-model-availability.js` exists, is executable, and parses as valid Node.
    - Has the `#!/usr/bin/env node` shebang on line 1.
    - Walks the `FALLBACK_CHAIN = ['gemini-3.1-pro', 'gemini-2.5-pro', 'gemini-1.5-pro']`.
    - Pins `location: 'asia-south1'` matching the Functions region (D-02).
    - Uses the `@google-cloud/vertexai` package installed by plan 03-03.
    - Accepts an explicit model ID via argv[2].
    - Exit codes: 0 on resolve, 1 on all-fail.
  </acceptance_criteria>
  <done>
    The probe script is on disk and parses cleanly. Ready for the human checkpoint (Task 2).
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking-human">
  <name>Task 2: HUMAN CHECKPOINT — Solo dev runs the model-availability probe; reports back which model resolved</name>
  <what-built>
    Task 1 wrote `functions/tool/verify-model-availability.js`. The script walks the fallback chain `gemini-3.1-pro` → `gemini-2.5-pro` → `gemini-1.5-pro` against the live Vertex AI `asia-south1` endpoint and prints which one resolves. Plan 03-03 left `MODEL_CONFIG.modelId = 'gemini-2.5-pro'` as the conservative default — this checkpoint either upgrades it (3.1 resolves), confirms it (2.5 wins), or downgrades it (only 1.5 resolves).

    This checkpoint is BLOCKING (`gate: blocking-human`). The executor cannot proceed to Task 3 without the human's response. `workflow.auto_advance: true` does NOT auto-resume this gate per plan-frontmatter `gate: blocking-human` (D-04 model-fallback decision has product implications: 3.1-pro is ~3× the cost of 1.5-pro per RESEARCH §Cost).
  </what-built>
  <how-to-verify>
    Solo dev runs these commands in order:

    1. **Authenticate ADC for Vertex AI** (one-time setup; skip if already done in a previous Phase 3 session):
       ```bash
       gcloud auth application-default login
       # Browser opens; sign in as arnobrizwan23@gmail.com (or whichever account
       # owns the mentor-mind-aa765 project).
       ```

    2. **Confirm Vertex AI API is enabled** in `mentor-mind-aa765`:
       ```bash
       gcloud config set project mentor-mind-aa765
       gcloud services list --enabled --filter="name:aiplatform.googleapis.com" --format="value(name)"
       # If output is empty: enable it.
       gcloud services enable aiplatform.googleapis.com
       # Wait ~30s for activation to propagate.
       ```

       (Plan 03-08 documents this in BACKEND_SETUP.md §1; this step is the early-execution gate.)

    3. **Run the probe** (walks the full fallback chain):
       ```bash
       cd /Users/arnobrizwan/Mentor-Mind
       node functions/tool/verify-model-availability.js
       ```

       Expected outcomes (one of four):

       (a) **`gemini-3.1-pro` resolves**:
           ```
           [verify-model] trying gemini-3.1-pro ... OK
           [verify-model] response: ok
           [verify-model] RESOLVED: gemini-3.1-pro
           ```
           → Best case. Report `a` to the executor.

       (b) **`gemini-3.1-pro` fails, `gemini-2.5-pro` resolves** (most likely outcome at execute time):
           ```
           [verify-model] trying gemini-3.1-pro ... FAIL (Model not found)
           [verify-model] trying gemini-2.5-pro ... OK
           [verify-model] response: ok
           [verify-model] RESOLVED: gemini-2.5-pro
           ```
           → Plan 03-03 default stays. Report `b` to the executor.

       (c) **`gemini-3.1-pro` AND `gemini-2.5-pro` fail, `gemini-1.5-pro` resolves**:
           ```
           [verify-model] trying gemini-3.1-pro ... FAIL (Model not found)
           [verify-model] trying gemini-2.5-pro ... FAIL (Model not found)
           [verify-model] trying gemini-1.5-pro ... OK
           [verify-model] RESOLVED: gemini-1.5-pro
           ```
           → Downgrade required. Report `c` to the executor.

       (d) **NONE resolve** — output ends with `NONE of the candidate models resolved`:
           ```
           [verify-model] NONE of the candidate models resolved.
           ```
           → STOP. Likely causes:
             - Vertex AI API not enabled (rerun Step 2).
             - ADC not configured (rerun Step 1).
             - The calling identity lacks `roles/aiplatform.user` (plan 03-08 BACKEND_SETUP.md §2 has the grant command; run it before retrying).
             - Network issue / regional outage (rare).
           Report `d` + the error message verbatim to the executor.

    4. **Respond to the executor with EXACTLY ONE of**: `a`, `b`, `c`, `d`, OR a detailed message describing what you saw.

    The executor will:
      - On `a`: edit `functions/src/lib/gemini.ts` line `modelId: 'gemini-2.5-pro'` → `modelId: 'gemini-3.1-pro'` and re-run `npm run build`.
      - On `b`: leave `MODEL_CONFIG.modelId` as-is (plan 03-03 default stands).
      - On `c`: edit `functions/src/lib/gemini.ts` line `modelId: 'gemini-2.5-pro'` → `modelId: 'gemini-1.5-pro'` and re-run `npm run build`.
      - On `d`: STOP, record the failure in this plan's SUMMARY, surface to user, block PR-1 merge.
  </how-to-verify>
  <resume-signal>Type exactly one of: `a` (gemini-3.1-pro resolved), `b` (gemini-2.5-pro resolved — plan 03-03 default stands), `c` (only gemini-1.5-pro resolved — downgrade required), `d` (none resolved — block PR-1), OR a detailed message describing the result. The executor records your response verbatim in 03-04-model-availability-checkpoint-SUMMARY.md and continues to Task 3.</resume-signal>
</task>

<task type="auto">
  <name>Task 3: Based on the checkpoint response, update functions/src/lib/gemini.ts MODEL_CONFIG.modelId (if needed) and re-run npm test + npm run build</name>
  <files>functions/src/lib/gemini.ts</files>
  <read_first>
    - The user's response from Task 2's checkpoint (verbatim).
    - /Users/arnobrizwan/Mentor-Mind/functions/src/lib/gemini.ts (CURRENT — confirm plan 03-03's `modelId: 'gemini-2.5-pro'` is the current value)
  </read_first>
  <action>
    Branch on the Task 2 response:

    **If response was `a` (gemini-3.1-pro resolved):**
      Step A1 — Edit `functions/src/lib/gemini.ts`:
        Find: `modelId: 'gemini-2.5-pro'`
        Replace with: `modelId: 'gemini-3.1-pro'`
      Step A2 — Re-run npm tests + build:
        ```bash
        cd /Users/arnobrizwan/Mentor-Mind/functions
        npm test -- --testPathPattern=gemini 2>&amp;1 | tail -10
        npm run build 2>&amp;1 | tail -5
        npm run lint 2>&amp;1 | tail -5
        ```
        All three must exit 0. The gemini.test.ts assertion `expect(typeof MODEL_CONFIG.modelId).toBe('string')` + `expect(MODEL_CONFIG.modelId.length).toBeGreaterThan(0)` still passes for any non-empty model ID.
      Step A3 — Commit:
        ```bash
        git add functions/src/lib/gemini.ts
        git commit -m "feat(functions): pin MODEL_CONFIG.modelId to gemini-3.1-pro (Phase 3 PR-1; D-01 / Q-1 resolved by Plan 03-04 checkpoint)"
        ```

    **If response was `b` (gemini-2.5-pro resolved — plan 03-03 default stands):**
      Step B1 — NO edit needed. MODEL_CONFIG.modelId stays `'gemini-2.5-pro'`.
      Step B2 — Record the no-op in the SUMMARY: "Checkpoint resolved: gemini-2.5-pro confirmed. No source change."
      Step B3 — No new commit needed (Task 1's commit already landed the script; the resolution is documented in the SUMMARY).

    **If response was `c` (only gemini-1.5-pro resolved):**
      Step C1 — Edit `functions/src/lib/gemini.ts`:
        Find: `modelId: 'gemini-2.5-pro'`
        Replace with: `modelId: 'gemini-1.5-pro'`
      Step C2 — Re-run npm tests + build (same as A2).
      Step C3 — Surface to user: "Pro tier 1.5 is the only available model. Cost is lower than 2.5/3.1 but capability may suffer for diagram analysis (Premium-tier image flow per D-05). Accept the downgrade or pause to escalate (e.g. request Vertex region change)?"
      Step C4 — On user confirmation, commit:
        ```bash
        git add functions/src/lib/gemini.ts
        git commit -m "feat(functions): downgrade MODEL_CONFIG.modelId to gemini-1.5-pro (Phase 3 PR-1; D-01 / Q-1 resolved by Plan 03-04 checkpoint; 2.5/3.1 not GA in asia-south1)"
        ```

    **If response was `d` (none resolved):**
      Step D1 — STOP. Do NOT edit gemini.ts.
      Step D2 — Record the failure in this plan's SUMMARY: include the verbatim error message from the script, the project ID, the gcloud auth status (`gcloud auth list`), and the IAM check (`gcloud projects get-iam-policy mentor-mind-aa765 --flatten="bindings[].members" --filter="bindings.members:serviceAccount:*" --format="value(bindings.role,bindings.members)"`).
      Step D3 — Surface to user: "Phase 3 PR-1 BLOCKED. No Gemini model resolved against Vertex AI asia-south1. Likely root causes: (1) Vertex AI API not enabled in mentor-mind-aa765 (plan 03-08 BACKEND_SETUP.md §1 — run `gcloud services enable aiplatform.googleapis.com`); (2) `roles/aiplatform.user` not granted to your gcloud identity OR to the Cloud Functions service account (plan 03-08 §2 has the grant command); (3) regional outage. Re-run the probe after fixing and re-respond to the checkpoint."
      Step D4 — Phase 3 is blocked until the human re-resolves. Wait.

    **Post-resolution sanity (a/b/c paths only):**
      Step E — Confirm the resolved model is exposed:
        ```bash
        cd /Users/arnobrizwan/Mentor-Mind
        grep "modelId:" functions/src/lib/gemini.ts
        # Should print exactly one line with the resolved value.
        ```
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -E "modelId: 'gemini-(1\.5|2\.5|3\.1)-pro'" functions/src/lib/gemini.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; npm test -- --testPathPattern=gemini 2>&amp;1 | grep -qE 'Tests:\s+[0-9]+ passed'</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; npm run build 2>&amp;1 | tail -3; test $? -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions &amp;&amp; npm run lint 2>&amp;1 | tail -3; test $? -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; git log --oneline -5 | grep -qE "(Plan 03-04|verify-model-availability|MODEL_CONFIG\.modelId)"</automated>
  </verify>
  <acceptance_criteria>
    - `functions/src/lib/gemini.ts` MODEL_CONFIG.modelId reflects the resolved model ID (3.1-pro / 2.5-pro / 1.5-pro).
    - `npm test -- --testPathPattern=gemini` exits 0.
    - `npm run build` + `npm run lint` both exit 0.
    - One commit per resolution path landed (or none on path `b`/`d`).
    - This plan's SUMMARY records the verbatim checkpoint response + the resolved model ID + the script run timestamp.
  </acceptance_criteria>
  <done>
    D-01 + RESEARCH Q-1 resolved. Plan 03-06 (callable handler) can safely call `makeGeminiClient('prod').generate({...})` knowing the model ID resolves. Plan 03-08 BACKEND_SETUP.md §3 records the resolved model in the runbook for future deploys.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| solo dev gcloud identity ⇄ Vertex AI | The probe uses `gcloud auth application-default login` ADC; the calling identity needs at least `roles/aiplatform.user`. Plan 03-08 BACKEND_SETUP.md §2 documents the grant. |
| probe script ⇄ live Vertex AI | Real billable call (~$0.01-0.05 per probe at Pro pricing); ~$0.15 worst case for walking the full chain. Cost recorded in this plan's SUMMARY. |
| checkpoint response ⇄ code edit | The executor edits `MODEL_CONFIG.modelId` based on a free-text human response. Malformed responses are caught by the post-edit `npm test` gate. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-3-MODEL-NOT-FOUND | Denial of Service | PR-1 merges with an unverified `MODEL_CONFIG.modelId`; production calls return `Model not found` 100% of the time | mitigate | THIS PLAN is the mitigation. The blocking human checkpoint cannot be auto-advanced. No model resolution = no PR-1 merge. |
| T-3-VERTEX-AUTH-FAIL | Denial of Service | Cloud Functions service account missing `roles/aiplatform.user`; every production call returns PERMISSION_DENIED even though the model name is valid | partial-mitigate | The probe runs as the solo dev's ADC identity, NOT the Functions SA. A green probe does NOT prove the Functions SA has the grant. Plan 03-08 documents the SA grant separately; plan 03-13 emulator smoke test exercises the local fake path (also not the SA). Real-SA verification carries forward to a post-deploy manual smoke (live `mentorBotChat` call) — recorded in VALIDATION.md Manual-Only row. |
| T-3-04-SCRIPT-LEAKED-ID | Information Disclosure | Probe script logs the project ID + model ID — could leak in CI logs if accidentally invoked there | mitigate | Script is NOT wired into CI (`functions:` job runs `npm ci && npm run lint && npm run build && npm test` only — plan 03-14). Script is manual-only by design. |
| T-3-04-CHECKPOINT-SKIP | Elevation of Privilege | A future executor with `workflow.auto_advance: true` skips this checkpoint, merging PR-1 with the plan 03-03 default model | mitigate | Plan frontmatter `autonomous: false` + Task 2 frontmatter `<task type="checkpoint:human-verify" gate="blocking-human">`. Per plan instructions: legitimacy + product-judgment checkpoints are never auto-advanceable. |
| T-3-04-FALLBACK-DRIFT | Tampering | A future contributor updates `FALLBACK_CHAIN` to remove 3.1-pro or add a non-Pro model (e.g. flash) without rerunning the checkpoint | accept | This is a documentation-trust issue, not a runtime threat. Phase 3 closeout (plan 03-15) checks that `MODEL_CONFIG.modelId` matches the FALLBACK_CHAIN[0..2]. Future tier changes (e.g. Phase 5+ adding `gemini-3.1-pro-large` for premium users per CONTEXT §Deferred Ideas) intentionally widen the chain. |
| T-3-SC-VERTEX-PROBE | Tampering (supply chain) | `@google-cloud/vertexai` package was already vetted by plan 03-03; this script inherits that trust | mitigate (inherited) | Plan 03-03's package-legitimacy gate is the canonical mitigation. No new dep added here. |
</threat_model>

<verification>
- `functions/tool/verify-model-availability.js` exists, is executable, parses cleanly.
- Shebang + FALLBACK_CHAIN + asia-south1 + VertexAI all present.
- `npm test -- --testPathPattern=gemini` passes (no regression from plan 03-03).
- `MODEL_CONFIG.modelId` resolves to one of `gemini-3.1-pro` / `gemini-2.5-pro` / `gemini-1.5-pro`.
- This plan's SUMMARY records the verbatim checkpoint response + project + run timestamp.
</verification>

<success_criteria>
- D-01 closed: pinned model resolves against live Vertex AI asia-south1.
- RESEARCH §Open Question Q-1 resolved (one of the three fallback paths).
- T-3-MODEL-NOT-FOUND mitigated by the blocking human checkpoint.
- Plan 03-06 can call `makeGeminiClient('prod').generate({...})` with confidence.
- Plan 03-08 BACKEND_SETUP.md §3 can record "Resolved model: <id>".
- Plan 03-15 closeout can mark AI-01 Complete.
</success_criteria>

<output>
Create `.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-04-model-availability-checkpoint-SUMMARY.md` when done. Record:
1. Full content of `functions/tool/verify-model-availability.js`.
2. The verbatim user response from Task 2 (one of: `a`, `b`, `c`, `d`, or detailed text).
3. The verbatim stdout of the `node functions/tool/verify-model-availability.js` run (project, candidates, per-candidate outcome, RESOLVED line).
4. The resolved `MODEL_CONFIG.modelId` value committed to `functions/src/lib/gemini.ts`.
5. The script run timestamp (UTC).
6. The commit SHA(s) — Task 1's script commit + (if applicable) Task 3's modelId update commit.
7. The PR-1 description fragment to be appended (model resolution record).
8. Forward-pointer: plan 03-08 BACKEND_SETUP.md §3 records the resolved model; plan 03-15 closeout flips AI-01 to Complete; if path `c` (1.5-pro) was taken, plan 03-15 also notes a Phase 5+ follow-up to retry 2.5/3.1 once GA.
</output>
</content>
