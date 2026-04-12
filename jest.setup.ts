// Global test setup: silence noisy native warnings and mock native modules
// that Jest cannot load in a Node environment.
//
// Runs via `setupFilesAfterEnv` so `jest.mock(...)` is available here.
jest.mock('expo-media-library', () => ({
  requestPermissionsAsync: jest.fn(async () => ({ status: 'granted' })),
  createAssetAsync: jest.fn(async () => ({ id: 'mock-asset' })),
}));

jest.mock('expo-image-picker', () => ({
  requestMediaLibraryPermissionsAsync: jest.fn(async () => ({ status: 'granted' })),
  launchImageLibraryAsync: jest.fn(async () => ({
    canceled: false,
    assets: [{ uri: 'file:///mock/video.mov' }],
  })),
  MediaTypeOptions: { Videos: 'Videos' },
}));

jest.mock('expo-file-system', () => ({
  cacheDirectory: 'file:///mock-cache/',
  documentDirectory: 'file:///mock-docs/',
  makeDirectoryAsync: jest.fn(async () => undefined),
  copyAsync: jest.fn(async () => undefined),
  getInfoAsync: jest.fn(async () => ({ exists: true, size: 1 })),
  deleteAsync: jest.fn(async () => undefined),
}));

jest.mock('expo-video-thumbnails', () => ({
  getThumbnailAsync: jest.fn(async () => ({ uri: 'file:///mock/still.jpg' })),
}));

jest.mock('expo-av', () => ({
  Video: {
    createAsync: jest.fn(async () => ({ durationMillis: 3000 })),
  },
}));
