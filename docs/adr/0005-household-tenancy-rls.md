# ADR-0005: Hushåll som tenant, behörighet via RLS

**Status:** Föreslagen

## Kontext
Appen ska stödja många separata hushåll. Klienten talar direkt med Postgres via
PostgREST; klientkod kan inte betraktas som en säkerhetsgräns.

## Beslut
- Alla tabeller med gemensam data har `household_id NOT NULL`.
- RLS aktiveras på alla tabeller i `public`; policys använder
  `private.is_household_member()` / `private.has_household_role()`
  (`SECURITY DEFINER`, `search_path = ''`) för att undvika rekursion.
- Tillståndsändrande flöden med flera steg (skapa hushåll, inbjudningar, rollbyte,
  utträde) körs som RPC/Edge Functions.
- Varje policy täcks av pgTAP-tester med minst två hushåll och flera roller.
- CI fallerar om någon tabell i `public` saknar RLS.

## Konsekvenser
- Säker multi-tenancy från första migreringen.
- Lite mer arbete per tabell, men följer ett fast mönster.
