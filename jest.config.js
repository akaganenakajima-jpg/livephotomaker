/** @type {import('jest').Config} */
module.exports = {
  preset: 'jest-expo',
  // `setupFilesAfterEnv` runs AFTER Jest's test framework is installed, so
  // `jest.mock(...)` and `expect(...)` are available. The previous config
  // used `setupFilesAfterEach`, which is not a real Jest option and was
  // silently ignored — breaking every mock in `jest.setup.ts`.
  setupFilesAfterEnv: ['<rootDir>/jest.setup.ts'],
  testMatch: ['**/__tests__/**/*.test.ts', '**/__tests__/**/*.test.tsx'],
  transformIgnorePatterns: [
    'node_modules/(?!(jest-)?react-native|@react-native|expo(nent)?|@expo(nent)?/.*|expo-.*|@expo/.*|react-navigation|@react-navigation/.*|@unimodules/.*|unimodules|sentry-expo|native-base|react-native-svg)',
  ],
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',
  },
  collectCoverageFrom: ['src/**/*.{ts,tsx}', 'app/**/*.{ts,tsx}'],
  testPathIgnorePatterns: ['/node_modules/', '/_legacy-swift/'],
};
