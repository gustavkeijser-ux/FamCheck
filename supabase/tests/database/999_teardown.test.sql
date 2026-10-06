-- =============================================================================
-- Städar bort testhjälparna (schemat `tests`) efter körningen. Viktigt när
-- testerna körs mot staging (`supabase test db --linked`): inget testschema
-- med EXECUTE-rättigheter får finnas kvar i en delad miljö.
-- =============================================================================
begin;
select plan(1);
drop schema if exists tests cascade;
select hasnt_schema('tests', 'testschemat är borttaget');
select * from finish();
commit;
