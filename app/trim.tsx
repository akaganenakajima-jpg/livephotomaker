import { router, useLocalSearchParams } from 'expo-router';
import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { t } from '@/i18n';

/**
 * Trim screen. In this scaffold we skip the actual trimming UI and just
 * forward the video URI to the export-options step. A future iteration
 * can add a scrubbable range selector here; the routing contract will
 * stay the same.
 */
export default function TrimScreen() {
  const { videoUri } = useLocalSearchParams<{ videoUri: string }>();

  return (
    <View style={styles.root} testID="trim-screen">
      <Text style={styles.title}>{t('trim.title')}</Text>
      <Text style={styles.body}>{t('trim.body')}</Text>
      <Pressable
        style={styles.primary}
        onPress={() =>
          router.replace({
            pathname: '/export-options',
            params: { videoUri },
          })
        }
        accessibilityLabel={t('trim.next')}
        testID="trim-next-button"
      >
        <Text style={styles.primaryText}>{t('trim.next')}</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    padding: 24,
    gap: 16,
    backgroundColor: '#fff',
  },
  title: { fontSize: 22, fontWeight: '700' },
  body: { fontSize: 15, color: '#3C3C43' },
  primary: {
    marginTop: 'auto',
    backgroundColor: '#007AFF',
    paddingVertical: 16,
    borderRadius: 14,
    alignItems: 'center',
  },
  primaryText: { color: '#fff', fontSize: 17, fontWeight: '600' },
});
