import { getDhakaDateKey, monthKey, QUOTA_TZ } from '../lib/quota';

describe('quota helpers', () => {
  it('QUOTA_TZ is the Asia/Dhaka IANA zone identifier', () => {
    expect(QUOTA_TZ).toBe('Asia/Dhaka');
  });

  describe('getDhakaDateKey', () => {
    it("returns Dhaka calendar date for a known UTC instant just before Dhaka midnight rollover", () => {
      // 2026-05-18 17:59 UTC = 2026-05-18 23:59 Dhaka — same Dhaka day
      const beforeRollover = new Date('2026-05-18T17:59:00.000Z');
      expect(getDhakaDateKey(beforeRollover)).toBe('2026-05-18');
    });

    it("returns next Dhaka calendar day right after Dhaka midnight rollover", () => {
      // 2026-05-18 18:00 UTC = 2026-05-19 00:00 Dhaka (UTC+6)
      const atRollover = new Date('2026-05-18T18:00:00.000Z');
      expect(getDhakaDateKey(atRollover)).toBe('2026-05-19');
    });

    it("does NOT use UTC date — UTC midnight is mid-day Dhaka, still same day", () => {
      // 2026-05-19 00:00 UTC = 2026-05-19 06:00 Dhaka — same Dhaka day, NOT 2026-05-18
      const atUtcMidnight = new Date('2026-05-19T00:00:00.000Z');
      expect(getDhakaDateKey(atUtcMidnight)).toBe('2026-05-19');
    });

    it('handles late-evening Dhaka time correctly (PITFALLS #3 regression)', () => {
      // 2026-05-19 17:59 UTC = 2026-05-19 23:59 Dhaka — still the same Dhaka day, not next
      const lateDhakaEvening = new Date('2026-05-19T17:59:00.000Z');
      expect(getDhakaDateKey(lateDhakaEvening)).toBe('2026-05-19');
    });
  });

  describe('monthKey', () => {
    it("returns YYYY-MM for a known instant", () => {
      const instant = new Date('2026-05-18T18:00:00.000Z');
      expect(monthKey(instant)).toBe('2026-05');
    });

    it("rolls over the month at Dhaka midnight, not UTC midnight", () => {
      // 2026-05-31 18:00 UTC = 2026-06-01 00:00 Dhaka — month rolls to June
      const monthRollover = new Date('2026-05-31T18:00:00.000Z');
      expect(monthKey(monthRollover)).toBe('2026-06');
    });
  });
});
