# ADR-0003: Medlem = person; `children` som tilläggstabell

**Status:** Accepterad (2026-10-06)

## Kontext
`managed_child` saknar inloggning men ska ha aktiviteter, rutiner, veckopeng och
sparmål, och ska senare kunna kopplas till ett konto utan att historiken förloras.
Kalenderdeltagare och ansvariga kan vara både vuxna och barn.

## Alternativ
1. Fristående `children`-tabell + `auth.users` för vuxna → polymorfa referenser
   överallt (antingen användare eller barn), och historiken måste flyttas när
   ett konto kopplas. **Avvisat.**
2. Separata tabeller `household_people` + `household_memberships` → två tabeller
   för nästan samma sak och fler joins. **Avvisat.**
3. **`household_members` = person i hushållet (valfritt `user_id`) + `children`
   som 1:1-tillägg för barnspecifik data.** **Valt.**

## Beslut
Alternativ 3. All domändata refererar `household_members.id`. Ett konto kopplas
genom att `user_id` sätts och `managed_child` blir `child`. Inga data flyttas.

## Konsekvenser
- Ett "medlemskap" kan sakna användare. Det dokumenteras och skyddas med checks.
- Avvikelse från specifikationen: `owner_user_id` → `owner_member_id`.
