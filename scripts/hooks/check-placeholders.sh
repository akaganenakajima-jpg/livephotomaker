#!/usr/bin/env bash
# check-placeholders.sh
#
# Bash twin of `scripts/windows/check-placeholders.ps1`. Fails the build if
# any canonical placeholder token is still present in tracked files so we
# never ship a build with example values. Runs on Windows git-bash, Linux
# and macOS alike.
set -euo pipefail

PATTERNS=(
  'EXPO_PROJECT_ID_PLACEHOLDER'
  'APPLE_TEAM_ID_PLACEHOLDER'
  'ASC_APP_ID_PLACEHOLDER'
  'APPLE_ID_PLACEHOLDER'
  'BUNDLE_IDENTIFIER_PLACEHOLDER'
)

EXCLUDE_DIRS=(
  ".git"
  "node_modules"
  ".expo"
  ".eas"
  "_legacy-swift"
  "build"
  "dist"
  "coverage"
  "DerivedData"
)

# Files that legitimately mention the placeholders for documentation reasons.
# Matches are relative paths (substring match is fine here).
ALLOWED_FILES=(
  "scripts/hooks/check-placeholders.sh"
  "scripts/windows/check-placeholders.ps1"
  "app.config.ts"
  "eas.json"
  "README.md"
  "docs/実機検証チェックリスト.md"
  ".env.example"
)

EXCLUDE_ARGS=()
for d in "${EXCLUDE_DIRS[@]}"; do
  EXCLUDE_ARGS+=("--exclude-dir=${d}")
done

is_allowed() {
  local f="$1"
  for allow in "${ALLOWED_FILES[@]}"; do
    # Normalise Windows backslashes just in case.
    local norm="${f//\\//}"
    if [[ "${norm}" == *"${allow}"* ]]; then
      return 0
    fi
  done
  return 1
}

FAILED=0
for pattern in "${PATTERNS[@]}"; do
  while IFS= read -r file; do
    [[ -z "${file}" ]] && continue
    if is_allowed "${file}"; then
      continue
    fi
    echo "UNREPLACED PLACEHOLDER in ${file}: ${pattern}"
    FAILED=1
  done < <(grep -R -I -l "${EXCLUDE_ARGS[@]}" -F "${pattern}" . 2>/dev/null || true)
done

if [[ "${FAILED}" -ne 0 ]]; then
  echo
  echo "One or more placeholders are still present in non-documentation files." >&2
  echo "See README '## プレースホルダ一覧' for the canonical replacement values." >&2
  exit 1
fi

echo "[placeholder-guard] OK"
