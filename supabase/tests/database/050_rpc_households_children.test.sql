-- =============================================================================
-- RPC-flöden: hushåll och barn
-- =============================================================================
begin;
select no_plan();
select tests.create_fixture();

-- ---------------------------------------------------------------- create_household
select tests.authenticate_as_anon();
select throws_ok($$ select public.create_household('Anon') $$, '42501', null, 'anon kan inte skapa hushåll');

select tests.authenticate_as('outsider');
select set_config('tests.new_household', public.create_household('  Familjen Test  ')::text, true);
select results_eq(
  $$ select name from public.households where id = current_setting('tests.new_household')::uuid $$,
  array['Familjen Test'],
  'create_household skapar ett hushåll med trimmat namn'
);
select results_eq(
  $$ select role::text from public.household_members where household_id = current_setting('tests.new_household')::uuid $$,
  array['owner'],
  'skaparen blir enda medlem med rollen owner'
);
select is(
  (select last_active_household_id from public.profiles where id = tests.id('user:outsider')),
  current_setting('tests.new_household')::uuid,
  'det nya hushållet blir aktivt hushåll'
);
select results_eq(
  $$ select action from public.audit_log where household_id = current_setting('tests.new_household')::uuid $$,
  array['household.created'],
  'household.created loggas'
);
select is(
  (select actor_user_id from public.audit_log where household_id = current_setting('tests.new_household')::uuid),
  tests.id('user:outsider'),
  'audit-händelsen har rätt aktör'
);
select throws_ok($$ select public.create_household('   ') $$, '22023', 'invalid_household_name', 'tomt namn avvisas');
select throws_ok(
  format('select public.create_household(%L)', repeat('x', 81)),
  '22023', 'invalid_household_name', 'för långt namn avvisas'
);

-- ---------------------------------------------------------------- update_household
select tests.authenticate_as('owner_a');
select lives_ok(
  format('select public.update_household(%L, %L, %L)', tests.id('household:a'), 'Nya namnet', 'Europe/Helsinki'),
  'owner_a kan uppdatera hushållet'
);
select results_eq(
  format('select name || %L || timezone from public.households where id = %L', '|', tests.id('household:a')),
  array['Nya namnet|Europe/Helsinki'],
  'namn och tidszon uppdaterades'
);
select throws_ok(
  format('select public.update_household(%L, null, %L)', tests.id('household:a'), 'Mars/Olympus'),
  '22023', 'invalid_timezone', 'ogiltig tidszon avvisas'
);
select tests.authenticate_as('adult_a');
select throws_ok(
  format('select public.update_household(%L, %L)', tests.id('household:a'), 'Adult'),
  '42501', 'forbidden', 'adult_a kan inte uppdatera hushållet'
);
select tests.authenticate_as('owner_b');
select throws_ok(
  format('select public.update_household(%L, %L)', tests.id('household:a'), 'Hackat'),
  '42501', 'forbidden', 'owner_b kan inte uppdatera hushåll A'
);
select throws_ok(
  format('select public.update_household(%L, %L)', gen_random_uuid(), 'Finns ej'),
  '42501', 'forbidden', 'okänt hushåll ger samma fel som saknad behörighet'
);

-- ---------------------------------------------------------------- create_child
select tests.authenticate_as('adult_a');
select set_config(
  'tests.child',
  public.create_child(tests.id('household:a'), ' Elsa ', '2019-03-01', '#FFAA00')::text,
  true
);
select results_eq(
  $$ select role::text || '|' || display_name || '|' || coalesce(user_id::text, 'null')
     from public.household_members where id = current_setting('tests.child')::uuid $$,
  array['managed_child|Elsa|null'],
  'create_child skapar ett managed_child utan konto'
);
select is(
  (select array[can_view_calendar, can_view_family_events, can_use_tasks_and_routines,
                can_view_allowance, can_view_own_balance, can_view_savings_goals]
   from public.children where member_id = current_setting('tests.child')::uuid),
  array[true, true, true, false, false, false],
  'D7: kalender/familj/uppgifter på, all ekonomi av'
);
select throws_ok(
  format('select public.create_child(%L, %L, %L)', tests.id('household:a'), 'Framtid', (current_date + 1)::text),
  '22023', 'birth_date_in_future', 'födelsedatum i framtiden avvisas'
);
select throws_ok(
  format('select public.create_child(%L, %L, null, %L)', tests.id('household:a'), 'Färg', 'red'),
  '22023', 'invalid_color', 'ogiltig färg avvisas'
);
select tests.authenticate_as('child_a');
select throws_ok(
  format('select public.create_child(%L, %L)', tests.id('household:a'), 'Syskon'),
  '42501', 'forbidden', 'child_a kan inte skapa barn'
);
select tests.authenticate_as('owner_b');
select throws_ok(
  format('select public.create_child(%L, %L)', tests.id('household:a'), 'Inkräktare'),
  '42501', 'forbidden', 'owner_b kan inte skapa barn i hushåll A'
);

-- ---------------------------------------------------------------- update_child_permissions
select tests.authenticate_as('owner_a');
select lives_ok(
  $$ select public.update_child_permissions(current_setting('tests.child')::uuid, p_can_view_allowance => true) $$,
  'owner_a kan slå på veckopeng för ett barn (opt-in)'
);
select is(
  (select can_view_allowance from public.children where member_id = current_setting('tests.child')::uuid),
  true,
  'behörigheten ändrades'
);
select is(
  (select metadata from public.audit_log
   where action = 'child.permissions_changed' and target_id = current_setting('tests.child')::uuid),
  '{"changed": {"can_view_allowance": [false, true]}}'::jsonb,
  'ändringen loggas med före/efter-värde'
);
select lives_ok(
  $$ select public.update_child_permissions(current_setting('tests.child')::uuid, p_can_view_allowance => true) $$,
  'samma värde igen går bra'
);
select is(
  (select count(*)::int from public.audit_log where action = 'child.permissions_changed'),
  1,
  'en oförändrad behörighet loggas inte igen'
);
select tests.authenticate_as('child_a');
select throws_ok(
  format('select public.update_child_permissions(%L, p_can_view_own_balance => true)', tests.id('member:child_a')),
  '42501', 'forbidden', 'child_a kan inte ändra sina egna behörigheter'
);
select tests.authenticate_as('owner_b');
select throws_ok(
  format('select public.update_child_permissions(%L, p_can_view_own_balance => true)', tests.id('member:child_a')),
  '42501', 'forbidden', 'owner_b kan inte ändra behörigheter för barn i A'
);
select tests.authenticate_as('owner_a');
select throws_ok(
  format('select public.update_child_permissions(%L, p_can_view_own_balance => true)', tests.id('member:adult_a')),
  '42501', 'forbidden', 'update_child_permissions fungerar inte på en vuxen'
);

-- ---------------------------------------------------------------- delete_household
select tests.authenticate_as('adult_a');
select throws_ok(
  format('select public.delete_household(%L, %L)', tests.id('household:a'), 'Nya namnet'),
  '42501', 'forbidden', 'adult_a kan inte radera hushållet'
);
select tests.authenticate_as('owner_a');
select throws_ok(
  format('select public.delete_household(%L, %L)', tests.id('household:a'), 'fel namn'),
  'P0001', 'confirmation_mismatch', 'radering kräver att namnet bekräftas'
);
select lives_ok(
  format('select public.delete_household(%L, %L)', tests.id('household:a'), 'Nya namnet'),
  'owner_a kan radera hushållet med korrekt bekräftelse'
);
select is_empty($$ select 1 from public.households $$, 'owner_a ser inga hushåll efter raderingen');

select tests.clear_authentication();
select is_empty(
  format('select 1 from public.household_members where household_id = %L', tests.id('household:a')),
  'medlemmar och barn raderades med hushållet'
);
select results_eq(
  format($$ select count(*)::int from public.audit_log
            where household_id = %L and action <> 'household.deleted'
              and (actor_user_id is not null or target_id is not null or metadata <> '{}') $$,
         tests.id('household:a')),
  array[0],
  'D8: äldre audit-händelser för hushållet anonymiserades'
);
select results_eq(
  format($$ select count(*)::int from public.audit_log where household_id = %L and action = 'household.deleted' $$,
         tests.id('household:a')),
  array[1],
  'household.deleted finns kvar (gallras efter 90 dagar)'
);

-- ---------------------------------------------------------------- purge_audit_log (D8)
update public.audit_log set created_at = now() - interval '91 days' where household_id = tests.id('household:a');
insert into public.audit_log (household_id, action, created_at)
values (tests.id('household:b'), 'household.updated', now() - interval '25 months');
-- A: created, updated, child.created, child.permissions_changed, deleted (5) + B:s gamla (1)
select is(private.purge_audit_log(), 6, 'gallring tar bort raderat hushålls händelser och händelser äldre än 24 mån');
select is_empty(
  format('select 1 from public.audit_log where household_id = %L', tests.id('household:a')),
  'inga händelser kvar för det raderade hushållet'
);
select is(
  (select count(*)::int from public.audit_log where household_id = tests.id('household:b')),
  1,
  'B:s färska händelse finns kvar'
);

select * from finish();
rollback;
