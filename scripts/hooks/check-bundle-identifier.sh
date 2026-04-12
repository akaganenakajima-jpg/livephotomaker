#!/usr/bin/env bash
# check-bundle-identifier.sh
#
# Ensures the canonical iOS bundle identifier is referenced in every file
# that must pin to it. The canonical value is declared in `app.config.ts`
# as `BUNDLE_IDENTIFIER`, and must match:
#
#   com.gen.videotolivephoto
#
# Drift between app.config.ts and the docs / submission scripts means an
# EAS submit that points at the wrong ASC record, which is expensive to
# catch after the fact.
set -euo pipefail

CANONICAL="com.gen.videotolivephoto"
SOURCE="app.config.ts"

if [[ ! -f "${SOURCE}" ]]; then
  echo "[bundle-guard] ${SOURCE} not found" >&2
  exit 1
fi

if ! grep -qF "${CANONICAL}" "${SOURCE}"; then
  echo "[bundle-guard] ${SOURCE} does not contain canonical bundle id ${CANONICAL}" >&2
  exit 1
fi

REQUIRED_FILES=(
  "README.md"
  "CLAUDE.md"
  "docs/実機検証チェックリスト.md"
  "docs/appstore-copy-ja.md"
  "docs/appstore-copy-en.md"
)

FAILED=0
for file in "${REQUIRED_FILES[@]}"; do
  if [[ -f "${file}" ]]; then
    if ! grep -qF "${CANONICAL}" "${file}"; then
      echo "WARN: ${file} does not mention ${CANONICAL}"
      FAILED=1
    fi
  fi
done

if [[ "${FAILED}" -ne 0 ]]; then
  echo "[bundle-guard] bundle id drift detected. Update docs to match ${CANONICAL}." >&2
  exit 1
fi

echo "[bundle-guard] canonical bundle id: ${CANONICAL}"
echo "[bundle-guard] OK"
