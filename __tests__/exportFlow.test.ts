import { createLivePhotoExportService } from '@/services/LivePhotoExportService';
import { createMockNativeLivePhotoBridge } from './mocks/MockNativeLivePhotoBridge';
import { createMockAdsService } from './mocks/MockAdsService';
import { createMockPurchaseService } from './mocks/MockPurchaseService';
import { useEntitlementStore } from '@/store/entitlementStore';
import { ProductIdentifier } from '@/constants/products';
import type { PreparedVideo } from '@/services/VideoProcessingService';

const preparedFixture: PreparedVideo = {
  movUri: 'file:///tmp/clip.mov',
  stillUri: 'file:///tmp/still.jpg',
  durationSeconds: 3,
};

describe('LivePhotoExportService (happy path)', () => {
  it('delegates to the native bridge with the prepared URIs', async () => {
    const bridge = createMockNativeLivePhotoBridge();
    const service = createLivePhotoExportService(bridge);

    const result = await service.saveFromPrepared(preparedFixture);

    expect(bridge.calls).toHaveLength(1);
    expect(bridge.calls[0]).toEqual({
      movUri: preparedFixture.movUri,
      stillUri: preparedFixture.stillUri,
    });
    expect(result.localIdentifier).toBe('mock-asset-id');
  });

  it('surfaces a typed AppError when the native side fails', async () => {
    const bridge = createMockNativeLivePhotoBridge({ throwKind: 'exportFailed' });
    const service = createLivePhotoExportService(bridge);

    await expect(service.saveFromPrepared(preparedFixture)).rejects.toMatchObject({
      kind: 'exportFailed',
    });
  });
});

describe('Rewarded ad flow', () => {
  beforeEach(() => {
    useEntitlementStore.setState({ entitlement: 'freeStandard' });
  });

  it('promotes free → oneTimeHQTrial when the user earns the reward', async () => {
    const ads = createMockAdsService({ presentResult: 'rewarded' });
    const result = await ads.presentRewarded();
    if (result === 'rewarded') {
      useEntitlementStore.getState().grantOneTimeHQTrial();
    }
    expect(useEntitlementStore.getState().entitlement).toBe('oneTimeHQTrial');
  });

  it('does nothing when the user dismisses without earning', async () => {
    const ads = createMockAdsService({ presentResult: 'dismissedWithoutReward' });
    const result = await ads.presentRewarded();
    if (result === 'rewarded') {
      useEntitlementStore.getState().grantOneTimeHQTrial();
    }
    expect(useEntitlementStore.getState().entitlement).toBe('freeStandard');
  });
});

describe('Purchase flow', () => {
  beforeEach(() => {
    useEntitlementStore.setState({ entitlement: 'freeStandard' });
  });

  it('unlocks premium on successful purchase', async () => {
    const purchase = createMockPurchaseService({ purchaseResult: true });
    const ok = await purchase.purchase(ProductIdentifier.PremiumHQUnlock);
    if (ok) useEntitlementStore.getState().markPremiumUnlocked();
    expect(useEntitlementStore.getState().entitlement).toBe('premiumUnlocked');
    expect(purchase.calls.purchase).toContain(ProductIdentifier.PremiumHQUnlock);
  });

  it('restores premium when the user was already entitled', async () => {
    const purchase = createMockPurchaseService({ premiumUnlocked: true });
    await purchase.restore();
    const unlocked = await purchase.isPremiumUnlocked();
    if (unlocked) useEntitlementStore.getState().markPremiumUnlocked();
    expect(useEntitlementStore.getState().entitlement).toBe('premiumUnlocked');
    expect(purchase.calls.restore).toBe(1);
  });
});
