-- =============================================================================
-- M1-08: Databasfunktioner (RPC) för känsliga operationer
-- Design: docs/architecture/DATA_MODEL_CORE.md §5, docs/security/ROLES_AND_PERMISSIONS.md §5
--
-- Alla RPC:er:
--   * är security definer med search_path = '' och fullt kvalificerade namn
--   * hämtar användaren från auth.uid(), aldrig från en parameter
--   * kontrollerar förmågan själva och skriver audit-händelser
--   * ger samma fel ('forbidden') oavsett om resursen saknas eller anroparen
--     saknar rätt, så att andra hushålls id:n inte kan avslöjas
--
-- Felkoder (message) som appen översätter, se docs/security/RPC_ERRORS.md:
--   42501 not_authenticated, forbidden
--   22023 invalid_*
--   P0001 last_owner, already_member, invitation_* m.fl.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Interna hjälpfunktioner
-- -----------------------------------------------------------------------------
create function private.require_user()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  return v_user;
end;
$$;

create function private.require_permission(p_household_id uuid, p_permission text)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_household_id is null or not private.has_permission(p_household_id, p_permission) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
end;
$$;

-- Normaliserar ett visningsnamn: inga kontrolltecken, trimmat, högst p_max tecken.
create function private.clean_name(p_value text, p_max integer)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(left(btrim(regexp_replace(coalesce(p_value, ''), '[[:cntrl:]]', '', 'g')), p_max), '')
$$;

create function private.hash_invitation_token(p_token text)
returns bytea
language sql
immutable
set search_path = ''
as $$
  select extensions.digest(p_token, 'sha256')
$$;

-- Framräknad status (lagras inte, se ADR-0006).
create function private.invitation_state(p_invitation public.household_invitations)
returns text
language sql
stable
set search_path = ''
as $$
  select case
    when p_invitation.revoked_at is not null then 'revoked'
    when p_invitation.accepted_at is not null then 'accepted'
    when p_invitation.expires_at <= now() then 'expired'
    else 'pending'
  end
$$;

-- Antal aktiva owners utöver en viss medlem (D9).
create function private.other_active_owner_count(p_household_id uuid, p_excluding_member_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from public.household_members m
  where m.household_id = p_household_id
    and m.role = 'owner'
    and m.status = 'active'
    and m.id <> p_excluding_member_id
$$;

create function private.assert_member_capacity(p_household_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (
    select count(*) from public.household_members m
    where m.household_id = p_household_id and m.status = 'active'
  ) >= 30 then
    raise exception 'member_limit_reached' using errcode = 'P0001';
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- Hushåll
-- -----------------------------------------------------------------------------
create function public.create_household(p_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := private.require_user();
  v_name text := private.clean_name(p_name, 81);
  v_display_name text;
  v_household_id uuid;
begin
  if v_name is null or char_length(v_name) > 80 then
    raise exception 'invalid_household_name' using errcode = '22023';
  end if;

  -- Skydd mot missbruk: högst 10 hushåll där man är owner.
  if (
    select count(*) from public.household_members m
    where m.user_id = v_user and m.role = 'owner' and m.status = 'active'
  ) >= 10 then
    raise exception 'household_limit_reached' using errcode = 'P0001';
  end if;

  select private.clean_name(p.display_name, 50) into v_display_name
  from public.profiles p where p.id = v_user;

  insert into public.households (name, created_by)
  values (v_name, v_user)
  returning id into v_household_id;

  insert into public.household_members (household_id, user_id, role, display_name, created_by)
  values (v_household_id, v_user, 'owner', coalesce(v_display_name, 'Jag'), v_user);

  update public.profiles
  set last_active_household_id = v_household_id
  where id = v_user and last_active_household_id is null;

  perform private.write_audit(v_household_id, 'household.created', 'household', v_household_id);
  return v_household_id;
end;
$$;

create function public.update_household(
  p_household_id uuid,
  p_name text default null,
  p_timezone text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := private.clean_name(p_name, 81);
  v_fields text[] := '{}'::text[];
begin
  perform private.require_user();
  perform private.require_permission(p_household_id, 'household.update');

  if p_name is not null then
    if v_name is null or char_length(v_name) > 80 then
      raise exception 'invalid_household_name' using errcode = '22023';
    end if;
    v_fields := array_append(v_fields, 'name');
  end if;
  if p_timezone is not null then
    v_fields := array_append(v_fields, 'timezone');
  end if;
  if cardinality(v_fields) = 0 then
    return;
  end if;

  update public.households h
  set name = coalesce(v_name, h.name),
      timezone = coalesce(p_timezone, h.timezone)
  where h.id = p_household_id;

  perform private.write_audit(
    p_household_id, 'household.updated', 'household', p_household_id,
    jsonb_build_object('fields', to_jsonb(v_fields))
  );
end;
$$;

-- Uttryckligt raderingsflöde (D9): kräver owner och att namnet bekräftas.
create function public.delete_household(p_household_id uuid, p_confirm_name text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
begin
  perform private.require_user();
  perform private.require_permission(p_household_id, 'household.delete');

  select h.name into v_name from public.households h where h.id = p_household_id for update;
  if p_confirm_name is distinct from v_name then
    raise exception 'confirmation_mismatch' using errcode = 'P0001';
  end if;

  -- D8: minimera audit-data för hushållet. Händelsetyp och tidpunkt behålls i
  -- högst 90 dagar (private.purge_audit_log), men vem och vad nollställs.
  update public.audit_log a
  set actor_user_id = null, target_id = null, metadata = '{}'::jsonb
  where a.household_id = p_household_id;

  perform private.write_audit(p_household_id, 'household.deleted', 'household', null);

  delete from public.households h where h.id = p_household_id;
end;
$$;

-- -----------------------------------------------------------------------------
-- Barn
-- -----------------------------------------------------------------------------
create function public.create_child(
  p_household_id uuid,
  p_display_name text,
  p_birth_date date default null,
  p_color text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := private.require_user();
  v_display_name text := private.clean_name(p_display_name, 51);
  v_member_id uuid;
begin
  perform private.require_permission(p_household_id, 'children.manage');
  perform private.assert_member_capacity(p_household_id);

  if v_display_name is null or char_length(v_display_name) > 50 then
    raise exception 'invalid_display_name' using errcode = '22023';
  end if;
  if p_color is not null and p_color !~ '^#[0-9A-Fa-f]{6}$' then
    raise exception 'invalid_color' using errcode = '22023';
  end if;

  insert into public.household_members (household_id, user_id, role, display_name, color, created_by)
  values (p_household_id, null, 'managed_child', v_display_name, p_color, v_user)
  returning id into v_member_id;

  insert into public.children (member_id, household_id, birth_date)
  values (v_member_id, p_household_id, p_birth_date);

  perform private.write_audit(p_household_id, 'child.created', 'household_member', v_member_id);
  return v_member_id;
end;
$$;

-- null = oförändrad. Alla ändringar loggas med före/efter-värden (inga personuppgifter).
create function public.update_child_permissions(
  p_member_id uuid,
  p_can_view_calendar boolean default null,
  p_can_view_family_events boolean default null,
  p_can_use_tasks_and_routines boolean default null,
  p_can_view_allowance boolean default null,
  p_can_view_own_balance boolean default null,
  p_can_view_savings_goals boolean default null
)
returns public.children
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_before public.children;
  v_after public.children;
  v_changes jsonb := '{}'::jsonb;
  v_key text;
begin
  perform private.require_user();

  select c.* into v_before
  from public.children c
  join public.household_members m on m.id = c.member_id
  where c.member_id = p_member_id and m.status = 'active'
  for update of c;

  perform private.require_permission(v_before.household_id, 'children.manage');

  update public.children c
  set can_view_calendar = coalesce(p_can_view_calendar, c.can_view_calendar),
      can_view_family_events = coalesce(p_can_view_family_events, c.can_view_family_events),
      can_use_tasks_and_routines = coalesce(p_can_use_tasks_and_routines, c.can_use_tasks_and_routines),
      can_view_allowance = coalesce(p_can_view_allowance, c.can_view_allowance),
      can_view_own_balance = coalesce(p_can_view_own_balance, c.can_view_own_balance),
      can_view_savings_goals = coalesce(p_can_view_savings_goals, c.can_view_savings_goals)
  where c.member_id = p_member_id
  returning c.* into v_after;

  foreach v_key in array array[
    'can_view_calendar', 'can_view_family_events', 'can_use_tasks_and_routines',
    'can_view_allowance', 'can_view_own_balance', 'can_view_savings_goals'
  ] loop
    if to_jsonb(v_before) -> v_key is distinct from to_jsonb(v_after) -> v_key then
      v_changes := v_changes || jsonb_build_object(
        v_key, jsonb_build_array(to_jsonb(v_before) -> v_key, to_jsonb(v_after) -> v_key)
      );
    end if;
  end loop;

  if v_changes <> '{}'::jsonb then
    perform private.write_audit(
      v_after.household_id, 'child.permissions_changed', 'household_member', p_member_id,
      jsonb_build_object('changed', v_changes)
    );
  end if;

  return v_after;
end;
$$;

-- -----------------------------------------------------------------------------
-- Inbjudningar
-- -----------------------------------------------------------------------------

-- Returnerar token i klartext EN gång. Bara hashen sparas.
create function public.create_invitation(
  p_household_id uuid,
  p_role public.member_role,
  p_email text default null,
  p_target_member_id uuid default null,
  p_expires_in_days integer default 7
)
returns table (invitation_id uuid, token text, expires_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := private.require_user();
  v_email text := nullif(lower(btrim(p_email)), '');
  v_token text;
  v_invitation public.household_invitations;
begin
  perform private.require_permission(p_household_id, 'members.invite');

  if p_role is null or p_role not in ('adult', 'child') then
    raise exception 'invalid_role' using errcode = '22023';
  end if;
  if p_expires_in_days is null or p_expires_in_days not between 1 and 30 then
    raise exception 'invalid_expiry' using errcode = '22023';
  end if;
  if v_email is not null and (char_length(v_email) > 320 or v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$') then
    raise exception 'invalid_email' using errcode = '22023';
  end if;

  if p_target_member_id is not null then
    if p_role <> 'child' then
      raise exception 'invalid_role' using errcode = '22023';
    end if;
    if not exists (
      select 1 from public.household_members m
      where m.id = p_target_member_id
        and m.household_id = p_household_id
        and m.role = 'managed_child'
        and m.status = 'active'
        and m.user_id is null
    ) then
      raise exception 'invalid_target_member' using errcode = '22023';
    end if;

    -- Bara en öppen inbjudan per barn: äldre återkallas.
    update public.household_invitations i
    set revoked_at = now(), revoked_by = v_user
    where i.target_member_id = p_target_member_id
      and i.accepted_at is null
      and i.revoked_at is null;
  end if;

  if (
    select count(*) from public.household_invitations i
    where i.household_id = p_household_id
      and i.accepted_at is null and i.revoked_at is null and i.expires_at > now()
  ) >= 20 then
    raise exception 'invitation_limit_reached' using errcode = 'P0001';
  end if;

  -- 32 slumpbytes som base64url utan utfyllnad = 43 tecken.
  v_token := translate(rtrim(encode(extensions.gen_random_bytes(32), 'base64'), '='), '+/', '-_');

  insert into public.household_invitations as i (
    household_id, role, target_member_id, invited_email, token_hash, expires_at, created_by
  )
  values (
    p_household_id, p_role, p_target_member_id, v_email,
    private.hash_invitation_token(v_token), now() + make_interval(days => p_expires_in_days), v_user
  )
  returning i.* into v_invitation;

  perform private.write_audit(
    p_household_id, 'member.invited', 'invitation', v_invitation.id,
    jsonb_build_object(
      'role', p_role,
      'has_email', v_email is not null,
      'links_child', p_target_member_id is not null
    )
  );

  return query select v_invitation.id, v_token, v_invitation.expires_at;
end;
$$;

-- Hittar och låser en inbjudan och kontrollerar status och e-post. Används av preview och accept.
create function private.resolve_invitation(p_token text, p_lock boolean)
returns public.household_invitations
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := private.require_user();
  v_invitation public.household_invitations;
  v_state text;
  v_email text;
  v_email_confirmed_at timestamptz;
begin
  if p_token is null or p_token !~ '^[A-Za-z0-9_-]{43}$' then
    raise exception 'invitation_not_found' using errcode = 'P0001';
  end if;

  if p_lock then
    select i.* into v_invitation from public.household_invitations i
    where i.token_hash = private.hash_invitation_token(p_token)
    for update;
  else
    select i.* into v_invitation from public.household_invitations i
    where i.token_hash = private.hash_invitation_token(p_token);
  end if;

  if not found then
    raise exception 'invitation_not_found' using errcode = 'P0001';
  end if;

  v_state := private.invitation_state(v_invitation);
  if v_state <> 'pending' then
    raise exception 'invitation_%', v_state using errcode = 'P0001';
  end if;

  -- Inbjudan knuten till e-post kräver samma VERIFIERADE e-post (AUTH_AND_IDENTITY §2.5).
  if v_invitation.invited_email is not null then
    select u.email, u.email_confirmed_at into v_email, v_email_confirmed_at
    from auth.users u where u.id = v_user;

    if v_email is null
      or v_email_confirmed_at is null
      or lower(v_email) <> lower(v_invitation.invited_email::text) then
      raise exception 'invitation_email_mismatch' using errcode = 'P0001';
    end if;
  end if;

  return v_invitation;
end;
$$;

create function public.preview_invitation(p_token text)
returns table (
  household_name text,
  invited_by_name text,
  role public.member_role,
  child_display_name text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invitation public.household_invitations := private.resolve_invitation(p_token, false);
begin
  return query
  select
    h.name,
    inviter.display_name,
    v_invitation.role,
    target.display_name,
    v_invitation.expires_at
  from public.households h
  left join public.household_members inviter
    on inviter.household_id = h.id and inviter.user_id = v_invitation.created_by
  left join public.household_members target
    on target.id = v_invitation.target_member_id
  where h.id = v_invitation.household_id;
end;
$$;

create function public.accept_invitation(p_token text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := private.require_user();
  v_invitation public.household_invitations := private.resolve_invitation(p_token, true);
  v_existing public.household_members;
  v_member_id uuid;
  v_display_name text;
begin
  select m.* into v_existing
  from public.household_members m
  where m.household_id = v_invitation.household_id and m.user_id = v_user
  for update;

  if found and v_existing.status = 'active' then
    raise exception 'already_member' using errcode = 'P0001';
  end if;

  select private.clean_name(p.display_name, 50) into v_display_name
  from public.profiles p where p.id = v_user;
  v_display_name := coalesce(v_display_name, 'Medlem');

  if v_invitation.target_member_id is not null then
    -- Koppla kontot till ett befintligt managed_child. Historiken följer med
    -- eftersom medlems-id:t inte ändras (ADR-0003).
    if v_existing.id is not null then
      raise exception 'already_member' using errcode = 'P0001';
    end if;

    update public.household_members m
    set user_id = v_user, role = 'child'
    where m.id = v_invitation.target_member_id
      and m.role = 'managed_child'
      and m.status = 'active'
      and m.user_id is null
    returning m.id into v_member_id;

    if v_member_id is null then
      raise exception 'invitation_target_unavailable' using errcode = 'P0001';
    end if;

    perform private.write_audit(
      v_invitation.household_id, 'child.account_linked', 'household_member', v_member_id,
      jsonb_build_object('invitation_id', v_invitation.id)
    );
  elsif v_existing.id is not null then
    -- Återinträde: samma rad återaktiveras så att historiken behålls.
    if (v_existing.role in ('child', 'managed_child')) <> (v_invitation.role = 'child') then
      raise exception 'invitation_role_conflict' using errcode = 'P0001';
    end if;
    perform private.assert_member_capacity(v_invitation.household_id);

    update public.household_members m
    set status = 'active', ended_at = null, joined_at = now(), role = v_invitation.role
    where m.id = v_existing.id
    returning m.id into v_member_id;
  else
    perform private.assert_member_capacity(v_invitation.household_id);

    insert into public.household_members (household_id, user_id, role, display_name, created_by)
    values (v_invitation.household_id, v_user, v_invitation.role, v_display_name, v_invitation.created_by)
    returning id into v_member_id;

    if v_invitation.role = 'child' then
      insert into public.children (member_id, household_id)
      values (v_member_id, v_invitation.household_id);
    end if;
  end if;

  update public.household_invitations i
  set accepted_at = now(), accepted_by = v_user
  where i.id = v_invitation.id;

  update public.profiles
  set last_active_household_id = v_invitation.household_id
  where id = v_user and last_active_household_id is null;

  perform private.write_audit(
    v_invitation.household_id, 'member.joined', 'household_member', v_member_id,
    jsonb_build_object('invitation_id', v_invitation.id, 'role', v_invitation.role)
  );

  return v_invitation.household_id;
end;
$$;

create function public.revoke_invitation(p_invitation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := private.require_user();
  v_invitation public.household_invitations;
begin
  select i.* into v_invitation from public.household_invitations i
  where i.id = p_invitation_id
  for update;

  perform private.require_permission(v_invitation.household_id, 'members.invite');

  if private.invitation_state(v_invitation) <> 'pending' then
    raise exception 'invitation_not_pending' using errcode = 'P0001';
  end if;

  update public.household_invitations i
  set revoked_at = now(), revoked_by = v_user
  where i.id = p_invitation_id;

  perform private.write_audit(
    v_invitation.household_id, 'invitation.revoked', 'invitation', p_invitation_id
  );
end;
$$;

-- -----------------------------------------------------------------------------
-- Medlemskap och roller (D9: minst en owner)
-- -----------------------------------------------------------------------------
create function public.change_member_role(p_member_id uuid, p_role public.member_role)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target public.household_members;
begin
  perform private.require_user();

  select m.* into v_target from public.household_members m
  where m.id = p_member_id and m.status = 'active'
  for update;

  perform private.require_permission(v_target.household_id, 'members.manage_roles');

  if p_role is null or p_role not in ('owner', 'adult') then
    raise exception 'invalid_role' using errcode = '22023';
  end if;
  -- Byte mellan barn- och vuxenroll kräver ett eget flöde (inte i M1).
  if v_target.role not in ('owner', 'adult') then
    raise exception 'role_change_not_supported' using errcode = 'P0001';
  end if;
  if v_target.role = p_role then
    return;
  end if;
  if v_target.role = 'owner'
    and private.other_active_owner_count(v_target.household_id, v_target.id) = 0 then
    raise exception 'last_owner' using errcode = 'P0001';
  end if;

  update public.household_members m set role = p_role where m.id = p_member_id;

  perform private.write_audit(
    v_target.household_id, 'member.role_changed', 'household_member', p_member_id,
    jsonb_build_object('from', v_target.role, 'to', p_role)
  );
end;
$$;

create function public.remove_member(p_member_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := private.require_user();
  v_target public.household_members;
begin
  select m.* into v_target from public.household_members m
  where m.id = p_member_id and m.status = 'active'
  for update;

  perform private.require_permission(v_target.household_id, 'members.remove');

  if v_target.user_id = v_user then
    raise exception 'use_leave_household' using errcode = 'P0001';
  end if;
  if v_target.role = 'owner'
    and private.other_active_owner_count(v_target.household_id, v_target.id) = 0 then
    raise exception 'last_owner' using errcode = 'P0001';
  end if;

  update public.household_members m
  set status = 'removed', ended_at = now()
  where m.id = p_member_id;

  -- Öppna inbjudningar för att koppla konto till personen gäller inte längre.
  update public.household_invitations i
  set revoked_at = now(), revoked_by = v_user
  where i.target_member_id = p_member_id and i.accepted_at is null and i.revoked_at is null;

  update public.profiles p
  set last_active_household_id = null
  where p.id = v_target.user_id and p.last_active_household_id = v_target.household_id;

  perform private.write_audit(
    v_target.household_id, 'member.removed', 'household_member', p_member_id,
    jsonb_build_object('role', v_target.role)
  );
end;
$$;

create function public.leave_household(p_household_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := private.require_user();
  v_me public.household_members := private.my_membership(p_household_id);
begin
  if v_me.id is null then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  -- Barn lämnar inte själva – en förälder tar bort medlemskapet.
  if v_me.role in ('child', 'managed_child') then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if v_me.role = 'owner' and private.other_active_owner_count(p_household_id, v_me.id) = 0 then
    raise exception 'last_owner' using errcode = 'P0001';
  end if;

  update public.household_members m
  set status = 'left', ended_at = now()
  where m.id = v_me.id;

  update public.profiles p
  set last_active_household_id = null
  where p.id = v_user and p.last_active_household_id = p_household_id;

  perform private.write_audit(p_household_id, 'member.left', 'household_member', v_me.id);
end;
$$;

-- -----------------------------------------------------------------------------
-- Gallring av audit-loggen (D8). Schemaläggs med pg_cron i en senare ticket.
-- -----------------------------------------------------------------------------
create function private.purge_audit_log()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_deleted integer;
begin
  delete from public.audit_log a
  where a.created_at < now() - interval '24 months'
     or a.household_id in (
       select d.household_id from public.audit_log d
       where d.action = 'household.deleted'
         and d.created_at < now() - interval '90 days'
     );
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

-- -----------------------------------------------------------------------------
-- Rättigheter
-- -----------------------------------------------------------------------------
revoke all on function
  private.require_user(),
  private.require_permission(uuid, text),
  private.clean_name(text, integer),
  private.hash_invitation_token(text),
  private.invitation_state(public.household_invitations),
  private.other_active_owner_count(uuid, uuid),
  private.assert_member_capacity(uuid),
  private.resolve_invitation(text, boolean),
  private.purge_audit_log()
from public, anon, authenticated;

revoke all on function
  public.create_household(text),
  public.update_household(uuid, text, text),
  public.delete_household(uuid, text),
  public.create_child(uuid, text, date, text),
  public.update_child_permissions(uuid, boolean, boolean, boolean, boolean, boolean, boolean),
  public.create_invitation(uuid, public.member_role, text, uuid, integer),
  public.preview_invitation(text),
  public.accept_invitation(text),
  public.revoke_invitation(uuid),
  public.change_member_role(uuid, public.member_role),
  public.remove_member(uuid),
  public.leave_household(uuid)
from public, anon;

grant execute on function
  public.create_household(text),
  public.update_household(uuid, text, text),
  public.delete_household(uuid, text),
  public.create_child(uuid, text, date, text),
  public.update_child_permissions(uuid, boolean, boolean, boolean, boolean, boolean, boolean),
  public.create_invitation(uuid, public.member_role, text, uuid, integer),
  public.preview_invitation(text),
  public.accept_invitation(text),
  public.revoke_invitation(uuid),
  public.change_member_role(uuid, public.member_role),
  public.remove_member(uuid),
  public.leave_household(uuid)
to authenticated;
