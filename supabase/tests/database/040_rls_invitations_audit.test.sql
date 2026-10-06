-- =============================================================================
-- RLS-matris: household_invitations och audit_log
-- =============================================================================
begin;
select plan(27);
select tests.create_fixture();

-- ---------------------------------------------------------------- household_invitations SELECT
select tests.authenticate_as('owner_a');
select is((select count(*)::int from public.household_invitations), 1, 'owner_a ser A:s inbjudan');
select tests.authenticate_as('adult_a');
select is_empty($$ select 1 from public.household_invitations $$, 'adult_a ser inga inbjudningar (D3: saknar members.invite)');
select tests.authenticate_as('child_a');
select is_empty($$ select 1 from public.household_invitations $$, 'child_a ser inga inbjudningar');
select tests.authenticate_as('multi');
select results_eq(
  $$ select household_id from public.household_invitations $$,
  array[tests.id('household:b')],
  'multi ser bara B:s inbjudan (owner i B, adult i A)'
);
select tests.authenticate_as('owner_b');
select is((select count(*)::int from public.household_invitations), 1, 'owner_b ser bara B:s inbjudan');
select tests.authenticate_as('outsider');
select is_empty($$ select 1 from public.household_invitations $$, 'outsider ser inga inbjudningar');
select tests.authenticate_as_anon();
select throws_ok($$ select 1 from public.household_invitations $$, '42501', null, 'anon nekas inbjudningar');

-- token_hash är aldrig läsbar
select tests.authenticate_as('owner_a');
select throws_ok($$ select token_hash from public.household_invitations $$, '42501', null, 'token_hash kan inte läsas');
select throws_ok($$ select * from public.household_invitations $$, '42501', null, 'select * nekas eftersom token_hash ingår');

-- ---------------------------------------------------------------- household_invitations INSERT/UPDATE/DELETE
select tests.authenticate_as('owner_a');
select throws_ok(
  format($$ insert into public.household_invitations (household_id, role, token_hash, expires_at)
            values (%L, 'adult', '\x00', now() + interval '1 day') $$, tests.id('household:a')),
  '42501', null, 'inbjudningar kan inte skapas direkt'
);
select throws_ok(
  format('update public.household_invitations set expires_at = now() + interval %L where household_id = %L', '20 days', tests.id('household:a')),
  '42501', null, 'inbjudningar kan inte förlängas direkt'
);
select throws_ok(
  format('update public.household_invitations set revoked_at = now() where household_id = %L', tests.id('household:a')),
  '42501', null, 'inbjudningar kan inte återkallas direkt (RPC med audit krävs)'
);
select throws_ok(
  format('delete from public.household_invitations where household_id = %L', tests.id('household:a')),
  '42501', null, 'inbjudningar kan inte raderas direkt'
);
select tests.authenticate_as('outsider');
select throws_ok(
  $$ update public.household_invitations set accepted_at = now() $$,
  '42501', null, 'outsider kan inte markera en inbjudan som accepterad'
);

-- ---------------------------------------------------------------- audit_log SELECT
select tests.authenticate_as('owner_a');
select results_eq($$ select household_id from public.audit_log $$, array[tests.id('household:a')], 'owner_a ser A:s audit log');
select tests.authenticate_as('adult_a');
select is_empty($$ select 1 from public.audit_log $$, 'adult_a ser ingen audit log (audit.read är owner-only)');
select tests.authenticate_as('child_a');
select is_empty($$ select 1 from public.audit_log $$, 'child_a ser ingen audit log');
select tests.authenticate_as('multi');
select results_eq($$ select household_id from public.audit_log $$, array[tests.id('household:b')], 'multi ser bara B:s audit log');
select tests.authenticate_as('owner_b');
select results_eq($$ select household_id from public.audit_log $$, array[tests.id('household:b')], 'owner_b ser bara B:s audit log');
select tests.authenticate_as('outsider');
select is_empty($$ select 1 from public.audit_log $$, 'outsider ser ingen audit log');
select tests.authenticate_as_anon();
select throws_ok($$ select 1 from public.audit_log $$, '42501', null, 'anon nekas audit log');

-- ---------------------------------------------------------------- audit_log är append-only
select tests.authenticate_as('owner_a');
select throws_ok(
  format($$ insert into public.audit_log (household_id, action) values (%L, 'household.created') $$, tests.id('household:a')),
  '42501', null, 'owner_a kan inte skriva i audit log'
);
select throws_ok($$ update public.audit_log set action = 'household.updated' $$, '42501', null, 'audit log kan inte ändras');
select throws_ok($$ delete from public.audit_log $$, '42501', null, 'audit log kan inte raderas');

-- private.write_audit kan inte anropas direkt av API-rollerna
select throws_ok(
  format($$ select private.write_audit(%L, 'household.created') $$, tests.id('household:a')),
  '42501', null, 'private.write_audit kan inte anropas av authenticated'
);
select tests.authenticate_as_anon();
select throws_ok(
  $$ select private.household_ids_with('household.read') $$,
  '42501', null, 'anon kan inte anropa behörighetsfunktioner'
);

-- Uppskjutna constraint-triggers körs annars aldrig eftersom testet rullas tillbaka.
-- Tvinga fram dem här så att alla ändringar ovan även klarar commit-kontrollerna.
select lives_ok($$ set constraints all immediate $$, 'alla uppskjutna kontroller (D9, barnkonsistens) håller');

select * from finish();
rollback;
