import { supabase } from '@/lib/supabase';

import { createAuthService } from './auth-service';

/** Appens auth-tjänst, bunden till den riktiga Supabase-klienten. */
export const authService = createAuthService(supabase);
