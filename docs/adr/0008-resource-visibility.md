# ADR-0008: Synlighet som generell säkerhetsprincip

**Status:** Accepterad (2026-10-06, beslut D10 och D2)

## Kontext
Ekonomiska konton, sparmål och senare även andra resurser ska kunna vara privata,
bara för vuxna eller för hela hushållet. Om det bara löses i UI:t kan ett barn
eller en annan vuxen läsa datan direkt via API:et.

## Beslut
- Enum `public.resource_visibility`: `private`, `adults`, `household`.
- Resurser med synlighet har `visibility` + `owner_member_id` (→ `household_members`).
- Funktionen `private.can_view_resource(household_id, visibility, owner_member_id)`
  är den enda tolkningen av nivåerna:
  - `private`: bara den aktiva medlem som äger resursen. **Inte heller owner** (D2).
  - `adults`: aktiva medlemmar med rollen owner eller adult.
  - `household`: alla aktiva medlemmar.
- En RLS-policy kombinerar alltid synligheten med en förmåga för resurstypen,
  t.ex. `finance.read AND can_view_resource(...)`. Barn saknar `finance.*` och
  ser därför aldrig ekonomi med nivån `household`. Barnets egna poster nås via
  separata, snäva policyer styrda av barnbehörigheterna.
- Funktionen är testad i `supabase/tests/database/080_visibility.test.sql` innan
  någon tabell använder den.

## Konsekvenser
- En ny resurstyp får synlighet genom att återanvända funktionen, inte genom egna regler.
- Transaktioner ärver kontots synlighet (de dupliceras inte).
