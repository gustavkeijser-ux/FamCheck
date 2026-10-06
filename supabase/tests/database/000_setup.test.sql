-- =============================================================================
-- Testhjälpare och fixturer (endast lokal databas och CI, aldrig i migreringar).
-- Den här filen COMMITTAR schemat `tests` så att övriga testfiler kan använda det.
-- Den är idempotent och körs först (filerna körs i bokstavsordning).
--
-- Testpersoner (RLS_STRATEGY.md §5.1):
--   owner_a, adult_a, child_a (eget konto), managed_a (utan konto) i hushåll A
--   owner_b i hushåll B
--   multi:    adult i A OCH owner i B
--   outsider: inloggad men medlem ingenstans
--   anon:     ej inloggad
-- =============================================================================
begin;
create extension if not exists pgtap with schema extensions;

create schema if not exists tests;
grant usage on schema tests to anon, authenticated;

create table if not exists tests.ids (key text primary key, id uuid not null);
grant select on tests.ids to anon, authenticated;

create or replace function tests.id(p_key text)
returns uuid
language plpgsql
stable
as $$
declare
  v_id uuid;
begin
  select i.id into v_id from tests.ids i where i.key = p_key;
  if v_id is null then
    raise exception 'tests.id: okänd nyckel %', p_key;
  end if;
  return v_id;
end;
$$;

create or replace function tests.create_user(p_key text, p_email text default null)
returns uuid
language plpgsql
as $$
declare
  v_id uuid := gen_random_uuid();
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) values (
    '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
    coalesce(p_email, p_key || '@test.famcheck.se'), '', now(),
    '{"provider":"email","providers":["email"]}', jsonb_build_object('full_name', p_key), now(), now()
  );
  insert into tests.ids (key, id) values ('user:' || p_key, v_id)
  on conflict (key) do update set id = excluded.id;
  return v_id;
end;
$$;

-- Simulerar en inloggad användare (samma claims som PostgREST sätter).
create or replace function tests.authenticate_as(p_key text)
returns void
language plpgsql
as $$
declare
  v_id uuid := tests.id('user:' || p_key);
begin
  perform set_config('role', 'authenticated', true);
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_id, 'role', 'authenticated', 'email', p_key || '@test.famcheck.se')::text,
    true
  );
end;
$$;

create or replace function tests.authenticate_as_anon()
returns void
language plpgsql
as $$
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
end;
$$;

create or replace function tests.clear_authentication()
returns void
language plpgsql
as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
end;
$$;

grant execute on all functions in schema tests to anon, authenticated;

-- Bygger standardfixturen direkt som postgres (oberoende av RPC:erna, som testas separat).
create or replace function tests.create_fixture()
returns void
language plpgsql
as $$
declare
  v_a uuid;
  v_b uuid;
  v_member uuid;
begin
  perform tests.create_user('owner_a');
  perform tests.create_user('adult_a');
  perform tests.create_user('child_a');
  perform tests.create_user('owner_b');
  perform tests.create_user('multi');
  perform tests.create_user('outsider');

  insert into public.households (name, created_by) values ('Hushåll A', tests.id('user:owner_a'))
  returning id into v_a;
  insert into public.households (name, created_by) values ('Hushåll B', tests.id('user:owner_b'))
  returning id into v_b;
  insert into tests.ids values ('household:a', v_a), ('household:b', v_b)
  on conflict (key) do update set id = excluded.id;

  insert into public.household_members (household_id, user_id, role, display_name)
  values (v_a, tests.id('user:owner_a'), 'owner', 'Owner A') returning id into v_member;
  insert into tests.ids values ('member:owner_a', v_member) on conflict (key) do update set id = excluded.id;

  insert into public.household_members (household_id, user_id, role, display_name)
  values (v_a, tests.id('user:adult_a'), 'adult', 'Adult A') returning id into v_member;
  insert into tests.ids values ('member:adult_a', v_member) on conflict (key) do update set id = excluded.id;

  insert into public.household_members (household_id, user_id, role, display_name)
  values (v_a, tests.id('user:child_a'), 'child', 'Child A') returning id into v_member;
  insert into public.children (member_id, household_id, birth_date) values (v_member, v_a, '2015-05-05');
  insert into tests.ids values ('member:child_a', v_member) on conflict (key) do update set id = excluded.id;

  insert into public.household_members (household_id, user_id, role, display_name)
  values (v_a, null, 'managed_child', 'Managed A') returning id into v_member;
  insert into public.children (member_id, household_id, birth_date) values (v_member, v_a, '2020-01-01');
  insert into tests.ids values ('member:managed_a', v_member) on conflict (key) do update set id = excluded.id;

  insert into public.household_members (household_id, user_id, role, display_name)
  values (v_a, tests.id('user:multi'), 'adult', 'Multi i A') returning id into v_member;
  insert into tests.ids values ('member:multi_a', v_member) on conflict (key) do update set id = excluded.id;

  insert into public.household_members (household_id, user_id, role, display_name)
  values (v_b, tests.id('user:owner_b'), 'owner', 'Owner B') returning id into v_member;
  insert into tests.ids values ('member:owner_b', v_member) on conflict (key) do update set id = excluded.id;

  insert into public.household_members (household_id, user_id, role, display_name)
  values (v_b, tests.id('user:multi'), 'owner', 'Multi i B') returning id into v_member;
  insert into tests.ids values ('member:multi_b', v_member) on conflict (key) do update set id = excluded.id;

  -- En öppen inbjudan och en audit-händelse per hushåll.
  insert into public.household_invitations (household_id, role, token_hash, expires_at, created_by)
  values (v_a, 'adult', extensions.digest('fixture-a', 'sha256'), now() + interval '7 days', tests.id('user:owner_a'));
  insert into public.household_invitations (household_id, role, token_hash, expires_at, created_by)
  values (v_b, 'adult', extensions.digest('fixture-b', 'sha256'), now() + interval '7 days', tests.id('user:owner_b'));
  insert into public.audit_log (household_id, action) values (v_a, 'household.created'), (v_b, 'household.created');
end;
$$;

select plan(1);
select has_function('tests', 'create_fixture', 'testhjälpare finns');
select * from finish();
commit;
