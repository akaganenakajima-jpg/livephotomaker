import { router } from 'expo-router';
import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
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
        <Text style={styles.label}>現在のプラン</Text>
        <Text style={styles.value}>{renderEntitlement(entitlement)}</Text>
      </View>

      <Pressable style={styles.button} onPress={onRestore}>
        <Text style={styles.buttonText}>購入を復元</Text>
      </Pressable>

      <Pressable style={styles.button} onPress={() => router.push('/paywall')}>
        <Text style={styles.buttonText}>高画質解放を購入</Text>
      </Pressable>

      {__DEV__ && (
        <Pressable
          style={styles.button}
          onPress={() => router.push('/debug')}
          testID="settings-open-debug"
        >
          <Text style={styles.buttonText}>デバッグ情報を開く</Text>
        </Pressable>
      )}
    </View>
  );
}

const renderEntitlement = (e: string): string => {
  switch (e) {
    case 'premiumUnlocked':
      return '高画質 (買い切り)';
    case 'oneTimeHQTrial':
      return '高画質 (1回のみ)';
    default:
      return '標準画質';
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
