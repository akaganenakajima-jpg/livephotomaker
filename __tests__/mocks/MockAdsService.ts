import type { AdResult, AdsService } from '@/services/AdsService';
import { shouldShowAds } from '@/types/ExportEntitlement';

export interface MockAdsServiceOptions {
  presentResult?: AdResult;
}

export const createMockAdsService = (
  opts: MockAdsServiceOptions = {},
): AdsService & { calls: { present: number; preload: number } } => {
  const calls = { present: 0, preload: 0 };
  return {
    calls,
    isEnabled: (e) => shouldShowAds(e),
    preloadRewarded: async () => {
      calls.preload += 1;
    },
    presentRewarded: async () => {
      calls.present += 1;
      return opts.presentResult ?? 'rewarded';
    },
  };
};
