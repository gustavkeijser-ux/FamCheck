/**
 * Roller och förmågor (capabilities).
 *
 * VIKTIGT: Det här är en SPEGEL av databasens `private.role_permissions`.
 * Databasen är den enda säkerhetsgränsen – den här modulen används bara för att
 * anpassa UI:t (t.ex. dölja en knapp). Ett paritetstest (permissions.test.ts)
 * fallerar om spegeln och migreringen glider isär.
 */

export const MEMBER_ROLES = ['owner', 'adult', 'child', 'managed_child'] as const;
export type MemberRole = (typeof MEMBER_ROLES)[number];

export const PERMISSIONS = [
  'household.read',
  'household.update',
  'household.delete',
  'members.read',
  'members.invite',
  'members.remove',
  'members.manage_roles',
  'children.manage',
  'audit.read',
  'subscription.manage',
  'bank.manage',
  'finance.read',
  'finance.write',
  'savings.write',
  'calendar.read',
  'calendar.write',
  'routines.write',
  'tasks.write',
] as const;
export type Permission = (typeof PERMISSIONS)[number];

/**
 * Förmågor som aldrig kan ges till någon annan än owner, inte ens via framtida
 * individuella tilldelningar (se ROLES_AND_PERMISSIONS.md §4).
 */
export const OWNER_ONLY_PERMISSIONS: readonly Permission[] = [
  'household.delete',
  'members.manage_roles',
  'subscription.manage',
];

const ADULT_PERMISSIONS: readonly Permission[] = [
  'household.read',
  'members.read',
  'children.manage',
  'finance.read',
  'finance.write',
  'savings.write',
  'calendar.read',
  'calendar.write',
  'routines.write',
  'tasks.write',
];

export const ROLE_PERMISSIONS: Readonly<Record<MemberRole, readonly Permission[]>> = {
  owner: PERMISSIONS,
  adult: ADULT_PERMISSIONS,
  // Barn får inga ekonomi- eller kalenderförmågor via sin roll. Deras åtkomst
  // till egna poster styrs av barnbehörigheterna (ChildPermissions).
  child: ['household.read', 'members.read'],
  // Loggar aldrig in.
  managed_child: [],
};

export function roleHasPermission(role: MemberRole, permission: Permission): boolean {
  return ROLE_PERMISSIONS[role].includes(permission);
}

export function isChildRole(role: MemberRole): role is 'child' | 'managed_child' {
  return role === 'child' || role === 'managed_child';
}

export function isAdultRole(role: MemberRole): role is 'owner' | 'adult' {
  return role === 'owner' || role === 'adult';
}
