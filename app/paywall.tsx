import { router } from 'expo-router';
import React, { useEffect, useState } from 'react';
import { ActivityIndicator, Alert, Pressable, StyleSheet, Text, View } from 'react-native';
import { ProductIdentifier } from '@/constants/products';
import { useServices } from '@/services/ServiceContext';
import { useEntitlementStore } from '@/store/entitlementStore';
import { t } from '@/i18n';
import { logger } from '@/utils/logger';
import type { Product } from '@/services/PurchaseService';

/**
 * Paywall / premium unlock screen. Presented modally from export-options.
 *
 * No forbidden claims: the copy never promises automatic wallpaper setting
 * and the CTA is a clean buy/restore pair. All IAP calls go through the
 * PurchaseService so tests can inject a mock.
 */
export default function PaywallScreen() {
  const { purchase, analytics } = useServices();
  const markPremiumUnlocked = useEntitlementStore((s) => s.markPremiumUnlocked);
  const [product, setProduct] = useState<Product | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    analytics.track('premium_paywall_viewed');
    let cancelled = false;
    const load = async () => {
      try {
        const list = await purchase.loadProducts();
        if (cancelled) return;
        setProduct(list.find((p) => p.id === ProductIdentifier.PremiumHQUnlock) ?? null);
      } catch (e) {
        logger.warn('paywall.loadProducts failed', e);
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    void load();
    return () => {
      cancelled = true;
    };
  }, [analytics, purchase]);

  const onBuy = async () => {
    setBusy(true);
    try {
      const ok = await purchase.purchase(ProductIdentifier.PremiumHQUnlock);
      if (ok) {
        analytics.track('premium_purchased');
        markPremiumUnlocked();
        router.back();
      }
    } catch (e) {
      logger.warn('paywall.purchase failed', e);
      Alert.alert('', t('error.purchase_failed'));
    } finally {
      setBusy(false);
    }
  };

  const onRestore = async () => {
    setBusy(true);
    try {
      analytics.track('restore_purchase_tapped');
      await purchase.restore();
      const unlocked = await purchase.isPremiumUnlocked();
      if (unlocked) {
        markPremiumUnlocked();
        router.back();
      }
    } catch (e) {
      logger.warn('paywall.restore failed', e);
      Alert.alert('', t('error.purchase_failed'));
    } finally {
      setBusy(false);
    }
  };

  return (
    <View style={styles.root}>
      <Text style={styles.title}>{t('paywall.title')}</Text>
      <Text style={styles.body}>{t('paywall.body')}</Text>

      {loading ? (
        <ActivityIndicator />
      ) : (
        <View style={styles.priceBox}>
          <Text style={styles.priceTitle}>{product?.displayName ?? 'Premium HQ Unlock'}</Text>
          <Text style={styles.price}>{product?.displayPrice ?? '—'}</Text>
        </View>
      )}

      <Pressable style={styles.primary} disabled={busy} onPress={onBuy}>
        <Text style={styles.primaryText}>{t('paywall.cta.buy')}</Text>
      </Pressable>
      <Pressable style={styles.secondary} disabled={busy} onPress={onRestore}>
        <Text style={styles.secondaryText}>{t('paywall.cta.restore')}</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, padding: 24, gap: 16, backgroundColor: '#fff' },
  title: { fontSize: 26, fontWeight: '700' },
  body: { fontSize: 15, color: '#3C3C43' },
  priceBox: {
    backgroundColor: '#F2F2F7',
    borderRadius: 14,
    padding: 18,
    gap: 4,
  },
  priceTitle: { fontSize: 15, color: '#3C3C43' },
  price: { fontSize: 26, fontWeight: '700' },
  primary: {
    backgroundColor: '#007AFF',
    paddingVertical: 16,
    borderRadius: 14,
    alignItems: 'center',
  },
  primaryText: { color: '#fff', fontSize: 17, fontWeight: '600' },
  secondary: { paddingVertical: 12, alignItems: 'center' },
  secondaryText: { color: '#007AFF', fontSize: 15 },
});
