/**
 * User's current entitlement for export quality and ads.
 *
 * State transitions:
 *   freeStandard   -> oneTimeHQTrial  (after a successful rewarded ad view)
 *   oneTimeHQTrial -> freeStandard    (after a successful HQ export)
 *   any            -> premiumUnlocked (after successful IAP purchase / restore)
 *
 * `premiumUnlocked` is terminal and always hides ads.
 */
export type ExportEntitlement = 'freeStandard' | 'oneTimeHQTrial' | 'premiumUnlocked';

export const canExportHighQuality = (e: ExportEntitlement): boolean =>
  e === 'premiumUnlocked' || e === 'oneTimeHQTrial';

export const shouldShowAds = (e: ExportEntitlement): boolean => e !== 'premiumUnlocked';

export const consumeTrial = (e: ExportEntitlement): ExportEntitlement =>
  e === 'oneTimeHQTrial' ? 'freeStandard' : e;
