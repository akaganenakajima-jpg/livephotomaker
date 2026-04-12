/**
 * sync-admob-app-json.js
 *
 * Syncs the AdMob iOS App ID from environment variable into app.json.
 *
 * react-native-google-mobile-ads v13.x ships an Xcode build-phase script
 * (ios_config.sh) that reads `react-native-google-mobile-ads.ios_app_id`
 * from app.json or app.config.js — it does NOT support app.config.ts.
 *
 * This script runs via the `postinstall` hook so that app.json always
 * reflects the current environment, whether local dev or EAS CI.
 *
 * Priority: EXPO_PUBLIC_ADMOB_IOS_APP_ID env  >  existing app.json value
 * Default : Google official test App ID (safe for dev builds)
 */

const fs = require('fs');
const path = require('path');

const APP_JSON_PATH = path.resolve(__dirname, '../app.json');
const GOOGLE_TEST_APP_ID = 'ca-app-pub-3940256099942544~1458002511';

const envAppId = process.env.EXPO_PUBLIC_ADMOB_IOS_APP_ID;
const iosAppId = envAppId && envAppId.length > 0 ? envAppId : GOOGLE_TEST_APP_ID;

let appJson = {};
if (fs.existsSync(APP_JSON_PATH)) {
  try {
    appJson = JSON.parse(fs.readFileSync(APP_JSON_PATH, 'utf-8'));
  } catch {
    console.warn('[sync-admob] app.json parse failed — recreating');
    appJson = {};
  }
}

if (!appJson['react-native-google-mobile-ads']) {
  appJson['react-native-google-mobile-ads'] = {};
}

const current = appJson['react-native-google-mobile-ads'].ios_app_id;
if (current !== iosAppId) {
  appJson['react-native-google-mobile-ads'].ios_app_id = iosAppId;
  fs.writeFileSync(APP_JSON_PATH, JSON.stringify(appJson, null, 2) + '\n', 'utf-8');
  console.log(`[sync-admob] app.json ios_app_id updated: ${iosAppId}`);
} else {
  console.log(`[sync-admob] app.json ios_app_id already in sync: ${iosAppId}`);
}
