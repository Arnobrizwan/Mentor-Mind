// Phase 3 interface — stub only. Do NOT implement in Phase 2.

export interface GeminiCallOptions {
  maxOutputTokens?: number;
  temperature?: number;
}

export interface GeminiResponse {
  text: string;
  finishReason?: string;
}

export async function callGemini(
  _prompt: string,
  _opts?: GeminiCallOptions
): Promise<GeminiResponse> {
  throw new Error("not implemented — see Phase 3");
}
