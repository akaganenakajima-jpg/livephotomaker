import { createAnalyticsService, type AnalyticsService } from './AnalyticsService';
import { createAdsService, type AdsService } from './AdsService';
import { createPurchaseService, type PurchaseService } from './PurchaseService';
import { createPhotoLibraryService, type PhotoLibraryService } from './PhotoLibraryService';
import {
  createVideoProcessingService,
  type VideoProcessingService,
} from './VideoProcessingService';
import { createNativeLivePhotoBridge, type NativeLivePhotoBridge } from './NativeLivePhotoBridge';
import {
  createLivePhotoExportService,
  type LivePhotoExportService,
} from './LivePhotoExportService';

/**
 * Aggregate container of service instances. A single instance is created at
 * app start and passed through React context. Tests build their own
 * container with mocks.
 */
export interface ServiceContainer {
  readonly analytics: AnalyticsService;
  readonly ads: AdsService;
  readonly purchase: PurchaseService;
  readonly photoLibrary: PhotoLibraryService;
  readonly videoProcessing: VideoProcessingService;
  readonly nativeLivePhoto: NativeLivePhotoBridge;
  readonly livePhotoExport: LivePhotoExportService;
}

export const createServiceContainer = (): ServiceContainer => {
  const nativeLivePhoto = createNativeLivePhotoBridge();
  return {
    analytics: createAnalyticsService(),
    ads: createAdsService(),
    purchase: createPurchaseService(),
    photoLibrary: createPhotoLibraryService(),
    videoProcessing: createVideoProcessingService(),
    nativeLivePhoto,
    livePhotoExport: createLivePhotoExportService(nativeLivePhoto),
  };
};

export type { AnalyticsService, AdsService, PurchaseService };
export type { PhotoLibraryService, VideoProcessingService };
export type { NativeLivePhotoBridge, LivePhotoExportService };
