import { parseEnvironment } from './env';

const valid = {
  EXPO_PUBLIC_APP_ENV: 'development',
  EXPO_PUBLIC_SUPABASE_URL: 'http://127.0.0.1:54321',
  EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_abcdefghijklmnop',
};

function fakeJwt(payload: object): string {
  const encode = (value: object) => btoa(JSON.stringify(value)).replace(/=+$/, '');
  return `${encode({ alg: 'HS256', typ: 'JWT' })}.${encode(payload)}.signature_signature`;
}

describe('parseEnvironment', () => {
  it('godtar en giltig lokal konfiguration', () => {
    expect(parseEnvironment(valid)).toEqual({
      appEnv: 'development',
      supabaseUrl: 'http://127.0.0.1:54321',
      supabasePublishableKey: 'sb_publishable_abcdefghijklmnop',
    });
  });

  it('kastar ett tydligt fel när en variabel saknas', () => {
    expect(() => parseEnvironment({ ...valid, EXPO_PUBLIC_SUPABASE_URL: undefined })).toThrow(
      /EXPO_PUBLIC_SUPABASE_URL/,
    );
  });

  it('avvisar okänd miljö', () => {
    expect(() => parseEnvironment({ ...valid, EXPO_PUBLIC_APP_ENV: 'staging' })).toThrow(
      /EXPO_PUBLIC_APP_ENV/,
    );
  });

  it('avvisar en hemlig nyckel', () => {
    expect(() =>
      parseEnvironment({
        ...valid,
        EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY: 'sb_secret_abcdefghijklmnop',
      }),
    ).toThrow(/hemlig nyckel/);
  });

  it('avvisar en JWT med rollen service_role', () => {
    const key = fakeJwt({ role: 'service_role', iss: 'supabase' });
    expect(() => parseEnvironment({ ...valid, EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY: key })).toThrow(
      /service role/,
    );
  });

  it('godtar en äldre anon-JWT', () => {
    const key = fakeJwt({ role: 'anon', iss: 'supabase' });
    expect(
      parseEnvironment({ ...valid, EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY: key })
        .supabasePublishableKey,
    ).toBe(key);
  });

  it('kräver HTTPS utanför utvecklingsmiljön', () => {
    expect(() => parseEnvironment({ ...valid, EXPO_PUBLIC_APP_ENV: 'production' })).toThrow(
      /HTTPS/,
    );
    expect(
      parseEnvironment({
        ...valid,
        EXPO_PUBLIC_APP_ENV: 'production',
        EXPO_PUBLIC_SUPABASE_URL: 'https://abc.supabase.co',
      }).appEnv,
    ).toBe('production');
  });
});
