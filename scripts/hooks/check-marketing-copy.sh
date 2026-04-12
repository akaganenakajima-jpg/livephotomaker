#!/usr/bin/env bash
# check-marketing-copy.sh
#
# Fails the build if any forbidden wallpaper-auto-set phrase is found anywhere
# in user-facing or deliverable text (code, docs, App Store copy, comments).
#
# Forbidden phrases are the canonical list in CLAUDE.md §禁止表現. They are
# banned because they imply the app sets the iOS lock-screen wallpaper
# automatically, which violates App Store review guidelines.
set -euo pipefail

PATTERNS=(
  "auto set wallpaper"
  "automatically set wallpaper"
  "1 tap wallpaper set"
  "wallpaper auto apply"
  "壁紙を自動設定"
  "ワンタップで壁紙設定"
  "自動で壁紙に設定"
)

# Directories we never scan. `_legacy-swift` holds the pre-pivot scaffold and
# is deliberately out-of-scope — metro/TS/eslint all ignore it too.
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

EXCLUDE_ARGS=()
for d in "${EXCLUDE_DIRS[@]}"; do
  EXCLUDE_ARGS+=("--exclude-dir=${d}")
done

FAILED=0
for pattern in "${PATTERNS[@]}"; do
  if grep -R -I -l "${EXCLUDE_ARGS[@]}" \
       --exclude="check-marketing-copy.sh" \
       --exclude="CLAUDE.md" \
       -F "${pattern}" . >/dev/null 2>&1; then
    echo "FORBIDDEN PHRASE FOUND: ${pattern}"
    grep -R -I -n "${EXCLUDE_ARGS[@]}" \
       --exclude="check-marketing-copy.sh" \
       --exclude="CLAUDE.md" \
       -F "${pattern}" .
    FAILED=1
  fi
done

if [[ "${FAILED}" -ne 0 ]]; then
  echo
  echo "One or more forbidden phrases were found. See CLAUDE.md §禁止表現." >&2
  exit 1
fi

echo "[marketing-copy-guard] OK"
