import * as functions from "firebase-functions/v1";
import type { UserRecord } from "firebase-functions/v1/auth";
import { setDefaultUserClaims } from "../lib/claims";
import { initRewardsDoc } from "../lib/rewards";

/**
 * REWD-02 — initialize rewards doc + default custom claims on signup.
 * Gen-1 auth trigger (stable alongside v2 callables).
 */
export const onUserCreate = functions
  .region("asia-south1")
  .auth.user()
  .onCreate(async (user: UserRecord) => {
    const uid = user.uid;
    try {
      await setDefaultUserClaims(uid);
      await initRewardsDoc(uid);
      functions.logger.info("onUserCreate: initialized rewards + claims", {
        uid,
      });
    } catch (err) {
      functions.logger.error("onUserCreate: failed", {
        uid,
        err: err instanceof Error ? err.message : String(err),
      });
    }
  });
