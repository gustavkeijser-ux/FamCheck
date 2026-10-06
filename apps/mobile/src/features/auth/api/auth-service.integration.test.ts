/**
 * Integrationstest mot en riktig Supabase-stack (lokal eller staging).
 * Körs med egen konfiguration (ren Node):
 *   SUPABASE_PUBLISHABLE_KEY=... pnpm --filter @famcheck/mobile test:integration
 * Mot staging sätts även SUPABASE_URL och en hemlig admin-nyckel (endast som CI-secret).
 *
 * Verifierar hela kedjan: e-postkod → session → RPC → RLS → inbjudan → radering.
 */
import {
  deleteTestUsers,
  newClient,
  obtainOtp,
  TEST_EMAIL_DOMAIN,
  usesAdminOtp,
} from '../../../test/supabase-test-env';
import { createAuthService } from './auth-service';

const describeIntegration = process.env.SUPABASE_INTEGRATION === '1' ? describe : describe.skip;
const run = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
const email = (name: string) => `${name}-${run}@${TEST_EMAIL_DOMAIN}`;
const createdEmails: string[] = [];

async function signIn(address: string) {
  createdEmails.push(address);
  const client = newClient();
  const auth = createAuthService(client);
  const token = await obtainOtp(address, async () => {
    expect(await auth.requestEmailOtp({ email: address })).toEqual({
      ok: true,
      data: { email: address },
    });
  });
  const session = await auth.verifyEmailOtp({ email: address, token });
  expect(session.ok).toBe(true);
  return { client, auth };
}

describeIntegration(
  `e-postinloggning mot Supabase (${usesAdminOtp ? 'admin-OTP' : 'Mailpit'})`,
  () => {
    jest.setTimeout(60_000);

    afterAll(async () => {
      await deleteTestUsers(createdEmails);
    });

    it('loggar in med kod, skapar hushåll och isoleras från andra hushåll', async () => {
      const anna = await signIn(email('anna'));
      const bo = await signIn(email('bo'));

      const { data: profiles } = await anna.client.from('profiles').select('display_name');
      expect(profiles).toEqual([{ display_name: `anna-${run}` }]);

      const { data: householdId, error } = await anna.client.rpc('create_household', {
        p_name: 'Familjen Test',
      });
      expect(error).toBeNull();
      expect(typeof householdId).toBe('string');

      const { data: annasHouseholds } = await anna.client.from('households').select('id, name');
      expect(annasHouseholds).toEqual([{ id: householdId, name: 'Familjen Test' }]);

      const { data: bosHouseholds } = await bo.client.from('households').select('id');
      expect(bosHouseholds).toEqual([]);
      const { error: inviteError } = await bo.client.rpc('create_invitation', {
        p_household_id: householdId as string,
        p_role: 'adult',
      });
      expect(inviteError?.message).toBe('forbidden');

      const { data: invitation } = await anna.client
        .rpc('create_invitation', { p_household_id: householdId as string, p_role: 'adult' })
        .single();
      const { error: acceptError } = await bo.client.rpc('accept_invitation', {
        p_token: invitation?.token ?? '',
      });
      expect(acceptError).toBeNull();
      const { data: bosHouseholdsAfter } = await bo.client.from('households').select('id');
      expect(bosHouseholdsAfter).toEqual([{ id: householdId }]);

      // Städning (och kontroll): owner raderar hushållet, Bo ser det inte längre.
      const { error: deleteError } = await anna.client.rpc('delete_household', {
        p_household_id: householdId as string,
        p_confirm_name: 'Familjen Test',
      });
      expect(deleteError).toBeNull();
      const { data: bosHouseholdsGone } = await bo.client.from('households').select('id');
      expect(bosHouseholdsGone).toEqual([]);

      expect(await anna.auth.signOut()).toEqual({ ok: true, data: null });
      expect(await anna.auth.getSession()).toBeNull();
    });

    it('avvisar fel kod', async () => {
      const address = email('fel');
      createdEmails.push(address);
      const client = newClient();
      const auth = createAuthService(client);
      await obtainOtp(address, () => auth.requestEmailOtp({ email: address }));
      await expect(auth.verifyEmailOtp({ email: address, token: '000000' })).resolves.toEqual({
        ok: false,
        error: 'invalid_code',
      });
    });

    it('nekar anonyma anrop till hushållsdata', async () => {
      const { data, error } = await newClient().from('households').select('id');
      expect(data).toBeNull();
      expect(error?.code).toBe('42501');
    });
  },
);
