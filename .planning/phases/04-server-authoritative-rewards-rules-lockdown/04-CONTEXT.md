# Phase 4: Server-Authoritative Rewards + Rules Lockdown - Context

**Gathered:** 2026-05-25
**Status:** Ready for planning
**Mode:** Auto-derived from ROADMAP.md, REQUIREMENTS.md (REWD-01..07), ARCHITECTURE.md §8, PITFALLS.md, and Phase 3 closeout — no open gray areas required user input (all locked in prior milestones).

<domain>
## Phase Boundary

Make points, badges, streak, and rewards history **server-authoritative**. Clients may **read** `/users/{uid}` and `/rewards/{uid}` (+ ledger subcollection) and **react** (streams, badge celebration UI). Clients must **never** write `points`, `badges`, `streak`, or ledger entries.

Deliverables:

1. **`onMessageWrite` Firestore trigger** (exported name may be `onSessionWrite` per roadmap wording) on `/sessions/{sessionId}/messages/{messageId}` — fires when Phase 3 `mentorBotChat` appends a message doc. Awards points + badges idempotently from document deltas and `clientRequestId`.
2. **`onUserCreate` Auth trigger** — initializes `/rewards/{uid}`, sets default custom claims `{ role: 'student', premium: false }` (REWD-02).
3. **Append-only ledger** at `/rewards/{uid}/ledger/{autoId}` — replaces unbounded `history` array on `/rewards/{uid}` (REWD-03). One-time migration for prod docs that already have `history[]`.
4. **`firestore.rules` lockdown** in the **same deploy** as the triggers (REWD-05, REWD-06) — malicious REST writes to `points`/`badges`/`streak` and all `/rewards/{uid}/**` writes rejected.
5. **Client cleanup** — remove all `FieldValue.increment('points')` and client `awardPoints` / `_awardPoints` / badge-write paths from viewmodels and repositories (REWD-04). Gamification becomes read-only + celebration reactions.
6. **Leaderboard cut** — remove Leaderboard tab and `getLeaderboard` fetch from Rewards screen (REWD-07); personal Badges + History only.

**Requirements covered:** REWD-01, REWD-02, REWD-03, REWD-04, REWD-05, REWD-06, REWD-07.
**Depends on:** Phase 3 (`mentorBotChat` writes `/sessions/{sid}/messages/{mid}` with `clientRequestId`, `role`, `createdAt`; usage docs server-only).

**Explicitly out of scope (later phases):** Stripe/premium claims implementation (Phase 5 — only default claims here), FCM, UI polish, global/cohort leaderboard (v2), admin panel.

</domain>

<decisions>
## Implementation Decisions

### Trigger topology (REWD-01)

- **D-01: Event source = `/sessions/{sessionId}/messages/{messageId}` document writes.** Phase 3 persists each user+assistant pair as message docs in this subcollection (`functions/src/index.ts`). The trigger uses `onDocumentWritten` (v2) with path `sessions/{sessionId}/messages/{messageId}`. Do NOT trigger only on parent `/sessions/{sid}` metadata updates — awards key off new **assistant** message docs (session completion signal) and user message metadata (`imageUrl`, `clientRequestId`).

- **D-02: Idempotency key = `clientRequestId` on the message doc + ledger dedupe.** Eventarc is at-least-once. Before awarding, transaction reads `/rewards/{uid}/ledger` query `where('clientRequestId','==', id).limit(1)` OR stores `dedupeKey: '{sessionId}:{clientRequestId}:{awardType}'` on ledger entries. Never award twice for the same trigger delivery.

- **D-03: Award policy lives in `functions/src/lib/rewards.ts` (new).** Port the authoritative point map from `lib/application/viewmodels/rewards/gamification_viewmodel.dart` `_pointsMap` verbatim:

  | Action key | Points |
  |------------|--------|
  | `daily_login` | 5 |
  | `complete_session` | 10 |
  | `five_questions_session` | 15 |
  | `upload_diagram` | 20 |
  | `daily_challenge` | 25 |
  | `streak_7` | 50 |
  | `streak_30` | 200 |
  | `earn_badge` | 30 |

  Badge catalog IDs match `gamification_viewmodel.dart` `_catalog`: `first_step`, `curious_learner`, `dedicated_learner`, `week_warrior`, `month_master`, `diagram_detective`, `subject_expert`. Threshold logic runs server-side using counters on `/users/{uid}` (same fields the client already reads for eligibility).

- **D-04: Award events (minimum v1.0 set).**
  - **First message of UTC+6 day** (Dhaka date via shared `QUOTA_TZ` / `getDhakaDateKey()` from `functions/src/lib/quota.ts`): `daily_login` (+5) once per day — gate with `/users/{uid}/usage/{dateKey}.loginRewarded` or ledger dedupe for `daily_login`+date.
  - **First assistant message in a session** (parent `messageCount` transitions 0→≥1 OR first `role=='assistant'` doc): `complete_session` (+10).
  - **Image user message** (`role=='user'` && `imageUrl` present): increment diagram counter; at 10 total → `diagram_detective` badge + `earn_badge` bonus.
  - **Session/question thresholds**: 5 sessions → `dedicated_learner`; 50/100 questions → badges per catalog; streak 7/30 → `week_warrior` / `month_master`.
  - Streak updates remain on `/users/{uid}` but **written only by trigger** (not client).

- **D-05: Failure isolation.** Rewards transaction failure MUST NOT roll back chat. Chat already committed in Phase 3 callable. Log `functions.logger.error` with `uid`, `sessionId`, `messageId`; optional dead-letter doc under `/system/rewards_errors/{id}` for admin inspection (server-only rules).

### Ledger schema (REWD-03)

- **D-06: Ledger doc shape** at `/rewards/{uid}/ledger/{autoId}`:

  ```ts
  {
    type: string,           // e.g. 'complete_session', 'earn_badge'
    amount: number,         // points delta (positive)
    clientRequestId?: string,
    sessionId?: string,
    messageId?: string,
    badgeId?: string,       // when type relates to badge
    awardedAt: Timestamp,   // server
    awardedBy: 'cloudFunction:onMessageWrite@v1',
  }
  ```

- **D-07: Parent `/rewards/{uid}` mirror fields** — keep `points` (int), `badges` (string[]), `userId` for backward-compatible streams. Trigger updates parent via transaction: `increment(points)`, `arrayUnion(badges)`. **Remove `history` array writes**; client History tab reads **ledger subcollection** paginated (`orderBy('awardedAt','desc').limit(50)`).

- **D-08: Migration** — one-shot script or callable `migrateRewardsHistory` (admin-only, run once): for each `/rewards/{uid}` with non-empty `history[]`, append ledger docs then `FieldValue.delete()` on `history`. Document in `BACKEND_SETUP.md ## Phase 4`. If no prod users yet, migration can be noop with a test fixture only.

### onUserCreate (REWD-02)

- **D-09: Auth `beforeUserCreated` or `onUserCreated` (v2)** — on new Firebase Auth user:
  1. `setCustomUserClaims(uid, { role: 'student', premium: false })` via Admin SDK (implement in `functions/src/lib/claims.ts` — replace Phase 5 stub for `getRole` only if needed; `setPremium` stays stub until Phase 5).
  2. Create `/rewards/{uid}` with `{ userId: uid, points: 0, badges: [] }` if absent.
  3. Do not duplicate `/users/{uid}` creation (still client registration flow).

### Rules lockdown (REWD-05, REWD-06)

- **D-10: Atomic deploy** — single command: `firebase deploy --only firestore:rules,functions` (or targeted function names). **Never** deploy rules lockdown without triggers live (bricks legitimate awards); **never** deploy triggers without rules (clients can still cheat during overlap).

- **D-11: Rules changes (concrete).**
  - `/users/{uid}`: self `update` MUST reject changes to `points`, `badges`, `streakDays` (use `request.resource.data.diff(resource.data).affectedKeys().hasAny(['points','badges','streakDays']) == false` for owner updates). Admin override unchanged.
  - `/rewards/{uid}`: `allow create, update: if false` for clients; `allow read: if isOwner(uid) || isAdmin()`.
  - `/rewards/{uid}/ledger/{lid}`: `allow read: if isOwner(uid) || isAdmin(); allow write: if false`.
  - `/sessions/{sid}/messages/{mid}`: change from client `write` to **read-only for owner** (Phase 3 callable uses Admin SDK). Parent session: client may still read; create/update of messages **false** for clients.

- **D-12: Rules unit tests** — extend `functions/src/__tests__/rules.test.ts`:
  - **FAIL before lockdown** tests (document expected flip): client cannot increment `points` on `/users/{uid}`.
  - **PASS after lockdown**: same assertions green.
  - Client cannot write `/rewards/{uid}/ledger/*`.
  - Requires Firestore emulator (`FIRESTORE_EMULATOR_HOST`).

### Client cleanup (REWD-04, REWD-07)

- **D-13: Delete write paths.**
  - `RewardsRepository.awardPoints`, `awardPointsBatch`, `addBadge`, `addBadgesBatch` — remove or hard-fail with `UnsupportedError` + delete all call sites.
  - `UsersRepository` point increment helpers used for rewards.
  - `ChatViewModel._awardPoints` and `unawaited(_awardPoints('complete_session'))`.
  - `GamificationViewModel.awardPoints` public API — replace with server-driven stream only; keep `badgeEarnedStream` by diffing `badges` array on `/rewards/{uid}` snapshots.
  - `DashboardViewModel` daily reward / streak point writes — server handles via trigger + usage doc.

- **D-14: History UI** — `RewardsViewModel` / screen History tab loads `RewardsRepository.watchLedger(uid)` (new stream) instead of `history` array on parent doc.

- **D-15: Leaderboard removal** — Remove third tab from `rewards_screen.dart`; delete `_LeaderboardTab`, `fetchLeaderboard` from `rewards_viewmodel.dart`, and gamification leaderboard state if unused. Keep `LeaderboardEntry` model file until Phase 7 cleanup or delete if zero refs.

### Testing + PR sequencing

- **D-16: PR boundaries.**
  - **PR-1 (server):** `functions/src/triggers/on_message_write.ts`, `on_user_create.ts`, `lib/rewards.ts`, unit tests with fake Firestore (or emulator harness).
  - **PR-2 (rules + rules tests):** `firestore.rules` + expanded `rules.test.ts`.
  - **PR-3 (client):** remove client writes, ledger stream, UI tab cut, widget tests updated.

  Each PR must keep CI green: `(cd functions && npm test)` + `flutter test`.

- **D-17: Jest coverage targets** — idempotency double-fire, daily_login once per Dhaka day, complete_session once per session, badge threshold edge, onUserCreate claims + rewards doc.

### Claude's Discretion

- Exact trigger export names and file layout under `functions/src/triggers/`.
- Whether streak is updated in the same transaction as points or a follow-up write.
- Migration implementation (script vs admin callable) as long as BACKEND_SETUP documents the manual step.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap & requirements
- `.planning/ROADMAP.md` — Phase 4 success criteria (lines 86–99)
- `.planning/REQUIREMENTS.md` — REWD-01..REWD-07
- `.planning/STATE.md` — Phase 3 closeout notes, pending manual follow-ups

### Architecture & pitfalls
- `.planning/research/ARCHITECTURE.md` — § Flow B (server-authoritative rewards), §8 build order (Phase 4), anti-patterns (double-write, idempotency)
- `.planning/research/PITFALLS.md` — ledger subcollection vs arrayUnion, rules lockdown checklist
- `.planning/research/SUMMARY.md` — Flow B diagram

### Phase 3 handoff
- `.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-CONTEXT.md` — D-08 message subcollection, D-17 rules deferred to Phase 4
- `functions/src/index.ts` — `mentorBotChat` session/message write shape
- `functions/src/lib/quota.ts` — `getDhakaDateKey()` for daily_login alignment

### Client gamification (port to server)
- `lib/application/viewmodels/rewards/gamification_viewmodel.dart` — `_pointsMap`, `_catalog`, eligibility helpers
- `lib/data/repositories/rewards_repository.dart` — current client write paths to remove
- `lib/presentation/screens/rewards/rewards_screen.dart` — Leaderboard tab to remove

### Security
- `firestore.rules` — current permissive `/rewards` and `/users` update rules (lines 49–94, 114–119)
- `functions/src/lib/claims.ts` — stub to partially implement for onUserCreate

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `functions/src/lib/quota.ts` — `getDhakaDateKey()` for daily_login alignment with rate limits (AI-04 / Phase 3).
- `functions/src/lib/admin.ts` — Firestore + Auth admin singleton.
- `functions/src/__tests__/rules.test.ts` — Phase 3 rules harness; extend for REWD-06.
- `GamificationViewModel.badgeEarnedStream` — keep; feed from `/rewards/{uid}` badge array diffs instead of client-side `addBadge`.
- `RewardsRepository.watchRewards` — keep parent doc stream; add `watchLedger`.

### Established Patterns
- Phase 3: Admin SDK writes bypass rules; clients read usage docs.
- Repository pattern in `lib/data/repositories/`; viewmodels must not import `cloud_firestore` for writes.
- Point action keys are string constants shared conceptually between Dart `_pointsMap` and TS `rewards.ts`.

### Integration Points
- Trigger fires after `mentorBotChat` message write → client `GamificationViewModel` / `RewardsViewModel` streams update → `badgeEarnedEventProvider` (Phase 7 overlay) can listen unchanged.
- `chat_viewmodel.dart` stops calling `_awardPoints`; completion signal is implicit when assistant message lands in Firestore.

</code_context>

<specifics>
## Specific Ideas

- User decision (roadmap): global + cohort leaderboard **cut** from v1.0 — personal stats only.
- User decision: trigger + rules lockdown **same deploy** — non-negotiable per ARCHITECTURE §8.
- Phase 3 manual follow-up: run production chat smoke while validating Phase 4 trigger awards end-to-end.

</specifics>

<deferred>
## Deferred Ideas

- Global / cohort leaderboard (v2).
- `setPremium` / Stripe claims (Phase 5).
- `BadgeCelebrationOverlay` full UI polish (Phase 7) — Phase 4 keeps stream contract.
- Session message client writes — locked to server in Phase 4; if tutor offline compose needs local drafts, that's Phase 7 scope.

</deferred>

---

*Phase: 04-Server-Authoritative Rewards + Rules Lockdown*
*Context gathered: 2026-05-25*
