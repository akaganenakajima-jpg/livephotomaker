import type { NativeLivePhotoBridge, NativeExportResult } from './NativeLivePhotoBridge';
import type { PreparedVideo } from './VideoProcessingService';

export interface LivePhotoExportService {
  isNativeAvailable(): boolean;
  /**
   * Hands the prepared pair off to the native module, which tags both files
   * with a shared asset identifier and saves them via PHAssetCreationRequest.
   * startSeconds / endSeconds are forwarded so the native AVAssetReader can
   * limit the output to the trimmed range without re-encoding.
   */
  saveFromPrepared(
    prepared: PreparedVideo,
    startSeconds: number,
    endSeconds: number,
  ): Promise<NativeExportResult>;
}

export const createLivePhotoExportService = (
  bridge: NativeLivePhotoBridge,
): LivePhotoExportService => ({
  isNativeAvailable: () => bridge.isAvailable(),
  saveFromPrepared: (prepared, startSeconds, endSeconds) =>
    bridge.saveLivePhoto({
      movUri: prepared.movUri,
      stillUri: prepared.stillUri,
      startSeconds,
      endSeconds,
    }),
});
