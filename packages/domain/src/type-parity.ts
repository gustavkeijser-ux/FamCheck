import type { Enums } from '@famcheck/types';

import type { MemberRole } from './roles';
import type { ResourceVisibility } from './visibility';

/**
 * Kompileringskontroller: domänens typer måste exakt motsvara databasens enums.
 * Om en migrering ändrar en enum utan att domänen uppdateras fallerar `pnpm typecheck`.
 */
type Equal<A, B> =
  (<T>() => T extends A ? 1 : 2) extends <T>() => T extends B ? 1 : 2 ? true : false;
type Assert<T extends true> = T;

export type MemberRoleMatchesDatabase = Assert<Equal<MemberRole, Enums<'member_role'>>>;
export type ResourceVisibilityMatchesDatabase = Assert<
  Equal<ResourceVisibility, Enums<'resource_visibility'>>
>;
