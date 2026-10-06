/**
 * Testmiljö för integrationstester (körs bara i Node/CI, aldrig i appen).
 *
 * Två lägen:
 *  - lokal stack: engångskoden hämtas från Mailpit
 *  - staging:     engångskoden skapas via admin-API:t (SUPABASE_SECRET_KEY finns
 *                 bara som CI-secret). Inga mejl skickas till påhittade adresser.
 */
import type { Database } from '@famcheck/types';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';

export const API_URL = process.env.SUPABASE_URL ?? 'http://127.0.0.1:54321';
export const PUBLISHABLE_KEY = process.env.SUPABASE_PUBLISHABLE_KEY ?? '';
const SECRET_KEY = process.env.SUPABASE_SECRET_KEY ?? '';
const MAILPIT_URL = process.env.MAILPIT_URL ?? 'http://127.0.0.1:54324';

export const usesAdminOtp = SECRET_KEY !== '';
/** Domän som aldrig kan ta emot e-post (RFC 2606). */
export const TEST_EMAIL_DOMAIN = 'famvy.test';

function memoryStorage() {
  const data = new Map<string, string>();
  return {
    getItem: async (key: string) => data.get(key) ?? null,
    setItem: async (key: string, value: string) => void data.set(key, value),
    removeItem: async (key: string) => void data.delete(key),
  };
}

export function newClient(): SupabaseClient<Database> {
  return createClient<Database>(API_URL, PUBLISHABLE_KEY, {
    auth: {
      storage: memoryStorage(),
      persistSession: true,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
}

function adminClient(): SupabaseClient<Database> {
  return createClient<Database>(API_URL, SECRET_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

async function otpFromMailpit(email: string): Promise<string> {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const search = await fetch(
      `${MAILPIT_URL}/api/v1/search?query=${encodeURIComponent(`to:${email}`)}`,
    );
    const { messages } = (await search.json()) as { messages: { ID: string }[] };
    const latest = messages[0];
    if (latest) {
      const message = (await (
        await fetch(`${MAILPIT_URL}/api/v1/message/${latest.ID}`)
      ).json()) as { Text: string };
      const code = /\b(\d{6})\b/.exec(message.Text)?.[1];
      if (code) return code;
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error(`Ingen kod hittades i Mailpit för ${email}`);
}

/**
 * Säkerställer att en engångskod finns för e-postadressen och returnerar den.
 * `requestViaApp` anropas bara lokalt (där Mailpit fångar mejlet).
 */
export async function obtainOtp(
  email: string,
  requestViaApp: () => Promise<unknown>,
): Promise<string> {
  if (!usesAdminOtp) {
    await requestViaApp();
    return otpFromMailpit(email);
  }
  const admin = adminClient();
  await admin.auth.admin.createUser({ email, email_confirm: true });
  const { data, error } = await admin.auth.admin.generateLink({ type: 'magiclink', email });
  if (error || !data.properties.email_otp) throw error ?? new Error('Ingen kod från generateLink');
  return data.properties.email_otp;
}

/** Tar bort testanvändare. Användare med medlemskap måste först ha lämnat/raderat sina hushåll. */
export async function deleteTestUsers(emails: string[]): Promise<void> {
  if (!usesAdminOtp) return; // lokala stacken nollställs med db reset
  const admin = adminClient();
  const { data } = await admin.auth.admin.listUsers({ perPage: 1000 });
  for (const user of data.users.filter((u) => u.email && emails.includes(u.email))) {
    const { error } = await admin.auth.admin.deleteUser(user.id);
    if (error) throw error;
  }
}
