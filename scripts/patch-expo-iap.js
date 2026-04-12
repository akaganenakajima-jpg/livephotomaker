/**
 * Patches expo-iap v2.6.0 ExpoIapModule.swift & Types.swift to fix Swift
 * compiler errors on Xcode 15.x (Swift 5.9) + iPhoneOS 17.x SDK.
 *
 * expo-iap v2.6.0 has several bugs that prevent compilation:
 *
 * Fix 1: getStorefront closure lacks return type annotation.
 * Fix 2: getAppTransaction uses `guard let` on non-optional VerificationResult,
 *         and accesses members directly on VerificationResult instead of
 *         .payloadValue.
 * Fix 3: IapErrorCode.featureNotSupported is referenced but not defined.
 * Fix 4: (legacy v2.5.x) Task { @MainActor in } concurrency capture.
 *
 * This script runs via the `postinstall` hook so the patch survives `npm install`.
 */

const fs = require('fs');
const path = require('path');

const modulePath = path.resolve(__dirname, '../node_modules/expo-iap/ios/ExpoIapModule.swift');
const typesPath = path.resolve(__dirname, '../node_modules/expo-iap/ios/Types.swift');

// ── Patch ExpoIapModule.swift ──────────────────────────────────────────────

if (!fs.existsSync(modulePath)) {
  console.log('[patch-expo-iap] ExpoIapModule.swift not found — skipping');
  process.exit(0);
}

let content = fs.readFileSync(modulePath, 'utf-8');
let changed = false;

// ── Fix 1: getStorefront closure return type ───────────────────────────────
const OLD_STOREFRONT = 'AsyncFunction("getStorefront") {';
const NEW_STOREFRONT = 'AsyncFunction("getStorefront") { () async -> String? in';

if (content.includes(OLD_STOREFRONT) && !content.includes(NEW_STOREFRONT)) {
  content = content.replace(OLD_STOREFRONT, NEW_STOREFRONT);
  console.log('[patch-expo-iap] Fix1: added return type to getStorefront');
  changed = true;
} else {
  console.log('[patch-expo-iap] Fix1: already applied or not found — skipping');
}

// ── Fix 2: getAppTransaction — VerificationResult is not Optional ──────────
// Before:
//   guard let appTransaction = try await AppTransaction.shared else { return nil }
//   return [ "appTransactionID": appTransaction.appAppleId, ... ]
//
// After:
//   let verificationResult = try await AppTransaction.shared
//   let appTransaction = try verificationResult.payloadValue
//   return [ "appTransactionID": appTransaction.appID, ... ]

const OLD_GET_APP_TX = `                guard let appTransaction = try await AppTransaction.shared else {
                    return nil
                }`;
const NEW_GET_APP_TX = `                let verificationResult = try await AppTransaction.shared
                let appTransaction = try verificationResult.payloadValue`;

if (content.includes(OLD_GET_APP_TX)) {
  content = content.replace(OLD_GET_APP_TX, NEW_GET_APP_TX);
  console.log('[patch-expo-iap] Fix2a: replaced guard let with verificationResult.payloadValue');
  changed = true;
}

// Fix the member accesses on AppTransaction (StoreKit 2, iOS 16+).
// Verified against Apple docs: AppTransaction has appID, bundleID,
// appVersion, originalAppVersion, originalPurchaseDate, environment,
// deviceVerification, deviceVerificationNonce, signedDate.
// It does NOT have: id, appAppleId, appAccountToken, originalAppAccountToken.

// appAppleId → appID  (UInt64, the App Apple ID)
if (content.includes('appTransaction.appAppleId')) {
  content = content.replace('appTransaction.appAppleId', 'appTransaction.appID');
  console.log('[patch-expo-iap] Fix2b: appAppleId → appID');
  changed = true;
}

// originalAppAccountToken does not exist on AppTransaction (it's on Transaction).
// Replace the whole dictionary entry with nil to keep the response shape.
if (content.includes('appTransaction.originalAppAccountToken')) {
  content = content.replace(
    '"originalAppAccountToken": appTransaction.originalAppAccountToken',
    '"originalAppAccountToken": nil as String?'
  );
  console.log('[patch-expo-iap] Fix2c: originalAppAccountToken → nil (not available on AppTransaction)');
  changed = true;
}

// ── Fix 3: IapErrorCode.featureNotSupported — add to Types.swift ──────────
if (fs.existsSync(typesPath)) {
  let typesContent = fs.readFileSync(typesPath, 'utf-8');
  if (!typesContent.includes('featureNotSupported')) {
    // Add featureNotSupported after the last error code constant
    typesContent = typesContent.replace(
      'static let connectionClosed = "E_CONNECTION_CLOSED"',
      'static let connectionClosed = "E_CONNECTION_CLOSED"\n    static let featureNotSupported = "E_FEATURE_NOT_SUPPORTED"'
    );
    // Also add to the cached dictionary
    typesContent = typesContent.replace(
      'connectionClosed: connectionClosed\n    ]',
      'connectionClosed: connectionClosed,\n        featureNotSupported: featureNotSupported\n    ]'
    );
    fs.writeFileSync(typesPath, typesContent, 'utf-8');
    console.log('[patch-expo-iap] Fix3: added featureNotSupported to IapErrorCode');
    changed = true;
  } else {
    console.log('[patch-expo-iap] Fix3: featureNotSupported already exists — skipping');
  }
}

// ── Fix 4: (legacy v2.5.x) Task { @MainActor in } ─────────────────────────
const OLD_TASK = 'Task { @MainActor in';
const NEW_TASK = 'Task { @MainActor [weak self] in';

if (content.includes(OLD_TASK)) {
  const count = (content.match(/Task \{ @MainActor in/g) || []).length;
  content = content.split(OLD_TASK).join(NEW_TASK);
  console.log(`[patch-expo-iap] Fix4: patched ${count} Task block(s) with [weak self]`);
  changed = true;
}

if (changed) {
  fs.writeFileSync(modulePath, content, 'utf-8');
  console.log('[patch-expo-iap] Done.');
} else {
  console.log('[patch-expo-iap] Nothing to patch.');
}
