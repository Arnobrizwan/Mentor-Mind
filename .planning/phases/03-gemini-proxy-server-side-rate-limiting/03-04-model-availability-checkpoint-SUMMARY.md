---
plan: 03-04
phase: 03-gemini-proxy-server-side-rate-limiting
status: complete
requirements: [AI-01]
decisions: [D-01, D-02]
date: 2026-05-20
---

# Plan 03-04 — Model Availability Checkpoint (AI-01, D-01)

## Outcome: `b` — `gemini-2.5-pro` confirmed (with a D-02 region correction)

The pinned model `gemini-2.5-pro` resolves against the live Vertex AI API and
returns content. **Model ID unchanged** from plan 03-03's default. The fallback
chain did NOT need to walk further down. However, the live verification surfaced
a **region defect in D-02** that required a code change (see Deviation below).

## Probe results (live Vertex AI, authenticated)

Verified via authenticated Vertex `generateContent` REST calls using the project
owner identity (`arnobrizwan23@gmail.com`, `roles/owner` on `mentor-mind-aa765`).

| Model | `asia-south1` (D-02 original) | `us-central1` (corrected) |
|---|---|---|
| `gemini-3.1-pro` | 404 NOT_FOUND | **404 NOT_FOUND** — not a GA model |
| `gemini-2.5-pro` | **404 NOT_FOUND** | **HTTP 200 ✓** `modelVersion: gemini-2.5-pro` |
| `gemini-1.5-pro` | 404 / denied | retired by Google |

Confirming call (`gemini-2.5-pro @ us-central1`): HTTP 200, response `"text": "Ok."`,
`"modelVersion": "gemini-2.5-pro"`. Run timestamp: 2026-05-20T06:35Z.

## Deviation — D-02 region pin corrected (`asia-south1` → `us-central1`)

**D-02 assumed the Vertex AI `location` must match the Cloud Functions deploy
region (`asia-south1`) "to avoid a cross-region hop."** Live verification proved
this wrong: **Gemini generative models are not served from `asia-south1` (Mumbai)**
— every model in the fallback chain returns `404 NOT_FOUND` there. `us-central1`
hosts the full Gemini catalog.

The Vertex API region is **independent** of the Cloud Functions deploy region.
Fix applied (commit `b06b6c9`):
- `functions/src/lib/gemini.ts` — added `MODEL_CONFIG.location = 'us-central1'`;
  `VertexGeminiClient` now reads `opts.modelConfig.location` instead of the
  hardcoded `'asia-south1'`. The `mentorBotChat` function still **deploys** in
  `asia-south1` — only the outbound Vertex call targets `us-central1`.
- `functions/tool/verify-model-availability.js` — probe `location` now
  `us-central1` (overridable via `VERTEX_LOCATION` env var).

D-02's no-API-key / ADC decision is unaffected and still correct.

## Files changed

- `functions/tool/verify-model-availability.js` — NEW (commit `a595222`),
  region-corrected (commit `b06b6c9`). One-shot Vertex probe walking the
  fallback chain.
- `functions/src/lib/gemini.ts` — `MODEL_CONFIG.location` added; doc comments
  D-01/D-02 updated (commit `b06b6c9`).

## Verification

- `npm run build` (tsc) — exit 0.
- `npm run lint` (eslint) — exit 0.
- `npm test -- --testPathIgnorePatterns=rules` — 38/38 pass (gemini suite 8/8;
  `MODEL_CONFIG` key assertions still hold after adding `location`).

## Known issue — local ADC is stale (does NOT block this plan)

The `verify-model-availability.js` script authenticates via Application Default
Credentials. This machine's ADC is a stale credential left over from an
unrelated project (`quota_project_id: ocr-api-arnob-2024`), so running the probe
script directly returns `IAM_PERMISSION_DENIED`. The model availability itself
was confirmed via the gcloud-CLI-token REST path instead (the CLI credential is
correctly `arnobrizwan23@gmail.com`).

To make the probe script self-verifying on this machine, refresh ADC:
```bash
gcloud auth application-default login        # sign in as arnobrizwan23@gmail.com
gcloud auth application-default set-quota-project mentor-mind-aa765
```
This is a local dev-environment fix only. **Production is unaffected** — the
deployed `mentorBotChat` function authenticates as its Cloud Functions runtime
service account (not user ADC); plan 03-08's BACKEND_SETUP.md documents granting
`roles/aiplatform.user` to that SA.

## PR-1 description fragment

```
## Model availability resolution (Plan 03-04)
Project: mentor-mind-aa765
Vertex location: us-central1  (CORRECTED from asia-south1 — Gemini not served in Mumbai)
Functions deploy region: asia-south1 (unchanged)
Resolved model: gemini-2.5-pro  (HTTP 200, modelVersion gemini-2.5-pro)
Script run: 2026-05-20T06:35Z
Decision: hold at gemini-2.5-pro (outcome b). gemini-3.1-pro is not a GA model
          (404); gemini-1.5-pro is retired. D-02 region pin corrected to us-central1.
```

## kluster.ai

⚠️ Your kluster.ai trial has ended. You can visit https://platform.kluster.ai/ to select a plan, subscribe, and re-enable protection.

## Next

03-15 (phase closeout). Forward note: 03-15 should record the D-02 → `us-central1`
correction and confirm the `roles/aiplatform.user` grant on the Functions SA
before the first `firebase deploy --only functions`.
