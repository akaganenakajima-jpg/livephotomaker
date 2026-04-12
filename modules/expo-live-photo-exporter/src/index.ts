import ExpoLivePhotoExporterModule from './ExpoLivePhotoExporterModule';

/**
 * Parameters for {@link saveLivePhotoToLibrary}.
 *
 * - `movUri`   : absolute `file://` URI of the short MOV (from the trimmed video).
 * - `stillUri` : absolute `file://` URI of the JPEG still frame that will be the key photo.
 *
 * Both files are rewritten in-place by the native side so they carry a shared
 * `com.apple.quicktime.content.identifier`, which is what turns them into a
 * Live Photo pair when saved via PHAssetCreationRequest.
 */
export interface SaveLivePhotoParams {
  readonly movUri: string;
  readonly stillUri: string;
}

export interface SaveLivePhotoResult {
  /** PHAsset local identifier assigned by Photos after the save succeeds. */
  readonly localIdentifier: string;
  /**
   * UUID that was written into both the JPEG (MakerApple[17]) and the MOV
   * (QuickTime content.identifier). Exposed for diagnostics only — callers
   * should never rely on its format.
   */
  readonly contentIdentifier: string;
}

/**
 * Pairs the given MOV and JPEG into a Live Photo and saves it to the Photos
 * library. Resolves with the created asset's `localIdentifier`.
 *
 * Throws if the native module is not linked (Expo Go) or if the user denies
 * photo-library permission.
 */
export async function saveLivePhotoToLibrary(
  params: SaveLivePhotoParams,
): Promise<SaveLivePhotoResult> {
  return ExpoLivePhotoExporterModule.saveLivePhotoToLibrary(params);
}

/**
 * Returns `true` when the native module is available at runtime. The JS
 * bridge uses this to fall back gracefully in Expo Go / unit tests.
 */
export function isAvailable(): boolean {
  return typeof ExpoLivePhotoExporterModule?.saveLivePhotoToLibrary === 'function';
}

export default {
  saveLivePhotoToLibrary,
  isAvailable,
};
