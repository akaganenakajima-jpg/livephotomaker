import type { Product, PurchaseService } from '@/services/PurchaseService';
import { ProductIdentifier, type ProductId } from '@/constants/products';

/**
 * In-memory purchase service for unit tests. All network calls are
 * replaced with deterministic resolved values the test can set up front.
 */
export interface MockPurchaseServiceOptions {
  products?: Product[];
  purchaseResult?: boolean;
  premiumUnlocked?: boolean;
  throwOnPurchase?: Error;
}

export const createMockPurchaseService = (
  opts: MockPurchaseServiceOptions = {},
): PurchaseService & { calls: { purchase: ProductId[]; restore: number } } => {
  const calls = { purchase: [] as ProductId[], restore: 0 };
  return {
    calls,
    loadProducts: async () =>
      opts.products ?? [
        {
          id: ProductIdentifier.PremiumHQUnlock,
          displayName: 'Premium HQ Unlock',
          displayPrice: '¥480',
        },
      ],
    purchase: async (productId) => {
      calls.purchase.push(productId);
      if (opts.throwOnPurchase) throw opts.throwOnPurchase;
      return opts.purchaseResult ?? true;
    },
    restore: async () => {
      calls.restore += 1;
    },
    isPremiumUnlocked: async () => opts.premiumUnlocked ?? false,
  };
};
