/** Stabila felkoder som UI:t översätter via i18n (auth.errors.<kod>). */
export const AUTH_ERROR_CODES = [
  'invalid_email',
  'invalid_code',
  'rate_limited',
  'network',
  'unknown',
] as const;
export type AuthErrorCode = (typeof AUTH_ERROR_CODES)[number];

export type AuthResult<T> = { ok: true; data: T } | { ok: false; error: AuthErrorCode };

interface ErrorLike {
  code?: unknown;
  status?: unknown;
  name?: unknown;
  message?: unknown;
}

/** Översätter fel från Supabase Auth till appens felkoder. Läcker aldrig serverns råa meddelanden. */
export function mapAuthError(error: unknown): AuthErrorCode {
  if (typeof error !== 'object' || error === null) return 'unknown';
  const { code, status, name } = error as ErrorLike;

  switch (code) {
    // Supabase Auth svarar otp_expired både för fel och för utgången kod.
    case 'otp_expired':
      return 'invalid_code';
    case 'over_email_send_rate_limit':
    case 'over_request_rate_limit':
      return 'rate_limited';
    case 'email_address_invalid':
    case 'validation_failed':
      return 'invalid_email';
  }
  if (status === 429) return 'rate_limited';
  if (name === 'AuthRetryableFetchError' || name === 'TypeError') return 'network';
  return 'unknown';
}
