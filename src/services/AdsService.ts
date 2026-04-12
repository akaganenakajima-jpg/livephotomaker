import type { ExportEntitlement } from '@/types/ExportEntitlement';
import { shouldShowAds } from '@/types/ExportEntitlement';
import { logger } from '@/utils/logger';

export type AdResult = 'rewarded' | 'dismissedWithoutReward' | 'failed';

export interface AdsService {
  isEnabled(entitlement: ExportEntitlement): boolean;
  preloadRewarded(): Promise<void>;
  /**
   * Presents the rewarded ad. Must only be called after the user explicitly
   * opted into watching. Never call this from a progress screen.
   */
  presentRewarded(): Promise<AdResult>;
}

/**
 * Default implementation. Dynamically requires `react-native-google-mobile-ads`
 * so the app still builds in Expo Go and on CI where the SDK is not linked.
 *
 * When the SDK is not available, `presentRewarded` returns `'failed'` so the
 * UI gracefully falls back to the standard-quality export path.
 */
export const createAdsService = (): AdsService => {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let mobileAds: any | null = null;
  try {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    mobileAds = require('react-native-google-mobile-ads');
  } catch {
    mobileAds = null;
  }

  let rewarded: {
    load: () => void;
    show: () => void;
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    addAdEventListener: (event: string, cb: (data?: any) => void) => () => void;
  } | null = null;

  const ensureRewarded = () => {
    if (!mobileAds) return null;
    if (rewarded) return rewarded;
    const unitId =
      process.env.EXPO_PUBLIC_ADMOB_IOS_REWARDED_UNIT_ID ||
      'ca-app-pub-3940256099942544/1712485313';
    rewarded = mobileAds.RewardedAd.createForAdRequest(unitId, {
      requestNonPersonalizedAdsOnly: true,
    });
    return rewarded;
  };

  return {
    isEnabled: (entitlement) => shouldShowAds(entitlement),

    preloadRewarded: async () => {
      const ad = ensureRewarded();
      if (!ad) return;
      try {
        ad.load();
      } catch (e) {
        logger.warn('ads.preloadRewarded failed', e);
      }
    },

    presentRewarded: async () => {
      const ad = ensureRewarded();
      if (!ad) return 'failed';
      return new Promise<AdResult>((resolve) => {
        let earned = false;
        const offEarned = ad.addAdEventListener('earned_reward', () => {
          earned = true;
        });
        const offClosed = ad.addAdEventListener('closed', () => {
          offEarned();
          offClosed();
          resolve(earned ? 'rewarded' : 'dismissedWithoutReward');
        });
        const offError = ad.addAdEventListener('error', () => {
          offEarned();
          offClosed();
          offError();
          resolve('failed');
        });
        try {
          ad.show();
        } catch {
          resolve('failed');
        }
      });
    },
  };
};
