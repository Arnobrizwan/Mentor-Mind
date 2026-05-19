// Phase 5 interface — stub only. Do NOT implement in Phase 2.

export type UserRole = "student" | "teacher" | "admin";

export async function setPremium(
  _uid: string,
  _isPremium: boolean
): Promise<void> {
  throw new Error("not implemented — see Phase 5");
}

export async function getRole(_uid: string): Promise<UserRole> {
  throw new Error("not implemented — see Phase 5");
}
