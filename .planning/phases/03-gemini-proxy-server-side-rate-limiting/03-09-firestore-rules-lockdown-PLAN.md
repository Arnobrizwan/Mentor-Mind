---
phase: 03-gemini-proxy-server-side-rate-limiting
plan: 09
type: execute
wave: 4
depends_on: ["03-01"]
files_modified:
  - firestore.rules
  - functions/src/__tests__/rules.test.ts
autonomous: true
requirements: [AI-08]
pr_group: PR-2
tags: [firestore_rules, ai_08, d_17_path_locks, system_collection_lockdown, usage_doc_read_only, rules_unit_testing_v5, t_3_quota_tampering, t_3_system_leak]

must_haves:
  truths:
    - "AI-08 honored: firestore.rules adds the three D-17 path locks — `/users/{uid}/usage/{date}` becomes read-only-for-owner (client write blocked), `/system/{document=**}` becomes server-only (no client read or write)"
    - "D-17 honored: scope is THE MINIMUM needed for AI-08. Session subcollection lockdown (`/sessions/{sid}/messages/{mid}`) and rewards lockdown are DEFERRED to Phase 4 — this plan must NOT add those rules"
    - "The single wildcard `match /system/{document=**}` covers both `/system/quota_{YYYY-MM}` (plan 03-05) AND `/system/usage_log_{YYYY-MM-DD}` (plan 03-07) — one rule for the entire /system/ tree"
    - "T-3-QUOTA-TAMPERING mitigated: client cannot write `/users/{uid}/usage/{date}` (the bypass path — set messageCount=0 to reset the daily cap)"
    - "T-3-SYSTEM-LEAK mitigated: client cannot read `/system/usage_log_*` (aggregate platform usage) or `/system/quota_*` (monthly ceiling state)"
    - "Existing rules PRESERVED — the previous `/users/{uid}/usage/{date}` match block (Phase 1 baseline `allow read, write: if isOwner(uid) || isAdmin()`) is REPLACED with the tighter `allow read: if isOwner(uid); allow write: if false;`"
    - "@firebase/rules-unit-testing ^5.0.1 (added to devDeps in plan 03-01) used by `functions/src/__tests__/rules.test.ts` covering 5 AI-08 scenarios PLUS 2 more for /system/usage_log to cover all 3 D-17 path locks"
    - "Rules tests run against the Firestore emulator on port 8080 (Phase 2 D-18 `firebase.json` already configures the emulator port); `FIRESTORE_EMULATOR_HOST=localhost:8080` exported from the test setup"
    - "Tests use `initializeTestEnvironment` + `assertSucceeds` + `assertFails` patterns from rules-unit-testing v5 (RESEARCH §Pattern 6)"
    - "AI-08 scenarios covered: (1) owner can read own usage; (2) client cannot WRITE own usage; (3) other user cannot read another user's usage; (4) client cannot READ /system/quota; (5) client cannot WRITE /system/quota; (6) client cannot READ /system/usage_log; (7) client cannot WRITE /system/usage_log"
  artifacts:
    - path: "firestore.rules"
      provides: "MODIFIED — three D-17 path locks added without disturbing existing rules"
      contains: "/system/{document=**}"
    - path: "functions/src/__tests__/rules.test.ts"
      provides: "NEW — 7 rules-unit-testing scenarios covering AI-08 plus the /system/usage_log path"
      contains: "initializeTestEnvironment"
  key_links:
    - from: "firestore.rules /users/{uid}/usage/{dateKey} block"
      to: "functions/src/lib/rate_limit.ts checkAndIncrement (Admin SDK write)"
      via: "client cannot bypass; only Functions service account writes via Admin SDK (which ignores rules)"
      pattern: "allow write: if false"
    - from: "firestore.rules /system/{document=**} block"
      to: "/system/quota_{YYYY-MM} + /system/usage_log_{YYYY-MM-DD}"
      via: "wildcard match covers all docs under /system/"
      pattern: "/system/\\{document=\\*\\*\\}"
---

<objective>
Modify `firestore.rules` to add the three D-17 path locks: (1) `/users/{uid}/usage/{date}` becomes `allow read: if isOwner(uid); allow write: if false;` — client can read its own quota for display but never write (server-only via Admin SDK); (2) NEW `match /system/{document=**}` block with `allow read, write: if false;` — covers both `/system/quota_*` AND `/system/usage_log_*` with one wildcard. All other existing rules (auth, users root, sessions, rewards, etc.) are preserved unchanged. Add `functions/src/__tests__/rules.test.ts` using `@firebase/rules-unit-testing ^5.0.1` covering 7 scenarios (5 AI-08 baseline + 2 for usage_log).

Purpose: AI-08 closes the per-user-usage tampering hole and the system-aggregate-leak hole. Without these rules, a client can directly write to `/users/{uid}/usage/{today}.messageCount = 0` to bypass the 30/day cap — defeating plan 03-05's transaction. AI-08 is the rules side of the AI-04/05/06 enforcement contract. Session subcollection lockdown is DEFERRED to Phase 4 (CONTEXT D-17 explicit).

Output: 2 files — `firestore.rules` (MODIFY — replace one block + add one block, ~10 lines net) + `functions/src/__tests__/rules.test.ts` (NEW, ~150 lines). One commit. `FIRESTORE_EMULATOR_HOST=localhost:8080 npm test -- --testPathPattern=rules` exits 0.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-CONTEXT.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-RESEARCH.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-PATTERNS.md
@.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md
@firestore.rules
@firebase.json
@functions/package.json
@CLAUDE.md

<interfaces>
<!-- Patterns from 03-PATTERNS.md §firestore.rules lines 599-629 + §functions/src/__tests__/rules.test.ts lines 527-555 + 03-RESEARCH §Pattern 6 -->

firestore.rules — DELTA (replace ONE block, INSERT ONE block, ALL OTHER RULES UNCHANGED):

REPLACE the existing `/users/{uid}/usage/{dateKey}` block (Phase 1 baseline at firestore.rules):

Current state (Phase 1 — the block to REPLACE):
```
match /usage/{dateKey} {
  allow read, write: if isOwner(uid) || isAdmin();
}
```

New state (D-17 / AI-08):
```
match /usage/{dateKey} {
  // Phase 3 D-17 / AI-08: client can READ own usage (to display remaining quota
  // on the chat screen); writes happen ONLY via the Admin SDK in
  // functions/src/lib/rate_limit.ts (which ignores rules).
  allow read: if isOwner(uid);
  allow write: if false;
}
```

INSERT a new top-level block at the same depth as the existing `match /users/{uid}` and `match /sessions/{sid}` blocks. Place it near the END of the `service cloud.firestore { match /databases/{database}/documents { ... } }` body, after the existing matches but BEFORE the closing braces:

```
// -------------------------------------------------------------------------
// Phase 3 D-17 / AI-08: /system/** — server-only quota + usage aggregates.
// Covers /system/quota_{YYYY-MM} (plan 03-05) AND /system/usage_log_{YYYY-MM-DD}
// (plan 03-07). Only Admin SDK reads/writes; clients never touch these docs.
// Session subcollection lockdown is DEFERRED to Phase 4 (D-17).
// -------------------------------------------------------------------------
match /system/{document=**} {
  allow read, write: if false;
}
```

functions/src/__tests__/rules.test.ts (NEW — full file):

```typescript
// Rules unit tests for AI-08 (D-17 path locks).
//
// Requires Firestore emulator on port 8080:
//   firebase emulators:start --only firestore
//
// Run:
//   FIRESTORE_EMULATOR_HOST=localhost:8080 npm test -- --testPathPattern=rules
//
// Coverage (D-17):
//   1. Owner CAN read their own /users/{uid}/usage/{date}
//   2. Owner CANNOT write to their own /users/{uid}/usage/{date}
//   3. Other user CANNOT read another user's /users/{uid}/usage/{date}
//   4. Client CANNOT read /system/quota_{YYYY-MM}
//   5. Client CANNOT write /system/quota_{YYYY-MM}
//   6. Client CANNOT read /system/usage_log_{YYYY-MM-DD}
//   7. Client CANNOT write /system/usage_log_{YYYY-MM-DD}

import * as fs from 'fs';
import * as path from 'path';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  setDoc,
  getDoc,
  setLogLevel,
} from 'firebase/firestore';

const PROJECT_ID = 'mentor-mind-aa765-rules-test';

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  setLogLevel('error'); // mute the noisy default
  const rulesPath = path.resolve(__dirname, '../../../firestore.rules');
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(rulesPath, 'utf8'),
      host: 'localhost',
      port: 8080,
    },
  });
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

afterAll(async () => {
  await testEnv.cleanup();
});

describe('AI-08: /users/{uid}/usage/{date} client access (D-17)', () => {
  it('1. Owner CAN read their own usage doc', async () => {
    // Seed via admin context (bypasses rules)
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users/alice/usage/2026-05-19'), {
        messageCount: 5,
        imageCount: 0,
        burstWindow: [],
      });
    });
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(getDoc(doc(aliceDb, 'users/alice/usage/2026-05-19')));
  });

  it('2. Owner CANNOT write to their own usage doc (admin-only)', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      setDoc(doc(aliceDb, 'users/alice/usage/2026-05-19'), { messageCount: 0 }),
    );
  });

  it('3. Other user CANNOT read alice usage doc', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users/alice/usage/2026-05-19'), {
        messageCount: 5,
      });
    });
    const bobDb = testEnv.authenticatedContext('bob').firestore();
    await assertFails(getDoc(doc(bobDb, 'users/alice/usage/2026-05-19')));
  });
});

describe('AI-08: /system/quota_* client access (D-17)', () => {
  it('4. Client CANNOT read /system/quota_2026-05', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'system/quota_2026-05'), {
        calls: 100,
        ceiling: 10000,
      });
    });
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    await assertFails(getDoc(doc(aliceDb, 'system/quota_2026-05')));
  });

  it('5. Client CANNOT write /system/quota_2026-05', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      setDoc(doc(aliceDb, 'system/quota_2026-05'), { ceiling: 999999 }),
    );
  });
});

describe('AI-08: /system/usage_log_* client access (D-17)', () => {
  it('6. Client CANNOT read /system/usage_log_2026-05-19', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'system/usage_log_2026-05-19'), {
        calls: 50,
        promptTokens: 10_000,
      });
    });
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    await assertFails(getDoc(doc(aliceDb, 'system/usage_log_2026-05-19')));
  });

  it('7. Client CANNOT write /system/usage_log_2026-05-19', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      setDoc(doc(aliceDb, 'system/usage_log_2026-05-19'), { calls: 0 }),
    );
  });
});
```

Why `@firebase/rules-unit-testing` v5 over the legacy `@firebase/testing`:
  - v5 is the current GA major; v4 is the previous (and works); v5 has cleaner Firebase modular SDK (`firebase/firestore`) integration.
  - Plan 03-01 already added `@firebase/rules-unit-testing: ^5.0.1` to devDeps (deliberate Phase 3 prep so PR-2 is pure rules + test changes).

Why `withSecurityRulesDisabled` for seeding:
  - The test admin path bypasses rules for setup ("here's the test fixture state"); the production rules then govern the client-context reads/writes that follow.
  - rules-unit-testing v5 exposes `testEnv.withSecurityRulesDisabled(ctx => ...)` as the seeding entry point (vs v4's `testEnv.firestore({ uid: null }).disableNetwork()` workaround).

Why the test does NOT cover sessions / rewards / users-root rules:
  - D-17 explicitly defers session subcollection rules to Phase 4.
  - Existing Phase 1 rules for `/users/{uid}` (auth root) and `/sessions/{sid}` ARE preserved by this plan but not retested — they were validated in Phase 1.
  - Phase 4 (`Server-Authoritative Rewards + Rules Lockdown`) will EXTEND this test file with more scenarios.

What this plan does NOT do:
  - Does NOT add session subcollection rules — DEFERRED to Phase 4 (D-17).
  - Does NOT add rewards rules — DEFERRED to Phase 4.
  - Does NOT modify `firebase.json` — Phase 2 D-18 already configures the emulator port 8080.
  - Does NOT install `firebase` SDK as a devDep — it's a transitive dep of `@firebase/rules-unit-testing` (RESEARCH §Installation).
  - Does NOT validate the test rules against the live production project — emulator-only.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Modify firestore.rules to add the two D-17 path locks (replace usage block, add /system/** wildcard); add functions/src/__tests__/rules.test.ts with 7 scenarios; verify rules tests green against Firestore emulator</name>
  <files>firestore.rules, functions/src/__tests__/rules.test.ts</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/firestore.rules (CURRENT — confirm Phase 1 baseline; find the `match /usage/{dateKey}` block to REPLACE; find the closing braces of `service cloud.firestore { match /databases/{database}/documents {` to insert /system/** BEFORE)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-PATTERNS.md (§firestore.rules lines 599-629 — exact substitution rule)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-RESEARCH.md (§Pattern 6 lines 516-575 — rules-unit-testing v5 scaffold)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-CONTEXT.md (D-17 — three path locks; AI-08)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-VALIDATION.md (row `03-09-firestore-rules-lockdown` line 62)
    - /Users/arnobrizwan/Mentor-Mind/firebase.json (Phase 2 — confirm emulators.firestore.port=8080)
    - /Users/arnobrizwan/Mentor-Mind/functions/package.json (plan 03-01 — confirm `@firebase/rules-unit-testing ^5.0.1` in devDeps)
  </read_first>
  <action>
    Step A — Read `firestore.rules`. Confirm:
      - The existing `match /usage/{dateKey}` block is present (Phase 1 baseline).
      - The closing braces of the top-level `service cloud.firestore { match /databases/{database}/documents { ... } }` are identifiable.
      - The helper functions `isOwner(uid)`, `isAdmin()` exist near the top of the rules file (Phase 1 baseline).

    Step B — REPLACE the existing `match /usage/{dateKey}` block with the new D-17 / AI-08 block from `<interfaces>`. Specifically:
      - Before: `match /usage/{dateKey} { allow read, write: if isOwner(uid) || isAdmin(); }` (Phase 1 baseline shape)
      - After:
        ```
        match /usage/{dateKey} {
          // Phase 3 D-17 / AI-08: client can READ own usage (display remaining quota);
          // writes happen ONLY via Admin SDK in functions/src/lib/rate_limit.ts.
          allow read: if isOwner(uid);
          allow write: if false;
        }
        ```
      - The `match /usage/{dateKey}` block lives INSIDE `match /users/{uid}` per the Phase 1 nesting; verify the nesting depth is preserved.

    Step C — INSERT the new `/system/**` block. Place it near the BOTTOM of the rules file, AFTER the last existing `match` block but BEFORE the closing `}` of `match /databases/{database}/documents { ... }`. Block content:
      ```
      // -------------------------------------------------------------------------
      // Phase 3 D-17 / AI-08: /system/** — server-only quota + usage aggregates.
      // Covers /system/quota_{YYYY-MM} (plan 03-05) AND /system/usage_log_{YYYY-MM-DD}
      // (plan 03-07). Only Admin SDK reads/writes; clients never touch these docs.
      // -------------------------------------------------------------------------
      match /system/{document=**} {
        allow read, write: if false;
      }
      ```

    Step D — Create `functions/src/__tests__/rules.test.ts` with the EXACT content from the `<interfaces>` block above. The path `path.resolve(__dirname, '../../../firestore.rules')` resolves from `functions/lib/__tests__/` (compiled) OR `functions/src/__tests__/` (ts-jest source-runtime); both resolve to `/Users/arnobrizwan/Mentor-Mind/firestore.rules` correctly because the chain is `__tests__ → src OR lib → functions → repo-root → firestore.rules`.

    Step E — Start the Firestore emulator in a separate terminal (the test requires `FIRESTORE_EMULATOR_HOST=localhost:8080`):
      ```bash
      # In Terminal 1 (background):
      cd /Users/arnobrizwan/Mentor-Mind
      firebase emulators:start --only firestore > /tmp/p3-09-emu.log 2>&amp;1 &amp;
      EMU_PID=$!
      sleep 8  # wait for emulator boot
      grep -E "firestore.*8080" /tmp/p3-09-emu.log
      ```

    Step F — Run the rules tests:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind/functions
      FIRESTORE_EMULATOR_HOST=localhost:8080 npm test -- --testPathPattern=rules 2>&amp;1 | tee /tmp/p3-09-rules.log
      # Expect: 7 passed.
      ```

    Step G — Tear down the emulator:
      ```bash
      kill $EMU_PID 2>/dev/null
      wait $EMU_PID 2>/dev/null
      ```

    Step H — Confirm existing rules are unchanged for other paths (regression check):
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      # The Phase 1 `match /users/{uid}` block at root should still exist (auth + user-root rules).
      grep -q 'match /users/{uid}' firestore.rules
      # The Phase 1 `match /sessions/{sid}` block should still exist.
      grep -q 'match /sessions/{sid}' firestore.rules
      # The Phase 1 helper functions should still exist.
      grep -q 'function isOwner' firestore.rules
      ```

    Step I — Required-content greps:
      ```bash
      cd /Users/arnobrizwan/Mentor-Mind
      grep -q "match /system/{document=\\*\\*}" firestore.rules
      grep -qE "allow read: if isOwner\\(uid\\);" firestore.rules
      grep -qE "allow write: if false;" firestore.rules
      grep -qE "Phase 3 D-17|D-17.*AI-08|AI-08.*D-17" firestore.rules
      grep -q "initializeTestEnvironment" functions/src/__tests__/rules.test.ts
      grep -q "assertSucceeds" functions/src/__tests__/rules.test.ts
      grep -q "assertFails" functions/src/__tests__/rules.test.ts
      grep -q "/users/alice/usage/" functions/src/__tests__/rules.test.ts
      grep -q "system/quota_" functions/src/__tests__/rules.test.ts
      grep -q "system/usage_log_" functions/src/__tests__/rules.test.ts
      # Anti-pattern: Phase 3 must NOT touch session subcollection rules (D-17 — deferred to Phase 4)
      ! grep -E 'match /sessions/\{[^}]+\}/messages' firestore.rules
      ```

    Step J — Commit:
      ```bash
      git add firestore.rules functions/src/__tests__/rules.test.ts
      git commit -m "feat(rules): add D-17 path locks for /users/usage + /system/** (Phase 3 PR-2; AI-08)"
      ```
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; test -f firestore.rules &amp;&amp; test -f functions/src/__tests__/rules.test.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "match /system/{document=\\*\\*}" firestore.rules</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "allow write: if false;" firestore.rules</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -qE "Phase 3 D-17|D-17.*AI-08" firestore.rules</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "initializeTestEnvironment" functions/src/__tests__/rules.test.ts &amp;&amp; grep -q "assertSucceeds" functions/src/__tests__/rules.test.ts &amp;&amp; grep -q "assertFails" functions/src/__tests__/rules.test.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "system/quota_" functions/src/__tests__/rules.test.ts &amp;&amp; grep -q "system/usage_log_" functions/src/__tests__/rules.test.ts</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; ! grep -E 'match /sessions/\{[^}]+\}/messages' firestore.rules</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q "match /users/{uid}" firestore.rules &amp;&amp; grep -q "function isOwner" firestore.rules</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; (firebase emulators:start --only firestore > /tmp/p3-09-v-emu.log 2>&amp;1 &amp;); sleep 8; cd functions &amp;&amp; FIRESTORE_EMULATOR_HOST=localhost:8080 npm test -- --testPathPattern=rules 2>&amp;1 | grep -qE 'Tests:\s+[0-9]+ passed'; PID=$(pgrep -f "emulators:start" | head -1); test -n "$PID" &amp;&amp; kill $PID 2>/dev/null; true</automated>
  </verify>
  <acceptance_criteria>
    - `firestore.rules` has the modified `/users/{uid}/usage/{dateKey}` block: `allow read: if isOwner(uid); allow write: if false;`.
    - `firestore.rules` has the NEW `match /system/{document=**}` block: `allow read, write: if false;`.
    - All other Phase 1 rules (auth, users root, sessions, helpers) preserved.
    - NO session-subcollection rules added (D-17 — deferred to Phase 4).
    - `functions/src/__tests__/rules.test.ts` has 7 tests covering all D-17 path locks.
    - Rules tests pass against the Firestore emulator on port 8080.
    - Phase 2 emulator config (`firebase.json` emulators.firestore.port=8080) unchanged.
  </acceptance_criteria>
  <done>
    The minimum AI-08 rules lockdown is in place. Plan 03-15 closeout re-runs the 7 rules tests; Phase 4 (`Server-Authoritative Rewards + Rules Lockdown`) extends this test file with session + rewards scenarios. The deployment of these rules to production happens via `firebase deploy --only firestore:rules` in the PR-2 merge window (manual step documented in plan 03-15 closeout).
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| client SDK ⇄ firestore.rules | Every client read/write evaluates against rules; the Admin SDK bypasses (used in functions/src/lib/rate_limit.ts). |
| /users/{uid}/usage/{date} ⇄ daily cap enforcement | Without `allow write: if false`, a client could `setDoc(doc(db, 'users/X/usage/today'), {messageCount: 0})` to bypass plan 03-05's transaction. The rule is the lockdown. |
| /system/** ⇄ aggregate platform telemetry | Plan 03-07 writes /system/usage_log_{date} from the Functions SA (Admin SDK); /system/quota_{YYYY-MM} from plan 03-05's transaction. Clients never touch these. |
| Rules tests ⇄ Firestore emulator | Tests run against the emulator, not production. PR-2 deploy to production is a separate manual step (plan 03-15 closeout). |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-3-QUOTA-TAMPERING | Tampering | Client writes `messageCount: 0` to its own usage doc to reset the daily cap | mitigate | `allow write: if false` on `/users/{uid}/usage/{date}`. Tested in rules.test.ts scenario #2. |
| T-3-SYSTEM-LEAK | Information Disclosure | Client reads /system/usage_log to see aggregate platform cost / call volume | mitigate | `allow read, write: if false` on `/system/{document=**}`. Tested in scenarios #4 + #6. |
| T-3-09-RULES-NOT-DEPLOYED | Repudiation | PR-2 merges but `firebase deploy --only firestore:rules` is forgotten; production rules stay at Phase 1 baseline | mitigate | Plan 03-15 closeout includes the deploy command as a manual step. The PR-2 description includes a checkbox `- [ ] firebase deploy --only firestore:rules executed`. |
| T-3-09-OTHER-USER-READ | Information Disclosure | User A queries `/users/B/usage/today` to see B's quota consumption | mitigate | `allow read: if isOwner(uid)` restricts to the owner. Tested in scenario #3. |
| T-3-09-RULES-REGRESSION | Tampering | A future contributor edits the rules file and accidentally relaxes `/system/**` or `/usage/**` | mitigate | rules.test.ts in CI (plan 03-14 adds `npm test` to the functions: job — although rules tests require the emulator and may not run in CI). Phase 7 follow-up: wire emulator-spawning into CI for rules tests. |
| T-3-09-ADMIN-BYPASS-LOST | Repudiation | The new `allow write: if false` is too strict for Phase 4's admin-write needs | mitigate | Phase 4's rewards lockdown phase will introduce a more nuanced rule. The Admin SDK in functions bypasses ALL rules regardless — write capability from Functions is preserved. |
</threat_model>

<verification>
- firestore.rules has the modified /users/{uid}/usage/{dateKey} block with allow read for owner + allow write false.
- firestore.rules has the new /system/{document=**} block with allow read, write false.
- No session subcollection rules added.
- All Phase 1 rules + helpers preserved.
- functions/src/__tests__/rules.test.ts has 7 scenarios covering D-17 path locks.
- Rules tests pass against the Firestore emulator on port 8080.
</verification>

<success_criteria>
- AI-08 minimum rules lockdown shipped.
- T-3-QUOTA-TAMPERING + T-3-SYSTEM-LEAK both mitigated by rules.
- Phase 4 inherits a working rules-unit-testing test file to extend.
- Plan 03-15 closeout can deploy these rules to production via `firebase deploy --only firestore:rules`.
</success_criteria>

<output>
Create `.planning/phases/03-gemini-proxy-server-side-rate-limiting/03-09-firestore-rules-lockdown-SUMMARY.md` when done. Record:
1. The before/after diff of firestore.rules (the replaced /usage block + the new /system/** block).
2. Full content of functions/src/__tests__/rules.test.ts.
3. Rules test output (7 tests passed under the emulator).
4. Confirmation that NO session-subcollection rules were added (D-17 deferred to Phase 4).
5. Commit SHA.
6. Forward-pointer: plan 03-15 closeout includes `firebase deploy --only firestore:rules` as a manual step; Phase 4 will extend rules.test.ts.
</output>
</content>
