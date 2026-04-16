import { router } from 'expo-router';
import React, { useState } from 'react';
import { Pressable, Share, StyleSheet, Text, View } from 'react-native';
import { t } from '@/i18n';
import { useDebugInfoStore } from '@/store/debugInfoStore';

/**
 * After a successful save. Shows the *user-side* steps to set a Live
 * Photo as a lock-screen wallpaper — we never do it for the user
 * (App Store guideline compliance).
 *
 * __DEV__ additions (dead-code-eliminated in production by Metro):
 *
 *   ① Identifier panel — shows localIdentifier / contentIdentifier with
 *     Share buttons so the operator can copy them to a PC-side note or
 *     cross-reference with Debug screen / Photos.app without navigating away.
 *
 *   ② Photos confirmation checklist — three tap-to-check items that guide
 *     the operator through the manual verification steps immediately after
 *     tapping "Done". Checked state is in-memory only (not persisted).
 */
export default function SuccessGuideScreen() {
  // Always call hooks unconditionally (React rules of hooks).
  // In production __DEV__ === false so the panel/checklist JSX blocks are
  // tree-shaken by Metro; the store subscription is harmless.
  const lastSaveResult = useDebugInfoStore((s) => s.lastSaveResult);

  // Checklist state — three manual verification items for Photos.app.
  // Keys map directly to the testIDs so Maestro can assert them.
  const [checks, setChecks] = useState({
    liveBadge: false,
    longPress: false,
    album: false,
  });
  const toggle = (key: keyof typeof checks) =>
    setChecks((prev) => ({ ...prev, [key]: !prev[key] }));

  const handleShare = async (value: string, label: string) => {
    try {
      // Share sheet on iOS always shows "Copy" as the first action —
      // no expo-clipboard dependency needed.
      await Share.share({ message: value, title: label });
    } catch {
      // User dismissed the sheet — no action needed.
    }
  };

  return (
    <View style={styles.root} testID="success-screen">
      <Text style={styles.title} testID="success-title">{t('success.title')}</Text>
      <Text style={styles.body}>{t('success.body')}</Text>
      <View style={styles.steps}>
        <Text style={styles.step}>{t('success.step1')}</Text>
        <Text style={styles.step}>{t('success.step2')}</Text>
        <Text style={styles.step}>{t('success.step3')}</Text>
        <Text style={styles.step}>{t('success.step4')}</Text>
      </View>

      {/* ── ① DEV identifier panel ──────────────────────────────────────────
          Shows the two native identifiers with Share buttons.
          Strings are intentionally hardcoded (DEV-only, never shown to users;
          consistent with DebugPanel which also has no i18n).
      ─────────────────────────────────────────────────────────────────────── */}
      {__DEV__ && (
        <View style={styles.devPanel} testID="success-dev-panel">
          <Text style={styles.devHeading}>DEV — 保存済み識別子</Text>

          <View style={styles.devRow}>
            <View style={styles.devRowText}>
              <Text style={styles.devLabel}>localIdentifier</Text>
              <Text style={styles.devValue} testID="success-local-identifier" selectable>
                {lastSaveResult?.localIdentifier ?? '—'}
              </Text>
            </View>
            {lastSaveResult?.localIdentifier ? (
              <Pressable
                style={styles.shareButton}
                onPress={() =>
                  handleShare(lastSaveResult.localIdentifier, 'localIdentifier')
                }
                testID="success-share-local-identifier"
                accessibilityLabel="localIdentifier を共有"
              >
                <Text style={styles.shareButtonText}>共有</Text>
              </Pressable>
            ) : null}
          </View>

          <View style={styles.devRow}>
            <View style={styles.devRowText}>
              <Text style={styles.devLabel}>contentIdentifier</Text>
              <Text style={styles.devValue} testID="success-content-identifier" selectable>
                {lastSaveResult?.contentIdentifier ?? '—'}
              </Text>
            </View>
            {lastSaveResult?.contentIdentifier ? (
              <Pressable
                style={styles.shareButton}
                onPress={() =>
                  handleShare(lastSaveResult.contentIdentifier, 'contentIdentifier')
                }
                testID="success-share-content-identifier"
                accessibilityLabel="contentIdentifier を共有"
              >
                <Text style={styles.shareButtonText}>共有</Text>
              </Pressable>
            ) : null}
          </View>

          {lastSaveResult && (
            <Text style={styles.devTimestamp}>
              {new Date(lastSaveResult.at).toISOString()}
            </Text>
          )}
        </View>
      )}

      {/* ── ② DEV Photos 確認チェックリスト ─────────────────────────────────
          Tap-to-check items. Operator uses this immediately after tapping
          "Done" and opening Photos.app. In-memory only — no persistence.
          testIDs allow Maestro to assert the items exist (future use).
      ─────────────────────────────────────────────────────────────────────── */}
      {__DEV__ && (
        <View style={styles.checklist} testID="success-checklist">
          <Text style={styles.checklistHeading}>Photos で確認 (DEV)</Text>

          <CheckItem
            label="LIVE バッジが表示されている"
            checked={checks.liveBadge}
            onPress={() => toggle('liveBadge')}
            testID="success-check-live-badge"
          />
          <CheckItem
            label="長押しで動画が再生される"
            checked={checks.longPress}
            onPress={() => toggle('longPress')}
            testID="success-check-long-press"
          />
          <CheckItem
            label="「Live Photos」アルバムに含まれる"
            checked={checks.album}
            onPress={() => toggle('album')}
            testID="success-check-album"
          />

          {/* Completion hint — turns green once all three are checked */}
          {checks.liveBadge && checks.longPress && checks.album && (
            <Text style={styles.checklistDone} testID="success-checklist-done">
              ✓ 3 / 3 確認完了
            </Text>
          )}
        </View>
      )}

      <Pressable
        style={styles.primary}
        onPress={() => router.replace('/')}
        accessibilityLabel={t('success.done')}
        testID="success-done-button"
      >
        <Text style={styles.primaryText}>{t('success.done')}</Text>
      </Pressable>
    </View>
  );
}

// ─── Sub-components ──────────────────────────────────────────────────────────

const CheckItem: React.FC<{
  label: string;
  checked: boolean;
  onPress: () => void;
  testID: string;
}> = ({ label, checked, onPress, testID }) => (
  <Pressable
    style={styles.checkRow}
    onPress={onPress}
    testID={testID}
    accessibilityRole="checkbox"
    accessibilityState={{ checked }}
    accessibilityLabel={label}
  >
    <Text style={[styles.checkBox, checked && styles.checkBoxChecked]}>
      {checked ? '✓' : '○'}
    </Text>
    <Text style={[styles.checkLabel, checked && styles.checkLabelChecked]}>{label}</Text>
  </Pressable>
);

// ─── Styles ──────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  root: { flex: 1, padding: 24, gap: 14, backgroundColor: '#fff' },
  title: { fontSize: 26, fontWeight: '700' },
  body: { fontSize: 15, color: '#3C3C43' },
  steps: { gap: 8, paddingVertical: 4 },
  step: { fontSize: 15, color: '#000' },
  primary: {
    marginTop: 'auto',
    backgroundColor: '#007AFF',
    paddingVertical: 16,
    borderRadius: 14,
    alignItems: 'center',
  },
  primaryText: { color: '#fff', fontSize: 17, fontWeight: '600' },

  // ── DEV identifier panel ──────────────────────────────────────────────────
  devPanel: {
    backgroundColor: '#F2F2F7',
    borderRadius: 12,
    padding: 12,
    gap: 6,
  },
  devHeading: {
    fontSize: 11,
    fontWeight: '700',
    color: '#8E8E93',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 2,
  },
  devRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  devRowText: { flex: 1, gap: 1 },
  devLabel: { fontSize: 11, color: '#8E8E93' },
  devValue: {
    fontSize: 13,
    color: '#000',
    fontFamily: 'Menlo',
  },
  devTimestamp: {
    fontSize: 11,
    color: '#8E8E93',
    fontFamily: 'Menlo',
    marginTop: 2,
  },
  shareButton: {
    backgroundColor: '#007AFF',
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 5,
    alignSelf: 'flex-start',
  },
  shareButtonText: { color: '#fff', fontSize: 12, fontWeight: '600' },

  // ── DEV Photos checklist ──────────────────────────────────────────────────
  checklist: {
    borderWidth: 1.5,
    borderColor: '#FF9500',
    borderRadius: 12,
    padding: 12,
    gap: 2,
  },
  checklistHeading: {
    fontSize: 12,
    fontWeight: '700',
    color: '#FF9500',
    marginBottom: 6,
  },
  checkRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 7,
    gap: 10,
  },
  checkBox: {
    fontSize: 18,
    color: '#C7C7CC',
    width: 22,
    textAlign: 'center',
  },
  checkBoxChecked: { color: '#34C759' },
  checkLabel: { fontSize: 14, color: '#3C3C43', flex: 1 },
  checkLabelChecked: { color: '#34C759' },
  checklistDone: {
    marginTop: 6,
    fontSize: 13,
    fontWeight: '700',
    color: '#34C759',
    textAlign: 'center',
  },
});
