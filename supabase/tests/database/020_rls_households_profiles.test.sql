-- =============================================================================
-- RLS-matris: households och profiles (SELECT/INSERT/UPDATE/DELETE per roll)
-- =============================================================================
begin;
select plan(32);
select tests.create_fixture();

-- ---------------------------------------------------------------- households
-- SELECT
select tests.authenticate_as('owner_a');
select results_eq($$ select name from public.households $$, array['Hushåll A'], 'owner_a ser bara hushåll A');
select tests.authenticate_as('adult_a');
select results_eq($$ select name from public.households $$, array['Hushåll A'], 'adult_a ser bara hushåll A');
select tests.authenticate_as('child_a');
select results_eq($$ select name from public.households $$, array['Hushåll A'], 'child_a ser bara hushåll A');
select tests.authenticate_as('multi');
select results_eq($$ select name from public.households order by name $$, array['Hushåll A', 'Hushåll B'], 'multi ser A och B');
select tests.authenticate_as('owner_b');
select results_eq($$ select name from public.households $$, array['Hushåll B'], 'owner_b ser bara hushåll B');
select tests.authenticate_as('outsider');
select is_empty($$ select 1 from public.households $$, 'outsider ser inga hushåll');
select tests.authenticate_as('owner_b');
select is_empty(
  format('select 1 from public.households where id = %L', tests.id('household:a')),
  'owner_b kan inte läsa hushåll A ens med känt id'
);
select tests.authenticate_as_anon();
select throws_ok($$ select 1 from public.households $$, '42501', null, 'anon nekas households');

-- INSERT / UPDATE / DELETE – endast via RPC
select tests.authenticate_as('owner_a');
select throws_ok($$ insert into public.households (name) values ('X') $$, '42501', null, 'owner_a kan inte INSERT direkt');
select throws_ok(
  format('update public.households set name = %L where id = %L', 'Hackat', tests.id('household:a')),
  '42501', null, 'owner_a kan inte UPDATE direkt (RPC krävs)'
);
select throws_ok(
  format('delete from public.households where id = %L', tests.id('household:a')),
  '42501', null, 'owner_a kan inte DELETE direkt (RPC krävs)'
);
select tests.authenticate_as('owner_b');
select throws_ok(
  format('delete from public.households where id = %L', tests.id('household:a')),
  '42501', null, 'owner_b kan inte DELETE hushåll A'
);
select tests.authenticate_as('child_a');
select throws_ok(
  format('update public.households set name = %L where id = %L', 'Barnets', tests.id('household:a')),
  '42501', null, 'child_a kan inte UPDATE'
);
select tests.authenticate_as_anon();
select throws_ok($$ insert into public.households (name) values ('X') $$, '42501', null, 'anon kan inte INSERT');

-- ---------------------------------------------------------------- profiles
-- SELECT: bara den egna profilen
select tests.authenticate_as('owner_a');
select results_eq(
  $$ select id from public.profiles $$,
  array[tests.id('user:owner_a')],
  'owner_a ser bara sin egen profil'
);
select is_empty(
  format('select 1 from public.profiles where id = %L', tests.id('user:adult_a')),
  'owner_a ser inte adult_a:s profil (samma hushåll)'
);
select tests.authenticate_as('child_a');
select results_eq($$ select id from public.profiles $$, array[tests.id('user:child_a')], 'child_a ser bara sin egen profil');
select tests.authenticate_as('outsider');
select results_eq($$ select id from public.profiles $$, array[tests.id('user:outsider')], 'outsider ser bara sin egen profil');
select tests.authenticate_as_anon();
select throws_ok($$ select 1 from public.profiles $$, '42501', null, 'anon nekas profiles');

-- UPDATE
select tests.authenticate_as('owner_a');
with u as (
  update public.profiles set display_name = 'Nytt namn' where id = tests.id('user:owner_a') returning 1
) select is(count(*)::int, 1, 'owner_a kan uppdatera sin egen profil') from u;
with u as (
  update public.profiles set display_name = 'Hackat' where id = tests.id('user:adult_a') returning 1
) select is(count(*)::int, 0, 'owner_a kan inte uppdatera någon annans profil') from u;
with u as (
  update public.profiles set last_active_household_id = tests.id('household:a') where id = tests.id('user:owner_a') returning 1
) select is(count(*)::int, 1, 'owner_a kan sätta aktivt hushåll till ett eget hushåll') from u;
select throws_ok(
  format('update public.profiles set last_active_household_id = %L where id = %L', tests.id('household:b'), tests.id('user:owner_a')),
  '42501', null, 'owner_a kan inte sätta aktivt hushåll till hushåll B'
);
select throws_ok(
  format('update public.profiles set id = gen_random_uuid() where id = %L', tests.id('user:owner_a')),
  '42501', null, 'profiles.id kan inte ändras'
);
select tests.authenticate_as('owner_b');
with u as (
  update public.profiles set display_name = 'Hackat' where id = tests.id('user:owner_a') returning 1
) select is(count(*)::int, 0, 'owner_b kan inte uppdatera owner_a:s profil') from u;

-- INSERT / DELETE
select tests.authenticate_as('outsider');
select throws_ok(
  $$ insert into public.profiles (id, display_name) values (gen_random_uuid(), 'X') $$,
  '42501', null, 'profiler kan inte skapas direkt'
);
select throws_ok(
  format('delete from public.profiles where id = %L', tests.id('user:outsider')),
  '42501', null, 'den egna profilen kan inte raderas direkt'
);
select tests.authenticate_as_anon();
select throws_ok($$ delete from public.profiles $$, '42501', null, 'anon kan inte DELETE profiles');

-- Profil skapas automatiskt vid registrering
select tests.clear_authentication();
select tests.create_user('new_person');
select is(
  (select display_name from public.profiles where id = tests.id('user:new_person')),
  'new_person',
  'en profil skapas automatiskt vid registrering'
);
select tests.create_user('ctrl', 'ctrl@test.famcheck.se');
select ok(
  (select count(*) from public.profiles where id = tests.id('user:ctrl')) = 1,
  'registrering fungerar även när metadata saknar namn'
);
select is(
  (select count(*)::int from public.profiles p join tests.ids i on i.id = p.id and i.key like 'user:%'),
  8,
  'alla testanvändare har exakt en profil'
);

-- Uppskjutna constraint-triggers körs annars aldrig eftersom testet rullas tillbaka.
-- Tvinga fram dem här så att alla ändringar ovan även klarar commit-kontrollerna.
select lives_ok($$ set constraints all immediate $$, 'alla uppskjutna kontroller (D9, barnkonsistens) håller');

select * from finish();
rollback;
