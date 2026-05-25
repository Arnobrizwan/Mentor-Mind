import {
  POINTS_MAP,
  buildDedupeKey,
  eligibleBadges,
  ledgerDocId,
  type UserStats,
} from "../lib/rewards";

describe("rewards policy", () => {
  it("POINTS_MAP matches Phase 4 CONTEXT", () => {
    expect(POINTS_MAP["daily_login"]).toBe(5);
    expect(POINTS_MAP["complete_session"]).toBe(10);
    expect(POINTS_MAP["earn_badge"]).toBe(30);
  });

  it("buildDedupeKey is stable", () => {
    const a = buildDedupeKey({
      type: "complete_session",
      sessionId: "s1",
      clientRequestId: "c1",
    });
    const b = buildDedupeKey({
      clientRequestId: "c1",
      sessionId: "s1",
      type: "complete_session",
    });
    expect(a).toBe(b);
  });

  it("ledgerDocId is deterministic", () => {
    const key = buildDedupeKey({ type: "daily_login", date: "2026-05-25" });
    expect(ledgerDocId(key)).toHaveLength(40);
    expect(ledgerDocId(key)).toBe(ledgerDocId(key));
  });

  it("eligibleBadges awards dedicated_learner at 5 sessions", () => {
    const stats: UserStats = {
      sessionsCompleted: 5,
      totalQuestions: 0,
      diagramUploads: 0,
      streakDays: 0,
      maxQuestionsInOneSubject: 0,
      badges: new Set(),
    };
    expect(eligibleBadges(stats)).toContain("first_step");
    expect(eligibleBadges(stats)).toContain("dedicated_learner");
  });

  it("eligibleBadges skips already earned", () => {
    const stats: UserStats = {
      sessionsCompleted: 10,
      totalQuestions: 100,
      diagramUploads: 10,
      streakDays: 30,
      maxQuestionsInOneSubject: 100,
      badges: new Set([
        "first_step",
        "curious_learner",
        "dedicated_learner",
        "week_warrior",
        "month_master",
        "diagram_detective",
        "subject_expert",
      ]),
    };
    expect(eligibleBadges(stats)).toHaveLength(0);
  });
});
