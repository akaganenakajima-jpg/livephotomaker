/**
 * Static registry of App Store product identifiers.
 *
 * IMPORTANT: This file is the single source of truth for product ids.
 * `scripts/hooks/check-iap-identifiers.sh` verifies docs reference the same
 * literal defined here.
 */
export const ProductIdentifier = {
  /**
   * Non-consumable IAP: unlocks high-quality export permanently and removes
   * all ads.
   */
  PremiumHQUnlock: 'com.gen.videotolivephoto.premium.hq_unlock',
} as const;

export type ProductId = (typeof ProductIdentifier)[keyof typeof ProductIdentifier];

export const ALL_PRODUCT_IDS: readonly ProductId[] = [ProductIdentifier.PremiumHQUnlock];
