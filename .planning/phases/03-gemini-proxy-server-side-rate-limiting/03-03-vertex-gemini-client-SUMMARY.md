---
phase: 03-gemini-proxy-server-side-rate-limiting
plan: "03"
subsystem: functions/gemini-client
tags: [vertex_ai_sdk, gemini_client_interface, fake_gemini_client, system_prompt_versioned, model_config, no_streaming, tdd]
dependency_graph:
  requires: ["03-01"]
  provides: ["makeGeminiClient", "GeminiClient", "VertexGeminiClient", "MODEL_CONFIG", "SYSTEM_PROMPT", "SYSTEM_PROMPT_VERSION"]
  affects: ["03-04", "03-06", "03-12"]
tech_stack:
  added: ["@google-cloud/vertexai@1.12.0"]
  patterns: ["GeminiClient interface seam (D-21)", "FakeGeminiClient for tests", "makeGeminiClient factory", "ADC-only auth (no API key)"]
key_files:
  created:
    - functions/src/__tests__/gemini.test.ts
  modified:
    - functions/src/lib/gemini.ts
    - functions/package.json
    - functions/package-lock.json
    - functions/tsconfig.json
decisions:
  - "Use inlineData (camelCase) not inline_data (snake_case) — @google-cloud/vertexai v1.12 TypeScript types use camelCase (SDK-level naming, not REST wire format)"
  - "Added skipLibCheck: true to tsconfig.json — @google-cloud/vertexai 1.12 depends on @google/genai which uses subpath imports requiring node16/nodenext moduleResolution; skipLibCheck is the standard workaround for module resolution mismatches in lib declarations"
  - "MODEL_CONFIG.modelId pinned to 'gemini-2.5-pro' (conservative fallback per RESEARCH Q-1); plan 03-04 may rewrite to 'gemini-3.1-pro' after live verification"
  - "VertexAI constructor placed inside generate() method body (lazy init) so makeGeminiClient('prod') is safe to instantiate in unit tests without ADC"
metrics:
  duration: "4 minutes"
  completed: "2026-05-19"
  tasks_completed: 1
  tasks_total: 1
  files_changed: 5
---

# Phase 03 Plan 03: Vertex Gemini Client Summary

**One-liner:** Replaced Phase 2 gemini.ts stub with Vertex AI client using ADC (no API key), GeminiClient interface seam, FakeGeminiClient, makeGeminiClient factory, versioned SYSTEM_PROMPT, and MODEL_CONFIG — all 8 unit tests green, build and lint clean.

## What Was Built

### functions/src/lib/gemini.ts (full replacement of Phase 2 stub)

Exports:
- `GeminiClient` interface — testable seam (D-21); `generate(opts)` returning `{ text, promptTokens, completionTokens }`
- `VertexGeminiClient` class — production impl wrapping `@google-cloud/vertexai`; uses ADC auth, asia-south1 region, no API key
- `makeGeminiClient(mode: 'prod' | 'fake')` factory — mode selection via `GEMINI_CLIENT_MODE` env var; defaults prod in handler
- `SYSTEM_PROMPT` const — verbatim copy of `_kSystemPrompt` from `lib/core/services/gemini_service.dart` lines 16-31 (Cambridge/Edexcel tone, MentorBot persona)
- `SYSTEM_PROMPT_VERSION = '1'` — plan 03-06 stamps onto each message doc as `promptVersion`
- `MODEL_CONFIG` — `{ modelId: 'gemini-2.5-pro', timeoutSeconds: 60, memory: '512MiB', maxOutputTokens: 1024, temperature: 0.7, topP: 0.95, topK: 40 }` (all 7 D-14 keys)
- `ModelConfig` type

Security/correctness features:
- `systemInstruction` field used for SYSTEM_PROMPT (separate channel from user content — T-3-PROMPT-INJECTION mitigation)
- Safety settings `BLOCK_MEDIUM_AND_ABOVE` on `HARM_CATEGORY_HATE_SPEECH` + `HARM_CATEGORY_DANGEROUS_CONTENT`
- Image path uses `inlineData` (base64) not `fileData` gs:// URI (Pitfall P-4 avoided)
- VertexAI constructor inside `generate()` body (lazy init — safe for unit test instantiation)

### functions/src/__tests__/gemini.test.ts (new)

8 tests across 3 describe blocks:
- `gemini module exports` (4 tests): SYSTEM_PROMPT_VERSION, SYSTEM_PROMPT fidelity, MODEL_CONFIG values, modelId type
- `FakeGeminiClient via makeGeminiClient("fake")` (2 tests): canned response shape, image option ignored
- `makeGeminiClient factory` (2 tests): fake resolves without network, prod returns VertexGeminiClient instance

### functions/tsconfig.json (modified)

Added `"skipLibCheck": true` — required for `@google-cloud/vertexai` 1.12 compatibility (see Deviations).

## Test Results

```
PASS src/__tests__/gemini.test.ts
  gemini module exports
    ✓ exports SYSTEM_PROMPT_VERSION as a string
    ✓ SYSTEM_PROMPT mentions MentorBot + O-Level + A-Level (Cambridge/Edexcel tone preserved)
    ✓ MODEL_CONFIG has the D-14 runtime config values
    ✓ MODEL_CONFIG.modelId is a non-empty string (plan 03-04 pins the verified value)
  FakeGeminiClient (via makeGeminiClient("fake"))
    ✓ generate returns the canned response shape
    ✓ generate ignores the image option (canned response unchanged)
  makeGeminiClient factory
    ✓ mode='fake' returns a client whose generate resolves immediately (no network)
    ✓ mode='prod' returns a VertexGeminiClient instance (constructor only — does not call Vertex)

Test Suites: 1 passed, 1 total
Tests:       8 passed, 8 total
```

Full suite: 15/15 passed (8 gemini + 7 quota).

## Package Resolution

- `@google-cloud/vertexai`: requested `^1.12.0`, resolved `1.12.0`
- Location in package-lock.json: `"@google-cloud/vertexai": "^1.12.0"` in dependencies

## Verification Gates

| Gate | Result |
|------|--------|
| `npm test -- --testPathPattern=gemini` | 8/8 PASS |
| `npm run build` | exit 0 |
| `npm run lint` | exit 0 |
| AI-10 anti-streaming grep (code only, excl. comments) | PASS — no `generateContentStream` in code |
| System prompt fidelity: "You are MentorBot, the AI tutor inside MentorMinds" | FOUND |
| System prompt fidelity: "O-Level and A-Level students in Bangladesh" | FOUND |
| System prompt fidelity: "[Subject: X, Level: Y]" | FOUND |
| `node -e "require('@google-cloud/vertexai')"` | exit 0 |

## AI-10 Anti-Streaming Grep Output

```
# grep excluding comments:
grep -vE '^\s*//' functions/src/lib/gemini.ts | grep -E 'generateContentStream|async\*|await for'
# No output — PASSED
```

Note: A comment line in the file contains `generateContentStream` as documentation that it is NOT used. The grep gate (excluding comments) confirms zero actual streaming calls in implementation code.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed `inline_data` (snake_case) to `inlineData` (camelCase) for SDK type compatibility**

- **Found during:** TDD GREEN phase — first build attempt
- **Issue:** The plan's `<interfaces>` block specified `{ inline_data: { mimeType, data } }` for image parts, matching the REST API wire format. However, `@google-cloud/vertexai` v1.12.0 TypeScript types define `InlineDataPart` with `inlineData` (camelCase), causing a `TS2322` type error when building the `parts` array.
- **Fix:** Changed the parts array type annotation from `Array<{ text: string } | { inline_data: ... }>` to `Part[]` (importing `Part` from the SDK), and used `inlineData` (camelCase) instead of `inline_data`.
- **Files modified:** `functions/src/lib/gemini.ts`
- **Why not Rule 4:** This is a naming convention difference in the SDK TypeScript types, not an architectural change. The underlying behavior is identical — same JSON is sent to the Vertex API.

**2. [Rule 1 - Bug] Added `skipLibCheck: true` to tsconfig.json for @google-cloud/vertexai 1.12 compatibility**

- **Found during:** TDD GREEN phase — first build attempt
- **Issue:** `@google-cloud/vertexai` 1.12.0 depends on `@google/genai` which uses ESM subpath imports (`@google/genai/vertex_internal`) incompatible with the functions project's `"module": "commonjs"` + default `moduleResolution: node` setting. This caused 9 `TS2307` errors from lib declarations in `node_modules`.
- **Fix:** Added `"skipLibCheck": true` to `functions/tsconfig.json`. This is the standard Firebase Functions solution for this class of third-party library type declaration incompatibility. It does NOT reduce our own code type safety — only skips checking `.d.ts` files in `node_modules`.
- **Files modified:** `functions/tsconfig.json`
- **Impact:** Zero reduction in source code type safety; only affects type-checking of node_modules declarations.

## No Live Vertex Calls

Per the parallel execution rule and project billing status (GCP billing DISABLED on mentor-mind-aa765), no live Vertex API calls were made. The plan's fake client path was used exclusively for all tests. The `mode='prod'` test instantiates `VertexGeminiClient` but does not call `generate()` — no network activity.

## Known Stubs

None in the files created/modified by this plan. The `makeGeminiClient('prod')` returns a real `VertexGeminiClient` whose `generate()` method will call Vertex AI in production — that is the intended behavior, not a stub.

## Threat Surface Scan

No new trust boundaries introduced beyond those documented in the plan's `<threat_model>`. The `GeminiClient` interface was added as designed. The `VertexGeminiClient` requires `GCLOUD_PROJECT` env var (validated at `generate()` call time with a clear error message).

## Forward Pointers

- **Plan 03-04** (checkpoint:human-verify): Run `functions/tool/verify-model-availability.js` to confirm `MODEL_CONFIG.modelId = 'gemini-2.5-pro'` resolves in asia-south1. If not, update to a GA model before PR-1 merges.
- **Plan 03-06** (callable handler): Import `makeGeminiClient`, `MODEL_CONFIG`, `SYSTEM_PROMPT_VERSION` from `./lib/gemini`. Wire: `const client = makeGeminiClient(process.env['GEMINI_CLIENT_MODE'] === 'fake' ? 'fake' : 'prod');`
- **Plan 03-12** (cleanup): Delete `lib/core/services/gemini_service.dart` — SYSTEM_PROMPT is now preserved verbatim in `functions/src/lib/gemini.ts`.

## Commit

- `5d6d5c9`: feat(functions): replace gemini.ts stub with Vertex AI client + GeminiClient seam + fake (Phase 3 PR-1; AI-01/AI-09/AI-10; D-01/D-02/D-03/D-04/D-14/D-21)

## kluster.ai Review

⚠️ Your kluster.ai trial has ended. You can visit https://platform.kluster.ai/ to select a plan, subscribe, and re-enable protection.

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| `functions/src/__tests__/gemini.test.ts` exists | FOUND |
| `functions/src/lib/gemini.ts` exists | FOUND |
| `03-03-vertex-gemini-client-SUMMARY.md` exists | FOUND |
| Commit `5d6d5c9` exists in git log | FOUND |
| `npm test -- --testPathPattern=gemini`: 8/8 tests pass | PASSED |
