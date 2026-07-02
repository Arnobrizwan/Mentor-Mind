import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";

// Singleton: initializeApp() uses FIREBASE_CONFIG env var set by the runtime.
// Guard prevents re-initialization when the module is hot-reloaded in emulator.
if (!admin.apps.length) {
  admin.initializeApp();
}

// Compatibility shim: under firebase-admin v13 in the Functions emulator
// runtime, the namespace statics `admin.firestore.FieldValue` and
// `admin.firestore.Timestamp` can be undefined (the modular SDK is the source
// of truth). Re-attach them from `firebase-admin/firestore` so the many
// existing `admin.firestore.FieldValue.*` / `admin.firestore.Timestamp.*`
// references across the codebase resolve. No-op in prod where they're present.
const _fs = admin.firestore as unknown as {
  FieldValue?: typeof FieldValue;
  Timestamp?: typeof Timestamp;
};
_fs.FieldValue ??= FieldValue;
_fs.Timestamp ??= Timestamp;

export const db = admin.firestore();
export const auth = admin.auth();
export default admin;
