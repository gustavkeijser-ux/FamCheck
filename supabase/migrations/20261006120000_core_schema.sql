-- =============================================================================
-- M1-06: Kärnschema – profiler, hushåll, medlemmar, barn, inbjudningar, audit log
-- Design: docs/architecture/DATA_MODEL_CORE.md
--
-- Den här migreringen skapar bara strukturen. Behörigheter och RLS kommer i
-- 20261006120100_permissions_and_rls.sql. Tills dess har API-rollerna INGEN
-- åtkomst till tabellerna (neka som standard).
-- =============================================================================

create extension if not exists citext with schema extensions;
create extension if not exists pgcrypto with schema extensions;

-- -----------------------------------------------------------------------------
-- Neka som standard
-- -----------------------------------------------------------------------------
-- Supabases standardrättigheter ger anon/authenticated bl.a. TRUNCATE på nya
-- tabeller i public. TRUNCATE går förbi RLS och tas därför bort. Varje tabell
-- får i stället uttryckliga GRANTs i sin migrering.
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;

-- Internt schema för behörighetslogik. Exponeras inte via API:et (config.toml).
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- Typer
-- -----------------------------------------------------------------------------
create type public.member_role as enum ('owner', 'adult', 'child', 'managed_child');
create type public.member_status as enum ('active', 'left', 'removed');

-- D10: generell åtkomstnivå för resurser. Genomdrivs av private.can_view_resource().
create type public.resource_visibility as enum ('private', 'adults', 'household');

-- -----------------------------------------------------------------------------
-- Hjälpfunktioner
-- -----------------------------------------------------------------------------
create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- households
-- -----------------------------------------------------------------------------
create table public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null
    constraint households_name_length check (char_length(name) between 1 and 80)
    constraint households_name_trimmed check (name = btrim(name))
    constraint households_name_no_control_chars check (name !~ '[[:cntrl:]]'),
  timezone text not null default 'Europe/Stockholm',
  currency char(3) not null default 'SEK'
    constraint households_currency_format check (currency ~ '^[A-Z]{3}$'),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.households is
  'Tenant. All gemensam data hör till ett hushåll. Skapas endast via create_household().';

create function private.validate_household()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (select 1 from pg_catalog.pg_timezone_names where name = new.timezone) then
    raise exception 'invalid_timezone' using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger households_validate
  before insert or update of timezone on public.households
  for each row execute function private.validate_household();

create trigger households_set_updated_at
  before update on public.households
  for each row execute function private.set_updated_at();

-- -----------------------------------------------------------------------------
-- profiles (1:1 med auth.users)
-- -----------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null
    constraint profiles_display_name_length check (char_length(display_name) between 1 and 80),
  avatar_path text
    constraint profiles_avatar_path_length check (char_length(avatar_path) <= 300),
  locale text not null default 'sv-SE'
    constraint profiles_locale_format check (locale ~ '^[a-z]{2}(-[A-Z]{2})?$'),
  -- Bara en bekvämlighet för appen. Används ALDRIG för behörighet.
  last_active_household_id uuid references public.households (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'Användarens egna uppgifter. Hushållskamrater läser household_members.display_name, inte profiles.';

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function private.set_updated_at();

-- Skapar en profil när en användare registreras. Hålls minimal: om den fallerar
-- går det inte att registrera sig.
create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
begin
  v_name := coalesce(
    nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'name'), ''),
    nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
    'Ny användare'
  );
  insert into public.profiles (id, display_name)
  values (new.id, left(v_name, 80));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- -----------------------------------------------------------------------------
-- household_members – en PERSON i hushållet (ADR-0003)
-- -----------------------------------------------------------------------------
create table public.household_members (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  -- RESTRICT: ett konto kan inte raderas så länge det har medlemskap. Kontoradering
  -- går via ett kontrollerat flöde som först hanterar medlemskapen (D9).
  user_id uuid references auth.users (id) on delete restrict,
  role public.member_role not null,
  status public.member_status not null default 'active',
  display_name text not null
    constraint household_members_display_name_length check (char_length(display_name) between 1 and 50)
    constraint household_members_display_name_trimmed check (display_name = btrim(display_name))
    constraint household_members_display_name_no_control_chars check (display_name !~ '[[:cntrl:]]'),
  color text
    constraint household_members_color_format check (color ~ '^#[0-9A-Fa-f]{6}$'),
  avatar_path text
    constraint household_members_avatar_path_length check (char_length(avatar_path) <= 300),
  joined_at timestamptz not null default now(),
  ended_at timestamptz,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- En användare har högst ett medlemskap per hushåll (återaktiveras vid återinträde).
  constraint household_members_user_unique unique (household_id, user_id),
  -- Gör sammansatta FK:er (household_id, member_id) möjliga från andra tabeller.
  constraint household_members_household_id_id_unique unique (household_id, id),
  -- managed_child har aldrig ett konto.
  constraint household_members_managed_child_no_user
    check (role <> 'managed_child' or user_id is null),
  -- Aktiva medlemmar med andra roller har alltid ett konto.
  constraint household_members_active_has_user
    check (role = 'managed_child' or user_id is not null or status <> 'active'),
  constraint household_members_ended_at_matches_status
    check ((status = 'active') = (ended_at is null))
);

comment on table public.household_members is
  'En person i hushållet, med eller utan konto. id är den stabila person-id som all domändata refererar.';

create index household_members_active_user_idx
  on public.household_members (user_id, household_id) where status = 'active';
create index household_members_household_idx on public.household_members (household_id);

create trigger household_members_set_updated_at
  before update on public.household_members
  for each row execute function private.set_updated_at();

-- -----------------------------------------------------------------------------
-- children – tilläggstabell 1:1 för barnroller (D1, D7)
-- -----------------------------------------------------------------------------
create table public.children (
  member_id uuid primary key,
  household_id uuid not null,
  birth_date date
    constraint children_birth_date_reasonable check (birth_date >= date '1900-01-01'),
  -- D7: kalender, familjeaktiviteter och uppgifter/rutiner på som standard.
  can_view_calendar boolean not null default true,
  can_view_family_events boolean not null default true,
  can_use_tasks_and_routines boolean not null default true,
  -- D7: all ekonomi är explicit opt-in per barn. Hushållets och vuxnas ekonomi
  -- kan ett barn aldrig få se, därför finns ingen flagga för det.
  can_view_allowance boolean not null default false,
  can_view_own_balance boolean not null default false,
  can_view_savings_goals boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint children_member_fk foreign key (household_id, member_id)
    references public.household_members (household_id, id) on delete cascade
);

comment on table public.children is
  'Barnspecifika uppgifter och barnbehörigheter för medlemmar med rollen child eller managed_child.';

create index children_household_idx on public.children (household_id);

create function private.validate_child()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.birth_date is not null and new.birth_date > current_date then
    raise exception 'birth_date_in_future' using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger children_validate
  before insert or update of birth_date on public.children
  for each row execute function private.validate_child();

create trigger children_set_updated_at
  before update on public.children
  for each row execute function private.set_updated_at();

-- Barnroll <=> children-rad. Kontrolleras i slutet av transaktionen, så att
-- medlem och children-rad kan skapas i valfri ordning i samma transaktion.
create function private.check_child_consistency()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_member_id uuid;
  v_role public.member_role;
  v_has_child_row boolean;
begin
  v_member_id := case when tg_table_name = 'children' then old.member_id else new.id end;

  select m.role into v_role from public.household_members m where m.id = v_member_id;
  if not found then
    return null; -- medlemmen är borttagen, children-raden försvinner via cascade
  end if;

  v_has_child_row := exists (select 1 from public.children c where c.member_id = v_member_id);

  if v_role in ('child', 'managed_child') and not v_has_child_row then
    raise exception 'child_member_requires_children_row' using errcode = '23514';
  end if;
  if v_role in ('owner', 'adult') and v_has_child_row then
    raise exception 'adult_member_cannot_have_children_row' using errcode = '23514';
  end if;
  return null;
end;
$$;

create constraint trigger household_members_child_consistency
  after insert or update of role on public.household_members
  deferrable initially deferred
  for each row execute function private.check_child_consistency();

create constraint trigger children_child_consistency
  after delete on public.children
  deferrable initially deferred
  for each row execute function private.check_child_consistency();

create function private.check_children_row_role()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.household_members m
    where m.id = new.member_id and m.role in ('child', 'managed_child')
  ) then
    raise exception 'children_row_requires_child_role' using errcode = '23514';
  end if;
  return new;
end;
$$;

create constraint trigger children_role_check
  after insert or update of member_id on public.children
  deferrable initially deferred
  for each row execute function private.check_children_row_role();

-- -----------------------------------------------------------------------------
-- D9: ett hushåll måste alltid ha minst en aktiv owner.
-- Sista skyddsnätet – RPC:erna ger tydliga fel innan det här slår till.
-- -----------------------------------------------------------------------------
create function private.check_household_has_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Hushållet håller på att raderas (cascade) – inget att skydda.
  if not exists (select 1 from public.households h where h.id = old.household_id) then
    return null;
  end if;

  if not exists (
    select 1 from public.household_members m
    where m.household_id = old.household_id and m.role = 'owner' and m.status = 'active'
  ) then
    raise exception 'household_requires_owner' using errcode = '23514';
  end if;
  return null;
end;
$$;

create constraint trigger household_members_require_owner
  after update of role, status or delete on public.household_members
  deferrable initially deferred
  for each row execute function private.check_household_has_owner();

-- -----------------------------------------------------------------------------
-- household_invitations
-- -----------------------------------------------------------------------------
create table public.household_invitations (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  role public.member_role not null
    -- Owner blir man genom rollbyte efter att man gått med.
    constraint household_invitations_role_invitable check (role in ('adult', 'child')),
  -- Satt = koppla ett konto till ett befintligt managed_child.
  target_member_id uuid,
  invited_email extensions.citext
    constraint household_invitations_email_length check (char_length(invited_email::text) <= 320),
  -- SHA-256 av token. Klartexten lagras aldrig.
  token_hash bytea not null
    constraint household_invitations_token_hash_unique unique
    constraint household_invitations_token_hash_length check (octet_length(token_hash) = 32),
  expires_at timestamptz not null,
  accepted_at timestamptz,
  accepted_by uuid references auth.users (id) on delete set null,
  revoked_at timestamptz,
  revoked_by uuid references auth.users (id) on delete set null,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),

  constraint household_invitations_target_fk foreign key (household_id, target_member_id)
    references public.household_members (household_id, id) on delete cascade,
  constraint household_invitations_target_requires_child
    check (target_member_id is null or role = 'child'),
  constraint household_invitations_expiry_window
    check (expires_at > created_at and expires_at <= created_at + interval '30 days'),
  constraint household_invitations_single_outcome
    check (accepted_at is null or revoked_at is null),
  constraint household_invitations_accepted_consistency
    check (accepted_by is null or accepted_at is not null),
  constraint household_invitations_revoked_consistency
    check (revoked_by is null or revoked_at is not null)
);

comment on table public.household_invitations is
  'Inbjudningar. Status (pending/accepted/revoked/expired) räknas fram. Hanteras endast via RPC.';

create index household_invitations_household_idx on public.household_invitations (household_id);

-- Högst en öppen inbjudan per barn som ska kopplas.
create unique index household_invitations_open_target_unique
  on public.household_invitations (target_member_id)
  where target_member_id is not null and accepted_at is null and revoked_at is null;

-- -----------------------------------------------------------------------------
-- audit_log – append-only (docs/security/AUDIT_LOG.md)
-- -----------------------------------------------------------------------------
create table public.audit_log (
  id bigint generated always as identity primary key,
  -- Ingen FK: händelser för raderade hushåll sparas i högst 90 dagar (D8).
  household_id uuid,
  actor_user_id uuid references auth.users (id) on delete set null,
  action text not null
    constraint audit_log_action_known check (action in (
      'household.created',
      'household.updated',
      'household.deleted',
      'member.invited',
      'invitation.revoked',
      'member.joined',
      'member.role_changed',
      'member.removed',
      'member.left',
      'child.created',
      'child.permissions_changed',
      'child.account_linked',
      'account.visibility_changed',
      'bank.connected',
      'bank.disconnected',
      'subscription.changed'
    )),
  target_type text
    constraint audit_log_target_type_length check (char_length(target_type) <= 50),
  target_id uuid,
  -- Får aldrig innehålla tokens, hemligheter eller onödiga personuppgifter.
  metadata jsonb not null default '{}'::jsonb
    constraint audit_log_metadata_object check (jsonb_typeof(metadata) = 'object')
    constraint audit_log_metadata_size check (pg_column_size(metadata) <= 4096),
  created_at timestamptz not null default now()
);

comment on table public.audit_log is
  'Säkerhetshändelser. Append-only: skrivs endast av private.write_audit().';

create index audit_log_household_created_idx on public.audit_log (household_id, created_at desc);
create index audit_log_created_idx on public.audit_log (created_at);

-- -----------------------------------------------------------------------------
-- RLS påslaget direkt – utan policyer är allt nekat tills nästa migrering.
-- -----------------------------------------------------------------------------
alter table public.households enable row level security;
alter table public.profiles enable row level security;
alter table public.household_members enable row level security;
alter table public.children enable row level security;
alter table public.household_invitations enable row level security;
alter table public.audit_log enable row level security;

revoke all on table
  public.households,
  public.profiles,
  public.household_members,
  public.children,
  public.household_invitations,
  public.audit_log
from anon, authenticated;
