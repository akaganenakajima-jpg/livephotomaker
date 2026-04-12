import { create } from 'zustand';
import { consumeTrial, type ExportEntitlement } from '@/types/ExportEntitlement';

interface EntitlementState {
  entitlement: ExportEntitlement;
  setEntitlement: (next: ExportEntitlement) => void;
  grantOneTimeHQTrial: () => void;
  consumeTrialIfNeeded: () => void;
  markPremiumUnlocked: () => void;
  downgradeToFree: () => void;
}

/**
 * Zustand store owning the ExportEntitlement state machine.
 * This is the single source of truth the rest of the app reads from.
 */
export const useEntitlementStore = create<EntitlementState>((set, get) => ({
  entitlement: 'freeStandard',

  setEntitlement: (next) => set({ entitlement: next }),

  grantOneTimeHQTrial: () => {
    if (get().entitlement === 'freeStandard') {
      set({ entitlement: 'oneTimeHQTrial' });
    }
  },

  consumeTrialIfNeeded: () => {
    set({ entitlement: consumeTrial(get().entitlement) });
  },

  markPremiumUnlocked: () => set({ entitlement: 'premiumUnlocked' }),

  downgradeToFree: () => {
    // Only used if a premium entitlement is actually revoked.
    if (get().entitlement === 'premiumUnlocked') {
      set({ entitlement: 'freeStandard' });
    }
  },
}));
