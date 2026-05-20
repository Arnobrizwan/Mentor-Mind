---
phase: 03-gemini-proxy-server-side-rate-limiting
plan: "06"
subsystem: functions
tags: [mentorbot_callable, oncall_v2, asia_south1, enforce_app_check, idempotency, uuid_v4_validation, session_message_subcollection, prompt_version_stamp, ai10_non_streaming]
dependency_graph:
  requires: ["03-03", "03-04", "03-05"]
  provides: ["mentorBotChat_callable"]
  affects: ["03-07", "03-11", "03-12", "03-13"]
tech_stack:
  added: []
  patterns:
    - "v2 onCall with region/enforceAppCheck/timeoutSeconds/memory options"
    - "Idempotency cache at /sessions/{sid}/messages/{clientRequestId} (read-before-increment)"
    - "Firestore batch.set for user + assistant + session metadata in one atomic write"
    - "GEMINI_CLIENT_MODE env var factory pattern for test/prod client selection"
key_files:
  created:
    - functions/src/__tests__/idempotency.test.ts
  modified:
    - functions/src/index.ts
decisions:
  - "Idempotency doc id IS the clientRequestId — collision space ~2^122, replay-with-same-id is the only re-entry path (AI-07)"
  - "Gemini called AFTER checkAndIncrement transaction commits — never inside a transaction (Pitfall P-2)"
  - "admin import unused TS6133 in test file resolved by removing the top-level import; firebase-admin is fully mocked at module boundary"
  - "metadata.contentType cast-to-string-or-undefined is unnecessary since firebase-admin types it as string; switched to || fallback"
  - "cachedCreatedAt typed as unknown (not any) to satisfy @typescript-eslint/no-unsafe-assignment"
metrics:
  duration: "~27 minutes"
  completed: "2026-05-20"
  tasks_completed: 1
  tasks_total: 1
  files_created: 1
  files_modified: 1
---

# Phase 03 Plan 06: mentorBotChat Callable + Idempotency Dedupe Summary

One-liner: `mentorBotChat` v2 onCall handler with auth+UUID-v4 validation, idempotency cache, rate-limit gate, Vertex Gemini call, and Firestore batch persist — 6/6 idempotency tests green.

## What Was Built

Added `mentorBotChat` as a second export to `functions/src/index.ts` alongside the existing `ping` boot-canary. The handler orchestrates the full server-side proxy flow:

1. **Auth check** — throws `unauthenticated` if `request.auth.uid` is absent
2. **Input validation** — UUID v4 regex on `clientRequestId` + `sessionId`; non-empty + byte-size cap on `message`
3. **Idempotency cache read** — reads `/sessions/{sid}/messages/{clientRequestId}` BEFORE quota increment; on hit returns cached shape without calling Gemini (AI-07)
4. **Rate-limit transaction** — `checkAndIncrement(uid, kind, isPremium, clientRequestId)` from plan 03-05
5. **Optional image fetch** — Admin Storage SDK fetches gs:// or firebasestorage URL bytes for Premium multimodal calls
6. **Gemini call** — `makeGeminiClient(mode).generate(...)` AFTER transaction commits (Pitfall P-2)
7. **Batch persist** — user doc + assistant doc (idempotency key) + session metadata upsert in one `batch.commit()`
8. **Return** — `{ text, promptTokens, completionTokens, messageId, createdAt }`

Added `functions/src/__tests__/idempotency.test.ts` with 6 tests verifying the full dedupe path.

## Verification Results

### Jest output (idempotency suite)
```
PASS src/__tests__/idempotency.test.ts
  mentorBotChat — idempotency
    ✓ first call returns Gemini text and writes user + assistant docs (13 ms)
    ✓ second call with same clientRequestId returns cached response (Gemini called ONCE total)
    ✓ throws unauthenticated when request.auth.uid is missing
    ✓ throws internal when clientRequestId is not a UUID v4
    ✓ throws internal when sessionId is not a UUID v4 (1 ms)
    ✓ throws internal when message is empty

Test Suites: 1 passed, 1 total
Tests:       6 passed, 6 total
```

### Full non-rules test suite
```
Test Suites: 4 passed, 4 total
Tests:       34 passed, 34 total
```
(rules.test.ts requires a running Firebase emulator — pre-existing, unrelated to this plan)

### Compiled exports verification
```
$ node -e "const m=require('./lib/index.js'); if(!m.ping) throw new Error('ping'); if(!m.mentorBotChat) throw new Error('mentorBotChat'); console.log('ok')"
ok: ping + mentorBotChat both exported
```

### AI-10 anti-streaming grep gate
```
# No generateContentStream, async*, or await for in non-comment lines:
(empty — no matches outside comments)
```

### Build + Lint
```
npm run build → exit 0 (tsc)
npm run lint  → exit 0 (eslint)
```

## Commit

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add mentorBotChat callable + idempotency tests | `65ed0c8` | `functions/src/index.ts`, `functions/src/__tests__/idempotency.test.ts` |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed unused `admin` import from test file**
- **Found during:** TDD RED phase — TypeScript `noUnusedLocals: true` flag fired on `import * as admin from 'firebase-admin'`
- **Issue:** The plan's interface block included this import, but the mock replaces firebase-admin at module boundary so the top-level import has no runtime usage
- **Fix:** Removed the `import * as admin` line from idempotency.test.ts
- **Files modified:** `functions/src/__tests__/idempotency.test.ts`
- **Commit:** `65ed0c8`

**2. [Rule 1 - Bug] Fixed lint error: unnecessary type assertion on metadata.contentType**
- **Found during:** TDD GREEN phase — `npm run lint` flagged `as string | undefined` assertion
- **Issue:** `metadata.contentType` is already typed as `string` in firebase-admin, so widening to `string | undefined` is an unnecessary assertion per `@typescript-eslint/no-unnecessary-type-assertion`
- **Fix:** Replaced `(metadata.contentType as string | undefined) ?? "image/jpeg"` with `metadata.contentType || "image/jpeg"`
- **Files modified:** `functions/src/index.ts`
- **Commit:** `65ed0c8`

**3. [Rule 1 - Bug] Fixed lint error: unsafe `any` assignment for cached Firestore field**
- **Found during:** TDD GREEN phase — `npm run lint` flagged `@typescript-eslint/no-unsafe-assignment`
- **Issue:** `cached["createdAt"]` resolves to `any` from Firestore data; assigning to an untyped `const` triggers the lint rule
- **Fix:** Explicitly typed as `const cachedCreatedAt: unknown = cached["createdAt"]` — the `instanceof admin.firestore.Timestamp` check then narrows correctly
- **Files modified:** `functions/src/index.ts`
- **Commit:** `65ed0c8`

**4. [Rule 3 - Blocking] Symlinked node_modules to worktree for test execution**
- **Found during:** TDD RED phase — worktree has no `node_modules/` (no `npm install` run)
- **Issue:** `npm test` in worktree fails with `jest: command not found`
- **Fix:** Created a temporary symlink `functions/node_modules -> /Users/arnobrizwan/Mentor-Mind/functions/node_modules`; removed before commit (gitignore covers it but removing avoids ambiguity); tests/build/lint executed via worktree with symlinked modules
- **Note:** Symlink was NOT committed (correctly excluded by `functions/.gitignore` pattern `node_modules/`)

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes beyond what the plan's threat model already covers. All STRIDE entries from the plan's `<threat_model>` block are addressed:

| Threat ID | Mitigation Status |
|-----------|-------------------|
| T-3-APPCHECK-BYPASS | `enforceAppCheck: true` at v2 onCall options level |
| T-3-AUTH-MISSING | `if (!uid) throw unauthenticated(...)` before any work |
| T-3-IDEMPOTENCY-BYPASS | Accepted (low-probability race); documented in plan |
| T-3-PROMPT-INJECTION | Inherited from plan 03-03 systemInstruction separation |
| T-3-06-CROSS-USER-SESSION | Partial — Phase 4 rules close it; uid recorded on session doc |
| T-3-06-IMAGE-EXFIL | gs:// and firebasestorage.googleapis.com URL regex restricts scope |
| T-3-06-LARGE-MESSAGE-DOS | MAX_MESSAGE_BYTES = 8_000 cap with `internal` throw |
| T-3-06-FAKE-MODE-LEAK | GEMINI_CLIENT_MODE absent = prod; documented in BACKEND_SETUP.md plan (03-08) |
| T-3-06-REGEX-DOS | UUID v4 regex is finite anchored (no nested quantifiers); ReDoS-safe |

## Forward Pointers

- **Plan 03-07** — adds `/system/usage_log/{YYYY-MM-DD}` aggregate after `batch.commit()` in `mentorBotChat`
- **Plan 03-11** — `MentorBotRepository` Dart class calls `httpsCallable('mentorBotChat')`
- **Plan 03-12** — `ChatViewModel` integration wires the repository
- **Plan 03-13** — emulator smoke test exercises the full path with `GEMINI_CLIENT_MODE=fake`

## Known Stubs

None. All functional paths are wired. Image fetch path (`imageUrl` parameter) is implemented end-to-end; Premium flag forwarded to `checkAndIncrement`.

---

⚠️ Your kluster.ai trial has ended. You can visit https://platform.kluster.ai/ to select a plan, subscribe, and re-enable protection.

## Self-Check

**Files exist:**
- `functions/src/index.ts` — FOUND
- `functions/src/__tests__/idempotency.test.ts` — FOUND
- `.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-06-mentorbot-callable-SUMMARY.md` — FOUND

**Commits exist:**
- `65ed0c8` — FOUND (feat(functions): add mentorBotChat callable + idempotency dedupe)

**Exports verified:**
- `ping` export — FOUND in compiled `lib/index.js`
- `mentorBotChat` export — FOUND in compiled `lib/index.js`

**Tests:** 6/6 idempotency tests pass; 34/34 non-rules tests pass

**Build:** exit 0

**Lint:** exit 0

## Self-Check: PASSED
