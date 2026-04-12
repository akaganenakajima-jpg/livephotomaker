import type { ExpoConfig, ConfigContext } from 'expo/config';

/**
 * Expo app configuration.
 *
 * Fixed (confirmed) values:
 *   BUNDLE_IDENTIFIER    - com.gen.videotolivephoto (confirmed)
 *   App Display Name     - Video to Live Photo (confirmed)
 *   Non-consumable IAP   - com.gen.videotolivephoto.premium.hq_unlock (confirmed)
 *
 * Placeholders the user still has to replace (see README §プレースホルダ一覧):
 *   EXPO_PROJECT_ID_PLACEHOLDER  - UUID returned by `npx eas init` (first-time setup).
 *                                  The `check:placeholders` script fails the
 *                                  build while this literal is still present.
 *   APPLE_TEAM_ID_PLACEHOLDER    - 10-char Apple Team ID from developer.apple.com (eas.json)
 *   ASC_APP_ID_PLACEHOLDER       - numeric App Store Connect app id (eas.json)
 */
const BUNDLE_IDENTIFIER = 'com.gen.videotolivephoto';

// Reads the real project id from the env when available (set by EAS CI or a
// local `.env` file). If the env var is missing OR empty, we leave the field
// undefined so that `eas init` can create a fresh project without choking on
// a placeholder value. The `check:placeholders` script scans this file for
// the literal below and fails the build while the fallback is still present.
const EXPO_PROJECT_ID_PLACEHOLDER = 'EXPO_PROJECT_ID_PLACEHOLDER';
const EXPO_PROJECT_ID_ENV = process.env.EXPO_PUBLIC_EAS_PROJECT_ID;
const EXPO_PROJECT_ID =
  EXPO_PROJECT_ID_ENV && EXPO_PROJECT_ID_ENV.length > 0
    ? EXPO_PROJECT_ID_ENV
    : EXPO_PROJECT_ID_PLACEHOLDER;

// AdMob iOS App ID. Read from env so real IDs never land in git.
// In dev builds this defaults to Google's official test App ID
// (https://developers.google.com/admob/ios/test-ads), which is safe to ship
// in a development / EAS preview build. Production EAS profiles must override
// `EXPO_PUBLIC_ADMOB_IOS_APP_ID` with the real AdMob app id.
const ADMOB_IOS_APP_ID =
  process.env.EXPO_PUBLIC_ADMOB_IOS_APP_ID ?? 'ca-app-pub-3940256099942544~1458002511';

export default ({ config }: ConfigContext): ExpoConfig => ({
  ...config,
  name: 'Video to Live Photo',
  slug: 'video-to-livephoto',
  version: '0.1.0',
  orientation: 'portrait',
  icon: './assets/icon.png',
  scheme: 'livephotomaker',
  userInterfaceStyle: 'automatic',
  // Note: Expo SDK 51 does not expose a typed top-level `newArchEnabled`
  // flag — it was added in SDK 52. We intentionally run on the Legacy
  // architecture under SDK 51; the Live Photo native module uses AVFoundation
  // + Photos framework APIs that work identically on both architectures.
  splash: {
    image: './assets/splash.png',
    resizeMode: 'contain',
    backgroundColor: '#ffffff',
  },
  assetBundlePatterns: ['**/*'],
  ios: {
    supportsTablet: false,
    bundleIdentifier: BUNDLE_IDENTIFIER,
    buildNumber: '1',
    infoPlist: {
      NSPhotoLibraryUsageDescription:
        '動画の読み込みとLive Photoの保存のために写真ライブラリへアクセスします。',
      NSPhotoLibraryAddUsageDescription: '作成したLive Photoを写真ライブラリへ保存します。',
      ITSAppUsesNonExemptEncryption: false,
      // AdMob: in react-native-google-mobile-ads v13.x the package does NOT
      // ship an Expo config plugin (that was added in v14). We therefore
      // inject all Info.plist keys the plugin would normally set, directly
      // here. Keep this block in sync with the SDK's requirements:
      //   - GADApplicationIdentifier   : AdMob iOS App ID
      //   - SKAdNetworkItems           : Apple SKAdNetwork ids the SDK needs
      //   - NSUserTrackingUsageDescription : ATT prompt copy (iOS 14.5+)
      GADApplicationIdentifier: ADMOB_IOS_APP_ID,
      NSUserTrackingUsageDescription:
        '広告の表示精度を維持するためにトラッキング許諾を使用します。拒否した場合でもアプリの機能に影響はありません。',
      SKAdNetworkItems: [
        { SKAdNetworkIdentifier: 'cstr6suwn9.skadnetwork' },
        { SKAdNetworkIdentifier: '4fzdc2evr5.skadnetwork' },
        { SKAdNetworkIdentifier: '4pfyvq9l8r.skadnetwork' },
        { SKAdNetworkIdentifier: '2fnua5tdw4.skadnetwork' },
        { SKAdNetworkIdentifier: 'ydx93a7ass.skadnetwork' },
      ],
    },
  },
  plugins: [
    [
      'expo-build-properties',
      {
        ios: {
          deploymentTarget: '15.1',
        },
      },
    ],
    'expo-router',
    'expo-media-library',
    [
      'expo-image-picker',
      { photosPermission: '動画の読み込みのために写真ライブラリへアクセスします。' },
    ],
    './modules/expo-live-photo-exporter/plugin/build/withExpoLivePhotoExporter',
    // NOTE: `react-native-google-mobile-ads` is intentionally NOT listed here.
    // v13.x has no Expo config plugin; the Info.plist keys it would have set
    // (GADApplicationIdentifier / SKAdNetworkItems / NSUserTrackingUsageDescription)
    // are injected manually above under `ios.infoPlist`. When upgrading the
    // package to ≥14.0 we can re-add the plugin entry and delete the manual keys.
    // expo-iap has no build-time config; runtime only, but we list it here so
    // the autolinking picker and EAS build cache stay in sync.
    'expo-iap',
  ],
  experiments: {
    typedRoutes: true,
  },
  extra: {
    // Only expose `eas.projectId` to the runtime config when we have a real
    // value. Emitting the placeholder literal confuses `eas init` / `eas build`
    // into thinking the project is already linked. `check:placeholders` still
    // catches the unset state because the placeholder literal is declared as
    // a top-level constant above.
    eas:
      EXPO_PROJECT_ID === EXPO_PROJECT_ID_PLACEHOLDER ? undefined : { projectId: EXPO_PROJECT_ID },
  },
});
