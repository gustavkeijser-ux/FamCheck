import type { Database } from '@famcheck/types';
import { requestEmailOtpSchema, verifyEmailOtpSchema } from '@famcheck/validation';
import type { Session, SupabaseClient } from '@supabase/supabase-js';

import { type AuthResult, mapAuthError } from './auth-errors';

/**
 * Affärslogik för inloggning, skild från UI:t. Tar klienten som beroende så att
 * den kan testas med en fejkad klient och mot den lokala Supabase-stacken.
 */
export function createAuthService(client: SupabaseClient<Database>) {
  return {
    /** Steg 1: skicka en sexsiffrig engångskod till e-postadressen. */
    async requestEmailOtp(input: { email: string }): Promise<AuthResult<{ email: string }>> {
      const parsed = requestEmailOtpSchema.safeParse(input);
      if (!parsed.success) return { ok: false, error: 'invalid_email' };

      try {
        const { error } = await client.auth.signInWithOtp({
          email: parsed.data.email,
          options: { shouldCreateUser: true },
        });
        if (error) return { ok: false, error: mapAuthError(error) };
        return { ok: true, data: { email: parsed.data.email } };
      } catch (error) {
        return { ok: false, error: mapAuthError(error) };
      }
    },

    /** Steg 2: verifiera koden och få en session. */
    async verifyEmailOtp(input: { email: string; token: string }): Promise<AuthResult<Session>> {
      const parsed = verifyEmailOtpSchema.safeParse(input);
      if (!parsed.success) {
        const emailInvalid = parsed.error.issues.some((issue) => issue.path[0] === 'email');
        return { ok: false, error: emailInvalid ? 'invalid_email' : 'invalid_code' };
      }

      try {
        const { data, error } = await client.auth.verifyOtp({
          email: parsed.data.email,
          token: parsed.data.token,
          type: 'email',
        });
        if (error) {
          const mapped = mapAuthError(error);
          return { ok: false, error: mapped === 'unknown' ? 'invalid_code' : mapped };
        }
        if (!data.session) return { ok: false, error: 'invalid_code' };
        return { ok: true, data: data.session };
      } catch (error) {
        return { ok: false, error: mapAuthError(error) };
      }
    },

    async signOut(): Promise<AuthResult<null>> {
      try {
        // scope 'local': loggar ut den här enheten. 'global' används vid "logga ut överallt".
        const { error } = await client.auth.signOut({ scope: 'local' });
        if (error) return { ok: false, error: mapAuthError(error) };
        return { ok: true, data: null };
      } catch (error) {
        return { ok: false, error: mapAuthError(error) };
      }
    },

    async getSession(): Promise<Session | null> {
      const { data } = await client.auth.getSession();
      return data.session;
    },

    onSessionChange(listener: (session: Session | null) => void): () => void {
      const { data } = client.auth.onAuthStateChange((_event, session) => listener(session));
      return () => data.subscription.unsubscribe();
    },
  };
}

export type AuthService = ReturnType<typeof createAuthService>;
