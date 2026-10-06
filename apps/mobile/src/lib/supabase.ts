import type { Database } from '@famcheck/types';
import { createClient } from '@supabase/supabase-js';
import { AppState, Platform } from 'react-native';

import { env } from './env';
import { sessionStorage } from './session-storage';

/**
 * Den enda Supabase-klienten i appen. Använder bara den publika nyckeln –
 * all behörighet avgörs av RLS och RPC:er i databasen (RLS_STRATEGY.md).
 * Importera aldrig klienten i komponenter; gå via features/<x>/api.
 */
export const supabase = createClient<Database>(env.supabaseUrl, env.supabasePublishableKey, {
  auth: {
    storage: sessionStorage,
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: false,
    flowType: 'pkce',
  },
});

// Förnya token bara när appen är i förgrunden (rekommendation för React Native).
if (Platform.OS !== 'web') {
  AppState.addEventListener('change', (state) => {
    if (state === 'active') {
      void supabase.auth.startAutoRefresh();
    } else {
      void supabase.auth.stopAutoRefresh();
    }
  });
}

export type AppSupabaseClient = typeof supabase;
