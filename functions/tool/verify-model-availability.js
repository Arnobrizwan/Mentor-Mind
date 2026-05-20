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
