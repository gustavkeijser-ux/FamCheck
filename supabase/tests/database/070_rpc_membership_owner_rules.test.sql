-- =============================================================================
-- RPC-flöden: roller och medlemskap. D9 – minst en owner per hushåll.
-- =============================================================================
begin;
select no_plan();
select tests.create_fixture();

-- ---------------------------------------------------------------- sista owner (D9)
select tests.authenticate_as('owner_a');
select throws_ok(
  format('select public.leave_household(%L)', tests.id('household:a')),
  'P0001', 'last_owner', 'D9: sista owner kan inte lämna hushållet'
);
select throws_ok(
  format($$ select public.change_member_role(%L, 'adult') $$, tests.id('member:owner_a')),
  'P0001', 'last_owner', 'D9: sista owner kan inte degradera sig själv'
);
select throws_ok(
  format('select public.remove_member(%L)', tests.id('member:owner_a')),
  'P0001', 'use_leave_household', 'man tar inte bort sig själv via remove_member'
);

-- D9: sista owner kan inte radera sitt konto utan att medlemskapet hanterats först.
select tests.clear_authentication();
select throws_ok(
  format('delete from auth.users where id = %L', tests.id('user:owner_b')),
  '23503', null, 'D9: ett konto med medlemskap kan inte raderas (FK RESTRICT)'
);
select throws_ok(
  format('delete from auth.users where id = %L', tests.id('user:adult_a')),
  '23503', null, 'inte heller en vanlig medlems konto – raderingsflödet måste hantera medlemskapen'
);
select lives_ok(
  format('delete from auth.users where id = %L', tests.id('user:outsider')),
  'ett konto utan medlemskap kan raderas'
);

-- D9: databasen stoppar även försök som går förbi RPC:erna (sista skyddsnätet).
set constraints household_members_require_owner immediate;
select throws_ok(
  format($$ update public.household_members set role = 'adult' where id = %L $$, tests.id('member:owner_a')),
  '23514', 'household_requires_owner', 'D9: databasen tillåter aldrig ett hushåll utan aktiv owner'
);
select throws_ok(
  format($$ update public.household_members set status = 'left', ended_at = now() where id = %L $$, tests.id('member:owner_a')),
  '23514', 'household_requires_owner', 'D9: inte heller via status'
);
set constraints household_members_require_owner deferred;

-- ---------------------------------------------------------------- change_member_role
select tests.authenticate_as('adult_a');
select throws_ok(
  format($$ select public.change_member_role(%L, 'owner') $$, tests.id('member:adult_a')),
  '42501', 'forbidden', 'adult kan inte göra sig själv till owner'
);
select tests.authenticate_as('multi');
select throws_ok(
  format($$ select public.change_member_role(%L, 'owner') $$, tests.id('member:multi_a')),
  '42501', 'forbidden', 'owner i B har ingen rollbehörighet i A'
);
select tests.authenticate_as('owner_b');
select throws_ok(
  format($$ select public.change_member_role(%L, 'adult') $$, tests.id('member:owner_a')),
  '42501', 'forbidden', 'owner i B kan inte ändra roller i A'
);

select tests.authenticate_as('owner_a');
select throws_ok(
  format($$ select public.change_member_role(%L, 'child') $$, tests.id('member:adult_a')),
  '22023', 'invalid_role', 'en vuxen kan inte göras till barn via rollbyte'
);
select throws_ok(
  format($$ select public.change_member_role(%L, 'adult') $$, tests.id('member:child_a')),
  'P0001', 'role_change_not_supported', 'ett barn kan inte göras till vuxen via rollbyte'
);
select lives_ok(
  format($$ select public.change_member_role(%L, 'owner') $$, tests.id('member:adult_a')),
  'D9: ett hushåll kan ha flera owners (owner_a gör adult_a till owner)'
);
select is(
  (select metadata from public.audit_log where action = 'member.role_changed' and target_id = tests.id('member:adult_a')),
  '{"from": "adult", "to": "owner"}'::jsonb,
  'rollbytet loggas'
);
select lives_ok(
  format($$ select public.change_member_role(%L, 'adult') $$, tests.id('member:owner_a')),
  'nu kan owner_a degradera sig själv eftersom en annan owner finns'
);

-- adult_a är nu enda owner
select tests.authenticate_as('adult_a');
select throws_ok(
  format($$ select public.change_member_role(%L, 'adult') $$, tests.id('member:adult_a')),
  'P0001', 'last_owner', 'den nya ensamma ownern kan inte heller degradera sig'
);
select lives_ok(
  format($$ select public.change_member_role(%L, 'owner') $$, tests.id('member:owner_a')),
  'adult_a återställer owner_a till owner'
);

-- ---------------------------------------------------------------- remove_member
select tests.authenticate_as('owner_b');
select throws_ok(
  format('select public.remove_member(%L)', tests.id('member:adult_a')),
  '42501', 'forbidden', 'owner i B kan inte ta bort medlemmar i A'
);
select tests.authenticate_as('child_a');
select throws_ok(
  format('select public.remove_member(%L)', tests.id('member:managed_a')),
  '42501', 'forbidden', 'barn kan inte ta bort medlemmar'
);
select tests.authenticate_as('owner_a');
select lives_ok(
  format('select public.remove_member(%L)', tests.id('member:adult_a')),
  'en owner kan ta bort en annan owner när minst en owner finns kvar'
);
select results_eq(
  format('select status::text from public.household_members where id = %L', tests.id('member:adult_a')),
  array['removed'],
  'medlemsraden finns kvar med status removed (historik)'
);
select tests.authenticate_as('adult_a');
select is_empty($$ select 1 from public.households $$, 'en borttagen medlem ser inte längre hushållet');
select is_empty($$ select 1 from public.household_members $$, 'en borttagen medlem ser inga medlemmar');

select tests.authenticate_as('owner_a');
select lives_ok(
  format('select public.remove_member(%L)', tests.id('member:managed_a')),
  'en owner kan ta bort ett managed_child'
);
select tests.clear_authentication();
select results_eq(
  format('select count(*)::int from public.children where member_id = %L', tests.id('member:managed_a')),
  array[1],
  'barnets data finns kvar efter borttagning (historik)'
);

-- ---------------------------------------------------------------- leave_household
select tests.authenticate_as('child_a');
select throws_ok(
  format('select public.leave_household(%L)', tests.id('household:a')),
  '42501', 'forbidden', 'ett barn kan inte lämna hushållet själv'
);
select tests.authenticate_as('outsider');
select throws_ok(
  format('select public.leave_household(%L)', tests.id('household:a')),
  '42501', 'forbidden', 'en icke-medlem kan inte lämna'
);
select tests.authenticate_as('multi');
select lives_ok(
  format('select public.leave_household(%L)', tests.id('household:a')),
  'multi lämnar hushåll A'
);
select results_eq(
  $$ select name from public.households $$,
  array['Hushåll B'],
  'multi ser bara hushåll B efter att ha lämnat A'
);
-- B har två owners (owner_b och multi): en kan lämna, den sista kan inte.
select tests.authenticate_as('owner_b');
select lives_ok(
  format('select public.leave_household(%L)', tests.id('household:b')),
  'owner_b kan lämna B eftersom multi också är owner'
);
select tests.authenticate_as('multi');
select throws_ok(
  format('select public.leave_household(%L)', tests.id('household:b')),
  'P0001', 'last_owner', 'D9: multi är nu sista owner i B och kan inte lämna'
);
select lives_ok(
  format('select public.delete_household(%L, %L)', tests.id('household:b'), 'Hushåll B'),
  'D9: sista owner kan i stället radera hushållet via det uttryckliga flödet'
);

-- ---------------------------------------------------------------- återinträde behåller person-id
select tests.authenticate_as('owner_a');
select set_config('tests.token_rejoin',
  (select token from public.create_invitation(tests.id('household:a'), 'adult')), true);
select tests.authenticate_as('multi');
select lives_ok(
  format('select public.accept_invitation(%L)', current_setting('tests.token_rejoin')),
  'multi kan gå med i A igen via en ny inbjudan'
);
select results_eq(
  format('select id from public.household_members where household_id = %L and user_id = %L',
         tests.id('household:a'), tests.id('user:multi')),
  array[tests.id('member:multi_a')],
  'återinträde återaktiverar samma medlemsrad (samma person-id, historiken behålls)'
);

select * from finish();
rollback;
