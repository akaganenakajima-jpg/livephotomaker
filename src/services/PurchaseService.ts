import type { AppError } from '@/types/AppError';
import { ALL_PRODUCT_IDS, ProductIdentifier, type ProductId } from '@/constants/products';
import { logger } from '@/utils/logger';

export interface Product {
  readonly id: ProductId;
  readonly displayName: string;
  readonly displayPrice: string;
}

export interface PurchaseService {
  /** Loads product metadata from the App Store (StoreKit 2). */
  loadProducts(): Promise<Product[]>;
  /** Attempts to buy the given product id. Returns true if the user completed. */
  purchase(productId: ProductId): Promise<boolean>;
  /** Restores non-consumable purchases. */
  restore(): Promise<void>;
  /** Returns true if the premium entitlement is currently active. */
  isPremiumUnlocked(): Promise<boolean>;
}

/**
 * Default implementation. Uses a lazy dynamic import so the bundle still
 * compiles on Expo Go where the StoreKit native module is not linked.
 *
 * In production the implementation should call into a StoreKit 2 wrapper
 * (e.g. `expo-iap` or a custom Expo Module). The returned interface intentionally
 * mirrors a subset of `Transaction.currentEntitlements` and `Product.purchase`.
 */
export const createPurchaseService = (): PurchaseService => {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let native: any | null = null;
  try {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    native = require('expo-iap');
  } catch {
    native = null;
  }

  const isAvailable = () => native !== null;

  return {
    loadProducts: async () => {
      if (!isAvailable()) return [];
      try {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const raw: any[] = await native.getProducts(ALL_PRODUCT_IDS);
        return raw.map((p) => ({
          id: p.productId as ProductId,
          displayName: p.title as string,
          displayPrice: p.price as string,
        }));
      } catch (e) {
        logger.warn('purchase.loadProducts failed', e);
        const err: AppError = {
          kind: 'purchaseFailed',
          underlying: e instanceof Error ? e.message : String(e),
        };
        throw err;
      }
    },

    purchase: async (productId) => {
      if (!isAvailable()) return false;
      try {
        const result = await native.requestPurchase(productId);
        return Boolean(result?.transactionId);
      } catch (e) {
        const err: AppError = {
          kind: 'purchaseFailed',
          underlying: e instanceof Error ? e.message : String(e),
        };
        throw err;
      }
    },

    restore: async () => {
      if (!isAvailable()) return;
      try {
        await native.restorePurchases();
      } catch (e) {
        const err: AppError = {
          kind: 'purchaseFailed',
          underlying: e instanceof Error ? e.message : String(e),
        };
        throw err;
      }
    },

    isPremiumUnlocked: async () => {
      if (!isAvailable()) return false;
      try {
        const entitlements: { productId: string }[] = await native.currentEntitlements();
        return entitlements.some((t) => t.productId === ProductIdentifier.PremiumHQUnlock);
      } catch (e) {
        logger.warn('purchase.isPremiumUnlocked failed', e);
        return false;
      }
    },
  };
};
