/**
 * Thin JS wrapper over the custom Expo Module that does the actual Live Photo
 * work on iOS. Every call to the native side MUST go through this bridge so
 * that tests can substitute a mock and so that non-iOS / Expo-Go builds fail
 * loudly with a useful error.
 *
 * Diagnostics: every save result (success or failure) is mirrored into
 * `useDebugInfoStore` so the in-app Debug screen can display the
 * localIdentifier / contentIdentifier / error code. This is the
 * Windows-only replacement for inspecting the Xcode device console —
 * Windows developers never need a Mac to see what the native module
 * produced on the iPhone.
 */
import type { AppError } from '@/types/AppError';
import { useDebugInfoStore } from '@/store/debugInfoStore';
import { logger } from '@/utils/logger';

export interface NativeExportInput {
  /** File URL of the source MOV clip. */
  readonly movUri: string;
  /** File URL of the extracted still image (JPEG/HEIC). */
  readonly stillUri: string;
  /** Trim start in seconds (default 0). */
  readonly startSeconds?: number;
  /** Trim end in seconds. Native side clamps to actual duration. */
  readonly endSeconds?: number;
}

export interface NativeExportResult {
  /** PHAsset local identifier assigned by Photos after save. */
  readonly localIdentifier: string;
  /**
   * UUID written into both the JPEG MakerApple[17] and the MOV
   * QuickTime content.identifier. Only exposed for diagnostics so the
   * dev console can confirm both sides of the pair share the same id.
   */
  readonly contentIdentifier?: string;
}

export interface NativeLivePhotoBridge {
  isAvailable(): boolean;
  /**
   * Generates the tagged MOV + JPEG pair and saves them as a Live Photo
   * asset in the user's library. Throws a typed `AppError` on failure so
   * the UI can render a localized message.
   */
  saveLivePhoto(input: NativeExportInput): Promise<NativeExportResult>;
}

/**
 * Narrow shape of the underlying Expo module binding. Keeps this bridge
 * free of `any` while still letting us fall back gracefully when the
 * module is not linked.
 */
interface NativeModuleShape {
  isAvailable?: () => boolean;
  saveLivePhotoToLibrary(input: NativeExportInput): Promise<{
    localIdentifier: string;
    contentIdentifier?: string;
  }>;
}

/** Shape of a native rejection from an Expo Modules promise. */
interface NativeRejection {
  code?: string;
  message?: string;
}

/**
 * Maps the native `code` field (see `ExpoLivePhotoExporterModule.swift`
 * `LivePhotoExporterError`) to a typed `AppError`. Unknown codes collapse
 * into `exportFailed` with the raw code embedded in `underlying`, so
 * diagnostics never get lost even when the native side adds new codes.
 */
const codeToAppError = (code: string, message: string): AppError => {
  switch (code) {
    case 'ERR_PHOTO_PERMISSION_DENIED':
      return { kind: 'photoPermissionDenied' };

    // Every pipeline-internal failure is surfaced as `exportFailed` with
    // the raw code preserved in `underlying` so developers can grep for it
    // in logs without the user-facing copy leaking implementation details.
    case 'ERR_INVALID_SOURCE_URI':
    case 'ERR_STILL_LOAD_FAILED':
    case 'ERR_STILL_WRITE_FAILED':
    case 'ERR_STILL_FINALIZE_FAILED':
    case 'ERR_MOVIE_TRACK_LOAD_FAILED':
    case 'ERR_MOVIE_VIDEO_TRACK_MISSING':
    case 'ERR_MOVIE_READER_CREATE_FAILED':
    case 'ERR_MOVIE_WRITER_CREATE_FAILED':
    case 'ERR_MOVIE_START_WRITING_FAILED':
    case 'ERR_MOVIE_VIDEO_APPEND_FAILED':
    case 'ERR_MOVIE_FINISH_WRITING_FAILED':
    case 'ERR_ASSET_CREATION_FAILED':
    case 'ERR_LIVE_PHOTO_EXPORT_FAILED':
      return { kind: 'exportFailed', underlying: `${code}: ${message}` };

    default:
      return { kind: 'exportFailed', underlying: `${code}: ${message}` };
  }
};

/**
 * Default bridge implementation. Loads the custom Expo module lazily so the
 * app can still render on Expo Go (with the Live-Photo path disabled).
 */
export const createNativeLivePhotoBridge = (): NativeLivePhotoBridge => {
  // Lazy require: if the native module is not linked (Expo Go / Jest /
  // Node) the require or the inner isAvailable() check leaves `mod` null
  // and every subsequent saveLivePhoto() call rejects with
  // `nativeModuleUnavailable`, which the UI can display cleanly.
  let mod: NativeModuleShape | null = null;

  try {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const imported = require('../../modules/expo-live-photo-exporter');
    const candidate = (imported?.default ?? imported ?? null) as NativeModuleShape | null;
    if (candidate && typeof candidate.isAvailable === 'function' && !candidate.isAvailable()) {
      logger.debug('NativeLivePhotoBridge: module present but isAvailable() false');
      mod = null;
    } else {
      mod = candidate;
    }
  } catch (e) {
    logger.debug('NativeLivePhotoBridge: native module not linked', e);
    mod = null;
  }

  return {
    isAvailable: () => mod !== null,

    saveLivePhoto: async (input) => {
      if (!mod) {
        const err: AppError = { kind: 'nativeModuleUnavailable' };
        // Surface to the Debug screen so the operator can tell at a glance
        // that the native module is not linked in this build.
        useDebugInfoStore
          .getState()
          .recordSaveError('ERR_NATIVE_MODULE_UNAVAILABLE', 'native module not linked');
        throw err;
      }
      // Dev-only log so the JS console in a Development Build shows exactly
      // which file URIs are handed to native and what comes back. Release
      // builds silently drop these via `utils/logger`.
      logger.debug('NativeLivePhotoBridge.saveLivePhoto ->', input);
      try {
        const result = await mod.saveLivePhotoToLibrary(input);
        logger.debug('NativeLivePhotoBridge.saveLivePhoto <-', result);
        // Mirror the ids into the Debug store so the Debug screen can show
        // them without any Mac/Xcode involvement. `contentIdentifier` is
        // technically optional in the TS shape but the Swift side always
        // returns it on the happy path; we still guard the cast defensively.
        if (result && typeof result.localIdentifier === 'string') {
          useDebugInfoStore.getState().recordSaveSuccess({
            localIdentifier: result.localIdentifier,
            contentIdentifier:
              typeof result.contentIdentifier === 'string' ? result.contentIdentifier : '(missing)',
          });
        }
        return result as NativeExportResult;
      } catch (e) {
        // Expo Modules surfaces native rejections as plain `Error` with a
        // `code` field (see Swift `promise.reject(code, message)`).
        const rejection = e as NativeRejection;
        const code: string = rejection?.code ?? 'ERR_LIVE_PHOTO_EXPORT_FAILED';
        const message = e instanceof Error ? e.message : String(e);
        logger.warn('NativeLivePhotoBridge.saveLivePhoto rejected', code, message);
        useDebugInfoStore.getState().recordSaveError(code, message);
        throw codeToAppError(code, message);
      }
    },
  };
};
