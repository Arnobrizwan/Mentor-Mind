---
phase: 02-cloud-functions-scaffolding-app-check
plan: 04
subsystem: infra
tags: [firebase_emulator, firebase_json, functions_port_5001, emulators_block]

# Dependency graph
requires:
  - phase: 02-cloud-functions-scaffolding-app-check
    provides: "02-01 scaffolded the functions/ monorepo; 02-03 compiled lib/index.js with the ping callable"
provides:
  - "firebase.json emulators.functions.port=5001 — enables `firebase emulators:start --only functions`"
  - "Top-level functions:[{source:functions}] — self-documents source path for Phase 3 deploy"
  - "Confirmed boot: functions[asia-south1-ping] registered at localhost:5001"
affects:
  - "02-07 (firebase_functions_provider — useFunctionsEmulator('localhost', 5001) must match this port)"
  - "02-08 (emulator_setup + main.dart — useFunctionsEmulator wiring)"
  - "02-09 (ping_smoke_test.dart — calls httpsCallable('ping') against localhost:5001)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "firebase.json emulators block ordering: auth(9099) → firestore(8080) → storage(9199) → functions(5001) → ui(4000)"
    - "Top-level functions array form ([{source:...}]) per firebase-tools v15.x convention"
    - "Pretty-printed firebase.json — firebase CLI accepts both minified and formatted forms"

key-files:
  created: []
  modified:
    - "firebase.json"

key-decisions:
  - "Used pretty-printed (Form 2) JSON instead of preserving minified single-line — improves legibility for a team; firebase CLI accepts both"
  - "Added discretionary top-level functions:[{source:functions}] (array form per firebase-tools v15.x) — makes firebase.json self-documenting and prepares for Phase 3 deploy --only functions:ping"
  - "Port 5001 is the Firebase default — matches every useFunctionsEmulator('localhost', 5001) call in Plans 02-07/02-08; no drift possible (verify asserts the literal)"

patterns-established:
  - "firebase.json emulator block ordering: auth → firestore → storage → functions → ui"
  - "Always assert emulators.functions.port===5001 with programmatic JSON.parse check after edit"

requirements-completed: [FUNC-06]

# Metrics
duration: 5min
completed: 2026-05-19
---

# Phase 02 Plan 04: Functions Emulator Config Summary

**firebase.json extended with emulators.functions port 5001 — boot smoke confirms functions[asia-south1-ping] registered at localhost:5001**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-05-19T00:00:00Z
- **Completed:** 2026-05-19T00:05:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Added `"functions": {"port": 5001}` to the emulators block in firebase.json, positioned between `storage` (9199) and `ui` (4000)
- Added top-level `"functions": [{"source": "functions"}]` for Phase 3 deploy readiness
- Pretty-printed firebase.json for legibility (was previously a single minified line)
- Full emulator boot smoke passed: `functions[asia-south1-ping]: http function initialized (http://127.0.0.1:5001/mentor-mind-aa765/asia-south1/ping)`

## Task Commits

Each task was committed atomically:

1. **Task 1: Add `functions: {port: 5001}` to firebase.json emulators block** - `34d3aa7` (feat)

**Plan metadata:** (committed with SUMMARY below)

## Files Created/Modified

- `firebase.json` — Added emulators.functions.port=5001, top-level functions source array, pretty-printed

## State Before / After

**BEFORE (minified, single line):**
```json
{"firestore":{"rules":"firestore.rules","indexes":"firestore.indexes.json"},"storage":{"rules":"storage.rules"},"emulators":{"auth":{"port":9099},"firestore":{"port":8080},"storage":{"port":9199},"ui":{"enabled":true,"port":4000}},"flutter":{...}}
```

**AFTER (pretty-printed):**
```json
{
  "firestore": {"rules": "firestore.rules", "indexes": "firestore.indexes.json"},
  "storage": {"rules": "storage.rules"},
  "functions": [{"source": "functions"}],
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

## Verification Results

| Check | Result |
|-------|--------|
| `JSON.parse` smoke | ok — valid JSON |
| `emulators.functions.port === 5001` | verified |
| All 5 emulator keys present (auth/firestore/storage/functions/ui) | all 5 present |
| flutter block preserved | verified (no deletion) |
| Emulator boot smoke | `functions[asia-south1-ping]: http function initialized (http://127.0.0.1:5001/mentor-mind-aa765/asia-south1/ping)` |

## Emulator Boot Stdout (key lines)

```
✔  functions: Loaded functions definitions from source: ping.
✔  functions[asia-south1-ping]: http function initialized (http://127.0.0.1:5001/mentor-mind-aa765/asia-south1/ping).

┌───────────┬────────────────┬─────────────────────────────────┐
│ Emulator  │ Host:Port      │ View in Emulator UI             │
├───────────┼────────────────┼─────────────────────────────────┤
│ Functions │ 127.0.0.1:5001 │ http://127.0.0.1:4000/functions │
└───────────┴────────────────┴─────────────────────────────────┘
```

## Decisions Made

- Used pretty-printed JSON (Form 2) instead of preserving minified single-line format — improves legibility; firebase CLI accepts both forms
- Added discretionary top-level `"functions": [{"source": "functions"}]` (array form per firebase-tools v15.x) — makes source path self-documenting and prepares for Phase 3 `firebase deploy --only functions:ping`
- Port 5001 is the Firebase default; matches every `useFunctionsEmulator('localhost', 5001)` call in Plans 02-07/02-08

## Deviations from Plan

None - plan executed exactly as written. The discretionary top-level functions source key was recommended in the plan and was added as specified.

## Issues Encountered

None. All verification steps passed on first attempt. Boot smoke produced the expected `functions[asia-south1-ping]` registration line, confirming Plans 02-03 and 02-04 work together correctly.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes introduced. Port 5001 binds to 127.0.0.1 (localhost only); no external exposure.

## Next Phase Readiness

- Plans 02-07 and 02-08 can now wire `useFunctionsEmulator('localhost', 5001)` — the port is confirmed live
- Plan 02-09's `ping_smoke_test.dart` can call `httpsCallable('ping')` against `localhost:5001`
- Phase 1 emulators (auth/firestore/storage) continue to work — the addition is purely additive
- No blockers

## Self-Check: PASSED

- `firebase.json` exists and modified: confirmed
- Commit `34d3aa7` exists: confirmed (`git log --oneline -1` shows `34d3aa7`)
- All 5 emulator keys present in firebase.json: confirmed
- Boot smoke shows `functions[asia-south1-ping]` at port 5001: confirmed

---
*Phase: 02-cloud-functions-scaffolding-app-check*
*Completed: 2026-05-19*
