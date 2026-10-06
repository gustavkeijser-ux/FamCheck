-- =============================================================================
-- D10: generell åtkomstnivå (private / adults / household) via private.can_view_resource()
-- D2:  owner kan INTE läsa andra vuxnas privata resurser.
-- Funktionen används av framtida tabeller (t.ex. ekonomiska konton) i RLS-policyer.
-- =============================================================================
begin;
select no_plan();
select tests.create_fixture();

create function pg_temp.can_view(p_household text, p_visibility text, p_owner text)
returns boolean
language sql
as $$
  select private.can_view_resource(
    tests.id(p_household),
    p_visibility::public.resource_visibility,
    case when p_owner is null then null else tests.id(p_owner) end
  )
$$;
grant execute on function pg_temp.can_view(text, text, text) to authenticated, anon;

-- owner_a
select tests.authenticate_as('owner_a');
select ok(pg_temp.can_view('household:a', 'private', 'member:owner_a'), 'owner_a ser sin egen privata resurs');
select ok(not pg_temp.can_view('household:a', 'private', 'member:adult_a'), 'D2: owner_a ser INTE adult_a:s privata resurs');
select ok(pg_temp.can_view('household:a', 'adults', null), 'owner_a ser resurser för vuxna');
select ok(pg_temp.can_view('household:a', 'household', null), 'owner_a ser hushållsresurser');
select ok(not pg_temp.can_view('household:b', 'household', null), 'owner_a ser inte B:s hushållsresurser');

-- adult_a
select tests.authenticate_as('adult_a');
select ok(pg_temp.can_view('household:a', 'private', 'member:adult_a'), 'adult_a ser sin egen privata resurs');
select ok(not pg_temp.can_view('household:a', 'private', 'member:owner_a'), 'adult_a ser inte owner_a:s privata resurs');
select ok(pg_temp.can_view('household:a', 'adults', null), 'adult_a ser resurser för vuxna');

-- child_a
select tests.authenticate_as('child_a');
select ok(not pg_temp.can_view('household:a', 'adults', null), 'child_a ser INTE resurser för vuxna');
select ok(pg_temp.can_view('household:a', 'household', null), 'child_a ser hushållsresurser (om resurstypen tillåter barn)');
select ok(pg_temp.can_view('household:a', 'private', 'member:child_a'), 'child_a ser sin egen privata resurs');
select ok(not pg_temp.can_view('household:a', 'private', 'member:adult_a'), 'child_a ser inte en vuxens privata resurs');

-- multi (adult i A, owner i B)
select tests.authenticate_as('multi');
select ok(pg_temp.can_view('household:a', 'private', 'member:multi_a'), 'multi ser sin privata resurs i A');
select ok(not pg_temp.can_view('household:b', 'private', 'member:multi_a'), 'en privat resurs kan inte "flyttas" till ett annat hushåll');
select ok(not pg_temp.can_view('household:b', 'private', 'member:owner_b'), 'multi (owner i B) ser inte owner_b:s privata resurs');

-- owner_b och outsider
select tests.authenticate_as('owner_b');
select ok(not pg_temp.can_view('household:a', 'household', null), 'owner_b ser inte A:s hushållsresurser');
select ok(not pg_temp.can_view('household:a', 'adults', null), 'owner_b ser inte A:s vuxenresurser');
select tests.authenticate_as('outsider');
select ok(not pg_temp.can_view('household:a', 'household', null), 'outsider ser inga resurser');
select ok(not pg_temp.can_view('household:a', 'private', 'member:owner_a'), 'outsider ser inga privata resurser');

-- Borttagna medlemmar förlorar åtkomst direkt
select tests.clear_authentication();
update public.household_members set status = 'removed', ended_at = now() where id = tests.id('member:adult_a');
select tests.authenticate_as('adult_a');
select ok(not pg_temp.can_view('household:a', 'private', 'member:adult_a'), 'en borttagen medlem ser inte ens sina tidigare privata resurser');
select ok(not pg_temp.can_view('household:a', 'household', null), 'en borttagen medlem ser inga hushållsresurser');

-- anon
select tests.authenticate_as_anon();
select throws_ok(
  format($$ select private.can_view_resource(%L, 'household', null) $$, tests.id('household:a')),
  '42501', null, 'anon kan inte anropa can_view_resource'
);

select * from finish();
rollback;
