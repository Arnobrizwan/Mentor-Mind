---
phase: 02-cloud-functions-scaffolding-app-check
plan: 04
type: execute
wave: 2
depends_on: ["02-01"]
files_modified:
  - firebase.json
autonomous: true
requirements: [FUNC-06]
pr_group: PR-1
tags: [firebase_emulator, firebase_json, functions_port_5001, emulators_block]

must_haves:
  truths:
    - "D-18 honored: firebase.json emulators block extends to add `functions: { port: 5001 }`"
    - "Block ordering preserved: auth(9099) → firestore(8080) → storage(9199) → functions(5001) → ui(4000)"
    - "Port 5001 is the Firebase default (RESEARCH §Specifics + PATTERNS.md self-modify rule); matches `useFunctionsEmulator('localhost', 5001)` calls in Plan 02-07 (firebase_functions_provider) and Plan 02-08 (emulator_setup + main.dart)"
    - "firebase.json is a single-line JSON file in this repo today — edit MUST preserve compactness OR re-format consistently (pretty-print is acceptable post-edit)"
    - "After edit, `firebase emulators:start --only functions` boots the emulator with `ping[asia-south1]` registered (assumes Plan 02-03 shipped the compiled lib/index.js)"
  artifacts:
    - path: "firebase.json"
      provides: "Adds emulators.functions.port=5001 so `firebase emulators:start` can host the ping callable"
      contains: "\"functions\""
  key_links:
    - from: "firebase.json emulators.functions.port"
      to: "functions/package.json main = lib/index.js"
      via: "firebase emulators:start --only functions loads lib/index.js"
      pattern: "lib/index.js"
    - from: "firebase.json emulators.functions.port = 5001"
      to: "Plan 02-08's useFunctionsEmulator('localhost', 5001)"
      via: "port literal must match"
      pattern: "5001"
---

<objective>
Extend the existing `firebase.json` emulators block with a single new entry: `"functions": {"port": 5001}`. Insert between the existing `"storage"` entry and the `"ui"` entry. Port 5001 is the Firebase default and matches every `useFunctionsEmulator('localhost', 5001)` call that lands in Plans 02-07 / 02-08.

Purpose: Plan 02-03 shipped the `ping` callable but the Firebase Functions emulator cannot host it without an entry in firebase.json's emulators block. With this entry, `firebase emulators:start --only functions` boots the emulator at localhost:5001 and registers `ping[asia-south1]`. Plan 02-09's `ping_smoke_test.dart` then calls `httpsCallable('ping')` against this emulator.

Output: One file modified — `firebase.json`. After commit, `firebase emulators:start --only functions` boots the emulator and stdout shows `ping[asia-south1]` registered. The phase 1 integration test (login_smoke_test.dart) continues to work because the emulator-only-functions flag is additive — running with `--only auth,firestore,storage,functions` (or the default `firebase emulators:start`) still starts all four.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-CONTEXT.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-RESEARCH.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-PATTERNS.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-VALIDATION.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-01-functions-monorepo-scaffold-PLAN.md
@.planning/phases/02-cloud-functions-scaffolding-app-check/02-03-ping-callable-PLAN.md
@firebase.json
@CLAUDE.md

<interfaces>
<!-- Self-modify pattern from 02-PATTERNS.md (lines 324-339) -->

firebase.json — CURRENT state (single-line JSON; minified):
  ```json
  {"firestore":{"rules":"firestore.rules","indexes":"firestore.indexes.json"},"storage":{"rules":"storage.rules"},"emulators":{"auth":{"port":9099},"firestore":{"port":8080},"storage":{"port":9199},"ui":{"enabled":true,"port":4000}},"flutter":{...}}
  ```

firebase.json — DESIRED state (after this plan; extending emulators block only):
  ```json
  {
    "firestore": {"rules": "firestore.rules", "indexes": "firestore.indexes.json"},
    "storage": {"rules": "storage.rules"},
    "emulators": {
      "auth": {"port": 9099},
      "firestore": {"port": 8080},
      "storage": {"port": 9199},
      "functions": {"port": 5001},
      "ui": {"enabled": true, "port": 4000}
    },
    "flutter": { ...preserved as-is... }
  }
  ```

  Equivalent minified (acceptable if the team prefers single-line JSON):
  ```json
  {"firestore":{"rules":"firestore.rules","indexes":"firestore.indexes.json"},"storage":{"rules":"storage.rules"},"emulators":{"auth":{"port":9099},"firestore":{"port":8080},"storage":{"port":9199},"functions":{"port":5001},"ui":{"enabled":true,"port":4000}},"flutter":{...preserved...}}
  ```

Insertion point: AFTER `"storage":{"port":9199}` and BEFORE `"ui":{"enabled":true,"port":4000}`. This preserves the auth → firestore → storage → functions → ui ordering per 02-PATTERNS.md self-modify rule.

What this plan does NOT do:
  - Does NOT change auth/firestore/storage/ui ports.
  - Does NOT add a `functions` top-level key (only the emulators.functions key — firebase emulators:start picks up source from functions/package.json automatically via the `--only functions` flag + the on-disk presence of `functions/` directory).
  - Does NOT add a `source: "functions"` config — firebase-tools auto-detects the `functions/` directory at the project root when `functions/package.json` exists. If the team prefers explicit configuration, add `"functions": {"source": "functions"}` as a SIBLING of `"emulators"` at the top level (not under emulators) — this is a discretionary addition and would prepare for `firebase deploy --only functions:ping` in Phase 3.

Discretionary addition (recommended):
  - Add `"functions": [{"source": "functions"}]` (array form per firebase-tools v15.x) at the top level, sibling of `emulators`. This makes the firebase.json self-documenting about where the functions source lives. firebase-tools 15.x accepts both the array and the singleton object forms. CHOOSE the array form per current firebase-tools convention. The verify command below allows BOTH cases.

Boot smoke (manual):
  - `cd /Users/arnobrizwan/Mentor-Mind && firebase emulators:start --only functions 2>&1 | tee /tmp/p2-04-emu.log`
  - Wait ~10s. Expect stdout line: `✔  functions[asia-south1-ping]: https function initialized` or similar.
  - If the emulator reports "no functions source configured", add the discretionary `"functions": [{"source": "functions"}]` block.
  - Ctrl-C to stop.

Why this depends on 02-01 only (not 02-03):
  - The firebase.json edit is independent of whether the ping callable exists yet. The emulator can boot with zero functions registered — it just shows an empty function list. So this plan can run in parallel with 02-03 (both wave 2). The "ping[asia-south1] registered" line in stdout requires 02-03 to be merged FIRST. For PR-1 coherence we ship 02-01 + 02-02 + 02-03 + 02-04 in the same PR.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add `functions: {port: 5001}` to firebase.json emulators block</name>
  <files>firebase.json</files>
  <read_first>
    - /Users/arnobrizwan/Mentor-Mind/firebase.json (CURRENT state — single-line JSON; confirm exact contents before editing)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-PATTERNS.md (§firebase.json — lines 324-339 self-modify rule; preserves auth→firestore→storage→functions→ui order)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-CONTEXT.md (D-18 — Functions emulator port = 5001)
    - /Users/arnobrizwan/Mentor-Mind/.planning/phases/02-cloud-functions-scaffolding-app-check/02-RESEARCH.md (§Specifics — "Functions emulator port: 5001 (Firebase default)" line 158)
  </read_first>
  <action>
    Step A — Read firebase.json:
      The file is single-line JSON. Confirm the current `"emulators"` block contains `auth`, `firestore`, `storage`, `ui` keys in that order. Capture the literal content for the SUMMARY.

    Step B — Edit firebase.json:
      Add the literal `"functions":{"port":5001}` entry to the emulators block, positioned BETWEEN `"storage":{"port":9199}` and `"ui":{"enabled":true,"port":4000}`.

      Acceptable edit forms (pick ONE):

      Form 1 — minified single-line (matches current style):
      ```json
      {"firestore":{"rules":"firestore.rules","indexes":"firestore.indexes.json"},"storage":{"rules":"storage.rules"},"emulators":{"auth":{"port":9099},"firestore":{"port":8080},"storage":{"port":9199},"functions":{"port":5001},"ui":{"enabled":true,"port":4000}},"flutter":{...preserved verbatim...}}
      ```

      Form 2 — pretty-printed (recommended for legibility going forward; firebase CLI accepts both):
      ```json
      {
        "firestore": {"rules": "firestore.rules", "indexes": "firestore.indexes.json"},
        "storage": {"rules": "storage.rules"},
        "emulators": {
          "auth": {"port": 9099},
          "firestore": {"port": 8080},
          "storage": {"port": 9199},
          "functions": {"port": 5001},
          "ui": {"enabled": true, "port": 4000}
        },
        "flutter": {...preserved verbatim...}
      }
      ```
      If Form 2 is chosen, run `node -e "console.log(JSON.stringify(JSON.parse(require('fs').readFileSync('firebase.json','utf8')), null, 2))" > firebase.json.tmp && mv firebase.json.tmp firebase.json` AFTER editing to canonicalize. Or simply hand-edit and validate JSON parse afterwards.

    Step C — Optional (recommended) — add explicit functions source:
      Add `"functions": [{"source": "functions"}]` at the TOP level (sibling of "emulators"). This is the discretionary addition described in `<interfaces>`. It makes firebase.json self-documenting; firebase-tools auto-detects the source today but Phase 3's `firebase deploy --only functions:ping` benefits from the explicit declaration.

      In Form 2 layout this would look like:
      ```json
      {
        "firestore": {...},
        "storage": {...},
        "functions": [{"source": "functions"}],
        "emulators": {...},
        "flutter": {...}
      }
      ```

      If skipping the discretionary addition, the verify command below tolerates both presence and absence of the top-level functions key.

    Step D — Validate JSON:
      `node -e "JSON.parse(require('fs').readFileSync('firebase.json','utf8')); console.log('ok')"`
      Must print `ok`.

    Step E — Verify the emulators.functions.port assertion:
      `node -e "const j=JSON.parse(require('fs').readFileSync('firebase.json','utf8')); if(!j.emulators || !j.emulators.functions || j.emulators.functions.port !== 5001) throw new Error('emulators.functions.port mismatch'); console.log('emulators.functions.port=5001 verified')"`

    Step F — Manual emulator boot smoke (best-effort; not blocking):
      `cd /Users/arnobrizwan/Mentor-Mind && firebase emulators:start --only functions 2>&1 | tee /tmp/p2-04-emu.log &`
      Wait 12 seconds.
      `grep -E "ping\[asia-south1\]|asia-south1-ping|http function initialized.*ping" /tmp/p2-04-emu.log || echo "(boot smoke skipped — ping registration assertion requires Plan 02-03's lib/index.js)"`
      Kill the emulator process. Acceptable outcome: either the grep finds the registration line (confirming 02-03 + 02-04 work together) OR the grep returns empty with the printed skip note (Plan 02-03 not yet merged in this branch).

    Step G — Commit:
      `git add firebase.json`
      Commit message: `feat(firebase): add functions emulator (port 5001) to firebase.json emulators block (Phase 2 PR-1 / FUNC-06; CONTEXT D-18)`.
  </action>
  <verify>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; node -e "const j=JSON.parse(require('fs').readFileSync('firebase.json','utf8')); if(j.emulators.functions.port !== 5001) throw new Error('emulators.functions.port !== 5001 actual=' + (j.emulators.functions &amp;&amp; j.emulators.functions.port)); console.log('ok')"</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; node -e "const j=JSON.parse(require('fs').readFileSync('firebase.json','utf8')); const e=j.emulators; if(!e.auth||!e.firestore||!e.storage||!e.functions||!e.ui) throw new Error('emulators block missing key'); console.log('all 5 emulators present')"</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; grep -q '"functions":[[:space:]]*{[[:space:]]*"port":[[:space:]]*5001' firebase.json &amp;&amp; grep -q '"auth":[[:space:]]*{[[:space:]]*"port":[[:space:]]*9099' firebase.json</automated>
    <automated>cd /Users/arnobrizwan/Mentor-Mind &amp;&amp; node -e "JSON.parse(require('fs').readFileSync('firebase.json','utf8')); console.log('valid JSON')"</automated>
  </verify>
  <acceptance_criteria>
    - firebase.json parses as valid JSON.
    - `emulators.functions.port === 5001` (programmatic JSON check).
    - All five emulator keys present: auth, firestore, storage, functions, ui.
    - The existing `flutter:` block and rules paths are preserved (no accidental removal during edit).
  </acceptance_criteria>
  <done>
    firebase.json declares the Functions emulator at port 5001. `firebase emulators:start --only functions` can now boot the emulator; combined with Plan 02-03's compiled lib/index.js it registers `ping[asia-south1]`. Plan 02-09's `ping_smoke_test.dart` will call `httpsCallable('ping')` against this emulator. The auth/firestore/storage emulators from Phase 1 continue to work — the addition is purely additive.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| dev machine ⇄ localhost:5001 | The functions emulator binds to 127.0.0.1:5001 by default; no external network exposure unless `--host 0.0.0.0` is passed. Phase 2 does not pass that flag. |
| firebase.json config ⇄ runtime emulator behavior | A malformed JSON edit breaks every `firebase` CLI invocation locally. Verified by Step D's `JSON.parse` smoke. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-2-04-PORT-COLLISION | Denial of Service | localhost:5001 already in use (e.g. an unrelated dev server) — `firebase emulators:start` fails to bind | accept | Port 5001 is the Firebase default and rarely collides; if it does, the developer can override per-run with `--port=NNNN` flag but the canonical port stays at 5001 per RESEARCH §Specifics. Plan 02-07's `useFunctionsEmulator('localhost', 5001)` hardcodes the same port — drift is detectable by manual run. |
| T-2-04-JSON-MALFORM | Tampering | A hand-edit produces invalid JSON, breaking every `firebase` CLI invocation locally | mitigate | Step D's `JSON.parse` smoke catches this. Verify command runs `node -e "JSON.parse(...)"` which exits non-zero on parse failure. |
| T-2-04-WRONG-PORT | Repudiation | The team picks a non-default port (e.g. 5555) — Plan 02-07/02-08 hardcodes a different port | mitigate | Verify command asserts `emulators.functions.port === 5001` literal. Plan 02-07's verify also greps `5001` in lib/data/services/firebase_functions_provider.dart's emulator wiring (Plan 02-08's). |
</threat_model>

<verification>
- firebase.json parses as valid JSON.
- emulators.functions.port = 5001.
- All five emulator keys (auth/firestore/storage/functions/ui) present.
- Flutter block and rules paths preserved.
</verification>

<success_criteria>
- D-18 met: firebase.json emulators block extends to include functions:{port:5001}.
- FUNC-06 partial (the Flutter SDK wiring lands in 02-07 / 02-08; the emulator host config lives here).
- Plan 02-09's `firebase emulators:start --only functions` can boot the emulator and host the ping callable from Plan 02-03.
- No Phase 1 regressions: auth/firestore/storage emulators continue to work for login_smoke_test.dart (D-11, D-24 honored).
</success_criteria>

<output>
Create `.planning/phases/02-cloud-functions-scaffolding-app-check/02-04-functions-emulator-config-SUMMARY.md` when done. Record: the BEFORE content of firebase.json (one line), the AFTER content (formatted), the JSON-parse smoke result, the `emulators.functions.port` assertion result, and (if attempted) the emulator boot stdout showing `ping[asia-south1]` registered.
</output>
