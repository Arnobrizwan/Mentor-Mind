import {
  activeModelId,
  GeminiTutorAIClient,
  GroqTutorAIClient,
  makeTutorAIClient,
  MODEL_CONFIG,
  resolveTutorAIProvider,
  SYSTEM_PROMPT,
  SYSTEM_PROMPT_VERSION,
} from '../lib/tutor_ai';

describe('tutor_ai module exports', () => {
  it('exports SYSTEM_PROMPT_VERSION as a string', () => {
    expect(SYSTEM_PROMPT_VERSION).toBe('3');
  });

  it('SYSTEM_PROMPT mentions MentorBot + O-Level + A-Level + curriculum cues + [Subject: X, Level: Y]', () => {
    expect(SYSTEM_PROMPT).toContain('MentorBot');
    expect(SYSTEM_PROMPT).toContain('O-Level');
    expect(SYSTEM_PROMPT).toContain('A-Level');
    expect(SYSTEM_PROMPT).toContain('Cambridge');
    expect(SYSTEM_PROMPT).toContain('Edexcel');
    expect(SYSTEM_PROMPT).toContain('[Subject: X, Level: Y]');
  });

  it('MODEL_CONFIG carries the D-14 runtime config values', () => {
    expect(MODEL_CONFIG.timeoutSeconds).toBe(60);
    expect(MODEL_CONFIG.memory).toBe('512MiB');
    expect(MODEL_CONFIG.maxOutputTokens).toBe(1024);
    expect(MODEL_CONFIG.temperature).toBe(0.7);
    expect(MODEL_CONFIG.topP).toBe(0.95);
  });

  it('MODEL_CONFIG.modelId is a non-empty string (the text-only model)', () => {
    expect(typeof MODEL_CONFIG.modelId).toBe('string');
    expect(MODEL_CONFIG.modelId.length).toBeGreaterThan(0);
  });

  it('MODEL_CONFIG.visionModelId is a non-empty string (the multimodal model)', () => {
    expect(typeof MODEL_CONFIG.visionModelId).toBe('string');
    expect(MODEL_CONFIG.visionModelId.length).toBeGreaterThan(0);
  });
});

describe('FakeTutorAIClient (via makeTutorAIClient("fake"))', () => {
  const client = makeTutorAIClient('fake');

  it('generate returns a non-empty canned response with positive token counts', async () => {
    const result = await client.generate({
      prompt: 'Hello',
      modelConfig: MODEL_CONFIG,
    });
    expect(typeof result.text).toBe('string');
    expect(result.text.length).toBeGreaterThan(0);
    expect(result.promptTokens).toBeGreaterThan(0);
    expect(result.completionTokens).toBeGreaterThan(0);
  });

  it('selects a subject-appropriate canned answer by keyword', async () => {
    const quad = await client.generate({
      prompt: 'Solve the quadratic 2x² + 5x − 3 = 0',
      modelConfig: MODEL_CONFIG,
    });
    expect(quad.text).toContain('Factorise');

    const bio = await client.generate({
      prompt: 'Explain photosynthesis',
      modelConfig: MODEL_CONFIG,
    });
    expect(bio.text.toLowerCase()).toContain('photosynthesis');
  });

  it('generate accepts the image option and still returns text', async () => {
    const result = await client.generate({
      prompt: 'Describe this image',
      image: { buffer: Buffer.from('fake-image-bytes'), mimeType: 'image/jpeg' },
      modelConfig: MODEL_CONFIG,
    });
    expect(result.text.length).toBeGreaterThan(0);
  });
});

describe('makeTutorAIClient factory', () => {
  it("mode='fake' returns a client whose generate resolves immediately (no network)", async () => {
    const client = makeTutorAIClient('fake');
    await expect(
      client.generate({ prompt: 'test', modelConfig: MODEL_CONFIG }),
    ).resolves.toHaveProperty('text');
  });

  it("mode='prod' returns a GeminiTutorAIClient by default (spec: Gemini API)", () => {
    // Client construction is side-effect-free; the API key is only read
    // inside generate(). Safe to instantiate in unit tests.
    delete process.env['TUTOR_AI_PROVIDER'];
    const client = makeTutorAIClient('prod');
    expect(client).toBeInstanceOf(GeminiTutorAIClient);
    expect(typeof client.generate).toBe('function');
  });

  it("TUTOR_AI_PROVIDER=groq falls back to GroqTutorAIClient", () => {
    process.env['TUTOR_AI_PROVIDER'] = 'groq';
    try {
      expect(resolveTutorAIProvider()).toBe('groq');
      expect(makeTutorAIClient('prod')).toBeInstanceOf(GroqTutorAIClient);
    } finally {
      delete process.env['TUTOR_AI_PROVIDER'];
    }
  });
});

describe('activeModelId', () => {
  it('returns the Gemini model for text and image on the default provider', () => {
    delete process.env['TUTOR_AI_PROVIDER'];
    expect(activeModelId(false)).toBe(MODEL_CONFIG.geminiModelId);
    expect(activeModelId(true)).toBe(MODEL_CONFIG.geminiModelId);
  });

  it('returns text/vision Llama models under the groq fallback', () => {
    process.env['TUTOR_AI_PROVIDER'] = 'groq';
    try {
      expect(activeModelId(false)).toBe(MODEL_CONFIG.modelId);
      expect(activeModelId(true)).toBe(MODEL_CONFIG.visionModelId);
    } finally {
      delete process.env['TUTOR_AI_PROVIDER'];
    }
  });
});
