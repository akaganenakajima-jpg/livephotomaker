module.exports = {
  root: true,
  extends: ['expo', 'prettier'],
  plugins: ['prettier'],
  rules: {
    'prettier/prettier': 'warn',
    '@typescript-eslint/consistent-type-imports': 'warn',
    'react-native/no-inline-styles': 'off',
    // Disabled due to a known interface incompatibility between
    // eslint-import-resolver-typescript@3.10+ and eslint-plugin-import@2.32
    // when pulled transitively via eslint-config-expo@7.1. The TS resolver
    // throws `typescript with invalid interface loaded as resolver` which
    // corrupts every import/* check that depends on it. TypeScript itself
    // (`npm run typecheck`, tsc --noEmit) already covers these rules, so
    // losing them at the ESLint layer has no coverage loss — it just
    // removes duplicate reporting.
    'import/namespace': 'off',
    'import/no-unresolved': 'off',
    'import/default': 'off',
    'import/named': 'off',
    'import/no-named-as-default-member': 'off',
  },
  ignorePatterns: ['node_modules', 'dist', 'build', '_legacy-swift', 'modules/*/build'],
};
