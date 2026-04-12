import { logger } from '@/utils/logger';

export type AnalyticsEvent =
  | 'app_open'
  | 'video_selected'
  | 'export_standard_started'
  | 'rewarded_trial_requested'
  | 'rewarded_trial_completed'
  | 'rewarded_trial_failed'
  | 'export_hq_started'
  | 'export_completed'
  | 'export_failed'
  | 'premium_paywall_viewed'
  | 'premium_purchased'
  | 'restore_purchase_tapped';

export interface AnalyticsService {
  track(event: AnalyticsEvent, params?: Record<string, string>): void;
}

export const createAnalyticsService = (): AnalyticsService => ({
  track: (event, params) => {
    logger.debug('analytics', event, params ?? {});
    // Real implementation would forward to an analytics backend here.
  },
});
