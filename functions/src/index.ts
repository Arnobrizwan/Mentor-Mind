import { onCall } from "firebase-functions/https";
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { db } from "./lib/admin";
import {
  makeGeminiClient,
  MODEL_CONFIG,
  SYSTEM_PROMPT_VERSION,
} from "./lib/gemini";
import { checkAndIncrement } from "./lib/rate_limit";
import { unauthenticated, internal, mapKnownError } from "./lib/errors";

// ---------------------------------------------------------------------------
// Phase 2 — ping (boot-canary; DO NOT REMOVE)
// ---------------------------------------------------------------------------

export const ping = onCall(
  {
    region: "asia-south1",
    enforceAppCheck: true,
  },
  (_request) => {
    return {
      ok: true,
      timestamp: Date.now(),
      region: "asia-south1",
    };
  }
);

// ---------------------------------------------------------------------------
// Phase 3 — mentorBotChat callable (AI-01 / AI-07 / AI-10)
// D-06: region=asia-south1, enforceAppCheck=true, timeoutSeconds, memory from MODEL_CONFIG
// D-07: error shapes via errors.ts factories (unauthenticated / internal / mapKnownError)
// D-08: writes user + assistant docs to /sessions/{sid}/messages/{mid}
// D-11: upserts /sessions/{sid} metadata
// D-04: promptVersion stamp on every message doc
// D-19: isPremium forwarded to checkAndIncrement (premium = bypass daily cap)
// D-21: GEMINI_CLIENT_MODE=fake → FakeGeminiClient; absent/prod → VertexGeminiClient
// AI-10: non-streaming (generateContent only; no generateContentStream)
// ---------------------------------------------------------------------------

const UUID_V4_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const MAX_MESSAGE_BYTES = 8_000; // ~2k tokens of UTF-8 (T-3-06-LARGE-MESSAGE-DOS mitigation)

export const mentorBotChat = onCall(
  {
    region: "asia-south1",
    enforceAppCheck: true,
    timeoutSeconds: MODEL_CONFIG.timeoutSeconds,
    memory: MODEL_CONFIG.memory,
  },
  async (request) => {
    const startMs = Date.now();

    // ---------------------- AUTH ----------------------
    const uid = request.auth?.uid;
    if (!uid) {
      throw unauthenticated("Authentication required");
    }
    const isPremium =
      (request.auth?.token as { premium?: boolean } | undefined)?.premium ===
      true;

    // ---------------------- INPUT VALIDATION ----------------------
    const data = (request.data ?? {}) as Record<string, unknown>;
    const sessionId =
      typeof data["sessionId"] === "string" ? data["sessionId"] : "";
    const clientRequestId =
      typeof data["clientRequestId"] === "string"
        ? data["clientRequestId"]
        : "";
    const message =
      typeof data["message"] === "string" ? data["message"] : "";
    const imageUrl =
      typeof data["imageUrl"] === "string" ? data["imageUrl"] : undefined;
    const subject =
      typeof data["subject"] === "string" ? data["subject"] : undefined;
    const level =
      typeof data["level"] === "string" ? data["level"] : undefined;

    if (!UUID_V4_REGEX.test(clientRequestId)) {
      throw internal("Invalid clientRequestId (must be UUID v4)");
    }
    if (!UUID_V4_REGEX.test(sessionId)) {
      throw internal("Invalid sessionId (must be UUID v4)");
    }
    if (!message || message.length === 0) {
      throw internal("message is required");
    }
    if (Buffer.byteLength(message, "utf8") > MAX_MESSAGE_BYTES) {
      throw internal("message too long");
    }

    const kind: "text" | "image" = imageUrl ? "image" : "text";

    try {
      // ---------------------- IDEMPOTENCY CACHE ----------------------
      // doc id == clientRequestId so a retry with the same id hits the SAME doc.
      // Read BEFORE checkAndIncrement — a completed retry must NOT double-charge quota
      // (PITFALLS #2 from plan 03-05).
      const idempotencyRef = db
        .collection("sessions")
        .doc(sessionId)
        .collection("messages")
        .doc(clientRequestId);
      const idempotencySnap = await idempotencyRef.get();
      if (idempotencySnap.exists) {
        const cached = idempotencySnap.data() ?? {};
        functions.logger.info("mentorBotChat: idempotent hit", {
          uid,
          sessionId,
          clientRequestId,
        });
        const cachedCreatedAt: unknown = cached["createdAt"];
        const createdAtMs =
          cachedCreatedAt instanceof admin.firestore.Timestamp
            ? cachedCreatedAt.toMillis()
            : Date.now();
        return {
          text: (cached["text"] as string) ?? "",
          promptTokens: (cached["promptTokens"] as number) ?? 0,
          completionTokens: (cached["completionTokens"] as number) ?? 0,
          messageId: clientRequestId,
          createdAt: createdAtMs,
        };
      }

      // ---------------------- RATE LIMIT (TRANSACTION) ----------------------
      // Pitfall P-2: Gemini is called AFTER this transaction commits — never inside it.
      await checkAndIncrement(uid, kind, isPremium, clientRequestId);

      // ---------------------- (OPTIONAL) IMAGE FETCH ----------------------
      // Accept gs:// path OR firebasestorage download URL; Admin SA's IAM gates
      // cross-project reads (T-3-06-IMAGE-EXFIL mitigation).
      let imageInline: { buffer: Buffer; mimeType: string } | undefined;
      if (imageUrl) {
        const gsMatch = imageUrl.match(/^gs:\/\/([^/]+)\/(.+)$/);
        const httpsMatch = imageUrl.match(
          /^https?:\/\/firebasestorage\.googleapis\.com\/v0\/b\/([^/]+)\/o\/([^?]+)/
        );
        const match = gsMatch ?? httpsMatch;
        if (!match) {
          throw internal(
            "Invalid imageUrl (must be gs:// or firebasestorage URL)"
          );
        }
        const bucket = match[1]!;
        const objectPath = decodeURIComponent(match[2]!);
        const file = admin.storage().bucket(bucket).file(objectPath);
        const [bytes] = await file.download();
        const [metadata] = await file.getMetadata();
        const mimeType = metadata.contentType || "image/jpeg";
        imageInline = { buffer: bytes, mimeType };
      }

      // ---------------------- GEMINI CALL (AFTER tx commits) ----------------------
      const mode: "prod" | "fake" =
        process.env["GEMINI_CLIENT_MODE"] === "fake" ? "fake" : "prod";
      const client = makeGeminiClient(mode);
      // Prompt prefix encodes subject + level so the system prompt can calibrate.
      const promptPrefix =
        subject && level ? `[Subject: ${subject}, Level: ${level}]\n` : "";
      const { text, promptTokens, completionTokens } = await client.generate({
        prompt: promptPrefix + message,
        ...(imageInline ? { image: imageInline } : {}),
        modelConfig: MODEL_CONFIG,
      });

      // ---------------------- PERSIST USER + ASSISTANT MESSAGE DOCS ----------------------
      const nowTs = admin.firestore.Timestamp.now();
      const userMessageRef = db
        .collection("sessions")
        .doc(sessionId)
        .collection("messages")
        .doc(`${clientRequestId}-user`);
      const assistantMessageRef = idempotencyRef; // doc id == clientRequestId — IDEMPOTENCY KEY

      const batch = db.batch();
      batch.set(userMessageRef, {
        role: "user",
        text: message,
        ...(imageUrl ? { imageUrl } : {}),
        clientRequestId,
        createdAt: nowTs,
        promptVersion: SYSTEM_PROMPT_VERSION,
      });
      batch.set(assistantMessageRef, {
        role: "assistant",
        text,
        clientRequestId,
        createdAt: nowTs,
        promptVersion: SYSTEM_PROMPT_VERSION,
        promptTokens,
        completionTokens,
      });
      // Upsert /sessions/{sid} metadata (D-11)
      batch.set(
        db.collection("sessions").doc(sessionId),
        {
          uid,
          ...(subject ? { subject } : {}),
          ...(level ? { level } : {}),
          startedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastMessageAt: nowTs,
          messageCount: admin.firestore.FieldValue.increment(2),
          lastClientRequestId: clientRequestId,
        },
        { merge: true }
      );
      await batch.commit();

      const durationMs = Date.now() - startMs;
      functions.logger.info("mentorBotChat: success", {
        uid,
        sessionId,
        clientRequestId,
        promptTokens,
        completionTokens,
        durationMs,
        mode,
      });

      return {
        text,
        promptTokens,
        completionTokens,
        messageId: clientRequestId,
        createdAt: nowTs.toMillis(),
      };
    } catch (err) {
      // resourceExhausted / unavailable / unauthenticated / internal propagate as-is;
      // unknown errors get wrapped via mapKnownError (Phase 2 D-05).
      throw mapKnownError(err);
    }
  }
);
