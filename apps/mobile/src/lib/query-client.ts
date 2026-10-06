import { QueryClient } from '@tanstack/react-query';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      retry: 2,
    },
    mutations: {
      // Säkerhetskritiska mutationer (inbjudningar, roller) ska aldrig köras om automatiskt.
      retry: 0,
    },
  },
});
