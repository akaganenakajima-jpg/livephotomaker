import * as ImagePicker from 'expo-image-picker';
import * as MediaLibrary from 'expo-media-library';
import { router } from 'expo-router';
import React, { useEffect, useState } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from 'react-native';
import { t } from '@/i18n';
import { useServices } from '@/services/ServiceContext';
import { useTestModeStore } from '@/store/testModeStore';
import { logger } from '@/utils/logger';

/**
 * Video import screen. Launches the system video picker on mount and
 * routes to the trim step with the picked URI. On cancel/denial we pop
 * back to home rather than trap the user on an empty screen.
 *
 * Test mode (__DEV__ only):
 *   When `testModeStore.isTestMode` is true, the native picker is bypassed.
 *   Instead, the most recently added video is fetched directly from the photo
 *   library via `MediaLibrary.getAssetsAsync`. This makes Maestro E2E flows
 *   fully deterministic — no native system UI to interact with.
 *   The operator enables test mode via the Switch on the home screen.
 */
export default function ImportScreen() {
  const { analytics } = useServices();
  const isTestMode = useTestModeStore((s) => s.isTestMode);
  const [state, setState] = useState<'idle' | 'picking' | 'error'>('idle');
  const [errorKey, setErrorKey] = useState<'import.error' | 'import.test_mode_no_video'>(
    'import.error',
  );

  useEffect(() => {
    let cancelled = false;
    const run = async () => {
      setState('picking');
      try {
        // ── Test mode: bypass the native photo picker ────────────────────────
        // Only available in Development Builds. In production __DEV__ is false
        // and testModeStore.isTestMode is always false, so this branch is
        // dead-code-eliminated by Metro.
        if (__DEV__ && isTestMode) {
          logger.info('import: test mode — fetching most recent video from library');

          // Request read permission (same as the normal picker path).
          const { status } = await MediaLibrary.requestPermissionsAsync();
          if (status !== 'granted') {
            logger.warn('import: test mode — photo library permission denied');
            router.back();
            return;
          }

          // Get the single most recently added video. sortBy defaults to
          // creationTime descending, so index 0 is always the newest.
          const { assets } = await MediaLibrary.getAssetsAsync({
            mediaType: MediaLibrary.MediaType.video,
            first: 1,
            sortBy: [[MediaLibrary.SortBy.creationTime, false]],
          });

          if (cancelled) return;

          if (!assets[0]) {
            logger.warn('import: test mode — no video found in library');
            setErrorKey('import.test_mode_no_video');
            setState('error');
            return;
          }

          // Resolve the ph:// asset reference to a local file:// URI.
          // shouldDownloadFromNetwork: false prevents triggering an iCloud
          // download during tests (we only want locally stored videos).
          const info = await MediaLibrary.getAssetInfoAsync(assets[0], {
            shouldDownloadFromNetwork: false,
          });

          if (cancelled) return;

          const uri = info.localUri ?? info.uri;
          logger.info('import: test mode resolved uri', uri);
          analytics.track('video_selected', { source: 'test_mode' });
          router.replace({ pathname: '/trim', params: { videoUri: uri } });
          return;
        }

        // ── Normal mode: launch the system photo picker ──────────────────────
        const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
        if (!permission.granted) {
          router.back();
          return;
        }
        const result = await ImagePicker.launchImageLibraryAsync({
          mediaTypes: ImagePicker.MediaTypeOptions.Videos,
          allowsEditing: false,
          quality: 1,
        });
        if (cancelled) return;
        if (result.canceled || !result.assets[0]) {
          router.back();
          return;
        }
        analytics.track('video_selected');
        router.replace({
          pathname: '/trim',
          params: { videoUri: result.assets[0].uri },
        });
      } catch (e) {
        logger.warn('import failed', e);
        setState('error');
      }
    };
    void run();
    return () => {
      cancelled = true;
    };
  }, [analytics, isTestMode]);

  if (state === 'error') {
    return (
      <View style={styles.root} testID="import-error-screen">
        <Text style={styles.errorText}>{t(errorKey)}</Text>
        <Pressable style={styles.button} onPress={() => router.back()}>
          <Text style={styles.buttonText}>{t('import.back')}</Text>
        </Pressable>
      </View>
    );
  }

  return (
    <View style={styles.root} testID="import-loading-screen">
      <ActivityIndicator testID="import-spinner" />
      <Text style={styles.hint}>
        {__DEV__ && isTestMode ? t('import.test_mode_loading') : t('import.loading')}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 16,
    backgroundColor: '#fff',
  },
  hint: { color: '#3C3C43', fontSize: 15 },
  errorText: { color: '#FF3B30', fontSize: 17, fontWeight: '600', textAlign: 'center' },
  button: {
    paddingHorizontal: 24,
    paddingVertical: 12,
    backgroundColor: '#007AFF',
    borderRadius: 12,
  },
  buttonText: { color: '#fff', fontSize: 17, fontWeight: '600' },
});
