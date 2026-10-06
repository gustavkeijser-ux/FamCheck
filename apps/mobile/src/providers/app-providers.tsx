import { QueryClientProvider } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { authService, SessionProvider } from '@/features/auth';
import { queryClient } from '@/lib/query-client';

export function AppProviders({ children }: { children: ReactNode }) {
  return (
    <SafeAreaProvider>
      <QueryClientProvider client={queryClient}>
        <SessionProvider authService={authService}>{children}</SessionProvider>
      </QueryClientProvider>
    </SafeAreaProvider>
  );
}
