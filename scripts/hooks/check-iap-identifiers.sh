#!/usr/bin/env bash
# check-iap-identifiers.sh
#
# Ensures the IAP product identifier defined in src/constants/products.ts is
# mentioned consistently in the user-facing docs. Single source of truth:
#
#   export const ProductIdentifier = {
#     PremiumHQUnlock: 'com.gen.videotolivephoto.premium.hq_unlock',
#   } as const;
#
set -euo pipefail

TS_FILE="src/constants/products.ts"

if [[ ! -f "${TS_FILE}" ]]; then
  echo "[iap-guard] ${TS_FILE} not found" >&2
  exit 1
fi

# Extract the PremiumHQUnlock literal. Matches: PremiumHQUnlock: 'jp.example...'
PRODUCT_ID=$(grep -E "PremiumHQUnlock\s*:\s*'[^']+'" "${TS_FILE}" | \
             sed -E "s/.*'([^']+)'.*/\1/" | head -n 1)

if [[ -z "${PRODUCT_ID}" ]]; then
  echo "[iap-guard] failed to extract product id from ${TS_FILE}" >&2
  exit 1
fi

echo "[iap-guard] canonical product id: ${PRODUCT_ID}"

FAILED=0
REQUIRED_FILES=(
  "README.md"
  "CLAUDE.md"
  "docs/appstore-copy-ja.md"
  "docs/appstore-copy-en.md"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [[ -f "${file}" ]]; then
    if ! grep -qF "${PRODUCT_ID}" "${file}"; then
      echo "WARN: ${file} does not mention ${PRODUCT_ID}"
      FAILED=1
    fi
  fi
done

if [[ "${FAILED}" -ne 0 ]]; then
  echo "[iap-guard] identifier drift detected. Update docs to match ${PRODUCT_ID}." >&2
  exit 1
fi

echo "[iap-guard] OK"
