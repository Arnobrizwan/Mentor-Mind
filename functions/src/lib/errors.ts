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

export function mapKnownError(error: unknown): HttpsError {
  if (error instanceof HttpsError) return error;
  const msg = error instanceof Error ? error.message : "Unknown error";
  return new HttpsError("internal", msg);
}
