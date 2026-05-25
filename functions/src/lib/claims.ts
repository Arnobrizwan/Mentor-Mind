import { auth } from "./admin";

// Phase 5 interface — setPremium stays stub until Stripe lands.

export type UserRole = "student" | "teacher" | "admin";

export type DefaultClaims = {
  role: UserRole;
  premium: boolean;
};

export const DEFAULT_CLAIMS: DefaultClaims = {
  role: "student",
  premium: false,
};

/** Sets default v1 claims on a new Auth user (REWD-02). */
export async function setDefaultUserClaims(uid: string): Promise<void> {
  await auth.setCustomUserClaims(uid, { ...DEFAULT_CLAIMS });
}

export async function setPremium(
  _uid: string,
  _isPremium: boolean
): Promise<void> {
  throw new Error("not implemented — see Phase 5");
}

export async function getRole(uid: string): Promise<UserRole> {
  const user = await auth.getUser(uid);
  const role = (user.customClaims?.["role"] as UserRole | undefined) ?? "student";
  if (role === "teacher" || role === "admin") return role;
  return "student";
}
