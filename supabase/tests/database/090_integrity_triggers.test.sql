-- =============================================================================
-- Integritetsregler som körs vid commit (uppskjutna constraint-triggers).
-- Testas genom att tvinga fram kontrollen med SET CONSTRAINTS ... IMMEDIATE.
-- =============================================================================
begin;
select no_plan();
select tests.create_fixture();
select lives_ok($$ set constraints all immediate $$, 'fixturen uppfyller alla integritetsregler');
set constraints all deferred;

-- Barnroll kräver children-rad
insert into public.household_members (household_id, role, display_name)
values (tests.id('household:a'), 'managed_child', 'Utan barnrad');
select throws_ok(
  $$ set constraints all immediate $$,
  '23514', 'child_member_requires_children_row', 'ett barn utan children-rad stoppas vid commit'
);
set constraints all deferred;
delete from public.household_members where display_name = 'Utan barnrad';

-- children-rad kräver barnroll
insert into public.children (member_id, household_id) values (tests.id('member:adult_a'), tests.id('household:a'));
select throws_ok(
  $$ set constraints all immediate $$,
  '23514', null, 'en vuxen kan inte ha en children-rad'
);
set constraints all deferred;
delete from public.children where member_id = tests.id('member:adult_a');

-- Ett barn kan inte bli vuxen genom en direkt rolländring (children-raden finns kvar)
update public.household_members set role = 'adult' where id = tests.id('member:child_a');
select throws_ok(
  $$ set constraints all immediate $$,
  '23514', 'adult_member_cannot_have_children_row', 'barnroll kan inte bytas direkt till vuxenroll'
);
set constraints all deferred;
update public.household_members set role = 'child' where id = tests.id('member:child_a');

-- Barnraden kan inte tas bort så länge personen har en barnroll
delete from public.children where member_id = tests.id('member:managed_a');
select throws_ok(
  $$ set constraints all immediate $$,
  '23514', 'child_member_requires_children_row', 'children-raden kan inte tas bort från ett barn'
);
set constraints all deferred;
insert into public.children (member_id, household_id) values (tests.id('member:managed_a'), tests.id('household:a'));

-- Sammansatt FK: en barnrad kan inte peka på en person i ett annat hushåll
select throws_ok(
  format('insert into public.children (member_id, household_id) values (%L, %L)',
         tests.id('member:owner_b'), tests.id('household:a')),
  '23503', null, 'children kan inte korsa hushåll'
);

-- Inbjudan till barnkoppling kan inte peka på en person i ett annat hushåll
select throws_ok(
  format($$ insert into public.household_invitations (household_id, role, target_member_id, token_hash, expires_at)
            values (%L, 'child', %L, extensions.digest('x', 'sha256'), now() + interval '1 day') $$,
         tests.id('household:a'), tests.id('member:owner_b')),
  '23503', null, 'en inbjudan kan inte koppla till en person i ett annat hushåll'
);

-- Check constraints
select throws_ok(
  format($$ insert into public.household_members (household_id, user_id, role, display_name)
            values (%L, %L, 'managed_child', 'Har konto') $$, tests.id('household:a'), tests.id('user:outsider')),
  '23514', null, 'managed_child kan inte ha ett konto'
);
select throws_ok(
  format($$ insert into public.household_members (household_id, role, display_name) values (%L, 'adult', 'Utan konto') $$,
         tests.id('household:a')),
  '23514', null, 'en aktiv vuxen måste ha ett konto'
);
select throws_ok(
  format($$ insert into public.household_invitations (household_id, role, token_hash, expires_at)
            values (%L, 'adult', extensions.digest('y', 'sha256'), now() + interval '31 days') $$, tests.id('household:a')),
  '23514', null, 'en inbjudan kan inte gälla längre än 30 dagar'
);
select throws_ok(
  format($$ insert into public.household_invitations (household_id, role, token_hash, expires_at)
            values (%L, 'owner', extensions.digest('z', 'sha256'), now() + interval '1 day') $$, tests.id('household:a')),
  '23514', null, 'man kan inte bjudas in direkt som owner'
);
select throws_ok(
  $$ insert into public.audit_log (action) values ('password.changed') $$,
  '23514', null, 'audit log godtar bara kända händelsetyper'
);
select throws_ok(
  $$ insert into public.audit_log (action, metadata) values ('household.created', '[]') $$,
  '23514', null, 'audit-metadata måste vara ett objekt'
);
select throws_ok(
  $$ insert into public.households (name) values (E'Namn\nmed radbrytning') $$,
  '23514', null, 'hushållsnamn får inte innehålla kontrolltecken'
);

select lives_ok($$ set constraints all immediate $$, 'efter återställning håller alla integritetsregler');
select * from finish();
rollback;
