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
  type Part,
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
    // Note: The @google-cloud/vertexai SDK v1.12 uses camelCase `inlineData` in TypeScript
    // types (not snake_case `inline_data` which is the REST wire format).
    const parts: Part[] = [{ text: opts.prompt }];
    if (opts.image) {
      parts.push({
        inlineData: {
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
