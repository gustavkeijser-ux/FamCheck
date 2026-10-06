import type { Session } from '@supabase/supabase-js';
import { useQueryClient } from '@tanstack/react-query';
import { createContext, type ReactNode, useContext, useEffect, useMemo, useState } from 'react';

import type { AuthService } from '../api/auth-service';

export type SessionState =
  | { status: 'loading'; session: null }
  | { status: 'signed_out'; session: null }
  | { status: 'signed_in'; session: Session };

const SessionContext = createContext<SessionState | null>(null);

export function toSessionState(session: Session | null): SessionState {
  return session ? { status: 'signed_in', session } : { status: 'signed_out', session: null };
}

export function SessionProvider({
  authService,
  children,
}: {
  authService: AuthService;
  children: ReactNode;
}) {
  const queryClient = useQueryClient();
  const [state, setState] = useState<SessionState>({ status: 'loading', session: null });

  useEffect(() => {
    let active = true;
    void authService.getSession().then((session) => {
      if (active) setState(toSessionState(session));
    });

    const unsubscribe = authService.onSessionChange((session) => {
      setState((previous) => {
        // Byte av användare eller utloggning: släng all cachad data från förra sessionen.
        if (previous.session?.user.id !== session?.user.id) queryClient.clear();
        return toSessionState(session);
      });
    });

    return () => {
      active = false;
      unsubscribe();
    };
  }, [authService, queryClient]);

  return <SessionContext.Provider value={state}>{children}</SessionContext.Provider>;
}

export function useSession(): SessionState {
  const value = useContext(SessionContext);
  if (!value) throw new Error('useSession måste användas inom <SessionProvider>');
  return value;
}

export function useCurrentUserEmail(): string | null {
  const state = useSession();
  return useMemo(() => state.session?.user.email ?? null, [state.session]);
}
