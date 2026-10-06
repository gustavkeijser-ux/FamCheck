import { z } from 'zod';

/**
 * Validerad runtime-konfiguration. Appen ska vägra starta med en otydlig eller
 * farlig konfiguration hellre än att köra mot fel miljö.
 *
 * OBS: Expo bygger bara in EXPO_PUBLIC_-variabler som refereras statiskt
 * (process.env.EXPO_PUBLIC_X), därför listas de explicit nedan.
 */
const envSchema = z
  .object({
    EXPO_PUBLIC_APP_ENV: z.enum(['development', 'preview', 'production']),
    EXPO_PUBLIC_SUPABASE_URL: z.url(),
    EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY: z
      .string()
      .min(20)
      .refine((key) => !key.startsWith('sb_secret_'), {
        message: 'En hemlig nyckel får aldrig byggas in i appen',
      })
      .refine((key) => !isServiceRoleJwt(key), {
        message: 'En service role-nyckel får aldrig byggas in i appen',
      }),
  })
  .refine(
    (env) =>
      env.EXPO_PUBLIC_APP_ENV === 'development' ||
      env.EXPO_PUBLIC_SUPABASE_URL.startsWith('https://'),
    { message: 'Preview och produktion måste använda HTTPS', path: ['EXPO_PUBLIC_SUPABASE_URL'] },
  );

export type AppEnvironment = {
  appEnv: 'development' | 'preview' | 'production';
  supabaseUrl: string;
  supabasePublishableKey: string;
};

/** Äldre Supabase-nycklar är JWT:er – avvisa en som har rollen service_role. */
function isServiceRoleJwt(key: string): boolean {
  const payload = key.split('.')[1];
  if (!payload) return false;
  try {
    const json = JSON.parse(globalThis.atob(payload.replace(/-/g, '+').replace(/_/g, '/'))) as {
      role?: unknown;
    };
    return json.role === 'service_role';
  } catch {
    return false;
  }
}

export function parseEnvironment(source: Record<string, string | undefined>): AppEnvironment {
  const result = envSchema.safeParse(source);
  if (!result.success) {
    const problems = result.error.issues
      .map((issue) => `  - ${issue.path.join('.') || 'env'}: ${issue.message}`)
      .join('\n');
    throw new Error(`Ogiltig app-konfiguration:\n${problems}\nSe apps/mobile/.env.example.`);
  }
  return {
    appEnv: result.data.EXPO_PUBLIC_APP_ENV,
    supabaseUrl: result.data.EXPO_PUBLIC_SUPABASE_URL,
    supabasePublishableKey: result.data.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  };
}

export const env: AppEnvironment = parseEnvironment({
  EXPO_PUBLIC_APP_ENV: process.env.EXPO_PUBLIC_APP_ENV,
  EXPO_PUBLIC_SUPABASE_URL: process.env.EXPO_PUBLIC_SUPABASE_URL,
  EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY: process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
});
