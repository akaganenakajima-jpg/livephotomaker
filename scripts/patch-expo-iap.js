/**
 * Patches expo-iap's ExpoIapModule.swift to fix Swift 5.10 concurrency errors.
 *
 * Problem 1: ExpoIapModule.swift uses `Task { @MainActor in self.method() }` with
 * [weak self] in the outer closure. Swift 5.10+ treats the outer `var self`
 * as captured by the inner @Sendable Task closure, which is a compile error:
 *   "reference to captured var 'self' in concurrently-executing code"
 *
 * Fix 1: Re-capture self in the Task's own capture list:
 *   Task { @MainActor [weak self] in ... }
 * This creates a new immutable binding in the Task scope, which is Sendable-safe.
 *
 * Problem 2: OnCreate/OnDestroy Task blocks have no outer [weak self], so after
 * Fix 1, `self` becomes ExpoIapModule? but the code calls self.setupStore() /
 * await self.cleanupStore() directly (no guard let). This causes:
 *   "value of optional type 'ExpoIapModule?' must be unwrapped"
 *
 * Fix 2: Change those direct calls to use optional chaining:
 *   self?.setupStore()
 *   await self?.cleanupStore()
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
// Task { @MainActor in  →  Task { @MainActor [weak self] in
const OLD1 = 'Task { @MainActor in';
const NEW1 = 'Task { @MainActor [weak self] in';

if (content.includes(OLD1)) {
  const count = (content.match(/Task \{ @MainActor in/g) || []).length;
  content = content.split(OLD1).join(NEW1);
  console.log(`[patch-expo-iap] Fix1: patched ${count} Task block(s) with [weak self]`);
  changed = true;
} else {
  console.log('[patch-expo-iap] Fix1: already applied or pattern not found — skipping');
}

// ── Fix 2 ──────────────────────────────────────────────────────────────────
// After Fix 1 some Task blocks now have optional self but call self.xxx directly
// (no guard let).  Convert to optional chaining so they compile.

// Pattern A: Task { @MainActor [weak self] in
//              self.setupStore()
const fix2a = content.replace(
  /(Task \{ @MainActor \[weak self\] in\n[ \t]+)(self)(\.setupStore\(\))/g,
  '$1$2?$3'
);
if (fix2a !== content) {
  console.log('[patch-expo-iap] Fix2a: patched self.setupStore() → self?.setupStore()');
  content = fix2a;
  changed = true;
}

// Pattern B: Task { @MainActor [weak self] in
//              await self.cleanupStore()
const fix2b = content.replace(
  /(Task \{ @MainActor \[weak self\] in\n[ \t]+await )(self)(\.cleanupStore\(\))/g,
  '$1$2?$3'
);
if (fix2b !== content) {
  console.log('[patch-expo-iap] Fix2b: patched await self.cleanupStore() → await self?.cleanupStore()');
  content = fix2b;
  changed = true;
}

if (changed) {
  fs.writeFileSync(filePath, content, 'utf-8');
  console.log('[patch-expo-iap] Done.');
} else {
  console.log('[patch-expo-iap] Nothing to patch.');
}
