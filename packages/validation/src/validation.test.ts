import { describe, expect, it } from 'vitest';

import {
  createChildSchema,
  createHouseholdSchema,
  createInvitationSchema,
  invitationTokenSchema,
  verifyEmailOtpSchema,
} from './index';

const HOUSEHOLD_ID = '6f1c1d1e-8d0b-4f53-9d6e-1f2a3b4c5d6e';

describe('createHouseholdSchema', () => {
  it('trimmar namnet', () => {
    expect(createHouseholdSchema.parse({ name: '  Familjen  ' })).toEqual({ name: 'Familjen' });
  });

  it.each(['', '   ', 'a'.repeat(81), 'Hej\u0000'])('avvisar %j', (name) => {
    expect(createHouseholdSchema.safeParse({ name }).success).toBe(false);
  });
});

describe('createChildSchema', () => {
  it('godtar ett barn med födelsedatum och färg', () => {
    const result = createChildSchema.safeParse({
      householdId: HOUSEHOLD_ID,
      displayName: 'Elsa',
      birthDate: '2018-04-12',
      color: '#33AAFF',
    });
    expect(result.success).toBe(true);
  });

  it('avvisar födelsedatum i framtiden', () => {
    const result = createChildSchema.safeParse({
      householdId: HOUSEHOLD_ID,
      displayName: 'Elsa',
      birthDate: '2999-01-01',
    });
    expect(result.success).toBe(false);
  });
});

describe('createInvitationSchema', () => {
  it('kräver rollen child när ett befintligt barn ska kopplas', () => {
    const result = createInvitationSchema.safeParse({
      householdId: HOUSEHOLD_ID,
      role: 'adult',
      targetMemberId: HOUSEHOLD_ID,
    });
    expect(result.success).toBe(false);
  });

  it('tillåter inte inbjudan som owner', () => {
    expect(
      createInvitationSchema.safeParse({ householdId: HOUSEHOLD_ID, role: 'owner' }).success,
    ).toBe(false);
  });

  it('normaliserar e-post', () => {
    const parsed = createInvitationSchema.parse({
      householdId: HOUSEHOLD_ID,
      role: 'adult',
      email: ' Anna@Example.SE ',
    });
    expect(parsed.email).toBe('anna@example.se');
  });
});

describe('invitationTokenSchema', () => {
  it('godtar 43 tecken base64url', () => {
    expect(invitationTokenSchema.safeParse('A'.repeat(42) + '_').success).toBe(true);
  });

  it('avvisar för kort token', () => {
    expect(invitationTokenSchema.safeParse('abc').success).toBe(false);
  });
});

describe('verifyEmailOtpSchema', () => {
  it('kräver sex siffror', () => {
    expect(verifyEmailOtpSchema.safeParse({ email: 'a@b.se', token: '123456' }).success).toBe(true);
    expect(verifyEmailOtpSchema.safeParse({ email: 'a@b.se', token: '12345' }).success).toBe(false);
  });
});
