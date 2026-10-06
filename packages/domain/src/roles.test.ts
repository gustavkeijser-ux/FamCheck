import { describe, expect, it } from 'vitest';

import { CHILD_FINANCE_PERMISSIONS, CHILD_PERMISSION_DEFAULTS } from './children';
import {
  MEMBER_ROLES,
  OWNER_ONLY_PERMISSIONS,
  PERMISSIONS,
  ROLE_PERMISSIONS,
  roleHasPermission,
} from './roles';

describe('ROLE_PERMISSIONS', () => {
  it('ger owner alla förmågor', () => {
    expect([...ROLE_PERMISSIONS.owner].sort()).toEqual([...PERMISSIONS].sort());
  });

  it('ger aldrig owner-reserverade förmågor till andra roller', () => {
    for (const role of MEMBER_ROLES.filter((r) => r !== 'owner')) {
      for (const permission of OWNER_ONLY_PERMISSIONS) {
        expect(roleHasPermission(role, permission)).toBe(false);
      }
    }
  });

  it('låter inte adult bjuda in som standard (D3)', () => {
    expect(roleHasPermission('adult', 'members.invite')).toBe(false);
  });

  it('ger aldrig barnroller ekonomi-, kalender- eller administrativa förmågor', () => {
    for (const role of ['child', 'managed_child'] as const) {
      for (const permission of ROLE_PERMISSIONS[role]) {
        expect(['household.read', 'members.read']).toContain(permission);
      }
    }
  });

  it('ger managed_child inga förmågor alls', () => {
    expect(ROLE_PERMISSIONS.managed_child).toHaveLength(0);
  });
});

describe('CHILD_PERMISSION_DEFAULTS (D7)', () => {
  it('har kalender, familjeaktiviteter och uppgifter/rutiner på', () => {
    expect(CHILD_PERMISSION_DEFAULTS.canViewCalendar).toBe(true);
    expect(CHILD_PERMISSION_DEFAULTS.canViewFamilyEvents).toBe(true);
    expect(CHILD_PERMISSION_DEFAULTS.canUseTasksAndRoutines).toBe(true);
  });

  it('har all ekonomi av (explicit opt-in)', () => {
    for (const key of CHILD_FINANCE_PERMISSIONS) {
      expect(CHILD_PERMISSION_DEFAULTS[key]).toBe(false);
    }
  });
});
