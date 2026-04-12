import { router } from 'expo-router';
import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { t } from '@/i18n';

/**
 * Optional preview step shown between export-progress and success-guide
 * when the app has already saved a Live Photo that the user wants to
 * verify. The preview itself is a thumbnail + hint text; the actual
 * long-press playback lives in the Photos app.
 */
export default function LivePhotoPreviewScreen() {
  return (
    <View style={styles.root}>
      <Text style={styles.title}>{t('preview.title')}</Text>
      <View style={styles.placeholder} />
      <Text style={styles.hint}>{t('preview.hint')}</Text>
      <Pressable style={styles.primary} onPress={() => router.replace('/success-guide')}>
        <Text style={styles.primaryText}>{t('success.done')}</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, padding: 24, gap: 16, backgroundColor: '#fff' },
  title: { fontSize: 22, fontWeight: '700' },
  placeholder: {
    height: 320,
    borderRadius: 18,
    backgroundColor: '#F2F2F7',
  },
  hint: { fontSize: 14, color: '#3C3C43' },
  primary: {
    marginTop: 'auto',
    backgroundColor: '#007AFF',
    paddingVertical: 16,
    borderRadius: 14,
    alignItems: 'center',
  },
  primaryText: { color: '#fff', fontSize: 17, fontWeight: '600' },
});
