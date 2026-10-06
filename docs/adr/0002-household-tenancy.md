# ADR-0002: Hushållet som tenant

**Status:** Accepterad (2026-10-06)

## Beslut
- Alla tabeller med gemensam data har `household_id uuid NOT NULL` med FK och index.
- Användar-id används bara för spårbarhet (`created_by`, `actor_user_id`), aldrig
  som ägare av gemensam data.
- Korsreferenser mellan tabeller använder sammansatt FK `(household_id, x_id)`,
  så att data från två hushåll aldrig kan blandas.
- En användare kan vara medlem i flera hushåll. Appens "aktiva hushåll" är bara
  ett UI-tillstånd, aldrig en behörighet.

## Konsekvenser
- Isoleringen garanteras av både RLS och FK-constraints.
- `household_id` finns på barntabeller (t.ex. `routine_steps`), vilket är en
  medveten denormalisering för enkel RLS och constraints.
