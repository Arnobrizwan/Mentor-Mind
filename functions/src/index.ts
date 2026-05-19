import { onCall } from "firebase-functions/https";

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
