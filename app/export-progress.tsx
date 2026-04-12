import { router, useLocalSearchParams } from 'expo-router';
import React, { useEffect, useState } from 'react';
import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';
import { ensurePhotoPermission } from '@/services/PhotoLibraryService';
import { useServices } from '@/services/ServiceContext';
import { useEntitlementStore } from '@/store/entitlementStore';
import type { ExportQuality } from '@/types/ExportQuality';
import type { AppError } from '@/types/AppError';
import { appErrorMessageKey } from '@/types/AppError';
import { t, type TranslationKey } from '@/i18n';
import { logger } from '@/utils/logger';

/**
 * Export-progress screen. Runs the full pipeline:
 *   1. ensure photo permission
 *   2. extract still + working MOV
 *   3. hand off to the native module to tag+save
 *   4. consume the one-time HQ trial if it was active
 *   5. navigate to the success guide
 *
 * This screen deliberately has no "retry from ad" affordance — ads are
 * only presented on the options screen, never on a failure.
 */
export default function ExportProgressScreen() {
  const { videoUri, quality } = useLocalSearchParams<{
    videoUri: string;
    quality: ExportQuality;
  }>();
  const { videoProcessing, livePhotoExport, photoLibrary, analytics } = useServices();
  const consumeTrial = useEntitlementStore((s) => s.consumeTrialIfNeeded);
  const [error, setError] = useState<AppError | null>(null);

  useEffect(() => {
    let cancelled = false;
    const run = async () => {
      try {
        await ensurePhotoPermission(photoLibrary);
        const prepared = await videoProcessing.prepare({
          sourceUri: videoUri,
          quality,
          startSeconds: 0,
          endSeconds: 3,
        });
        if (quality === 'high') {
          analytics.track('export_hq_started');
        }
        await livePhotoExport.saveFromPrepared(prepared);
        if (cancelled) return;
        consumeTrial();
        analytics.track('export_completed', { quality });
        router.replace('/success-guide');
      } catch (e) {
        logger.warn('export failed', e);
        const appErr: AppError =
          e && typeof e === 'object' && 'kind' in (e as Record<string, unknown>)
            ? (e as AppError)
            : {
                kind: 'exportFailed',
                underlying: e instanceof Error ? e.message : String(e),
              };
        if (!cancelled) setError(appErr);
        analytics.track('export_failed', { reason: appErr.kind });
      }
    };
    void run();
    return () => {
      cancelled = true;
    };
  }, [analytics, consumeTrial, livePhotoExport, photoLibrary, quality, videoProcessing, videoUri]);

  if (error) {
    return (
      <View style={styles.root}>
        <Text style={styles.errorTitle}>エラー</Text>
        <Text style={styles.body}>{t(appErrorMessageKey(error) as TranslationKey)}</Text>
      </View>
    );
  }

  return (
    <View style={styles.root}>
      <ActivityIndicator size="large" />
      <Text style={styles.title}>{t('export.progress.title')}</Text>
      <Text style={styles.body}>{t('export.progress.hint')}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 12,
    padding: 24,
    backgroundColor: '#fff',
  },
  title: { fontSize: 20, fontWeight: '700' },
  body: { fontSize: 15, color: '#3C3C43', textAlign: 'center' },
  errorTitle: { fontSize: 22, fontWeight: '700', color: '#FF3B30' },
});
