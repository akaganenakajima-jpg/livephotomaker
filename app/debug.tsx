import React from 'react';
import DebugPanel from '@/components/DebugPanel';

/**
 * /debug route. Renders the DebugPanel full-screen so the operator can
 * read the last save's localIdentifier / contentIdentifier and the most
 * recent error code from inside the app itself — no Xcode, no Mac.
 *
 * Reachable via the Settings screen. The entry point is guarded behind
 * `__DEV__` so it never ships in a production build.
 */
export default function DebugScreen() {
  return <DebugPanel />;
}
