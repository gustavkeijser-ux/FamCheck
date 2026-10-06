-- =============================================================================
-- M1-07: Förmågor (capabilities), behörighetsfunktioner och RLS
-- Design: docs/security/ROLES_AND_PERMISSIONS.md, docs/security/RLS_STRATEGY.md
--
-- Principer:
--   * Policyer kontrollerar FÖRMÅGOR, inte roller. Roll -> förmåga finns bara i
--     private.role_permissions.
--   * Hjälpfunktionerna returnerar id-mängder och används som
--     `x in (select private.fn(...))` så att de räknas ut en gång per fråga.
--   * Tillståndsändringar sker via RPC:er (nästa migrering). Direkt skrivning
--     begränsas med kolumnrättigheter.
--   * private-schemat exponeras inte via API:et, men authenticated behöver
--     USAGE/EXECUTE för att policyerna ska kunna anropa funktionerna.
-- =============================================================================

grant usage on schema private to authenticated;

-- -----------------------------------------------------------------------------
-- Roll -> förmåga
-- -----------------------------------------------------------------------------
create table private.role_permissions (
  role public.member_role not null,
  permission text not null
    constraint role_permissions_permission_known check (permission in (
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
      'tasks.write'
    )),
  primary key (role, permission),
  -- Barnroller får aldrig ekonomi-, kalender- eller administrativa förmågor via sin roll.
  constraint role_permissions_child_limits check (
    role not in ('child', 'managed_child') or permission in ('household.read', 'members.read')
  ),
  -- Owner-reserverade förmågor (D3, ROLES_AND_PERMISSIONS §4).
  constraint role_permissions_owner_only check (
    role = 'owner' or permission not in ('household.delete', 'members.manage_roles', 'subscription.manage')
  )
);

revoke all on table private.role_permissions from public, anon, authenticated;

-- PARITET: packages/domain/src/roles.ts speglar exakt detta block och ett test
-- jämför dem. Ändra båda samtidigt.
-- role_permissions:begin
insert into private.role_permissions (role, permission) values
  ('owner', 'household.read'),
  ('owner', 'household.update'),
  ('owner', 'household.delete'),
  ('owner', 'members.read'),
  ('owner', 'members.invite'),
  ('owner', 'members.remove'),
  ('owner', 'members.manage_roles'),
  ('owner', 'children.manage'),
  ('owner', 'audit.read'),
  ('owner', 'subscription.manage'),
  ('owner', 'bank.manage'),
  ('owner', 'finance.read'),
  ('owner', 'finance.write'),
  ('owner', 'savings.write'),
  ('owner', 'calendar.read'),
  ('owner', 'calendar.write'),
  ('owner', 'routines.write'),
  ('owner', 'tasks.write'),
  ('adult', 'household.read'),
  ('adult', 'members.read'),
  ('adult', 'children.manage'),
  ('adult', 'finance.read'),
  ('adult', 'finance.write'),
  ('adult', 'savings.write'),
  ('adult', 'calendar.read'),
  ('adult', 'calendar.write'),
  ('adult', 'routines.write'),
  ('adult', 'tasks.write'),
  ('child', 'household.read'),
  ('child', 'members.read');
-- role_permissions:end

-- -----------------------------------------------------------------------------
-- Behörighetsfunktioner
-- security definer: läser household_members utan att trigga dess egen RLS
-- (undviker rekursion). Användaren hämtas ALLTID från auth.uid().
--
-- Utbyggnadspunkt (D3): individuella tilldelningar, t.ex. ge en viss adult
-- 'members.invite', läggs till som en UNION i household_ids_with() mot en
-- framtida tabell. Inga policyer behöver ändras.
-- -----------------------------------------------------------------------------

-- Hushåll där anroparen har en viss förmåga.
create function private.household_ids_with(p_permission text)
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.household_id
  from public.household_members m
  join private.role_permissions rp on rp.role = m.role
  where m.user_id = (select auth.uid())
    and m.status = 'active'
    and rp.permission = p_permission
$$;

-- Anroparens aktiva medlems-id:n (ett per hushåll).
create function private.my_member_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.id
  from public.household_members m
  where m.user_id = (select auth.uid())
    and m.status = 'active'
$$;

-- Har anroparen förmågan i just det här hushållet? Används av RPC:er.
create function private.has_permission(p_household_id uuid, p_permission text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.household_members m
    join private.role_permissions rp on rp.role = m.role
    where m.household_id = p_household_id
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and rp.permission = p_permission
  )
$$;

-- Anroparens aktiva medlemskap i ett hushåll (null om inget).
create function private.my_membership(p_household_id uuid)
returns public.household_members
language sql
stable
security definer
set search_path = ''
as $$
  select m.*
  from public.household_members m
  where m.household_id = p_household_id
    and m.user_id = (select auth.uid())
    and m.status = 'active'
$$;

-- D10: generell åtkomstnivå. Kombineras i policyer med en förmåga för
-- resurstypen (t.ex. finance.read). Privat skyddar även mot owner (D2).
create function private.can_view_resource(
  p_household_id uuid,
  p_visibility public.resource_visibility,
  p_owner_member_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case p_visibility
    when 'private' then exists (
      select 1 from public.household_members m
      where m.id = p_owner_member_id
        and m.household_id = p_household_id
        and m.user_id = (select auth.uid())
        and m.status = 'active'
    )
    when 'adults' then exists (
      select 1 from public.household_members m
      where m.household_id = p_household_id
        and m.user_id = (select auth.uid())
        and m.status = 'active'
        and m.role in ('owner', 'adult')
    )
    when 'household' then exists (
      select 1 from public.household_members m
      where m.household_id = p_household_id
        and m.user_id = (select auth.uid())
        and m.status = 'active'
    )
    else false
  end
$$;

-- Skriver en audit-händelse. Får aldrig anropas med tokens eller hemligheter i metadata.
create function private.write_audit(
  p_household_id uuid,
  p_action text,
  p_target_type text default null,
  p_target_id uuid default null,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.audit_log (household_id, actor_user_id, action, target_type, target_id, metadata)
  values (p_household_id, (select auth.uid()), p_action, p_target_type, p_target_id, coalesce(p_metadata, '{}'::jsonb));
$$;

revoke all on function
  private.household_ids_with(text),
  private.my_member_ids(),
  private.has_permission(uuid, text),
  private.my_membership(uuid),
  private.can_view_resource(uuid, public.resource_visibility, uuid),
  private.write_audit(uuid, text, text, uuid, jsonb)
from public, anon;

-- Policyerna körs som authenticated och behöver dessa.
grant execute on function
  private.household_ids_with(text),
  private.my_member_ids(),
  private.can_view_resource(uuid, public.resource_visibility, uuid)
to authenticated;
-- has_permission, my_membership och write_audit används bara inifrån
-- security definer-RPC:er och behöver ingen grant till authenticated.

-- Triggerfunktioner ska inte kunna anropas direkt.
revoke all on function
  private.set_updated_at(),
  private.validate_household(),
  private.handle_new_user(),
  private.validate_child(),
  private.check_child_consistency(),
  private.check_children_row_role(),
  private.check_household_has_owner()
from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- profiles
-- -----------------------------------------------------------------------------
grant select on table public.profiles to authenticated;
grant update (display_name, avatar_path, locale, last_active_household_id)
  on table public.profiles to authenticated;

create policy profiles_select_own on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (
    id = (select auth.uid())
    and (
      last_active_household_id is null
      or last_active_household_id in (select private.household_ids_with('household.read'))
    )
  );
-- Ingen INSERT (trigger vid registrering) och ingen DELETE (kontoradering via eget flöde).

-- -----------------------------------------------------------------------------
-- households – läsning via RLS, alla ändringar via RPC
-- -----------------------------------------------------------------------------
grant select on table public.households to authenticated;

create policy households_select_member on public.households
  for select to authenticated
  using (id in (select private.household_ids_with('household.read')));

-- -----------------------------------------------------------------------------
-- household_members
-- -----------------------------------------------------------------------------
grant select on table public.household_members to authenticated;
-- Bara presentationskolumner. role, status och user_id ändras endast via RPC.
grant update (display_name, color, avatar_path) on table public.household_members to authenticated;

create policy household_members_select on public.household_members
  for select to authenticated
  using (household_id in (select private.household_ids_with('members.read')));

create policy household_members_update_presentation on public.household_members
  for update to authenticated
  using (
    status = 'active'
    and (
      -- Vuxna får ändra sin egen presentation.
      (user_id = (select auth.uid()) and role in ('owner', 'adult'))
      -- Den som hanterar barn får ändra barnens presentation.
      or (
        role in ('child', 'managed_child')
        and household_id in (select private.household_ids_with('children.manage'))
      )
    )
  )
  with check (
    household_id in (select private.household_ids_with('members.read'))
  );

-- -----------------------------------------------------------------------------
-- children
-- -----------------------------------------------------------------------------
grant select on table public.children to authenticated;
-- Barnbehörigheterna ändras endast via update_child_permissions() (audit).
grant update (birth_date) on table public.children to authenticated;

create policy children_select on public.children
  for select to authenticated
  using (
    household_id in (select private.household_ids_with('children.manage'))
    -- Ett barn med konto ser sina egna behörigheter (för att anpassa barnläget).
    or member_id in (select private.my_member_ids())
  );

create policy children_update_profile on public.children
  for update to authenticated
  using (household_id in (select private.household_ids_with('children.manage')))
  with check (household_id in (select private.household_ids_with('children.manage')));

-- -----------------------------------------------------------------------------
-- household_invitations – ingen direkt skrivning, token_hash kan inte läsas
-- -----------------------------------------------------------------------------
grant select (
  id, household_id, role, target_member_id, invited_email, expires_at,
  accepted_at, accepted_by, revoked_at, revoked_by, created_by, created_at
) on table public.household_invitations to authenticated;

create policy household_invitations_select on public.household_invitations
  for select to authenticated
  using (household_id in (select private.household_ids_with('members.invite')));

-- -----------------------------------------------------------------------------
-- audit_log – läsning för audit.read, inga skrivningar via API:et
-- -----------------------------------------------------------------------------
grant select on table public.audit_log to authenticated;

create policy audit_log_select on public.audit_log
  for select to authenticated
  using (household_id in (select private.household_ids_with('audit.read')));

-- -----------------------------------------------------------------------------
-- service_role (endast Edge Functions på servern) – går förbi RLS men behöver
-- tabellrättigheter, t.ex. för kontoradering i M2.
-- -----------------------------------------------------------------------------
grant select, insert, update, delete on table
  public.households,
  public.profiles,
  public.household_members,
  public.children,
  public.household_invitations
to service_role;
grant select on table public.audit_log to service_role;
