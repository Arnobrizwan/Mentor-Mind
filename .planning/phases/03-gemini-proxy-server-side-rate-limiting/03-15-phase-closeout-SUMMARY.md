---
plan: 03-15
phase: 03-gemini-proxy-server-side-rate-limiting
status: complete
requirements: [AI-01, AI-02, AI-03, AI-04, AI-05, AI-06, AI-07, AI-08, AI-09, AI-10]
date: 2026-05-20
---

# Plan 03-15 — Phase 3 Closeout

Phase 3 (Gemini Proxy + Server-Side Rate Limiting) is **complete** — 15/15 plans
landed on `main`, all 10 AI-* requirements traced Complete, `03-VALIDATION.md`
closed + `nyquist_compliant: true`. Production deploy executed.

## Task 1 — SUMMARY walk

All 14 prior plan SUMMARYs (03-01..03-14) exist, non-empty, and record green
verify gates. Plan commit SHAs (feat/fix/test/build):

| Plan | Commit | Plan | Commit |
|---|---|---|---|
| 03-01 jest harness | `8bff956` | 03-08 backend setup | `a33ff9e` |
| 03-02 quota const | `70c340d` | 03-09 firestore rules | `4bd4d5c` |
| 03-03 vertex client | `5d6d5c9` | 03-10 uuid + quota dart | `3427c8d` |
| 03-04 model checkpoint | `a595222`,`b06b6c9` | 03-11 MentorBotRepository | `0282c16` |
| 03-05 rate-limit txn | `fa8229a` | 03-12 chat viewmodel swap | `93045cb`,`ca52d1f` |
| 03-06 mentorBotChat | `0f458fb` | 03-13 smoke test | `d7eadc1` |
| 03-07 usage log | `402fdec` | 03-14 CI npm test | `2318e91` |

## Task 2 — 03-VALIDATION.md

Frontmatter flipped: `status: closed`, `nyquist_compliant: true`,
`wave_0_complete: true`, `closed: 2026-05-20`. Per-Plan Verification Map: 15 rows
✅, 1 row (03-13) ⏸ "live emulator run deferred to local dev" (the test file
exists + analyzes clean; the live run needs emulator + iOS simulator). Wave 0 +
Validation Sign-Off checkboxes all `[x]`. Approval: `closed by Plan 03-15 on 2026-05-20`.

## Task 3 — ROADMAP.md

Phase 3 bullet `- [x]` + `(completed 2026-05-20)`; detail `**Plans**: 15 plans
(03-01 through 03-15)`; progress table row `15/15 | Complete | 2026-05-20`.

## Task 4 — REQUIREMENTS.md

AI-01..AI-10 checklist boxes → `[x]`; traceability rows → `Complete`.

Note on **AI-01**: the requirement text says "reads `GEMINI_API_KEY` from Google
Secret Manager." The implementation went further — **Vertex AI + ADC, no API key
at all** (D-02). There is no key to store, so Secret Manager is moot. The
requirement's intent (all Gemini calls proxied server-side, zero client-side
key) is fully satisfied; the no-key approach is strictly stronger.

## Task 5 — HUMAN CHECKPOINT: leaked key rotation (D-22 / AI-02)

User response: **`a` — Yes, the leaked Google AI Studio key was revoked.**
AI-02 closed as Complete.

## Task 6 — HUMAN CHECKPOINT: model resolution (D-01 / Q-1)

Resolved: **`b` — `gemini-2.5-pro`** (plan 03-03 default holds). Verified live via
authenticated Vertex `generateContent` (HTTP 200, `modelVersion: gemini-2.5-pro`).
`gemini-3.1-pro` → 404 (not a GA model); `gemini-1.5-pro` retired.
BACKEND_SETUP.md §Phase 3 §7 updated with the resolved model + the
`us-central1` region correction.

## Task 7 — STATE.md

Advanced to Phase 4: `completed_phases: 3`, `completed_plans: 37`, `percent: 43`,
`Phase: 4`, `Status: Ready to discuss`. Phase 3 decision appended to Accumulated
Context. Billing + budget blockers moved to a Resolved section. Phase 3 manual
follow-ups recorded.

## Task 8 — Production deploy

Deployed to `mentor-mind-aa765` on 2026-05-20:

- **`firebase deploy --only firestore:rules`** — ✓ rules released to `cloud.firestore`
  (locks `/users/{uid}/usage/{date}` admin-write + `/system/**` server-only).
- **`firebase deploy --only functions --force`** — ✓ `ping` + `mentorBotChat`
  both **ACTIVE / GEN_2** in `asia-south1`. Artifact Registry cleanup policy
  auto-configured on repo `gcf-artifacts`.

Deploy snags resolved during closeout:
1. `MONTHLY_CALL_CEILING` param had no value in non-interactive deploy → created
   `functions/.env` with `MONTHLY_CALL_CEILING=10000` (non-secret, committed).
2. Cloud Build failed "missing permission on the build service account" →
   granted `roles/cloudbuild.builds.builder` **and** `roles/aiplatform.user` to
   the compute SA `722452556351-compute@developer.gserviceaccount.com`
   (the latter is the function runtime SA — needed for live Vertex calls).

Console: https://console.firebase.google.com/project/mentor-mind-aa765/overview

## Cross-doc consistency

All 5 checks PASS: ROADMAP `15/15 Complete`, ROADMAP Phase 3 `[x]`, STATE
`Phase: 4`, VALIDATION `nyquist_compliant: true`, REQUIREMENTS no `Phase 3 Pending`.

## Open follow-ups (non-blocking — carry to Phase 4 discuss)

- ⏸ **03-13 smoke test** — live emulator run not yet executed (test file ready).
- **Functions runtime SA** — `roles/aiplatform.user` was granted to the compute
  SA during this closeout; the live `mentorBotChat` Vertex path is now unblocked
  but has not had an end-to-end production smoke (`flutter run` → real chat).
- **Local ADC stale** — `verify-model-availability.js` via ADC fails; refresh
  with `gcloud auth application-default login`.
- **Node 20 deprecation** — Cloud Functions runtime Node 20 is deprecated
  (decommission 2026-10-30); `firebase-functions` is also flagged outdated.
  Schedule a runtime/SDK bump before Phase 6.
- **Artifact Registry** — `--force` set a time-based (1-day) cleanup policy on
  `gcf-artifacts`; BACKEND_SETUP.md §3 originally specified keep-last-3. Retune
  if the count-based policy is preferred.

## kluster.ai

⚠️ Your kluster.ai trial has ended. You can visit https://platform.kluster.ai/ to select a plan, subscribe, and re-enable protection.

## Phase 3 — final state

15/15 plans complete. functions: 45 jest tests green (38 unit + 7 rules).
Flutter: 47 tests green. `ping` + `mentorBotChat` live in `asia-south1`;
`firestore.rules` lockdown deployed. In-binary `GEMINI_API_KEY` removed,
`google_generative_ai` dropped, leaked key revoked. Next: `/gsd-discuss-phase 4`.
