import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import React from 'react';
import { t } from '@/i18n';
import { ServiceProvider } from '@/services/ServiceContext';

/**
 * Root layout. Wraps the navigation stack with the ServiceProvider so every
 * screen can call `useServices()` without extra wiring. Tests build their
 * own provider with mocks.
 */
export default function RootLayout() {
  return (
    <ServiceProvider>
      <StatusBar style="auto" />
      <Stack
        screenOptions={{
          headerTitleStyle: { fontWeight: '600' },
        }}
      >
        <Stack.Screen name="index" options={{ title: t('nav.home') }} />
        <Stack.Screen name="import" options={{ title: t('nav.import') }} />
        <Stack.Screen name="trim" options={{ title: t('nav.trim') }} />
        <Stack.Screen name="export-options" options={{ title: t('nav.export_options') }} />
        <Stack.Screen
          name="export-progress"
          options={{ title: t('nav.export_progress'), gestureEnabled: false }}
        />
        <Stack.Screen name="live-photo-preview" options={{ title: t('nav.preview') }} />
        <Stack.Screen name="success-guide" options={{ title: t('nav.success') }} />
        <Stack.Screen name="paywall" options={{ title: t('nav.paywall'), presentation: 'modal' }} />
        <Stack.Screen name="settings" options={{ title: t('nav.settings') }} />
        <Stack.Screen name="debug" options={{ title: t('nav.debug') }} />
      </Stack>
    </ServiceProvider>
  );
}
