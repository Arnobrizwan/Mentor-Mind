import * as admin from "firebase-admin";

// Singleton: initializeApp() uses FIREBASE_CONFIG env var set by the runtime.
// Guard prevents re-initialization when the module is hot-reloaded in emulator.
if (!admin.apps.length) {
  admin.initializeApp();
}

export const db = admin.firestore();
export const auth = admin.auth();
export default admin;
