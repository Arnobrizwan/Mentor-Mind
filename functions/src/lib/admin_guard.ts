import { CallableRequest } from "firebase-functions/v2/https";
import { db } from "./admin";
import { permissionDenied, unauthenticated } from "./errors";

/** Defense-in-depth admin check (ADMN-08). */
export async function requireAdmin(
  request: CallableRequest<unknown>
): Promise<string> {
  const uid = request.auth?.uid;
  if (!uid) {
    throw unauthenticated("Authentication required");
  }
  const claimRole = (request.auth?.token as { role?: string } | undefined)
    ?.role;
  if (claimRole !== "admin") {
    throw permissionDenied("Admin role required");
  }
  const userSnap = await db.collection("users").doc(uid).get();
  const docRole = userSnap.data()?.["role"];
  if (docRole !== "admin") {
    throw permissionDenied("Admin role required");
  }
  return uid;
}
