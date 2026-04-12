import { create } from 'zustand';

/**
 * Debug info store. The NativeLivePhotoBridge pushes the most recent save
 * result (success or failure) here so the in-app Debug screen can render
 * them. This is the Windows-only replacement for inspecting the Xcode
 * device console — every id and error code that would have been visible
 * there is mirrored into this store.
 */
export interface DebugSaveResult {
  readonly localIdentifier: string;
  readonly contentIdentifier: string;
  readonly at: number;
}

export interface DebugSaveError {
  readonly code: string;
  readonly message: string;
  readonly at: number;
}

interface DebugInfoState {
  lastSaveResult: DebugSaveResult | null;
  lastError: DebugSaveError | null;
  /**
   * Number of saves recorded since app start (successes only). Used by the
   * Debug banner to tell "never run" apart from "run once and succeeded".
   */
  successCount: number;
  /** Number of errors recorded since app start (failures only). */
  errorCount: number;

  recordSaveSuccess: (result: { localIdentifier: string; contentIdentifier: string }) => void;
  recordSaveError: (code: string, message: string) => void;
  clear: () => void;
}

export const useDebugInfoStore = create<DebugInfoState>((set) => ({
  lastSaveResult: null,
  lastError: null,
  successCount: 0,
  errorCount: 0,

  recordSaveSuccess: (result) =>
    set((s) => ({
      lastSaveResult: {
        localIdentifier: result.localIdentifier,
        contentIdentifier: result.contentIdentifier,
        at: Date.now(),
      },
      // Clear the previous error when a new success comes in, so the Debug
      // screen reflects the *current* state rather than a stale failure.
      lastError: null,
      successCount: s.successCount + 1,
    })),

  recordSaveError: (code, message) =>
    set((s) => ({
      lastError: {
        code,
        message,
        at: Date.now(),
      },
      errorCount: s.errorCount + 1,
    })),

  clear: () =>
    set({
      lastSaveResult: null,
      lastError: null,
      successCount: 0,
      errorCount: 0,
    }),
}));
