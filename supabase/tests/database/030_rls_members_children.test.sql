-- =============================================================================
-- RLS-matris: household_members och children
-- Särskilt: barn kan inte ändra roller, egna behörigheter eller andras data.
-- =============================================================================
begin;
select plan(37);
select tests.create_fixture();

-- ---------------------------------------------------------------- household_members SELECT
select tests.authenticate_as('owner_a');
select is((select count(*)::int from public.household_members), 5, 'owner_a ser A:s 5 medlemmar');
select tests.authenticate_as('adult_a');
select is((select count(*)::int from public.household_members), 5, 'adult_a ser A:s 5 medlemmar');
select tests.authenticate_as('child_a');
select is((select count(*)::int from public.household_members), 5, 'child_a ser A:s 5 medlemmar (namn/färg)');
select tests.authenticate_as('multi');
select is((select count(*)::int from public.household_members), 7, 'multi ser medlemmar i A och B');
select tests.authenticate_as('owner_b');
select is((select count(*)::int from public.household_members), 2, 'owner_b ser bara B:s 2 medlemmar');
select is_empty(
  format('select 1 from public.household_members where household_id = %L', tests.id('household:a')),
  'owner_b kan inte läsa A:s medlemmar med känt hushålls-id'
);
select tests.authenticate_as('outsider');
select is_empty($$ select 1 from public.household_members $$, 'outsider ser inga medlemmar');
select tests.authenticate_as_anon();
select throws_ok($$ select 1 from public.household_members $$, '42501', null, 'anon nekas household_members');

-- ---------------------------------------------------------------- household_members INSERT/DELETE
select tests.authenticate_as('owner_a');
select throws_ok(
  format($$ insert into public.household_members (household_id, user_id, role, display_name)
            values (%L, %L, 'owner', 'Inkräktare') $$, tests.id('household:a'), tests.id('user:outsider')),
  '42501', null, 'owner_a kan inte lägga till medlemmar direkt'
);
select tests.authenticate_as('outsider');
select throws_ok(
  format($$ insert into public.household_members (household_id, user_id, role, display_name)
            values (%L, %L, 'owner', 'Inkräktare') $$, tests.id('household:a'), tests.id('user:outsider')),
  '42501', null, 'outsider kan inte göra sig själv till medlem'
);
select tests.authenticate_as('owner_a');
select throws_ok(
  format('delete from public.household_members where id = %L', tests.id('member:adult_a')),
  '42501', null, 'owner_a kan inte DELETE medlemmar direkt (remove_member krävs)'
);

-- ---------------------------------------------------------------- household_members UPDATE
select tests.authenticate_as('owner_a');
with u as (update public.household_members set display_name = 'Mamma' where id = tests.id('member:owner_a') returning 1)
select is(count(*)::int, 1, 'owner_a kan ändra sitt eget visningsnamn') from u;
select throws_ok(
  format($$ update public.household_members set role = 'owner' where id = %L $$, tests.id('member:adult_a')),
  '42501', null, 'roll kan inte ändras direkt, inte ens av owner'
);
select throws_ok(
  format($$ update public.household_members set status = 'removed' where id = %L $$, tests.id('member:adult_a')),
  '42501', null, 'status kan inte ändras direkt'
);
select throws_ok(
  format($$ update public.household_members set user_id = %L where id = %L $$, tests.id('user:owner_a'), tests.id('member:managed_a')),
  '42501', null, 'user_id kan inte ändras direkt'
);
select throws_ok(
  format($$ update public.household_members set household_id = %L where id = %L $$, tests.id('household:b'), tests.id('member:owner_a')),
  '42501', null, 'en medlem kan inte flyttas till ett annat hushåll'
);

select tests.authenticate_as('adult_a');
with u as (update public.household_members set color = '#112233' where id = tests.id('member:adult_a') returning 1)
select is(count(*)::int, 1, 'adult_a kan ändra sin egen färg') from u;
with u as (update public.household_members set display_name = 'Hackat' where id = tests.id('member:owner_a') returning 1)
select is(count(*)::int, 0, 'adult_a kan inte ändra owner_a:s namn') from u;
with u as (update public.household_members set color = '#445566' where id = tests.id('member:managed_a') returning 1)
select is(count(*)::int, 1, 'adult_a kan ändra ett barns färg (children.manage)') from u;

select tests.authenticate_as('child_a');
with u as (update public.household_members set display_name = 'Bästa barnet' where id = tests.id('member:child_a') returning 1)
select is(count(*)::int, 0, 'child_a kan inte ändra sitt eget namn') from u;
with u as (update public.household_members set display_name = 'Hackat' where id = tests.id('member:owner_a') returning 1)
select is(count(*)::int, 0, 'child_a kan inte ändra en förälders namn') from u;
select throws_ok(
  format($$ update public.household_members set role = 'owner' where id = %L $$, tests.id('member:child_a')),
  '42501', null, 'child_a kan inte ge sig själv rollen owner'
);

select tests.authenticate_as('owner_b');
with u as (update public.household_members set display_name = 'Hackat' where household_id = tests.id('household:a') returning 1)
select is(count(*)::int, 0, 'owner_b kan inte ändra A:s medlemmar') from u;

-- ---------------------------------------------------------------- children SELECT
select tests.authenticate_as('owner_a');
select is((select count(*)::int from public.children), 2, 'owner_a ser A:s 2 barn');
select tests.authenticate_as('adult_a');
select is((select count(*)::int from public.children), 2, 'adult_a ser A:s 2 barn');
select tests.authenticate_as('child_a');
select results_eq(
  $$ select member_id from public.children $$,
  array[tests.id('member:child_a')],
  'child_a ser bara sin egen barnrad (inte syskons födelsedatum)'
);
select tests.authenticate_as('owner_b');
select is_empty($$ select 1 from public.children $$, 'owner_b ser inga barn (B har inga)');
select tests.authenticate_as('outsider');
select is_empty($$ select 1 from public.children $$, 'outsider ser inga barn');
select tests.authenticate_as_anon();
select throws_ok($$ select 1 from public.children $$, '42501', null, 'anon nekas children');

-- ---------------------------------------------------------------- children UPDATE/INSERT/DELETE
select tests.authenticate_as('adult_a');
with u as (update public.children set birth_date = '2020-02-02' where member_id = tests.id('member:managed_a') returning 1)
select is(count(*)::int, 1, 'adult_a kan ändra ett barns födelsedatum') from u;
select throws_ok(
  format('update public.children set can_view_allowance = true where member_id = %L', tests.id('member:managed_a')),
  '42501', null, 'barnbehörigheter kan inte ändras direkt (RPC med audit krävs)'
);

select tests.authenticate_as('child_a');
select throws_ok(
  format('update public.children set can_view_own_balance = true where member_id = %L', tests.id('member:child_a')),
  '42501', null, 'child_a kan inte ge sig själv ekonomibehörighet'
);
with u as (update public.children set birth_date = '2010-01-01' where member_id = tests.id('member:child_a') returning 1)
select is(count(*)::int, 0, 'child_a kan inte ändra sitt födelsedatum') from u;

select tests.authenticate_as('owner_b');
with u as (update public.children set birth_date = '2010-01-01' where household_id = tests.id('household:a') returning 1)
select is(count(*)::int, 0, 'owner_b kan inte ändra A:s barn') from u;

select tests.authenticate_as('owner_a');
select throws_ok(
  format('insert into public.children (member_id, household_id) values (%L, %L)', tests.id('member:adult_a'), tests.id('household:a')),
  '42501', null, 'barnrader kan inte skapas direkt'
);
select throws_ok(
  format('delete from public.children where member_id = %L', tests.id('member:managed_a')),
  '42501', null, 'barnrader kan inte raderas direkt'
);

-- Uppskjutna constraint-triggers körs annars aldrig eftersom testet rullas tillbaka.
-- Tvinga fram dem här så att alla ändringar ovan även klarar commit-kontrollerna.
select lives_ok($$ set constraints all immediate $$, 'alla uppskjutna kontroller (D9, barnkonsistens) håller');

select * from finish();
rollback;
