import { Link } from 'expo-router';
import React from 'react';
import { Pressable, StyleSheet, Switch, Text, View } from 'react-native';
import { t } from '@/i18n';
import { useTestModeStore } from '@/store/testModeStore';

/**
 * Home screen. Single primary action: "choose a video". Settings is a
 * secondary button. No promise of wallpaper changing — App Store guideline
 * compliance lives in the copy layer.
 *
 * In __DEV__ builds only, a Test Mode row is rendered below the settings
 * button. When enabled, the import screen bypasses the native photo picker
 * and silently selects the most recently added video so Maestro E2E flows
 * can run without interacting with native system UI.
 */
export default function HomeScreen() {
  // Always call hooks unconditionally (React rules). In production the store
  // setTestMode guard keeps isTestMode === false, and all __DEV__ JSX blocks
  // are dead-code-eliminated by Metro at bundle time.
  const isTestMode = useTestModeStore((s) => s.isTestMode);
  const setTestMode = useTestModeStore((s) => s.setTestMode);

  return (
    <View style={styles.root} testID="home-screen">
      {/* Test mode active banner — visible to both operator and Maestro */}
      {__DEV__ && isTestMode && (
        <View style={styles.testBanner} testID="home-test-mode-banner">
          <Text style={styles.testBannerText}>TEST MODE</Text>
        </View>
      )}

      <View style={styles.hero}>
        <Text style={styles.title} testID="home-title">{t('home.title')}</Text>
        <Text style={styles.subtitle} testID="home-subtitle">{t('home.subtitle')}</Text>
      </View>

      <Link href="/import" asChild>
        <Pressable
          style={styles.primaryButton}
          accessibilityRole="button"
          accessibilityLabel={t('home.start')}
          testID="home-start-button"
        >
          <Text style={styles.primaryButtonText}>{t('home.start')}</Text>
        </Pressable>
      </Link>

      <Link href="/settings" asChild>
        <Pressable
          style={styles.secondaryButton}
          accessibilityRole="button"
          accessibilityLabel={t('home.settings')}
          testID="home-settings-button"
        >
          <Text style={styles.secondaryButtonText}>{t('home.settings')}</Text>
        </Pressable>
      </Link>

      {/* ─── DEV-only test mode section ─────────────────────────────────────
          Never rendered in production (Metro dead-code-eliminates __DEV__ blocks).
          Kept at the bottom so it never occludes the primary CTA in normal use.
      ──────────────────────────────────────────────────────────────────────── */}
      {__DEV__ && (
        <View style={styles.testModeSection}>
          <View style={styles.testModeRow}>
            <View style={styles.testModeTextGroup}>
              <Text style={styles.testModeLabel}>{t('debug.test_mode')}</Text>
              <Text style={styles.testModeDetail}>{t('debug.test_mode.detail')}</Text>
            </View>
            <Switch
              value={isTestMode}
              onValueChange={setTestMode}
              testID="home-test-mode-toggle"
              accessibilityLabel={t('debug.test_mode')}
            />
          </View>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    paddingHorizontal: 24,
    paddingTop: 48,
    paddingBottom: 32,
    backgroundColor: '#fff',
  },
  // hero takes all remaining space, pushing the buttons to the bottom
  hero: { flex: 1, gap: 8 },
  title: { fontSize: 34, fontWeight: '700', color: '#000' },
  subtitle: { fontSize: 17, color: '#3C3C43' },
  primaryButton: {
    backgroundColor: '#007AFF',
    paddingVertical: 16,
    borderRadius: 14,
    alignItems: 'center',
    marginBottom: 12,
  },
  primaryButtonText: { color: '#fff', fontSize: 17, fontWeight: '600' },
  secondaryButton: { paddingVertical: 16, alignItems: 'center' },
  secondaryButtonText: { color: '#007AFF', fontSize: 17 },

  // Test mode section — only rendered in DEV builds
  testModeSection: {
    marginTop: 16,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#C6C6C8',
    paddingTop: 12,
  },
  testModeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
  },
  testModeTextGroup: { flex: 1 },
  testModeLabel: { fontSize: 14, fontWeight: '600', color: '#3C3C43' },
  testModeDetail: { fontSize: 12, color: '#8E8E93', marginTop: 2 },

  // Orange banner shown above the hero when test mode is active
  testBanner: {
    backgroundColor: '#FF9500',
    borderRadius: 8,
    paddingVertical: 6,
    paddingHorizontal: 12,
    alignItems: 'center',
    marginBottom: 16,
  },
  testBannerText: {
    fontSize: 13,
    fontWeight: '700',
    color: '#fff',
    letterSpacing: 1,
  },
});
