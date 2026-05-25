import { auth } from "./admin";

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

/** Merges premium flag into existing custom claims (PAY-04). */
export async function setPremiumClaim(
  uid: string,
  premium: boolean
): Promise<void> {
  const user = await auth.getUser(uid);
  const existing = (user.customClaims ?? {}) as Record<string, unknown>;
  const role = (existing["role"] as UserRole | undefined) ?? "student";
  await auth.setCustomUserClaims(uid, {
    ...existing,
    role,
    premium,
  });
}

export async function setUserRoleClaim(
  uid: string,
  role: UserRole
): Promise<void> {
  const user = await auth.getUser(uid);
  const existing = (user.customClaims ?? {}) as Record<string, unknown>;
  await auth.setCustomUserClaims(uid, {
    ...existing,
    role,
    premium: Boolean(existing["premium"]),
  });
}

export async function getRole(uid: string): Promise<UserRole> {
  const user = await auth.getUser(uid);
  const role = (user.customClaims?.["role"] as UserRole | undefined) ?? "student";
  if (role === "teacher" || role === "admin") return role;
  return "student";
}
