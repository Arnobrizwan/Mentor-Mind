// Tutor AI client — Gemini API (primary, per project spec) with Groq + Llama
// 3.3 70B as an env-selectable fallback (TUTOR_AI_PROVIDER=groq).
//
// Provider selection:
//   - Default: Gemini (generativelanguage.googleapis.com, GEMINI_API_KEY).
//     The project SRS/SDD specify the Gemini API for MentorBot; Gemini is
//     natively multimodal so text and diagram questions use one model.
//     Called over REST with Node's global fetch — no extra SDK dependency.
//   - TUTOR_AI_PROVIDER=groq: Groq + Llama 3.3 70B (GROQ_API_KEY). Kept as a
//     fallback for free-tier quota headroom / no-training-on-prompts policy.
//
// Migration history (the file path used to be `lib/gemini.ts`):
//   - Phase 3 originally used @google-cloud/vertexai (Gemini via Vertex AI
//     in us-central1 — paid tier, IAM-gated, ADC-based).
//   - Interim: Groq + Llama 3.3 70B, OpenAI-compatible API, plain API key.
//   - Now: Gemini AI Studio API by default (spec alignment), Groq retained
//     behind TUTOR_AI_PROVIDER=groq.
//
// Architecture invariants from earlier phases (do NOT regress):
//   - TutorAIClient interface + FakeTutorAIClient + makeTutorAIClient factory.
//   - SYSTEM_PROMPT_VERSION bumped on every prompt edit so message docs are
//     traceable to a prompt revision when auditing answer quality.
//   - Non-streaming (the callable handler builds the typing indicator from
//     the in-flight Future, not a Stream).
//   - Image payloads sent as inline base64 data URLs (no Cloud Storage URIs).

import Groq from 'groq-sdk';

// ---------------------------------------------------------------------------
// Versioned prompt — bump SYSTEM_PROMPT_VERSION on every edit so message docs
// can be filtered by prompt revision when auditing answer quality.
// ---------------------------------------------------------------------------

export const SYSTEM_PROMPT_VERSION = '3';

export const SYSTEM_PROMPT = `You are MentorBot, the AI tutor inside MentorMinds — a study app for O-Level and A-Level students in Bangladesh preparing for Cambridge (CAIE / CIE) and Edexcel exams.

## Calibration

Match the student's selected level (O-Level or A-Level) and the exam board conventions:
- **Cambridge** — favour syllabus terminology and mark-scheme command words ("state", "describe", "explain", "calculate", "compare"). End-of-chapter style.
- **Edexcel** — favour Edexcel command words ("identify", "discuss", "evaluate", "deduce", "assess"). Reference the Edexcel formula booklet conventions when relevant.

You will receive messages prefixed with \`[Subject: X, Level: Y]\` as context. Use that to calibrate tone, depth, and which subject playbook below to apply. If no prefix is provided, infer from the question and pick the closest playbook.

## Subject playbooks

**Mathematics** — show every algebraic step, not just final answers. Cite the syllabus topic (e.g. "P1: Quadratics", "C3: Differentiation"). For proofs, state the assumption and the goal before working. For statistics, name the distribution before plugging in.

**Physics** — start with the formula, then substitute units. Default to SI; flag when a quantity is in cm / g / min. Describe force directions in words before the calculation. For optics / circuits, describe the diagram in text first.

**Chemistry** — always balance equations. Include state symbols (s / l / g / aq). For organic chemistry, name with IUPAC and show curly-arrow mechanisms in text where relevant. For mole calculations, structure as: known → unknown → equation → substitute → answer.

**Biology** — define key terms before using them. Use sectioned answers (Definition / Mechanism / Example) for processes like respiration, photosynthesis, gene expression, homeostasis. Cite the specific syllabus subsection when possible.

**English (Language + Literature)** — for unseen passages, structure as PEEL (Point / Evidence / Explanation / Link). For comprehension, quote with line references. For language analysis, name the device (metaphor, anaphora, juxtaposition) before explaining effect.

**Economics / Business / Accounting** — use diagrams in text (e.g. supply-demand axes labelled). Show formulas first (e.g. "Total Revenue = Price × Quantity") then substitute.

**ICT / Computer Science** — use code fences for code. For algorithms, give pseudocode before any language-specific implementation. Comment the non-obvious lines.

**History** — structure cause/consequence answers in numbered points. Date every event. For source-based questions, name the source type (primary/secondary), state provenance, evaluate reliability (purpose, audience, bias), then answer. For essay questions, signpost paragraphs ("Politically...", "Economically...", "Socially...").

**Geography** — pair physical processes with named real-world case studies (e.g. Bangladesh cyclones, Sundarbans, Ganges delta) when relevant. For diagrams, describe in text with labelled stages. For map questions, give bearings + distances + grid references. For human geography, use the framework: define → describe → explain → evaluate.

## Style rules

- Markdown only: **bold** for key terms, \`inline code\` for short formulas, triple-backtick fences for worked solutions / pseudocode, bullets for lists, \`##\` subheadings for long answers.
- Short paragraphs. Avoid wall-of-text.
- Prefer Socratic prompts when the student is one step from the answer; give the full solution when they're stuck.
- Cite the syllabus topic when relevant ("Cambridge IGCSE Math 0580 / Topic 2.1", "Edexcel A-Level Physics 9PH0 / Topic 4").
- Use Bangladeshi context (taka, local examples) ONLY when it genuinely helps. Don't force it.
- Never invent exam results or fabricate facts. If unsure, say so: "I'm not sure — please verify with your textbook or teacher."
- Stay on-topic for the student's selected subject. Gently redirect off-topic questions: "That's outside what I can help with in a study session — try the search bar for materials, or message your teacher."

## Worked examples (calibration reference)

### Example 1 — Math O-Level, Cambridge style

User: \`[Subject: Mathematics, Level: O Level]\` Solve 2x² + 5x − 3 = 0

You:
**Step 1 — Factorise.** Find two numbers whose product is (2)(−3) = −6 and whose sum is 5. Those are 6 and −1.

\`\`\`
2x² + 6x − x − 3 = 0
2x(x + 3) − 1(x + 3) = 0
(2x − 1)(x + 3) = 0
\`\`\`

**Step 2 — Solve each bracket.** \`x = 1/2\` or \`x = −3\`.

**Topic:** Cambridge IGCSE Math 0580 / Topic 2.5 (Quadratic equations).

### Example 2 — Physics A-Level, Edexcel style

User: \`[Subject: Physics, Level: A Level]\` A 2 kg block slides down a frictionless 30° incline. Find the acceleration.

You:
**Forces along the incline.** Only the component of gravity along the slope contributes (no friction, normal force is perpendicular):

\`F = mg sinθ\`

**Substitute** (g = 9.81 m/s², θ = 30°):

\`\`\`
F = (2)(9.81) sin(30°) = 9.81 N
a = F / m = 9.81 / 2 = 4.905 m/s²
\`\`\`

**Topic:** Edexcel A-Level Physics 9PH0 / Topic 3 (Dynamics).

### Example 3 — Chemistry O-Level, mole calculation

User: \`[Subject: Chemistry, Level: O Level]\` How many moles of NaCl are in 11.7 g?

You:
**Known:** mass = 11.7 g. **Unknown:** moles.

**Equation:** \`n = m / M\` where M(NaCl) = 23 + 35.5 = 58.5 g/mol.

\`\`\`
n = 11.7 / 58.5 = 0.20 mol
\`\`\`

**Topic:** Cambridge IGCSE Chemistry 0620 / Topic 4 (Stoichiometry).

### Example 4 — Biology O-Level, sectioned answer

User: \`[Subject: Biology, Level: O Level]\` Explain photosynthesis.

You:
**Definition.** Photosynthesis is the process by which green plants convert light energy into chemical energy stored in glucose.

**Word equation.**
\`\`\`
carbon dioxide + water  →(light, chlorophyll)→  glucose + oxygen
6 CO₂ + 6 H₂O          →(light, chlorophyll)→  C₆H₁₂O₆ + 6 O₂
\`\`\`

**Mechanism (two stages).**
- **Light-dependent stage** — in the thylakoid membrane; chlorophyll absorbs light; water is split (photolysis) → O₂ released, H⁺ and electrons drive ATP and NADPH formation.
- **Light-independent stage (Calvin cycle)** — in the stroma; CO₂ is fixed onto RuBP, reduced using ATP + NADPH → glucose.

**Limiting factors.** Light intensity, CO₂ concentration, temperature.

**Topic:** Cambridge IGCSE Biology 0610 / Topic 6 (Plant nutrition).

### Example 5 — History A-Level, source evaluation

User: \`[Subject: History, Level: A Level]\` How useful is a 1947 newspaper editorial in studying the Partition of India?

You:
**Provenance.** Primary source. Editorial = opinion piece. Written 1947 (the year of Partition) → contemporary, no hindsight.

**Useful for...**
1. **Tone of public discourse** — captures how the press framed Partition in real time.
2. **Editorial position** — papers had political alignments (Hindu / Muslim / British-owned), so we learn what the paper's audience was being told.

**Limits.**
1. **Bias.** Editorials are persuasive, not factual. A Calcutta paper vs a Lahore paper would frame the same event opposite ways.
2. **Censorship.** Late-colonial press was monitored — some criticism would have been self-censored.
3. **Audience.** Reflects literate, urban readership, not the rural majority who experienced Partition violence.

**Verdict.** Useful for *attitudes* and *propaganda framing*, less so for *factual chronology* — corroborate with official documents (Mountbatten papers, Cabinet Mission records).

**Topic:** Edexcel A-Level History 9HI0 / Paper 2 (India c.1914–48).

Stay within this style. Calibrate depth to the student's level.
`;

// ---------------------------------------------------------------------------
// Model + generation config
// ---------------------------------------------------------------------------
//
// modelId (text-only) — llama-3.3-70b-versatile. Best free-tier quality on
// mathematics / science / English on Groq as of May 2026.
//
// visionModelId — meta-llama/llama-4-scout-17b-16e-instruct. Llama 4 Scout is
// natively multimodal (text + images). Used only when an image is attached.
//
// To upgrade quality: bump modelId to `llama-3.3-70b-specdec` (faster speculative
// decoding variant) or to a paid model. No other code change needed.

export const MODEL_CONFIG = {
  // Gemini (default provider) — natively multimodal, one model for text+vision.
  geminiModelId: 'gemini-2.5-flash',
  // Groq fallback (TUTOR_AI_PROVIDER=groq)
  modelId: 'llama-3.3-70b-versatile',
  visionModelId: 'meta-llama/llama-4-scout-17b-16e-instruct',
  timeoutSeconds: 60,
  memory: '512MiB' as const,
  maxOutputTokens: 1024,
  temperature: 0.7,
  topP: 0.95,
} as const;

export type ModelConfig = typeof MODEL_CONFIG;

// ---------------------------------------------------------------------------
// TutorAIClient interface — testable seam
// ---------------------------------------------------------------------------

export interface TutorAIClient {
  generate(opts: {
    prompt: string;
    image?: { buffer: Buffer; mimeType: string };
    modelConfig: ModelConfig;
  }): Promise<{ text: string; promptTokens: number; completionTokens: number }>;
}

// ---------------------------------------------------------------------------
// GroqTutorAIClient — production impl wrapping groq-sdk with an API key from
// GROQ_API_KEY. The key is sourced from functions/.env at deploy time and
// never reaches the client app (compliance requirement).
// ---------------------------------------------------------------------------

export class GroqTutorAIClient implements TutorAIClient {
  async generate(opts: {
    prompt: string;
    image?: { buffer: Buffer; mimeType: string };
    modelConfig: ModelConfig;
  }): Promise<{ text: string; promptTokens: number; completionTokens: number }> {
    const apiKey = process.env['GROQ_API_KEY'];
    if (!apiKey) {
      throw new Error(
        'GROQ_API_KEY env var not set. Obtain a free key at https://console.groq.com/keys and add it to functions/.env before deploy.',
      );
    }

    const client = new Groq({ apiKey });

    // Build the user message. For images, Llama 4 Scout expects an OpenAI-style
    // multipart content array with a base64 data URL.
    const userContent = opts.image
      ? [
          { type: 'text' as const, text: opts.prompt },
          {
            type: 'image_url' as const,
            image_url: {
              url: `data:${opts.image.mimeType};base64,${opts.image.buffer.toString('base64')}`,
            },
          },
        ]
      : opts.prompt;

    const model = opts.image
      ? opts.modelConfig.visionModelId
      : opts.modelConfig.modelId;

    const completion = await client.chat.completions.create({
      model,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: userContent },
      ],
      temperature: opts.modelConfig.temperature,
      top_p: opts.modelConfig.topP,
      max_tokens: opts.modelConfig.maxOutputTokens,
    });

    const text = completion.choices[0]?.message?.content ?? '';
    const promptTokens = completion.usage?.prompt_tokens ?? 0;
    const completionTokens = completion.usage?.completion_tokens ?? 0;
    return { text, promptTokens, completionTokens };
  }
}

// ---------------------------------------------------------------------------
// GeminiTutorAIClient — default production impl calling the Gemini API over
// REST (Node 22 global fetch; no SDK dependency). API key from GEMINI_API_KEY,
// sourced from functions/.env at deploy time — never reaches the client app.
// ---------------------------------------------------------------------------

interface GeminiGenerateContentResponse {
  candidates?: Array<{
    content?: { parts?: Array<{ text?: string }> };
  }>;
  usageMetadata?: {
    promptTokenCount?: number;
    candidatesTokenCount?: number;
  };
}

export class GeminiTutorAIClient implements TutorAIClient {
  async generate(opts: {
    prompt: string;
    image?: { buffer: Buffer; mimeType: string };
    modelConfig: ModelConfig;
  }): Promise<{ text: string; promptTokens: number; completionTokens: number }> {
    const apiKey = process.env['GEMINI_API_KEY'];
    if (!apiKey) {
      throw new Error(
        'GEMINI_API_KEY env var not set. Obtain a key at https://aistudio.google.com/apikey and add it to functions/.env before deploy.',
      );
    }

    const model = opts.modelConfig.geminiModelId;
    const parts: Array<Record<string, unknown>> = [{ text: opts.prompt }];
    if (opts.image) {
      parts.push({
        inlineData: {
          mimeType: opts.image.mimeType,
          data: opts.image.buffer.toString('base64'),
        },
      });
    }

    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': apiKey,
        },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
          contents: [{ role: 'user', parts }],
          generationConfig: {
            temperature: opts.modelConfig.temperature,
            topP: opts.modelConfig.topP,
            maxOutputTokens: opts.modelConfig.maxOutputTokens,
          },
        }),
      },
    );

    if (!res.ok) {
      const body = await res.text().catch(() => '');
      throw new Error(`Gemini API error ${res.status}: ${body.slice(0, 300)}`);
    }

    const data = (await res.json()) as GeminiGenerateContentResponse;
    const text = (data.candidates?.[0]?.content?.parts ?? [])
      .map((p) => p.text ?? '')
      .join('');
    const promptTokens = data.usageMetadata?.promptTokenCount ?? 0;
    const completionTokens = data.usageMetadata?.candidatesTokenCount ?? 0;
    return { text, promptTokens, completionTokens };
  }
}

// ---------------------------------------------------------------------------
// FakeTutorAIClient — inline canned-response impl for unit + integration tests
// ---------------------------------------------------------------------------

// Canned but realistic, exam-style answers. Selected by keyword so an offline
// showcase / integration run produces watchable, on-brand MentorBot output
// without a live LLM key. Unit tests only assert the shape (non-empty text +
// token counts), so richer copy here is safe.
const QUADRATIC_ANSWER = `**Step 1 — Factorise.** Find two numbers whose product is (2)(−3) = −6 and whose sum is 5. Those are 6 and −1.

\`\`\`
2x² + 6x − x − 3 = 0
2x(x + 3) − 1(x + 3) = 0
(2x − 1)(x + 3) = 0
\`\`\`

**Step 2 — Solve each bracket.** \`x = 1/2\` or \`x = −3\`.

**Topic:** Cambridge IGCSE Math 0580 / Topic 2.5 (Quadratic equations).`;

const PHOTOSYNTHESIS_ANSWER = `**Definition.** Photosynthesis is how green plants convert light energy into chemical energy stored in glucose.

**Word + symbol equation.**
\`\`\`
carbon dioxide + water  →(light, chlorophyll)→  glucose + oxygen
6 CO₂ + 6 H₂O          →(light, chlorophyll)→  C₆H₁₂O₆ + 6 O₂
\`\`\`

**Mechanism (two stages).**
- **Light-dependent** — thylakoid membrane; water is split (photolysis) → O₂ released, ATP + NADPH formed.
- **Light-independent (Calvin cycle)** — stroma; CO₂ fixed onto RuBP, reduced with ATP + NADPH → glucose.

**Limiting factors.** Light intensity, CO₂ concentration, temperature.

**Topic:** Cambridge IGCSE Biology 0610 / Topic 6 (Plant nutrition).`;

const NEWTON_ANSWER = `**Forces along the incline.** With no friction, only the component of gravity along the slope drives the motion:

\`F = mg sinθ\`

**Substitute** (g = 9.81 m/s², θ = 30°):

\`\`\`
F = (2)(9.81) sin(30°) = 9.81 N
a = F / m = 9.81 / 2 = 4.905 m/s²
\`\`\`

**Topic:** Edexcel A-Level Physics 9PH0 / Topic 3 (Dynamics).`;

const GENERIC_ANSWER = `Great question — here's how I'd approach it.

**1. Identify what's being asked.** Pin down the command word (state / explain / calculate / evaluate) so the depth matches the mark scheme.

**2. Recall the key idea.** Write the relevant definition or formula first, then the values you know.

**3. Work through it step by step**, showing each line of reasoning so an examiner can follow the method marks.

**4. State the answer clearly** with correct units, and link it back to the syllabus topic.

Send me the specific problem — subject, level and the exact wording — and I'll give you the full worked solution in this style.`;

function cannedAnswer(prompt: string): string {
  const p = prompt.toLowerCase();
  if (p.includes('quadratic') || p.includes('2x²') || p.includes('2x^2') || /solve.*x/.test(p)) {
    return QUADRATIC_ANSWER;
  }
  if (p.includes('photosynth')) return PHOTOSYNTHESIS_ANSWER;
  if (p.includes('incline') || p.includes('acceleration') || p.includes('newton')) {
    return NEWTON_ANSWER;
  }
  return GENERIC_ANSWER;
}

const fakeTutorAIClient: TutorAIClient = {
  generate: async (opts) => {
    const text = cannedAnswer(opts.prompt);
    return {
      text,
      promptTokens: Math.max(10, Math.round(opts.prompt.length / 4)),
      completionTokens: Math.round(text.length / 4),
    };
  },
};

// ---------------------------------------------------------------------------
// Factory — mode via TUTOR_AI_CLIENT_MODE (fake | prod); prod provider via
// TUTOR_AI_PROVIDER (gemini default per spec | groq fallback).
// ---------------------------------------------------------------------------

export type TutorAIProvider = 'gemini' | 'groq';

export function resolveTutorAIProvider(): TutorAIProvider {
  return process.env['TUTOR_AI_PROVIDER'] === 'groq' ? 'groq' : 'gemini';
}

// The model id a prod call will use — recorded in logs/message docs so answer
// quality can be audited per model.
export function activeModelId(hasImage: boolean): string {
  if (resolveTutorAIProvider() === 'groq') {
    return hasImage ? MODEL_CONFIG.visionModelId : MODEL_CONFIG.modelId;
  }
  return MODEL_CONFIG.geminiModelId;
}

export function makeTutorAIClient(mode: 'prod' | 'fake'): TutorAIClient {
  if (mode === 'fake') return fakeTutorAIClient;
  return resolveTutorAIProvider() === 'groq'
    ? new GroqTutorAIClient()
    : new GeminiTutorAIClient();
}
