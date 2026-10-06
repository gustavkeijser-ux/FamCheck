// Gemensam ESLint-konfiguration (flat config) för hela monorepot.
import js from '@eslint/js';
import expoConfig from 'eslint-config-expo/flat.js';
import prettier from 'eslint-config-prettier';
import globals from 'globals';
import tseslint from 'typescript-eslint';

const strictTypeScript = {
  rules: {
    '@typescript-eslint/no-explicit-any': 'error',
    '@typescript-eslint/no-non-null-assertion': 'error',
    '@typescript-eslint/consistent-type-imports': ['error', { prefer: 'type-imports' }],
    '@typescript-eslint/no-unused-vars': [
      'error',
      { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
    ],
    eqeqeq: ['error', 'always'],
    'no-console': ['error', { allow: ['warn', 'error'] }],
  },
};

// Beroenderegler: paket får aldrig importera från appen (se REPOSITORY_STRUCTURE.md).
const packageBoundaries = {
  files: ['packages/**/*.{ts,tsx}'],
  rules: {
    'no-restricted-imports': [
      'error',
      {
        patterns: [
          {
            group: ['@famcheck/mobile', '**/apps/**'],
            message: 'Paket får inte importera från apps/.',
          },
        ],
      },
    ],
  },
};

// Delade paket ska fungera i React Native, Node och Deno (Edge Functions), se risk R9.
const platformNeutralPackages = {
  files: ['packages/{domain,utils,validation,types}/src/**/*.ts'],
  ignores: ['**/*.test.ts'],
  rules: {
    'no-restricted-imports': [
      'error',
      {
        patterns: [
          {
            group: ['node:*', 'fs', 'path', 'react-native', 'expo*'],
            message: 'Delade paket måste vara plattformsneutrala.',
          },
          {
            group: ['@famcheck/mobile', '**/apps/**'],
            message: 'Paket får inte importera från apps/.',
          },
        ],
      },
    ],
  },
};

export default tseslint.config(
  {
    ignores: [
      '**/node_modules/**',
      '**/dist/**',
      '**/.expo/**',
      'apps/mobile/ios/**',
      'apps/mobile/android/**',
      'packages/types/src/database.ts',
      'supabase/functions/**',
      'supabase/.temp/**',
    ],
  },
  // Rena TypeScript-paket och skript
  {
    files: ['packages/**/*.{ts,tsx}', 'scripts/**/*.{js,mjs}', '*.{js,mjs}'],
    extends: [js.configs.recommended, ...tseslint.configs.strict],
    languageOptions: { globals: { ...globals.node } },
    ...strictTypeScript,
  },
  packageBoundaries,
  platformNeutralPackages,
  // Expo-appen
  ...expoConfig.map((config) => ({ ...config, files: ['apps/mobile/**/*.{js,jsx,ts,tsx}'] })),
  {
    files: ['apps/mobile/**/*.{ts,tsx}'],
    extends: [...tseslint.configs.strict],
    settings: {
      'import/resolver': { typescript: { project: 'apps/mobile/tsconfig.json' } },
    },
    ...strictTypeScript,
  },
  {
    files: ['apps/mobile/**/*.test.{ts,tsx}', 'apps/mobile/jest.setup.ts'],
    languageOptions: { globals: { ...globals.jest } },
  },
  prettier,
);
