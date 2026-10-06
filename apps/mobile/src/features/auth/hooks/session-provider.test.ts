import type { Session } from '@supabase/supabase-js';

import { toSessionState } from './session-provider';

describe('toSessionState', () => {
  it('ger signed_out utan session', () => {
    expect(toSessionState(null)).toEqual({ status: 'signed_out', session: null });
  });

  it('ger signed_in med session', () => {
    const session = { user: { id: 'u1' } } as Session;
    expect(toSessionState(session)).toEqual({ status: 'signed_in', session });
  });
});
