import { router } from 'expo-router';
import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { t } from '@/i18n';
import { useEntitlement } from '@/hooks/useEntitlement';
import { useServices } from '@/services/ServiceContext';
import { useEntitlementStore } from '@/store/entitlementStore';

/**
 * Settings screen. Shows current entitlement status and exposes restore
 * purchases. Keeps the copy boring and factual (App Store compliance).
 */
export default function SettingsScreen() {
  const { entitlement } = useEntitlement();
  const { purchase, analytics } = useServices();
  const markPremiumUnlocked = useEntitlementStore((s) => s.markPremiumUnlocked);

  const onRestore = async () => {
    analytics.track('restore_purchase_tapped');
    try {
      await purchase.restore();
      const unlocked = await purchase.isPremiumUnlocked();
      if (unlocked) markPremiumUnlocked();
    } catch {
      // PurchaseService surfaces its own error; nothing to do here.
    }
  };

  return (
    <View style={styles.root}>
      <View style={styles.row}>
        <Text style={styles.label}>{t('settings.plan_label')}</Text>
        <Text style={styles.value}>{renderEntitlement(entitlement)}</Text>
      </View>

      <Pressable style={styles.button} onPress={onRestore}>
        <Text style={styles.buttonText}>{t('settings.restore')}</Text>
      </Pressable>

      <Pressable style={styles.button} onPress={() => router.push('/paywall')}>
        <Text style={styles.buttonText}>{t('settings.buy_premium')}</Text>
      </Pressable>

      {__DEV__ && (
        <Pressable
          style={styles.button}
          onPress={() => router.push('/debug')}
          testID="settings-open-debug"
        >
          <Text style={styles.buttonText}>{t('settings.debug')}</Text>
        </Pressable>
      )}
    </View>
  );
}

const renderEntitlement = (e: string): string => {
  switch (e) {
    case 'premiumUnlocked':
      return t('settings.plan_premium');
    case 'oneTimeHQTrial':
      return t('settings.plan_trial');
    default:
      return t('settings.plan_free');
  }
};

const styles = StyleSheet.create({
  root: { flex: 1, padding: 20, gap: 16, backgroundColor: '#F2F2F7' },
  row: {
    backgroundColor: '#fff',
    borderRadius: 14,
    padding: 18,
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  label: { fontSize: 15, color: '#3C3C43' },
  value: { fontSize: 15, fontWeight: '600' },
  button: {
    backgroundColor: '#fff',
    borderRadius: 14,
    padding: 18,
    alignItems: 'center',
  },
  buttonText: { fontSize: 17, color: '#007AFF' },
});
