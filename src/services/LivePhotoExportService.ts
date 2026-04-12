import type { NativeLivePhotoBridge, NativeExportResult } from './NativeLivePhotoBridge';
import type { PreparedVideo } from './VideoProcessingService';

export interface LivePhotoExportService {
  isNativeAvailable(): boolean;
  /**
   * Hands the prepared pair off to the native module, which tags both files
   * with a shared asset identifier and saves them via PHAssetCreationRequest.
   */
  saveFromPrepared(prepared: PreparedVideo): Promise<NativeExportResult>;
}

export const createLivePhotoExportService = (
  bridge: NativeLivePhotoBridge,
): LivePhotoExportService => ({
  isNativeAvailable: () => bridge.isAvailable(),
  saveFromPrepared: (prepared) =>
    bridge.saveLivePhoto({
      movUri: prepared.movUri,
      stillUri: prepared.stillUri,
    }),
});
