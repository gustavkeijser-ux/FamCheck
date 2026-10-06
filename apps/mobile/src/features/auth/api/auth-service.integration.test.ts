/**
 * Integrationstest mot den LOKALA Supabase-stacken (pnpm db:start).
 * Körs med egen konfiguration (ren Node), t.ex. i CI:s databasjobb:
 *   SUPABASE_PUBLISHABLE_KEY=... pnpm --filter @famcheck/mobile test:integration
 *
 * Verifierar hela kedjan: e-postkod → session → RPC → RLS.
 */
import type { Database } from '@famcheck/types';
import { createClient } from '@supabase/supabase-js';

import { createAuthService } from './auth-service';

const API_URL = process.env.SUPABASE_URL ?? 'http://127.0.0.1:54321';
const PUBLISHABLE_KEY = process.env.SUPABASE_PUBLISHABLE_KEY ?? '';
const MAILPIT_URL = process.env.MAILPIT_URL ?? 'http://127.0.0.1:54324';

const describeIntegration = process.env.SUPABASE_INTEGRATION === '1' ? describe : describe.skip;

function memoryStorage() {
  const data = new Map<string, string>();
  return {
    getItem: async (key: string) => data.get(key) ?? null,
    setItem: async (key: string, value: string) => void data.set(key, value),
    removeItem: async (key: string) => void data.delete(key),
  };
}

function newClient() {
  return createClient<Database>(API_URL, PUBLISHABLE_KEY, {
    auth: {
      storage: memoryStorage(),
      persistSession: true,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
}

/** Hämtar den senaste sexsiffriga koden som skickats till adressen från Mailpit. */
async function fetchOtpFromMailpit(email: string): Promise<string> {
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

async function signIn(email: string) {
  const client = newClient();
  const auth = createAuthService(client);
  expect(await auth.requestEmailOtp({ email })).toEqual({ ok: true, data: { email } });
  const token = await fetchOtpFromMailpit(email);
  const session = await auth.verifyEmailOtp({ email, token });
  expect(session.ok).toBe(true);
  return { client, auth };
}

describeIntegration('e-postinloggning mot lokal Supabase', () => {
  jest.setTimeout(30_000);
  const run = Date.now();

  it('loggar in med kod, skapar hushåll och isoleras från andra hushåll', async () => {
    const anna = await signIn(`anna-${run}@famcheck.test`);
    const bo = await signIn(`bo-${run}@famcheck.test`);

    // Profil skapad av triggern, synlig bara för en själv.
    const { data: profiles } = await anna.client.from('profiles').select('display_name');
    expect(profiles).toEqual([{ display_name: `anna-${run}` }]);

    const { data: householdId, error } = await anna.client.rpc('create_household', {
      p_name: 'Familjen Test',
    });
    expect(error).toBeNull();
    expect(typeof householdId).toBe('string');

    const { data: annasHouseholds } = await anna.client.from('households').select('id, name');
    expect(annasHouseholds).toEqual([{ id: householdId, name: 'Familjen Test' }]);

    // Bo kan varken se hushållet eller ta sig in via API:et.
    const { data: bosHouseholds } = await bo.client.from('households').select('id');
    expect(bosHouseholds).toEqual([]);
    const { error: inviteError } = await bo.client.rpc('create_invitation', {
      p_household_id: householdId as string,
      p_role: 'adult',
    });
    expect(inviteError?.message).toBe('forbidden');

    // Anna bjuder in Bo, Bo accepterar och ser nu hushållet.
    const { data: invitation } = await anna.client
      .rpc('create_invitation', { p_household_id: householdId as string, p_role: 'adult' })
      .single();
    const { error: acceptError } = await bo.client.rpc('accept_invitation', {
      p_token: invitation?.token ?? '',
    });
    expect(acceptError).toBeNull();
    const { data: bosHouseholdsAfter } = await bo.client.from('households').select('id');
    expect(bosHouseholdsAfter).toEqual([{ id: householdId }]);

    // Utloggning tar bort sessionen.
    expect(await anna.auth.signOut()).toEqual({ ok: true, data: null });
    expect(await anna.auth.getSession()).toBeNull();
  });

  it('avvisar fel kod', async () => {
    const client = newClient();
    const auth = createAuthService(client);
    const email = `fel-${run}@famcheck.test`;
    await auth.requestEmailOtp({ email });
    await expect(auth.verifyEmailOtp({ email, token: '000000' })).resolves.toEqual({
      ok: false,
      error: 'invalid_code',
    });
  });

  it('nekar anonyma anrop till hushållsdata', async () => {
    const { data, error } = await newClient().from('households').select('id');
    expect(data).toBeNull();
    expect(error?.code).toBe('42501');
  });
});
