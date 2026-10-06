import { useMutation } from '@tanstack/react-query';

import { authService } from '../api';
import type { AuthErrorCode, AuthResult } from '../api/auth-errors';

/** Kastar felkoden så att TanStack Query hanterar den som ett fel. */
async function unwrap<T>(promise: Promise<AuthResult<T>>): Promise<T> {
  const result = await promise;
  if (!result.ok) throw new AuthFlowError(result.error);
  return result.data;
}

export class AuthFlowError extends Error {
  constructor(readonly code: AuthErrorCode) {
    super(code);
    this.name = 'AuthFlowError';
  }
}

export function useRequestEmailOtp() {
  return useMutation({
    mutationFn: (email: string) => unwrap(authService.requestEmailOtp({ email })),
  });
}

export function useVerifyEmailOtp() {
  return useMutation({
    mutationFn: (input: { email: string; token: string }) =>
      unwrap(authService.verifyEmailOtp(input)),
  });
}

export function useSignOut() {
  return useMutation({
    mutationFn: () => unwrap(authService.signOut()),
  });
}

export function errorCodeOf(error: unknown): AuthErrorCode | null {
  return error instanceof AuthFlowError ? error.code : error ? 'unknown' : null;
}
