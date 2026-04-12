import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import React from 'react';
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
        <Stack.Screen name="index" options={{ title: 'Video to Live Photo' }} />
        <Stack.Screen name="import" options={{ title: '動画を選ぶ' }} />
        <Stack.Screen name="trim" options={{ title: 'トリム' }} />
        <Stack.Screen name="export-options" options={{ title: '書き出し方法' }} />
        <Stack.Screen name="export-progress" options={{ title: '作成中', gestureEnabled: false }} />
        <Stack.Screen name="live-photo-preview" options={{ title: 'プレビュー' }} />
        <Stack.Screen name="success-guide" options={{ title: '保存しました' }} />
        <Stack.Screen name="paywall" options={{ title: '高画質解放', presentation: 'modal' }} />
        <Stack.Screen name="settings" options={{ title: '設定' }} />
        <Stack.Screen name="debug" options={{ title: 'デバッグ情報' }} />
      </Stack>
    </ServiceProvider>
  );
}
