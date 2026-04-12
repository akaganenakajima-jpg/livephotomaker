import { Link } from 'expo-router';
import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { t } from '@/i18n';

/**
 * Home screen. Single primary action: "choose a video". Settings is a
 * secondary button. No promise of wallpaper changing — App Store guideline
 * compliance lives in the copy layer.
 */
export default function HomeScreen() {
  return (
    <View style={styles.root}>
      <View style={styles.hero}>
        <Text style={styles.title}>{t('home.title')}</Text>
        <Text style={styles.subtitle}>{t('home.subtitle')}</Text>
      </View>
      <Link href="/import" asChild>
        <Pressable style={styles.primaryButton} accessibilityRole="button">
          <Text style={styles.primaryButtonText}>{t('home.start')}</Text>
        </Pressable>
      </Link>
      <Link href="/settings" asChild>
        <Pressable style={styles.secondaryButton} accessibilityRole="button">
          <Text style={styles.secondaryButtonText}>{t('home.settings')}</Text>
        </Pressable>
      </Link>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    paddingHorizontal: 24,
    paddingTop: 48,
    paddingBottom: 32,
    justifyContent: 'space-between',
    backgroundColor: '#fff',
  },
  hero: { gap: 8 },
  title: { fontSize: 34, fontWeight: '700', color: '#000' },
  subtitle: { fontSize: 17, color: '#3C3C43' },
  primaryButton: {
    backgroundColor: '#007AFF',
    paddingVertical: 16,
    borderRadius: 14,
    alignItems: 'center',
  },
  primaryButtonText: { color: '#fff', fontSize: 17, fontWeight: '600' },
  secondaryButton: { paddingVertical: 16, alignItems: 'center' },
  secondaryButtonText: { color: '#007AFF', fontSize: 17 },
});
