import { router } from 'expo-router';
import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { t } from '@/i18n';

/**
 * After a successful save. Shows the *user-side* steps to set a Live
 * Photo as a lock-screen wallpaper — we never do it for the user
 * (App Store guideline compliance).
 */
export default function SuccessGuideScreen() {
  return (
    <View style={styles.root}>
      <Text style={styles.title}>{t('success.title')}</Text>
      <Text style={styles.body}>{t('success.body')}</Text>
      <View style={styles.steps}>
        <Text style={styles.step}>{t('success.step1')}</Text>
        <Text style={styles.step}>{t('success.step2')}</Text>
        <Text style={styles.step}>{t('success.step3')}</Text>
        <Text style={styles.step}>{t('success.step4')}</Text>
      </View>
      <Pressable style={styles.primary} onPress={() => router.replace('/')}>
        <Text style={styles.primaryText}>{t('success.done')}</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, padding: 24, gap: 16, backgroundColor: '#fff' },
  title: { fontSize: 26, fontWeight: '700' },
  body: { fontSize: 15, color: '#3C3C43' },
  steps: { gap: 8, paddingVertical: 8 },
  step: { fontSize: 15, color: '#000' },
  primary: {
    marginTop: 'auto',
    backgroundColor: '#007AFF',
    paddingVertical: 16,
    borderRadius: 14,
    alignItems: 'center',
  },
  primaryText: { color: '#fff', fontSize: 17, fontWeight: '600' },
});
