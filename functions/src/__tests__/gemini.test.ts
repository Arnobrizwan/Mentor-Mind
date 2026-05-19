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
