#!/usr/bin/env bash
# CI gate for QUAL-04 / layered_imports — mirrors tool/lints layered_imports rule.
# Fast ripgrep check; use `dart run custom_lint lib test` locally for full plugin run.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

fail=0

if rg -l "package:(cloud_firestore|firebase_auth|firebase_storage|firebase_messaging)" \
  lib/presentation 2>/dev/null; then
  echo "::error::Layered imports: lib/presentation must not import Firebase SDKs."
  fail=1
fi

if rg -l "package:mentor_minds/presentation/" lib/data 2>/dev/null; then
  echo "::error::Layered imports: lib/data must not import lib/presentation."
  fail=1
fi

exit "$fail"
