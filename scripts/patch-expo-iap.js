/**
 * Patches expo-iap's ExpoIapModule.swift to fix Swift compiler errors
 * on Xcode 15.x / Swift 5.9–5.10.
 *
 * Problem (v2.6.0): The `AsyncFunction("getStorefront")` closure contains
 * multiple statements but lacks an explicit return type annotation. Swift's
 * type inference cannot deduce the return type for multi-statement closures,
 * causing:
 *   "cannot infer return type for closure with multiple statements;
 *    add explicit type to disambiguate"
 *
 * Fix: Add `() async -> String? in` to the closure signature.
 *
 * This script runs via the `postinstall` hook so the patch survives `npm install`.
 */

const fs = require('fs');
const path = require('path');

const filePath = path.resolve(
  __dirname,
  '../node_modules/expo-iap/ios/ExpoIapModule.swift'
);

if (!fs.existsSync(filePath)) {
  console.log('[patch-expo-iap] ExpoIapModule.swift not found — skipping');
  process.exit(0);
}

let content = fs.readFileSync(filePath, 'utf-8');
let changed = false;

// ── Fix 1 ──────────────────────────────────────────────────────────────────
// AsyncFunction("getStorefront") {           →
// AsyncFunction("getStorefront") { () async -> String? in
//
// The closure body has two statements (let + return), so Swift cannot infer
// the return type. We add an explicit `() async -> String? in` annotation.
const OLD_STOREFRONT = 'AsyncFunction("getStorefront") {';
const NEW_STOREFRONT = 'AsyncFunction("getStorefront") { () async -> String? in';

if (content.includes(OLD_STOREFRONT) && !content.includes(NEW_STOREFRONT)) {
  content = content.replace(OLD_STOREFRONT, NEW_STOREFRONT);
  console.log('[patch-expo-iap] Fix1: added return type annotation to getStorefront closure');
  changed = true;
} else {
  console.log('[patch-expo-iap] Fix1: already applied or pattern not found — skipping');
}

// ── Fix 2 (legacy v2.5.x) ────────────────────────────────────────────────
// Task { @MainActor in  →  Task { @MainActor [weak self] in
// Kept for safety in case the user downgrades expo-iap.
const OLD_TASK = 'Task { @MainActor in';
const NEW_TASK = 'Task { @MainActor [weak self] in';

if (content.includes(OLD_TASK)) {
  const count = (content.match(/Task \{ @MainActor in/g) || []).length;
  content = content.split(OLD_TASK).join(NEW_TASK);
  console.log(`[patch-expo-iap] Fix2: patched ${count} Task block(s) with [weak self]`);
  changed = true;
}

if (changed) {
  fs.writeFileSync(filePath, content, 'utf-8');
  console.log('[patch-expo-iap] Done.');
} else {
  console.log('[patch-expo-iap] Nothing to patch.');
}
