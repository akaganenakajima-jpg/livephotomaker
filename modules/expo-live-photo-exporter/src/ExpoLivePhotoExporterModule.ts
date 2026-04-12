import { requireNativeModule } from 'expo-modules-core';

/**
 * Native binding. `requireNativeModule` throws at runtime in environments
 * where the module is not linked (e.g. Expo Go, Jest). The JS side wraps
 * this with a try/catch and an `isAvailable()` check so the app can
 * gracefully disable Live Photo export in those environments.
 */
interface NativeBinding {
  saveLivePhotoToLibrary(params: {
    movUri: string;
    stillUri: string;
  }): Promise<{ localIdentifier: string; contentIdentifier: string }>;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
let nativeModule: NativeBinding | any = {};
try {
  nativeModule = requireNativeModule('ExpoLivePhotoExporter');
} catch {
  nativeModule = {};
}

export default nativeModule as NativeBinding;
