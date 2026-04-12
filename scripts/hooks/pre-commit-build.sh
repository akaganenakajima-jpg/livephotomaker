#!/usr/bin/env bash
# pre-commit-build.sh
#
# Minimal build gate before committing. Skips gracefully on non-Mac hosts so
# that Claude Code on Windows can still commit documentation-only changes.
set -euo pipefail

if [[ "$(uname)" != "Darwin" ]]; then
  echo "[pre-commit] skipping xcodebuild on non-Darwin host"
  exit 0
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "[pre-commit] xcodebuild not found, skipping"
  exit 0
fi

make build
