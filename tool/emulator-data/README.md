# Emulator Seed Data

This directory holds Firebase Local Emulator Suite seed snapshots for the
Phase 1 integration smoke test (`integration_test/login_smoke_test.dart`,
CI-06 / Anchor 5).

## Why this is empty (Plan 01-09 closeout state)

The integration test's `setUpAll` is **idempotent** — it creates the
`smoke@example.com` user on every run (catching the `email-already-in-use`
exception when re-running against an existing seed). A pre-committed
snapshot is therefore optional for correctness; it only speeds up
emulator boot.

Plan 01-09 ships the integration test + the wiring helpers but does NOT
ship a snapshot, because:

1. The orchestrator hadn't run a live emulator+test cycle during plan
   execution (test compiles + analyzes clean; live run is the developer's
   first `flutter test integration_test/...`).
2. Each contributor's emulator may pick a different export timestamp.
3. The Phase 1 seed is tiny (single user + one Firestore doc) and the
   `setUpAll` re-seeds in ~50ms.

Plan 01-10 (GitHub Actions CI) will boot a clean emulator on every PR
run, so a committed snapshot is not on the critical path.

## Regenerating a snapshot (optional, for faster local dev loops)

```bash
# Terminal 1 — start emulator with import + export-on-exit
firebase emulators:start \
  --only auth,firestore,storage \
  --import=tool/emulator-data \
  --export-on-exit=tool/emulator-data

# Terminal 2 — run the integration test against it
flutter test integration_test/login_smoke_test.dart \
  --dart-define=USE_EMULATOR=true \
  -d <simulator-or-device-id>

# When the test passes, Ctrl-C the emulator in Terminal 1.
# The shutdown writes a fresh snapshot to this directory.

# Verify + commit
git status tool/emulator-data/
git add tool/emulator-data/
git commit -m "chore(emulator): refresh seed snapshot (Phase 1 anchor 5)"
```

## What lives in a fresh dump

When the snapshot exists, this directory will contain:

```
tool/emulator-data/
├── auth_export/
│   ├── accounts.json     # smoke@example.com bcrypt hash + metadata
│   └── config.json       # emulator auth config (sign-in methods)
├── firestore_export/
│   ├── firestore_export.overall_export_metadata
│   └── all_namespaces/
│       └── all_kinds/
│           └── all_kinds.export_metadata
└── firebase-export-metadata.json
```

**Do not commit real user data here.** The emulator dump captures
whatever data was in the emulator at shutdown; if a contributor
accidentally imported real Firebase data (`firebase emulators:start
--import=<production-export>`), the dump would carry it. Always export
from a clean-room emulator that was only seeded by the integration
test's `setUpAll`.

## Functions emulator

Not wired in Phase 1 — per D-10, the Functions emulator lands in Phase 2
alongside the `functions/` TypeScript monorepo. When Phase 2 ships, this
README will be updated to include `functions_export/` in the regen flow.
