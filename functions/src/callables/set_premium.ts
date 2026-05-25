import { onCall } from "firebase-functions/v2/https";
import { applyManualPremium } from "../lib/subscriptions";
import { requireAdmin } from "../lib/admin_guard";

/** PAY-03 — admin-only manual premium grant/revoke. */
export const setPremium = onCall(
  {
    region: "asia-south1",
    enforceAppCheck: true,
  },
  async (request) => {
    const adminUid = await requireAdmin(request);
    const data = (request.data ?? {}) as Record<string, unknown>;
    const targetUid = typeof data["uid"] === "string" ? data["uid"] : "";
    const isPremium = data["isPremium"] === true;
    if (!targetUid) {
      throw new Error("uid is required");
    }
    await applyManualPremium(targetUid, isPremium, adminUid);
    return { ok: true, uid: targetUid, isPremium };
  }
);
