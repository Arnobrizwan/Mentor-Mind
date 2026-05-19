---
phase: 03-gemini-proxy-server-side-rate-limiting
plan: 03
type: execute
wave: 2
depends_on: ["03-01"]
files_modified:
  - functions/package.json
  - functions/package-lock.json
  - functions/src/lib/gemini.ts
  - functions/src/__tests__/gemini.test.ts
autonomous: true
requirements: [AI-01, AI-09, AI-10]
pr_group: PR-1
tags: [vertex_ai_sdk, gemini_client_interface, fake_gemini_client, system_prompt_versioned, model_config, no_streaming]

must_haves:
  truths:
    - "D-01 honored: a model ID is pinned in `MODEL_CONFIG.modelId`; plan 03-04 verifies it resolves against live Vertex API before PR-1 merges (`gemini-3.1-pro` preferred; fallback to `gemini-2.5-pro` then `gemini-1.5-pro`)"
    - "D-02 honored: `@google-cloud/vertexai ^1.12.0` is the SDK; ADC auth; no API key anywhere; location pinned to `asia-south1` matching the Functions region (no cross-region hop)"
    - "D-03 honored: `SYSTEM_PROMPT` is a hardcoded TS const in `gemini.ts` — updatable without app release (just `firebase deploy --only functions:mentorBotChat`)"
    - "D-04 honored: `SYSTEM_PROMPT_VERSION = '1'` is exported; plan 03-06 stamps it onto each message doc as `promptVersion: '1'`"
    - "D-09 (AI-09) full text: SYSTEM_PROMPT copied verbatim from `lib/core/services/gemini_service.dart` lines 16-31 (`_kSystemPrompt`) BEFORE plan 03-12 deletes that file — the Cambridge/Edexcel marking-scheme tone is preserved exactly"
    - "D-14 honored: `MODEL_CONFIG` exports `{ modelId, timeoutSeconds: 60, memory: '512MiB', maxOutputTokens: 1024, temperature: 0.7, topP: 0.95, topK: 40 }`"
    - "D-21 honored: `GeminiClient` interface + `VertexGeminiClient` prod impl + inline `FakeGeminiClient` + `makeGeminiClient(mode)` factory; mode selected via `process.env.GEMINI_CLIENT_MODE` (fake/prod, default prod)"
    - "AI-10 honored: implementation uses `generateContent` ONLY, never `generateContentStream`; static grep gate asserts zero hits for the streaming method anywhere in `functions/src/lib/gemini.ts`"
    - "T-3-PROMPT-INJECTION mitigated: system prompt sent via Vertex SDK's `systemInstruction` field (separate from user content) — the SDK enforces separation; safety settings BLOCK_MEDIUM_AND_ABOVE on HARM_CATEGORY_HATE_SPEECH + HARM_CATEGORY_DANGEROUS_CONTENT"
    - "Image flow per D-05 + Pattern 4: `image?: { buffer: Buffer; mimeType: string }` passed via `inline_data` (base64) — NOT `fileData` gs:// URI (Pitfall P-4 — Vertex SA needs cross-IAM grant for fileData)"
    - "Package legitimacy: `@google-cloud/vertexai ^1.12.0` Approved per RESEARCH §Package Legitimacy Audit (official Google org, no postinstall, manual npm verification)"
  artifacts:
    - path: "functions/src/lib/gemini.ts"
      provides: "GeminiClient interface + VertexGeminiClient class + makeGeminiClient factory + SYSTEM_PROMPT + SYSTEM_PROMPT_VERSION + MODEL_CONFIG exports"
      contains: "GeminiClient"
    - path: "functions/src/__tests__/gemini.test.ts"
      provides: "Unit tests for the FakeGeminiClient (canned response) + makeGeminiClient factory selection"
      contains: "makeGeminiClient"
    - path: "functions/package.json"
      provides: "Adds @google-cloud/vertexai ^1.12.0 dep"
      contains: "@google-cloud/vertexai"
  key_links:
    - from: "functions/src/lib/gemini.ts"
      to: "functions/src/index.ts (plan 03-06 mentorBotChat handler)"
      via: "handler imports `makeGeminiClient`, `MODEL_CONFIG`, `SYSTEM_PROMPT_VERSION`"
      pattern: "makeGeminiClient|MODEL_CONFIG"
    - from: "functions/src/lib/gemini.ts SYSTEM_PROMPT"
      to: "lib/core/services/gemini_service.dart lines 16-31 (_kSystemPrompt)"
      via: "verbatim text copy BEFORE plan 03-12 deletes the Dart source"
      pattern: "MentorBot, the AI tutor"
---

<objective>
Replace the Phase 2 stub at `functions/src/lib/gemini.ts` with the real Vertex AI client. Add `@google-cloud/vertexai ^1.12.0` to dependencies. Export: `GeminiClient` interface, `ModelConfig` type, `VertexGeminiClient` class, `FakeGeminiClient` inline object, `makeGeminiClient(mode)` factory, `SYSTEM_PROMPT` const (verbatim copy of the Cambridge/Edexcel tone string from `lib/core/services/gemini_service.dart` lines 16-31), `SYSTEM_PROMPT_VERSION = '1'`, `MODEL_CONFIG`. Add `functions/src/__tests__/gemini.test.ts` covering the fake client and the factory.

Purpose: AI-01 + AI-09 + AI-10 together require a Vertex-backed callable with a server-resident system prompt, non-streaming responses, and a testable seam for unit tests (no real Vertex calls in CI — D-21). The `GeminiClient` interface is that seam: production wraps `@google-cloud/vertexai`; tests use the inline fake. Plan 03-04 verifies the pinned `MODEL_CONFIG.modelId` actually resolves before PR-1 merges. Plan 03-06 (callable handler) calls `client.generate(...)` AFTER the rate-limit transaction commits.

Output: 4 files (`gemini.ts` filled; `gemini.test.ts` new; `package.json` + `package-lock.json` updated). Single commit. `npm test -- --testPathPattern=gemini` green, `npm run build` green.
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
@lib/core/services/gemini_service.dart
@functions/src/lib/gemini.ts
@functions/tsconfig.json
@CLAUDE.md

<interfaces>
<!-- Patterns from 03-PATTERNS.md §functions/src/lib/gemini.ts lines 84-159 + 03-RESEARCH §Pattern 1 lines 296-344 + §Pattern 2 lines 348-372 + §Code Examples lines 706-714 -->

functions/src/lib/gemini.ts (REPLACE the existing stub — full file):

```typescript
// Phase 3 — Vertex AI Gemini client (replaces the Phase 2 stub).
//
// D-01: Model ID pinned in MODEL_CONFIG.modelId. Plan 03-04 verifies it resolves
//       against live Vertex API in asia-south1 BEFORE PR-1 merges. Fallback
//       chain documented in 03-RESEARCH Open Question Q-1.
// D-02: Vertex AI via @google-cloud/vertexai + ADC. No API key. Location is
//       'asia-south1' matching the Functions region — no cross-region hop.
// D-03: SYSTEM_PROMPT lives as a hardcoded TS const (AI-09 — updatable via
//       `firebase deploy --only functions:mentorBotChat`, no app release).
// D-04: SYSTEM_PROMPT_VERSION stamped onto each message doc by the handler.
// D-21: GeminiClient interface + FakeGeminiClient + makeGeminiClient factory.
//       Selected via GEMINI_CLIENT_MODE env var (fake | prod).
// AI-10: generateContent only — no generateContentStream (non-streaming v1.0).

import {
  VertexAI,
  HarmCategory,
  HarmBlockThreshold,
} from '@google-cloud/vertexai';

// ---------------------------------------------------------------------------
// Versioned prompt — copy of lib/core/services/gemini_service.dart _kSystemPrompt
// (lines 16-31). Stays verbatim so plan 03-12 can delete the Dart file without
// drift. Bump SYSTEM_PROMPT_VERSION whenever this text changes.
// ---------------------------------------------------------------------------

export const SYSTEM_PROMPT_VERSION = '1';

export const SYSTEM_PROMPT = `You are MentorBot, the AI tutor inside MentorMinds — a study app for O-Level and A-Level students in Bangladesh.

How you teach:
- Explain concepts clearly using simple language, short paragraphs, and worked examples.
- Match difficulty to the student's selected level (O-Level or A-Level).
- Use markdown: **bold** for key terms, bullet points for lists, inline \`code\` for formulas, and triple-backtick code fences for worked solutions or step-by-step algorithms.
- When relevant, briefly cite the syllabus topic so the student can locate it in their book.
- Prefer Socratic guidance when the student is close to the answer; give the full solution when they're stuck.
- Keep answers focused. Break long answers into sections with short headings.
- Stay on-topic for the student's selected subject; gently redirect off-topic questions.
- Never invent exam results or fabricate facts — if you're unsure, say so.
- Use Bangladeshi examples (taka, local place names) only when it genuinely helps; don't force it.

You will receive messages prefixed with \`[Subject: X, Level: Y]\` as context. Use that to calibrate tone and depth.
`;

// ---------------------------------------------------------------------------
// Model + generation config (D-14)
// ---------------------------------------------------------------------------

export const MODEL_CONFIG = {
  modelId: 'gemini-2.5-pro', // ← Plan 03-04 may update to gemini-3.1-pro after live verification.
  timeoutSeconds: 60,
  memory: '512MiB' as const,
  maxOutputTokens: 1024,
  temperature: 0.7,
  topP: 0.95,
  topK: 40,
} as const;

export type ModelConfig = typeof MODEL_CONFIG;

// ---------------------------------------------------------------------------
// GeminiClient interface — testable seam (D-21)
// ---------------------------------------------------------------------------

export interface GeminiClient {
  generate(opts: {
    prompt: string;
    image?: { buffer: Buffer; mimeType: string };
    modelConfig: ModelConfig;
  }): Promise<{ text: string; promptTokens: number; completionTokens: number }>;
}

// ---------------------------------------------------------------------------
// VertexGeminiClient — production impl wrapping @google-cloud/vertexai
// ---------------------------------------------------------------------------

export class VertexGeminiClient implements GeminiClient {
  async generate(opts: {
    prompt: string;
    image?: { buffer: Buffer; mimeType: string };
    modelConfig: ModelConfig;
  }): Promise<{ text: string; promptTokens: number; completionTokens: number }> {
    const project = process.env['GCLOUD_PROJECT'];
    if (!project) {
      throw new Error('GCLOUD_PROJECT env var not set (expected from Cloud Functions v2 runtime)');
    }

    const vertexAI = new VertexAI({ project, location: 'asia-south1' });
    const model = vertexAI.getGenerativeModel({
      model: opts.modelConfig.modelId,
      generationConfig: {
        temperature: opts.modelConfig.temperature,
        topP: opts.modelConfig.topP,
        topK: opts.modelConfig.topK,
        maxOutputTokens: opts.modelConfig.maxOutputTokens,
      },
      safetySettings: [
        {
          category: HarmCategory.HARM_CATEGORY_HATE_SPEECH,
          threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
        },
        {
          category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT,
          threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
        },
      ],
      systemInstruction: {
        role: 'system',
        parts: [{ text: SYSTEM_PROMPT }],
      },
    });

    // Build the user content parts. Image (if present) is sent as inline base64
    // — NOT fileData gs:// URI (Pitfall P-4 — would require Vertex SA cross-IAM grant).
    const parts: Array<
      | { text: string }
      | { inline_data: { mimeType: string; data: string } }
    > = [{ text: opts.prompt }];
    if (opts.image) {
      parts.push({
        inline_data: {
          mimeType: opts.image.mimeType,
          data: opts.image.buffer.toString('base64'),
        },
      });
    }

    const result = await model.generateContent({
      contents: [{ role: 'user', parts }],
    });

    const text =
      result.response.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
    const promptTokens =
      result.response.usageMetadata?.promptTokenCount ?? 0;
    const completionTokens =
      result.response.usageMetadata?.candidatesTokenCount ?? 0;
    return { text, promptTokens, completionTokens };
  }
}

// ---------------------------------------------------------------------------
// FakeGeminiClient — inline canned-response impl for unit + integration tests
// ---------------------------------------------------------------------------

const fakeGeminiClient: GeminiClient = {
  generate: async (_opts) => ({
    text: 'Fake MentorBot response for testing.',
    promptTokens: 10,
    completionTokens: 20,
  }),
};

// ---------------------------------------------------------------------------
// Factory — selected via GEMINI_CLIENT_MODE env var (fake | prod)
// ---------------------------------------------------------------------------

export function makeGeminiClient(mode: 'prod' | 'fake'): GeminiClient {
  if (mode === 'fake') return fakeGeminiClient;
  return new VertexGeminiClient();
}
```

functions/src/__tests__/gemini.test.ts (NEW — full file):

```typescript
import { makeGeminiClient, MODEL_CONFIG, SYSTEM_PROMPT, SYSTEM_PROMPT_VERSION } from '../lib/gemini';

describe('gemini module exports', () => {
  it('exports SYSTEM_PROMPT_VERSION as a string', () => {
    expect(SYSTEM_PROMPT_VERSION).toBe('1');
  });

  it('SYSTEM_PROMPT mentions MentorBot + O-Level + A-Level (Cambridge/Edexcel tone preserved)', () => {
    expect(SYSTEM_PROMPT).toContain('MentorBot');
    expect(SYSTEM_PROMPT).toContain('O-Level');
    expect(SYSTEM_PROMPT).toContain('A-Level');
    expect(SYSTEM_PROMPT).toContain('[Subject: X, Level: Y]');
  });

  it('MODEL_CONFIG has the D-14 runtime config values', () => {
    expect(MODEL_CONFIG.timeoutSeconds).toBe(60);
    expect(MODEL_CONFIG.memory).toBe('512MiB');
    expect(MODEL_CONFIG.maxOutputTokens).toBe(1024);
    expect(MODEL_CONFIG.temperature).toBe(0.7);
    expect(MODEL_CONFIG.topP).toBe(0.95);
    expect(MODEL_CONFIG.topK).toBe(40);
  });

  it('MODEL_CONFIG.modelId is a non-empty string (plan 03-04 pins the verified value)', () => {
    expect(typeof MODEL_CONFIG.modelId).toBe('string');
    expect(MODEL_CONFIG.modelId.length).toBeGreaterThan(0);
  });
});

describe('FakeGeminiClient (via makeGeminiClient("fake"))', () => {
  const client = makeGeminiClient('fake');

  it('generate returns the canned response shape', async () => {
    const result = await client.generate({
      prompt: 'Hello',
      modelConfig: MODEL_CONFIG,
    });
    expect(result.text).toBe('Fake MentorBot response for testing.');
    expect(result.promptTokens).toBe(10);
    expect(result.completionTokens).toBe(20);
  });

  it('generate ignores the image option (canned response unchanged)', async () => {
    const result = await client.generate({
      prompt: 'Describe this image',
      image: { buffer: Buffer.from('fake-image-bytes'), mimeType: 'image/jpeg' },
      modelConfig: MODEL_CONFIG,
    });
    expect(result.text).toBe('Fake MentorBot response for testing.');
  });
});

describe('makeGeminiClient factory', () => {
  it("mode='fake' returns a client whose generate resolves immediately (no network)", async () => {
    const client = makeGeminiClient('fake');
    await expect(
      client.generate({ prompt: 'test', modelConfig: MODEL_CONFIG }),
    ).resolves.toHaveProperty('text');
  });

  it("mode='prod' returns a VertexGeminiClient instance (constructor only — does not call Vertex)", () => {
    // VertexGeminiClient construction is side-effect-free; no Vertex call until
    // generate() is invoked. We can safely instantiate in unit tests.
    const client = makeGeminiClient('prod');
    expect(client).toBeDefined();
    expect(typeof client.generate).toBe('function');
  });
});
```

Why we do NOT call `jest.mock('@google-cloud/vertexai')`:
  - The fake-client path is what unit tests use. Production VertexGeminiClient is constructed but not invoked in tests (its constructor is side-effect-free — it only stashes config).
  - If we wanted to assert that `VertexGeminiClient.generate` correctly calls `model.generateContent`, that's an integration concern handled by plan 03-04's live verification script + plan 03-13's emulator smoke test (with `GEMINI_CLIENT_MODE=fake`).
  - Mocking `@google-cloud/vertexai` per-test would add complexity for marginal coverage. D-21 intentionally favors the fake-client seam over deep SDK mocking.

Package install (Step B in Task 1):
  - `cd functions && npm install @google-cloud/vertexai@^1.12.0` adds the dep to `dependencies` (NOT devDeps — it's runtime code).
  - Regenerates package-lock.json. Commit both.
  - RESEARCH §Package Legitimacy Audit confirms the package is Approved (official Google org, no postinstall scripts).

Why VertexAI constructor is in `generate()` not the class constructor:
  - Lazy init: the VertexAI client may attempt ADC validation at construction time; we defer until a real call happens.
  - Allows `makeGeminiClient('prod')` to be instantiated in unit tests without firing a Vertex round-trip.

Why the `inline_data` parts shape (not `inlineData`):
  - The @google-cloud/vertexai SDK 1.12 uses snake_case `inline_data` for the parts shape (matches the Vertex REST API protobuf wire format). This is documented at googleapis.dev/nodejs/vertexai.
  - RESEARCH §Code Examples Pattern 1 confirms this is the verified shape.

What this plan does NOT do:
  - Does NOT call the real Vertex API in CI (the fake client path keeps CI free of network deps).
  - Does NOT add a `secrets: []` option to the callable in plan 03-06 — Vertex uses ADC, not Secret Manager.
  - Does NOT verify `MODEL_CONFIG.modelId` resolves against the live Vertex API — that's plan 03-04 (checkpoint).
  - Does NOT modify functions/src/index.ts (the callable export is plan 03-06).
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Install @google-cloud/vertexai ^1.12.0; replace functions/src/lib/gemini.ts stub with the full Vertex client + interface + fake + factory; add unit tests; verify build + lint + test green</name>
  <files>functions/package.json, functions/package-lock.json, functions/src/lib/gemini.ts, functions/src/__tests__/gemini.test.ts</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/lib/core/services/gemini_service.dart (lines 16-31 — the _kSystemPrompt text to copy verbatim into the TS SYSTEM_PROMPT const; CRITICAL — copy BEFORE plan 03-12 deletes this file)
    - /Users/arnobrizwan/Mentor-Mind/functions/src/lib/gemini.ts (CURRENT stub — confirm Phase 2 placeholder shape; delete entirely)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-RESEARCH.md (§Pattern 1 lines 296-344 — Vertex SDK getGenerativeModel + generateContent shape; §Pattern 2 lines 348-372 — GeminiClient interface + factory; §Code Examples lines 706-744; §Pitfall P-1 — model availability; §Pitfall P-4 — inline_data not fileData)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-PATTERNS.md (§functions/src/lib/gemini.ts lines 84-159 — FILL substitution rule)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-CONTEXT.md (D-01, D-02, D-03, D-04, D-14, D-21; §Specifics Mock GeminiClient interface shape)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md (row `03-03-vertex-gemini-client` line 56 — Automated Command verbatim)
    - /Users/arnobrizwan/Mentor-Mind/functions/package.json (Phase 2 baseline — confirm `firebase-admin ^13.10.0` + `firebase-functions ^6.6.0` are present)
  </read_first>
  <behavior>
    - `import { makeGeminiClient, MODEL_CONFIG, SYSTEM_PROMPT, SYSTEM_PROMPT_VERSION } from '../lib/gemini'` resolves at TS compile.
    - `SYSTEM_PROMPT_VERSION === '1'`.
    - `SYSTEM_PROMPT` contains the literal substrings `MentorBot`, `O-Level`, `A-Level`, `[Subject: X, Level: Y]` (Cambridge/Edexcel tone preserved verbatim from gemini_service.dart).
    - `MODEL_CONFIG.timeoutSeconds === 60`, `MODEL_CONFIG.memory === '512MiB'`, `MODEL_CONFIG.maxOutputTokens === 1024`, `MODEL_CONFIG.temperature === 0.7`, `MODEL_CONFIG.topP === 0.95`, `MODEL_CONFIG.topK === 40`.
    - `MODEL_CONFIG.modelId` is a non-empty string (plan 03-04 may overwrite it).
    - `makeGeminiClient('fake').generate({ prompt, modelConfig })` resolves to `{ text: 'Fake MentorBot response for testing.', promptTokens: 10, completionTokens: 20 }`.
    - `makeGeminiClient('prod')` returns a `VertexGeminiClient` instance (constructor only — no Vertex network call).
    - `node -e "require('@google-cloud/vertexai')"` exits 0 (package installed).
    - Static grep gate: ZERO hits for `generateContentStream` OR `async\*` OR `await for` anywhere in `functions/src/lib/gemini.ts`.
  </behavior>
  <action>
    Step A — Read lib/core/services/gemini_service.dart lines 16-31 to extract `_kSystemPrompt`. Capture the exact text (between the `'''` delimiters). This becomes the body of the TS `SYSTEM_PROMPT` const. Escape backticks (`\``) since the TS const uses a template literal.

    Step B — Install Vertex AI SDK:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind/functions
      nvm use 20
      npm install --save @google-cloud/vertexai@^1.12.0
      ```
      Confirm `package.json` `dependencies` block now contains `"@google-cloud/vertexai": "^1.12.0"` and `package-lock.json` records the resolved version (run `npm view @google-cloud/vertexai version` to confirm latest is in `1.12.x` range).
      Run `node -e "require('@google-cloud/vertexai')"` — exits 0.

    Step C — TDD RED: Create `functions/src/__tests__/gemini.test.ts` with the exact content from the `<interfaces>` block. Run `npm test -- --testPathPattern=gemini` — expect compile failures because the current `gemini.ts` is still the Phase 2 stub (missing `SYSTEM_PROMPT`, `SYSTEM_PROMPT_VERSION`, `MODEL_CONFIG`, `makeGeminiClient`, etc.).

    Step D — TDD GREEN: Replace `functions/src/lib/gemini.ts` ENTIRELY with the full content from the `<interfaces>` block. Specifically:
      - DELETE the Phase 2 stub (`callGemini`, `GeminiCallOptions`, `GeminiResponse` exports — these were placeholder names; nothing in the codebase calls them yet because the only consumer was Phase 3 planned work).
      - PASTE the new file content verbatim. Verify:
        - `SYSTEM_PROMPT` body matches `_kSystemPrompt` from gemini_service.dart character-for-character (modulo template-literal escaping of backticks for inline code spans like `\`code\`` and `\`\`\`code fences\`\`\``).
        - `MODEL_CONFIG.modelId` is `'gemini-2.5-pro'` (the conservative fallback per RESEARCH Q-1; plan 03-04 may rewrite it to `'gemini-3.1-pro'` if that resolves).
        - All imports use the named-export shape from `@google-cloud/vertexai`.

    Step E — Run unit tests:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind/functions
      npm test -- --testPathPattern=gemini 2>&1 | tee /tmp/p3-03-test.log
      # Expect: 8 tests passed (4 exports + 2 FakeGeminiClient + 2 factory)
      ```

    Step F — TS compile + lint:
      ```bash
      npm run build 2>&1 | tail -10  # tsc — exits 0
      npm run lint  2>&1 | tail -10  # eslint — exits 0
      ```
      Common fix-ups:
        - `Array<{ text: string } | { inline_data: ... }>` may need explicit type annotation on `parts` if ESLint's `@typescript-eslint/no-unsafe-assignment` fires.
        - The unused-vars rule may fire on `_opts` parameter; convention is `_` prefix to suppress.

    Step G — AI-10 static grep gate (anti-streaming):
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      ! grep -E 'generateContentStream|async\*|await for' functions/src/lib/gemini.ts
      # Must find nothing — Phase 3 ships non-streaming only.
      ```

    Step H — System prompt fidelity gate:
      ```bash
      # Compare key phrases preserved from gemini_service.dart _kSystemPrompt:
      grep -q "You are MentorBot, the AI tutor inside MentorMinds" functions/src/lib/gemini.ts
      grep -q "O-Level and A-Level students in Bangladesh" functions/src/lib/gemini.ts
      grep -q "\\[Subject: X, Level: Y\\]" functions/src/lib/gemini.ts
      # All three greps MUST find one or more hits.
      ```

    Step I — Commit:
      `git add functions/package.json functions/package-lock.json functions/src/lib/gemini.ts functions/src/__tests__/gemini.test.ts`
      Commit message: `feat(functions): replace gemini.ts stub with Vertex AI client + GeminiClient seam + fake (Phase 3 PR-1; AI-01/AI-09/AI-10; D-01/D-02/D-03/D-04/D-14/D-21)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && grep -q "@google-cloud/vertexai" functions/package.json && node -e "require('./functions/node_modules/@google-cloud/vertexai')"</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && test -f functions/src/lib/gemini.ts && test -f functions/src/__tests__/gemini.test.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && grep -q "export interface GeminiClient" functions/src/lib/gemini.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && grep -q "export const SYSTEM_PROMPT " functions/src/lib/gemini.ts && grep -q "export const SYSTEM_PROMPT_VERSION = '1'" functions/src/lib/gemini.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && grep -q "export const MODEL_CONFIG" functions/src/lib/gemini.ts && grep -q "export function makeGeminiClient" functions/src/lib/gemini.ts && grep -q "export class VertexGeminiClient" functions/src/lib/gemini.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && grep -q "location: 'asia-south1'" functions/src/lib/gemini.ts && grep -q "systemInstruction" functions/src/lib/gemini.ts && grep -q "inline_data" functions/src/lib/gemini.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && grep -q "HarmBlockThreshold" functions/src/lib/gemini.ts && grep -q "HARM_CATEGORY_HATE_SPEECH" functions/src/lib/gemini.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && ! grep -E 'generateContentStream|async\*' functions/src/lib/gemini.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind && grep -q "MentorBot" functions/src/lib/gemini.ts && grep -q "O-Level" functions/src/lib/gemini.ts && grep -q "A-Level" functions/src/lib/gemini.ts && grep -q "\\[Subject: X, Level: Y\\]" functions/src/lib/gemini.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions && npm test -- --testPathPattern=gemini 2>&1 | grep -qE 'Tests:\s+([8-9]|[1-9][0-9]+) passed'</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions && npm run build 2>&1 | tail -3; test $? -eq 0</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind/functions && npm run lint 2>&1 | tail -3; test $? -eq 0</automated>
  </verify>
  <acceptance_criteria>
    - `@google-cloud/vertexai ^1.12.0` in `functions/package.json` dependencies; `node -e "require('@google-cloud/vertexai')"` exits 0.
    - `functions/src/lib/gemini.ts` exports: GeminiClient (interface), VertexGeminiClient (class), makeGeminiClient (factory), SYSTEM_PROMPT (string), SYSTEM_PROMPT_VERSION ('1'), MODEL_CONFIG (object), ModelConfig (type).
    - `SYSTEM_PROMPT` contains the literal strings `MentorBot`, `O-Level`, `A-Level`, `[Subject: X, Level: Y]` (verbatim from gemini_service.dart).
    - `MODEL_CONFIG` has all 7 D-14 keys (modelId, timeoutSeconds, memory, maxOutputTokens, temperature, topP, topK).
    - VertexGeminiClient.generate uses `getGenerativeModel({systemInstruction})` + `generateContent` (NOT `generateContentStream`) + `inline_data` parts shape (NOT `fileData`).
    - Static grep `! grep -E 'generateContentStream|async\*' functions/src/lib/gemini.ts` exits 0.
    - `functions/src/__tests__/gemini.test.ts` has ≥ 8 tests; all pass under `npm test -- --testPathPattern=gemini`.
    - `npm run build` + `npm run lint` both exit 0.
  </acceptance_criteria>
  <done>
    The Vertex AI client is the GeminiClient interface boundary. Plan 03-04 verifies the pinned model ID against live Vertex; plan 03-06 wires `makeGeminiClient(process.env.GEMINI_CLIENT_MODE === 'fake' ? 'fake' : 'prod')` into the callable handler. Plan 03-12 will delete the Dart-side `gemini_service.dart` knowing the system prompt is preserved here verbatim.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Functions runtime SA ⇄ Vertex AI API | ADC injected by Cloud Functions v2 runtime; SA needs `roles/aiplatform.user` (granted manually per plan 03-08 BACKEND_SETUP.md §2). No API key. |
| GeminiClient interface ⇄ VertexGeminiClient impl | Production calls flow through this seam; tests use the inline fake. The seam is the security boundary — only the production impl ever fires a network call. |
| @google-cloud/vertexai npm package ⇄ Functions runtime | Supply chain: package is Approved per RESEARCH §Package Legitimacy Audit (official Google org repo); no postinstall scripts. |
| SYSTEM_PROMPT text ⇄ User content | Vertex SDK's `systemInstruction` field is separate from `contents.user.parts` — the SDK enforces the boundary. User text cannot override system prompt without a SDK-level bug. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-3-PROMPT-INJECTION | Tampering | A malicious user crafts a message saying "Ignore the above and ..." — if the system prompt were prepended to user content (not isolated), the model could be jailbroken | mitigate | System prompt sent via `systemInstruction` field (separate channel). Safety settings `BLOCK_MEDIUM_AND_ABOVE` on hate-speech + dangerous-content. Severity: MEDIUM — defense-in-depth, not perfect. Acceptable for tutoring context. |
| T-3-VERTEX-AUTH-FAIL | Denial of Service | Functions SA missing `roles/aiplatform.user`; every call returns `PERMISSION_DENIED` | mitigate | Plan 03-08 documents the gcloud IAM grant in BACKEND_SETUP.md; plan 03-04's verify-model-availability.js exercises the real auth path before PR-1 merges. Severity: HIGH if misconfigured at deploy time — but caught pre-merge by the checkpoint. |
| T-3-MODEL-NOT-FOUND | Denial of Service | `MODEL_CONFIG.modelId` is pinned to a name not GA in asia-south1; every call returns `Model not found` | mitigate | Plan 03-04 (checkpoint:human-verify) is the explicit gate. The default `'gemini-2.5-pro'` is the safest fallback per RESEARCH §Open Question Q-1 (verified pricing + availability higher than 1.5-pro). Severity: HIGH — but caught pre-merge. |
| T-3-SC-VERTEX | Tampering (supply chain) | A malicious major version of `@google-cloud/vertexai` ships to npm | mitigate | Pinned `^1.12.0` (caret allows minor/patch but blocks major). RESEARCH §Package Legitimacy Audit confirmed official Google org repo + no postinstall. Plan 03-15 closeout re-validates `package-lock.json` integrity. |
| T-3-IMAGE-SIZE-DOS | Denial of Service | A user uploads a 100MB image; inline base64 bloats the Vertex request; timeout | accept (with soft cap in handler) | The 4MB soft cap is implemented in plan 03-06's handler (where `imageUrl` is fetched). gemini.ts itself accepts the buffer without size check. Defer to plan 03-06. |
| T-3-SAFETY-BYPASS | Information Disclosure | Safety settings too lax; harmful content returned to a minor (target audience is teens) | accept | `BLOCK_MEDIUM_AND_ABOVE` on the two highest-risk categories is the project default. Sexual + harassment categories use SDK defaults. Future tuning is a Phase 5+ amendment. |
</threat_model>

<verification>
- `@google-cloud/vertexai ^1.12.0` installed; package-lock.json updated.
- functions/src/lib/gemini.ts has all 7 exports (GeminiClient, VertexGeminiClient, makeGeminiClient, SYSTEM_PROMPT, SYSTEM_PROMPT_VERSION, MODEL_CONFIG, ModelConfig).
- SYSTEM_PROMPT contains the verbatim Cambridge/Edexcel-tone text from gemini_service.dart.
- AI-10 anti-streaming grep gate green.
- 8+ unit tests pass.
- npm build + lint green.
</verification>

<success_criteria>
- AI-01: Vertex AI client wired with ADC (no API key).
- AI-09: System prompt is a versioned TS const (updatable via `firebase deploy --only functions`).
- AI-10: `generateContent` only — no streaming method anywhere.
- D-21: Testable seam (interface + fake + factory) operational.
- Plan 03-04 can run `verify-model-availability.js` against the pinned `MODEL_CONFIG.modelId`.
- Plan 03-06 can import and call `makeGeminiClient(...)`.
- Plan 03-12 will delete gemini_service.dart knowing SYSTEM_PROMPT preserves the prompt.
</success_criteria>

<output>
Create `.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-03-vertex-gemini-client-SUMMARY.md` when done. Record:
1. Final functions/src/lib/gemini.ts content (full file).
2. Final functions/src/__tests__/gemini.test.ts content + jest output (≥ 8/8 pass).
3. `@google-cloud/vertexai` resolved version from `npm view @google-cloud/vertexai version` and from `functions/package-lock.json`.
4. Lint + build exit codes.
5. AI-10 grep output (empty — no generateContentStream).
6. System prompt fidelity grep output (3 phrases found).
7. Commit SHA.
8. Forward-pointer: plan 03-04 verifies `MODEL_CONFIG.modelId` resolves; plan 03-06 wires the handler.
</output>
</content>
</invoke>