import { HttpsError } from "firebase-functions/https";

export function unauthenticated(message: string): HttpsError {
  return new HttpsError("unauthenticated", message);
}

export function permissionDenied(message: string): HttpsError {
  return new HttpsError("permission-denied", message);
}

export function failedPrecondition(message: string): HttpsError {
  return new HttpsError("failed-precondition", message);
}

export function invalidArgument(message: string): HttpsError {
  return new HttpsError("invalid-argument", message);
}

export function internal(message: string): HttpsError {
  return new HttpsError("internal", message);
}

// D-07: resource-exhausted factory — used for daily cap + burst limit rejections.
// details.reason: 'daily' | 'burst' per D-07 HttpsError shape spec.
export function resourceExhausted(
  message: string,
  details?: Record<string, unknown>,
): HttpsError {
  return new HttpsError("resource-exhausted", message, details);
}

// D-07: unavailable factory — used for monthly-ceiling rejection.
// details.reason: 'monthly-ceiling' per D-07 HttpsError shape spec.
export function unavailable(
  message: string,
  details?: Record<string, unknown>,
): HttpsError {
  return new HttpsError("unavailable", message, details);
}

export function mapKnownError(error: unknown): HttpsError {
  if (error instanceof HttpsError) return error;
  const msg = error instanceof Error ? error.message : "Unknown error";
  return new HttpsError("internal", msg);
}
