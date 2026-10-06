import type { ConfigContext, ExpoConfig } from 'expo/config';

/**
 * Dynamisk app-konfiguration per miljö. Se docs/architecture/ENVIRONMENTS.md.
 *
 * EXPO_PUBLIC_APP_ENV styr både byggkonfigurationen (bundle id, scheme) och
 * runtime (src/lib/env.ts), så att de aldrig kan peka på olika miljöer.
 */
type AppEnv = 'development' | 'preview' | 'production';

const VARIANTS: Record<AppEnv, { name: string; bundleId: string; scheme: string }> = {
  development: { name: 'FamCheck (dev)', bundleId: 'se.famcheck.app.dev', scheme: 'famcheck-dev' },
  preview: {
    name: 'FamCheck (preview)',
    bundleId: 'se.famcheck.app.preview',
    scheme: 'famcheck-preview',
  },
  production: { name: 'FamCheck', bundleId: 'se.famcheck.app', scheme: 'famcheck' },
};

function resolveAppEnv(value: string | undefined): AppEnv {
  const appEnv = value ?? 'development';
  if (appEnv === 'development' || appEnv === 'preview' || appEnv === 'production') return appEnv;
  throw new Error(`Okänd EXPO_PUBLIC_APP_ENV: ${appEnv}`);
}

export default ({ config }: ConfigContext): ExpoConfig => {
  const appEnv = resolveAppEnv(process.env.EXPO_PUBLIC_APP_ENV);
  const variant = VARIANTS[appEnv];

  return {
    ...config,
    name: variant.name,
    slug: 'famcheck',
    scheme: variant.scheme,
    version: '0.1.0',
    orientation: 'portrait',
    userInterfaceStyle: 'automatic',
    runtimeVersion: { policy: 'fingerprint' },
    ios: {
      bundleIdentifier: variant.bundleId,
      supportsTablet: false,
      config: { usesNonExemptEncryption: false },
    },
    android: {
      package: variant.bundleId,
      // Ingen säkerhetskopiering av lokal data (krypterad session) till Google.
      allowBackup: false,
    },
    plugins: ['expo-router', 'expo-secure-store', 'expo-localization'],
    experiments: { typedRoutes: true },
    extra: { appEnv },
  };
};
