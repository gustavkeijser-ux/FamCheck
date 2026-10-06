/**
 * Barnbehörigheter (beslut D7). Speglar kolumnerna i `public.children`.
 *
 * - Kalender, familjeaktiviteter och uppgifter/rutiner är på som standard.
 * - All ekonomi är explicit opt-in per barn.
 * - Hushållets gemensamma ekonomi och vuxnas ekonomi kan barn ALDRIG få se –
 *   det finns därför ingen flagga för det (se ROLES_AND_PERMISSIONS.md §3).
 */
export interface ChildPermissions {
  canViewCalendar: boolean;
  canViewFamilyEvents: boolean;
  canUseTasksAndRoutines: boolean;
  canViewAllowance: boolean;
  canViewOwnBalance: boolean;
  canViewSavingsGoals: boolean;
}

export const CHILD_PERMISSION_DEFAULTS: Readonly<ChildPermissions> = {
  canViewCalendar: true,
  canViewFamilyEvents: true,
  canUseTasksAndRoutines: true,
  canViewAllowance: false,
  canViewOwnBalance: false,
  canViewSavingsGoals: false,
};

export const CHILD_FINANCE_PERMISSIONS = [
  'canViewAllowance',
  'canViewOwnBalance',
  'canViewSavingsGoals',
] as const satisfies readonly (keyof ChildPermissions)[];
