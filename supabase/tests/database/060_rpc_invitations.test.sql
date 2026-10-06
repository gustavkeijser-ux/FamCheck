-- =============================================================================
-- RPC-flöden: inbjudningar (säkra, utgående, engångs, återkallbara)
-- =============================================================================
begin;
select no_plan();
select tests.create_fixture();
select tests.create_user('newbie');
select tests.create_user('invitee', 'invitee@example.se');
select tests.create_user('unverified', 'unverified@example.se');
update auth.users set email_confirmed_at = null where id = tests.id('user:unverified');
select tests.create_user('kid');
select tests.create_user('kid2');

-- ---------------------------------------------------------------- create_invitation: behörighet
select tests.authenticate_as('adult_a');
select throws_ok(
  format($$ select * from public.create_invitation(%L, 'adult') $$, tests.id('household:a')),
  '42501', 'forbidden', 'D3: adult kan inte bjuda in som standard'
);
select tests.authenticate_as('child_a');
select throws_ok(
  format($$ select * from public.create_invitation(%L, 'adult') $$, tests.id('household:a')),
  '42501', 'forbidden', 'child kan inte bjuda in'
);
select tests.authenticate_as('owner_b');
select throws_ok(
  format($$ select * from public.create_invitation(%L, 'adult') $$, tests.id('household:a')),
  '42501', 'forbidden', 'owner i B kan inte bjuda in till A'
);
select tests.authenticate_as('multi');
select throws_ok(
  format($$ select * from public.create_invitation(%L, 'adult') $$, tests.id('household:a')),
  '42501', 'forbidden', 'multi (owner i B, adult i A) kan inte bjuda in till A'
);

-- ---------------------------------------------------------------- create_invitation: validering
select tests.authenticate_as('owner_a');
select throws_ok(
  format($$ select * from public.create_invitation(%L, 'owner') $$, tests.id('household:a')),
  '22023', 'invalid_role', 'man kan inte bjudas in som owner'
);
select throws_ok(
  format($$ select * from public.create_invitation(%L, 'adult', null, null, 31) $$, tests.id('household:a')),
  '22023', 'invalid_expiry', 'utgångstid över 30 dagar avvisas'
);
select throws_ok(
  format($$ select * from public.create_invitation(%L, 'adult', 'inte-en-epost') $$, tests.id('household:a')),
  '22023', 'invalid_email', 'ogiltig e-post avvisas'
);
select throws_ok(
  format($$ select * from public.create_invitation(%L, 'adult', null, %L) $$, tests.id('household:a'), tests.id('member:managed_a')),
  '22023', 'invalid_role', 'koppling av barn kräver rollen child'
);
select throws_ok(
  format($$ select * from public.create_invitation(%L, 'child', null, %L) $$, tests.id('household:a'), tests.id('member:child_a')),
  '22023', 'invalid_target_member', 'ett barn som redan har konto kan inte kopplas igen'
);
select throws_ok(
  format($$ select * from public.create_invitation(%L, 'child', null, %L) $$, tests.id('household:a'), tests.id('member:owner_b')),
  '22023', 'invalid_target_member', 'en person i ett annat hushåll kan inte väljas'
);

-- ---------------------------------------------------------------- adult-inbjudan: hela flödet
select set_config('tests.token_adult',
  (select token from public.create_invitation(tests.id('household:a'), 'adult')), true);
select is(length(current_setting('tests.token_adult')), 43, 'token är 43 tecken base64url (256 bitar)');
select ok(current_setting('tests.token_adult') ~ '^[A-Za-z0-9_-]{43}$', 'token är url-säker');

select tests.clear_authentication();
select is(
  (select count(*)::int from public.household_invitations
   where token_hash = extensions.digest(current_setting('tests.token_adult'), 'sha256')),
  1,
  'bara SHA-256-hashen av token lagras'
);
select is_empty(
  $$ select 1 from public.household_invitations i
     where encode(i.token_hash, 'escape') like '%' || current_setting('tests.token_adult') || '%' $$,
  'token lagras inte i klartext'
);
select is_empty(
  $$ select 1 from public.audit_log where metadata::text like '%' || current_setting('tests.token_adult') || '%' $$,
  'token finns inte i audit-loggen'
);

select tests.authenticate_as('newbie');
select results_eq(
  $$ select household_name || '|' || invited_by_name || '|' || role::text
     from public.preview_invitation(current_setting('tests.token_adult')) $$,
  array['Hushåll A|Owner A|adult'],
  'preview visar hushållets namn, vem som bjöd in och roll'
);
select is_empty($$ select 1 from public.households $$, 'preview ger ingen läsrätt till hushållet');
select is(
  public.accept_invitation(current_setting('tests.token_adult')),
  tests.id('household:a'),
  'newbie accepterar inbjudan'
);
select results_eq(
  $$ select role::text || '|' || status::text from public.household_members where user_id = tests.id('user:newbie') $$,
  array['adult|active'],
  'newbie blev adult i hushåll A'
);
select is((select count(*)::int from public.households), 1, 'newbie ser nu hushåll A');

select tests.authenticate_as('outsider');
select throws_ok(
  format('select public.accept_invitation(%L)', current_setting('tests.token_adult')),
  'P0001', 'invitation_accepted', 'en inbjudan kan bara användas en gång'
);
select throws_ok(
  format('select * from public.preview_invitation(%L)', current_setting('tests.token_adult')),
  'P0001', 'invitation_accepted', 'en använd inbjudan kan inte förhandsvisas'
);
select throws_ok($$ select public.accept_invitation('kort') $$, 'P0001', 'invitation_not_found', 'felaktigt format avvisas');
select throws_ok(
  format('select public.accept_invitation(%L)', repeat('A', 43)),
  'P0001', 'invitation_not_found', 'okänd token avvisas'
);
select tests.authenticate_as_anon();
select throws_ok(
  format('select public.accept_invitation(%L)', current_setting('tests.token_adult')),
  '42501', null, 'anon kan inte acceptera inbjudningar'
);

-- Den som redan är medlem
select tests.authenticate_as('owner_a');
select set_config('tests.token_dup',
  (select token from public.create_invitation(tests.id('household:a'), 'adult')), true);
select tests.authenticate_as('adult_a');
select throws_ok(
  format('select public.accept_invitation(%L)', current_setting('tests.token_dup')),
  'P0001', 'already_member', 'en befintlig medlem kan inte acceptera igen'
);

-- ---------------------------------------------------------------- utgång och återkallelse
select tests.authenticate_as('owner_a');
select set_config('tests.token_expired',
  (select token from public.create_invitation(tests.id('household:a'), 'adult')), true);
select tests.clear_authentication();
update public.household_invitations
set created_at = now() - interval '8 days', expires_at = now() - interval '1 day'
where token_hash = extensions.digest(current_setting('tests.token_expired'), 'sha256');
select tests.authenticate_as('outsider');
select throws_ok(
  format('select public.accept_invitation(%L)', current_setting('tests.token_expired')),
  'P0001', 'invitation_expired', 'en utgången inbjudan kan inte användas'
);

select tests.authenticate_as('owner_a');
select set_config('tests.token_revoked',
  (select token from public.create_invitation(tests.id('household:a'), 'adult')), true);
select tests.clear_authentication();
select set_config('tests.invitation_revoked',
  (select id::text from public.household_invitations
   where token_hash = extensions.digest(current_setting('tests.token_revoked'), 'sha256')), true);
select tests.authenticate_as('adult_a');
select throws_ok(
  format('select public.revoke_invitation(%L)', current_setting('tests.invitation_revoked')),
  '42501', 'forbidden', 'adult kan inte återkalla inbjudningar'
);
select tests.authenticate_as('owner_b');
select throws_ok(
  format('select public.revoke_invitation(%L)', current_setting('tests.invitation_revoked')),
  '42501', 'forbidden', 'owner i B kan inte återkalla A:s inbjudningar'
);
select tests.authenticate_as('owner_a');
select lives_ok(
  format('select public.revoke_invitation(%L)', current_setting('tests.invitation_revoked')),
  'owner_a kan återkalla en inbjudan'
);
select throws_ok(
  format('select public.revoke_invitation(%L)', current_setting('tests.invitation_revoked')),
  'P0001', 'invitation_not_pending', 'en återkallad inbjudan kan inte återkallas igen'
);
select tests.authenticate_as('outsider');
select throws_ok(
  format('select public.accept_invitation(%L)', current_setting('tests.token_revoked')),
  'P0001', 'invitation_revoked', 'en återkallad inbjudan kan inte användas'
);

-- ---------------------------------------------------------------- e-postbunden inbjudan
select tests.authenticate_as('owner_a');
select set_config('tests.token_email',
  (select token from public.create_invitation(tests.id('household:a'), 'adult', ' Invitee@Example.SE ')), true);
select tests.authenticate_as('outsider');
select throws_ok(
  format('select public.accept_invitation(%L)', current_setting('tests.token_email')),
  'P0001', 'invitation_email_mismatch', 'fel e-post kan inte acceptera en e-postbunden inbjudan'
);
select throws_ok(
  format('select * from public.preview_invitation(%L)', current_setting('tests.token_email')),
  'P0001', 'invitation_email_mismatch', 'fel e-post kan inte heller förhandsvisa'
);
select tests.authenticate_as('invitee');
select is(
  public.accept_invitation(current_setting('tests.token_email')),
  tests.id('household:a'),
  'rätt verifierad e-post (skiftlägesokänsligt) kan acceptera'
);

select tests.authenticate_as('owner_a');
select set_config('tests.token_unverified',
  (select token from public.create_invitation(tests.id('household:a'), 'adult', 'unverified@example.se')), true);
select tests.authenticate_as('unverified');
select throws_ok(
  format('select public.accept_invitation(%L)', current_setting('tests.token_unverified')),
  'P0001', 'invitation_email_mismatch', 'overifierad e-post räcker inte'
);

-- ---------------------------------------------------------------- koppla konto till managed_child
select tests.authenticate_as('owner_a');
select set_config('tests.token_link_old',
  (select token from public.create_invitation(tests.id('household:a'), 'child', null, tests.id('member:managed_a'))), true);
select set_config('tests.token_link',
  (select token from public.create_invitation(tests.id('household:a'), 'child', null, tests.id('member:managed_a'))), true);

select tests.authenticate_as('kid');
select throws_ok(
  format('select public.accept_invitation(%L)', current_setting('tests.token_link_old')),
  'P0001', 'invitation_revoked', 'en ny kopplingsinbjudan återkallar den äldre'
);
select results_eq(
  $$ select child_display_name from public.preview_invitation(current_setting('tests.token_link')) $$,
  array['Managed A'],
  'preview visar vilket barn kontot kopplas till'
);
select lives_ok(
  format('select public.accept_invitation(%L)', current_setting('tests.token_link')),
  'barnet accepterar kopplingen'
);
select tests.clear_authentication();
select results_eq(
  format('select role::text || %L || user_id::text from public.household_members where id = %L', '|', tests.id('member:managed_a')),
  array['child|' || tests.id('user:kid')::text],
  'samma medlems-id har nu konto och rollen child (historiken följer med)'
);
select is(
  (select birth_date from public.children where member_id = tests.id('member:managed_a')),
  '2020-01-01'::date,
  'barnraden är oförändrad'
);
select results_eq(
  format($$ select action from public.audit_log where target_id = %L and action in ('child.account_linked', 'member.joined') order by action $$,
         tests.id('member:managed_a')),
  array['child.account_linked', 'member.joined'],
  'kopplingen loggas'
);

select tests.authenticate_as('kid');
select results_eq(
  $$ select member_id from public.children $$,
  array[tests.id('member:managed_a')],
  'det kopplade barnet ser bara sin egen barnrad'
);
select is_empty($$ select 1 from public.audit_log $$, 'det kopplade barnet ser ingen audit log');
select is_empty($$ select 1 from public.household_invitations $$, 'det kopplade barnet ser inga inbjudningar');

-- ---------------------------------------------------------------- barn utan befintlig profil
select tests.authenticate_as('owner_a');
select set_config('tests.token_child',
  (select token from public.create_invitation(tests.id('household:a'), 'child')), true);
select tests.authenticate_as('kid2');
select lives_ok(
  format('select public.accept_invitation(%L)', current_setting('tests.token_child')),
  'ett barn kan gå med via en barninbjudan'
);
select tests.clear_authentication();
select results_eq(
  format($$ select m.role::text || '|' || c.can_view_allowance::text
            from public.household_members m join public.children c on c.member_id = m.id
            where m.user_id = %L $$, tests.id('user:kid2')),
  array['child|false'],
  'barnet får rollen child och standardbehörigheter (ekonomi av)'
);

-- Uppskjutna constraint-triggers körs annars aldrig eftersom testet rullas tillbaka.
-- Tvinga fram dem här så att alla ändringar ovan även klarar commit-kontrollerna.
select lives_ok($$ set constraints all immediate $$, 'alla uppskjutna kontroller (D9, barnkonsistens) håller');

select * from finish();
rollback;
