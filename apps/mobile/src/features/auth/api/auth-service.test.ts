import type { Database } from '@famcheck/types';
import type { Session, SupabaseClient } from '@supabase/supabase-js';

import { mapAuthError } from './auth-errors';
import { createAuthService } from './auth-service';

function fakeClient(
  overrides: Partial<Record<'signInWithOtp' | 'verifyOtp' | 'signOut', jest.Mock>> = {},
) {
  const auth = {
    signInWithOtp:
      overrides.signInWithOtp ?? jest.fn().mockResolvedValue({ data: {}, error: null }),
    verifyOtp:
      overrides.verifyOtp ??
      jest
        .fn()
        .mockResolvedValue({ data: { session: { user: { id: 'u1' } } as Session }, error: null }),
    signOut: overrides.signOut ?? jest.fn().mockResolvedValue({ error: null }),
    getSession: jest.fn().mockResolvedValue({ data: { session: null } }),
    onAuthStateChange: jest
      .fn()
      .mockReturnValue({ data: { subscription: { unsubscribe: jest.fn() } } }),
  };
  return { auth, client: { auth } as unknown as SupabaseClient<Database> };
}

describe('requestEmailOtp', () => {
  it('normaliserar e-post och skapar användare vid behov', async () => {
    const { auth, client } = fakeClient();
    const result = await createAuthService(client).requestEmailOtp({ email: '  Anna@Example.SE ' });

    expect(result).toEqual({ ok: true, data: { email: 'anna@example.se' } });
    expect(auth.signInWithOtp).toHaveBeenCalledWith({
      email: 'anna@example.se',
      options: { shouldCreateUser: true },
    });
  });

  it('avvisar ogiltig e-post utan att anropa servern', async () => {
    const { auth, client } = fakeClient();
    const result = await createAuthService(client).requestEmailOtp({ email: 'inte-epost' });

    expect(result).toEqual({ ok: false, error: 'invalid_email' });
    expect(auth.signInWithOtp).not.toHaveBeenCalled();
  });

  it('översätter rate limit-fel', async () => {
    const { client } = fakeClient({
      signInWithOtp: jest
        .fn()
        .mockResolvedValue({ error: { code: 'over_email_send_rate_limit', status: 429 } }),
    });
    await expect(createAuthService(client).requestEmailOtp({ email: 'a@b.se' })).resolves.toEqual({
      ok: false,
      error: 'rate_limited',
    });
  });

  it('översätter nätverksfel', async () => {
    const { client } = fakeClient({
      signInWithOtp: jest.fn().mockRejectedValue(new TypeError('Network request failed')),
    });
    await expect(createAuthService(client).requestEmailOtp({ email: 'a@b.se' })).resolves.toEqual({
      ok: false,
      error: 'network',
    });
  });
});

describe('verifyEmailOtp', () => {
  it('returnerar sessionen vid rätt kod', async () => {
    const { auth, client } = fakeClient();
    const result = await createAuthService(client).verifyEmailOtp({
      email: 'a@b.se',
      token: '123456',
    });

    expect(result.ok).toBe(true);
    expect(auth.verifyOtp).toHaveBeenCalledWith({
      email: 'a@b.se',
      token: '123456',
      type: 'email',
    });
  });

  it('avvisar en kod som inte är sex siffror utan att anropa servern', async () => {
    const { auth, client } = fakeClient();
    await expect(
      createAuthService(client).verifyEmailOtp({ email: 'a@b.se', token: '12ab' }),
    ).resolves.toEqual({
      ok: false,
      error: 'invalid_code',
    });
    expect(auth.verifyOtp).not.toHaveBeenCalled();
  });

  it('översätter otp_expired (fel eller utgången kod) till invalid_code', async () => {
    const { client } = fakeClient({
      verifyOtp: jest
        .fn()
        .mockResolvedValue({
          data: { session: null },
          error: { code: 'otp_expired', status: 403 },
        }),
    });
    await expect(
      createAuthService(client).verifyEmailOtp({ email: 'a@b.se', token: '123456' }),
    ).resolves.toEqual({
      ok: false,
      error: 'invalid_code',
    });
  });

  it('behandlar okända serverfel som fel kod utan att läcka meddelandet', async () => {
    const { client } = fakeClient({
      verifyOtp: jest
        .fn()
        .mockResolvedValue({
          data: { session: null },
          error: { message: 'Token has expired or is invalid' },
        }),
    });
    await expect(
      createAuthService(client).verifyEmailOtp({ email: 'a@b.se', token: '123456' }),
    ).resolves.toEqual({
      ok: false,
      error: 'invalid_code',
    });
  });
});

describe('signOut', () => {
  it('loggar bara ut den här enheten', async () => {
    const { auth, client } = fakeClient();
    await expect(createAuthService(client).signOut()).resolves.toEqual({ ok: true, data: null });
    expect(auth.signOut).toHaveBeenCalledWith({ scope: 'local' });
  });
});

describe('mapAuthError', () => {
  it.each([
    [null, 'unknown'],
    ['sträng', 'unknown'],
    [{ code: 'otp_expired' }, 'invalid_code'],
    [{ status: 429 }, 'rate_limited'],
    [{ code: 'validation_failed' }, 'invalid_email'],
    [{ name: 'AuthRetryableFetchError' }, 'network'],
    [{ code: 'something_new' }, 'unknown'],
  ])('%j → %s', (input, expected) => {
    expect(mapAuthError(input)).toBe(expected);
  });
});
