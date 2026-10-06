-- =============================================================================
-- Metatester – skyddsnät som gäller ALLA tabeller och funktioner, även framtida.
-- (RLS_STRATEGY.md §5.4)
-- =============================================================================
begin;
select plan(13);

-- 1. Alla tabeller i public har RLS påslaget.
select is_empty(
  $$ select c.relname::text from pg_class c
     where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p')
       and not c.relrowsecurity $$,
  'alla tabeller i public har RLS påslaget'
);

-- 2. anon har inga tabellrättigheter alls i public.
select is_empty(
  $$ select table_name::text || ':' || privilege_type from information_schema.role_table_grants
     where table_schema = 'public' and grantee = 'anon' $$,
  'anon saknar tabellrättigheter i public'
);

-- 3. authenticated har aldrig TRUNCATE, TRIGGER eller REFERENCES (går förbi RLS / onödigt).
select is_empty(
  $$ select table_name::text || ':' || privilege_type from information_schema.role_table_grants
     where table_schema = 'public' and grantee = 'authenticated'
       and privilege_type in ('TRUNCATE', 'TRIGGER', 'REFERENCES') $$,
  'authenticated saknar TRUNCATE/TRIGGER/REFERENCES'
);

-- 4. Inga tabeller i public har direkt INSERT eller DELETE för authenticated i M1 (allt via RPC).
select is_empty(
  $$ select table_name::text || ':' || privilege_type from information_schema.role_table_grants
     where table_schema = 'public' and grantee = 'authenticated'
       and privilege_type in ('INSERT', 'DELETE') $$,
  'authenticated har ingen direkt INSERT/DELETE (tillståndsändringar via RPC)'
);

-- 5. UPDATE bara på uttryckligen tillåtna kolumner.
select set_eq(
  $$ select table_name::text || '.' || column_name::text from information_schema.column_privileges
     where table_schema = 'public' and grantee = 'authenticated' and privilege_type = 'UPDATE' $$,
  array[
    'profiles.display_name', 'profiles.avatar_path', 'profiles.locale', 'profiles.last_active_household_id',
    'household_members.display_name', 'household_members.color', 'household_members.avatar_path',
    'children.birth_date'
  ],
  'UPDATE är begränsad till presentationskolumner'
);

-- 6. audit_log är append-only för API-rollerna.
select ok(
  not has_table_privilege('authenticated', 'public.audit_log', 'INSERT,UPDATE,DELETE'),
  'audit_log kan inte skrivas av authenticated'
);

-- 7. token_hash kan inte läsas via API:et.
select ok(
  not has_column_privilege('authenticated', 'public.household_invitations', 'token_hash', 'SELECT'),
  'household_invitations.token_hash är inte läsbar'
);

-- 8. Alla security definer-funktioner i public/private har search_path satt.
select is_empty(
  $$ select p.oid::regprocedure::text from pg_proc p
     where p.pronamespace in ('public'::regnamespace, 'private'::regnamespace)
       and p.prosecdef
       and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) cfg where cfg like 'search_path=%') $$,
  'alla security definer-funktioner har search_path'
);

-- 9. anon kan inte köra någon funktion i public.
select is_empty(
  $$ select p.oid::regprocedure::text from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and has_function_privilege('anon', p.oid, 'EXECUTE') $$,
  'anon kan inte köra några funktioner i public'
);

-- 10. authenticated kan bara köra den uttryckliga vitlistan av RPC:er i public.
select set_eq(
  $$ select p.proname::text from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and has_function_privilege('authenticated', p.oid, 'EXECUTE') $$,
  array[
    'create_household', 'update_household', 'delete_household',
    'create_child', 'update_child_permissions',
    'create_invitation', 'preview_invitation', 'accept_invitation', 'revoke_invitation',
    'change_member_role', 'remove_member', 'leave_household'
  ],
  'authenticated kan bara köra vitlistade RPC:er'
);

-- 11. anon har ingen åtkomst till private-schemat.
select ok(not has_schema_privilege('anon', 'private', 'USAGE'), 'anon saknar åtkomst till private');

-- 12. authenticated kan inte läsa roll/förmåga-tabellen direkt.
select ok(
  not has_table_privilege('authenticated', 'private.role_permissions', 'SELECT'),
  'private.role_permissions är inte läsbar för authenticated'
);

-- 13. Roll -> förmåga stämmer exakt med ROLES_AND_PERMISSIONS.md (D3: adult saknar members.invite).
select set_eq(
  $$ select role::text || ':' || permission from private.role_permissions $$,
  array[
    'owner:household.read', 'owner:household.update', 'owner:household.delete', 'owner:members.read',
    'owner:members.invite', 'owner:members.remove', 'owner:members.manage_roles', 'owner:children.manage',
    'owner:audit.read', 'owner:subscription.manage', 'owner:bank.manage', 'owner:finance.read',
    'owner:finance.write', 'owner:savings.write', 'owner:calendar.read', 'owner:calendar.write',
    'owner:routines.write', 'owner:tasks.write',
    'adult:household.read', 'adult:members.read', 'adult:children.manage', 'adult:finance.read',
    'adult:finance.write', 'adult:savings.write', 'adult:calendar.read', 'adult:calendar.write',
    'adult:routines.write', 'adult:tasks.write',
    'child:household.read', 'child:members.read'
  ],
  'roll/förmåga-matrisen är exakt den dokumenterade'
);

select * from finish();
rollback;
