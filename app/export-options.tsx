import { router, useLocalSearchParams } from 'expo-router';
import React from 'react';
import { Alert, Pressable, StyleSheet, Text, View } from 'react-native';
import { useEntitlement } from '@/hooks/useEntitlement';
import { useEntitlementStore } from '@/store/entitlementStore';
import { useServices } from '@/services/ServiceContext';
import { t } from '@/i18n';

/**
 * Export-options screen.
 * Three user choices: standard (free), rewarded HQ trial (watch ad once),
 * premium HQ unlock (IAP). The rewarded option is hidden when the user
 * has already unlocked premium.
 */
export default function ExportOptionsScreen() {
  const { videoUri } = useLocalSearchParams<{ videoUri: string }>();
  const { entitlement, shouldShowAds } = useEntitlement();
  const { ads, analytics } = useServices();
  const grantTrial = useEntitlementStore((s) => s.grantOneTimeHQTrial);

  const goProgress = (quality: 'standard' | 'high') => {
    router.replace({
      pathname: '/export-progress',
      params: { videoUri, quality },
    });
  };

  const onStandard = () => {
    analytics.track('export_standard_started');
    goProgress('standard');
  };

  const onRewarded = async () => {
    analytics.track('rewarded_trial_requested');
    const result = await ads.presentRewarded();
    if (result === 'rewarded') {
      analytics.track('rewarded_trial_completed');
      grantTrial();
      goProgress('high');
    } else {
      analytics.track('rewarded_trial_failed', { result });
      Alert.alert('', t('error.ad_unavailable'));
    }
  };

  const onPremium = () => {
    router.push('/paywall');
  };

  return (
    <View style={styles.root} testID="export-options-screen">
      <Text style={styles.title}>{t('export.options.title')}</Text>

      <Pressable
        style={styles.option}
        onPress={onStandard}
        accessibilityLabel={t('export.options.standard')}
        testID="export-option-standard"
      >
        <Text style={styles.optionTitle}>{t('export.options.standard')}</Text>
        <Text style={styles.optionBody}>{t('export.options.standard.detail')}</Text>
      </Pressable>

      {shouldShowAds && entitlement === 'freeStandard' ? (
        <Pressable
          style={styles.option}
          onPress={onRewarded}
          accessibilityLabel={t('export.options.rewarded')}
          testID="export-option-rewarded"
        >
          <Text style={styles.optionTitle}>{t('export.options.rewarded')}</Text>
          <Text style={styles.optionBody}>{t('export.options.rewarded.detail')}</Text>
        </Pressable>
      ) : null}

      {entitlement !== 'premiumUnlocked' ? (
        <Pressable
          style={styles.optionPrimary}
          onPress={onPremium}
          accessibilityLabel={t('export.options.premium')}
          testID="export-option-premium"
        >
          <Text style={styles.optionPrimaryTitle}>{t('export.options.premium')}</Text>
          <Text style={styles.optionPrimaryBody}>{t('export.options.premium.detail')}</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    padding: 20,
    gap: 16,
    backgroundColor: '#F2F2F7',
  },
  title: { fontSize: 22, fontWeight: '700', marginBottom: 8 },
  option: {
    backgroundColor: '#fff',
    borderRadius: 14,
    padding: 18,
    gap: 6,
  },
  optionTitle: { fontSize: 17, fontWeight: '600' },
  optionBody: { fontSize: 14, color: '#3C3C43' },
  optionPrimary: {
    backgroundColor: '#007AFF',
    borderRadius: 14,
    padding: 18,
    gap: 6,
  },
  optionPrimaryTitle: { fontSize: 17, fontWeight: '700', color: '#fff' },
  optionPrimaryBody: { fontSize: 14, color: '#FFFFFFCC' },
});
