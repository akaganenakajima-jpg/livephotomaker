import * as ImagePicker from 'expo-image-picker';
import { router } from 'expo-router';
import React, { useEffect, useState } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from 'react-native';
import { useServices } from '@/services/ServiceContext';
import { logger } from '@/utils/logger';

/**
 * Video import screen. Launches the system video picker on mount and
 * routes to the trim step with the picked URI. On cancel/denial we pop
 * back to home rather than trap the user on an empty screen.
 */
export default function ImportScreen() {
  const { analytics } = useServices();
  const [state, setState] = useState<'idle' | 'picking' | 'error'>('idle');

  useEffect(() => {
    let cancelled = false;
    const run = async () => {
      setState('picking');
      try {
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
  }, [analytics]);

  if (state === 'error') {
    return (
      <View style={styles.root}>
        <Text style={styles.errorText}>動画を読み込めませんでした。</Text>
        <Pressable style={styles.button} onPress={() => router.back()}>
          <Text style={styles.buttonText}>戻る</Text>
        </Pressable>
      </View>
    );
  }

  return (
    <View style={styles.root}>
      <ActivityIndicator />
      <Text style={styles.hint}>動画を選んでください…</Text>
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
  errorText: { color: '#FF3B30', fontSize: 17, fontWeight: '600' },
  button: {
    paddingHorizontal: 24,
    paddingVertical: 12,
    backgroundColor: '#007AFF',
    borderRadius: 12,
  },
  buttonText: { color: '#fff', fontSize: 17, fontWeight: '600' },
});
