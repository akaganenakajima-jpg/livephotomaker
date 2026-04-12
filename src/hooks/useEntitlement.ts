import { useEntitlementStore } from '@/store/entitlementStore';
import { canExportHighQuality, shouldShowAds } from '@/types/ExportEntitlement';

/**
 * Convenience hook exposing the entitlement plus derived flags.
 */
export const useEntitlement = () => {
  const entitlement = useEntitlementStore((s) => s.entitlement);
  return {
    entitlement,
    canExportHighQuality: canExportHighQuality(entitlement),
    shouldShowAds: shouldShowAds(entitlement),
  };
};
