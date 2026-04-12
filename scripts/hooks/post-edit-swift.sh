#!/usr/bin/env bash
# post-edit-swift.sh
#
# Runs swiftformat / swiftlint on changed Swift files. Intended to be wired
# as a Claude Code PostToolUse hook (file matcher: *.swift).
set -euo pipefail

FILE="${1:-}"

if [[ -z "${FILE}" ]]; then
  exit 0
fi

case "${FILE}" in
  *.swift) ;;
  *) exit 0 ;;
esac

if command -v swiftformat >/dev/null 2>&1; then
  swiftformat "${FILE}" || true
fi

if command -v swiftlint >/dev/null 2>&1; then
  swiftlint lint --quiet --path "${FILE}" || true
fi
