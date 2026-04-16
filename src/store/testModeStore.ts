import { create } from 'zustand';

interface TestModeState {
  /**
   * When true, the import screen bypasses the native photo picker and instead
   * silently selects the most recently added video from the photo library via
   * MediaLibrary.getAssetsAsync. This eliminates the flaky native-UI step from
   * Maestro E2E flows.
   *
   * Always false in production builds regardless of what the setter receives,
   * because the toggle is only rendered when __DEV__ is true.
   */
  isTestMode: boolean;
  setTestMode: (enabled: boolean) => void;
}

/**
 * Test-mode store — Development Build only (__DEV__).
 *
 * This store lives in-memory (no AsyncStorage persistence). Maestro flows
 * toggle it at the start of each run via the home-screen Switch, then turn
 * it off at cleanup. Zustand state is reset on app kill, which is fine
 * because Maestro always relaunches fresh.
 */
export const useTestModeStore = create<TestModeState>((set) => ({
  isTestMode: false,
  // Guard: production builds can never enter test mode even if this code path
  // is somehow reached. __DEV__ is a Metro compile-time constant, so the
  // production bundle dead-code-eliminates the `true` branch entirely.
  setTestMode: (enabled) => set({ isTestMode: __DEV__ ? enabled : false }),
}));
