#!/usr/bin/env bash
# check-admob-config.sh
#
# Profile-aware AdMob configuration guard.
#
# - dev-sim / development : Google test App ID is acceptable
# - preview / production  : MUST use a real AdMob App ID (test ID = FAIL)
#
# Checks both app.json (used by ios_config.sh at Xcode build time)
# and the EXPO_PUBLIC_ADMOB_IOS_APP_ID env var (used by app.config.ts).
set -euo pipefail

GOOGLE_TEST_APP_ID="ca-app-pub-3940256099942544~1458002511"

# Determine current profile from EXPO_PUBLIC_ENV (set by eas.json per profile).
# When running locally (npm run check:admob) the var may be unset — treat as dev.
PROFILE="${EXPO_PUBLIC_ENV:-development}"

# ── 1. app.json existence check ───────────────────────────────────────────
APP_JSON="app.json"
if [[ ! -f "${APP_JSON}" ]]; then
  echo "[admob-guard] FAIL: ${APP_JSON} not found. Run 'npm install' to generate it." >&2
  exit 1
fi

# ── 2. ios_app_id key presence ────────────────────────────────────────────
APP_JSON_ID=$(node -e "
  try {
    const j = require('./${APP_JSON}');
    const id = (j['react-native-google-mobile-ads'] || {}).ios_app_id || '';
    process.stdout.write(id);
  } catch { process.stdout.write(''); }
" 2>/dev/null || true)

if [[ -z "${APP_JSON_ID}" ]]; then
  echo "[admob-guard] FAIL: react-native-google-mobile-ads.ios_app_id is missing in ${APP_JSON}" >&2
  exit 1
fi

# ── 3. Profile-aware validation ───────────────────────────────────────────
case "${PROFILE}" in
  development|dev-sim)
    # Test ID is fine for dev builds
    echo "[admob-guard] OK (profile=${PROFILE}, ios_app_id=${APP_JSON_ID})"
    ;;
  preview|production)
    if [[ "${APP_JSON_ID}" == "${GOOGLE_TEST_APP_ID}" ]]; then
      echo "[admob-guard] FAIL: profile=${PROFILE} requires a real AdMob App ID." >&2
      echo "  Current value is the Google test App ID: ${GOOGLE_TEST_APP_ID}" >&2
      echo "  Set EXPO_PUBLIC_ADMOB_IOS_APP_ID in EAS secrets or .env and re-run 'npm install'." >&2
      exit 1
    fi
    # Also check env var consistency (app.config.ts reads this)
    ENV_ID="${EXPO_PUBLIC_ADMOB_IOS_APP_ID:-}"
    if [[ -n "${ENV_ID}" && "${ENV_ID}" == "${GOOGLE_TEST_APP_ID}" ]]; then
      echo "[admob-guard] FAIL: EXPO_PUBLIC_ADMOB_IOS_APP_ID is still the Google test ID for profile=${PROFILE}." >&2
      exit 1
    fi
    echo "[admob-guard] OK (profile=${PROFILE}, ios_app_id=${APP_JSON_ID})"
    ;;
  *)
    echo "[admob-guard] WARN: unknown profile '${PROFILE}' — treating as development"
    echo "[admob-guard] OK (profile=${PROFILE}, ios_app_id=${APP_JSON_ID})"
    ;;
esac
