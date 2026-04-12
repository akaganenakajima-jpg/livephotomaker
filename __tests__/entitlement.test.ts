import {
  canExportHighQuality,
  consumeTrial,
  shouldShowAds,
  type ExportEntitlement,
} from '@/types/ExportEntitlement';
import { useEntitlementStore } from '@/store/entitlementStore';

describe('ExportEntitlement helpers', () => {
  it('only premium and oneTimeHQTrial can export HQ', () => {
    expect(canExportHighQuality('freeStandard')).toBe(false);
    expect(canExportHighQuality('oneTimeHQTrial')).toBe(true);
    expect(canExportHighQuality('premiumUnlocked')).toBe(true);
  });

  it('ads are suppressed only for premium', () => {
    expect(shouldShowAds('freeStandard')).toBe(true);
    expect(shouldShowAds('oneTimeHQTrial')).toBe(true);
    expect(shouldShowAds('premiumUnlocked')).toBe(false);
  });

  it('consumeTrial only downgrades the trial state', () => {
    const cases: [ExportEntitlement, ExportEntitlement][] = [
      ['freeStandard', 'freeStandard'],
      ['oneTimeHQTrial', 'freeStandard'],
      ['premiumUnlocked', 'premiumUnlocked'],
    ];
    for (const [input, expected] of cases) {
      expect(consumeTrial(input)).toBe(expected);
    }
  });
});

describe('entitlementStore state machine', () => {
  beforeEach(() => {
    useEntitlementStore.setState({ entitlement: 'freeStandard' });
  });

  it('grants a one-time HQ trial from freeStandard', () => {
    useEntitlementStore.getState().grantOneTimeHQTrial();
    expect(useEntitlementStore.getState().entitlement).toBe('oneTimeHQTrial');
  });

  it('does not grant a trial when already premium', () => {
    useEntitlementStore.getState().markPremiumUnlocked();
    useEntitlementStore.getState().grantOneTimeHQTrial();
    expect(useEntitlementStore.getState().entitlement).toBe('premiumUnlocked');
  });

  it('consuming the trial downgrades to freeStandard exactly once', () => {
    useEntitlementStore.getState().grantOneTimeHQTrial();
    useEntitlementStore.getState().consumeTrialIfNeeded();
    expect(useEntitlementStore.getState().entitlement).toBe('freeStandard');
    useEntitlementStore.getState().consumeTrialIfNeeded();
    expect(useEntitlementStore.getState().entitlement).toBe('freeStandard');
  });

  it('premium is terminal (no accidental downgrade from consume)', () => {
    useEntitlementStore.getState().markPremiumUnlocked();
    useEntitlementStore.getState().consumeTrialIfNeeded();
    expect(useEntitlementStore.getState().entitlement).toBe('premiumUnlocked');
  });
});
