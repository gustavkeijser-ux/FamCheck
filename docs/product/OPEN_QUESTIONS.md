# Beslut och öppna frågor

## Beslutade (2026-10-06)

| # | Beslut |
|---|---|
| D1 | `children` är en tilläggstabell till `household_members` ([ADR-0003](../adr/0003-member-as-person.md)). |
| D2 | Owner kan **inte** läsa andra vuxnas privata konton. Administrativ behörighet ger inte rätt att läsa privat ekonomi. |
| D3 | Adult kan inte bjuda in som standard, owner kan. Båda vuxna i första hushållet kan vara owner. Individuella förmågor (t.ex. `members.invite`) ska kunna ges senare. |
| D4 | `owner_member_id`. `current_balance`, `current_amount`, `spent` och `remaining` lagras inte när de kan räknas fram. Undantag: saldo som banken rapporterar och låst rollover. |
| D5 | pnpm. |
| D6 | Supabase `eu-north-1` (Stockholm). Finns regionen inte när projektet skapas: stoppa och dokumentera vilka EU-regioner som finns innan en annan väljs. |
| D7 | Barn: kalender, uppgifter/rutiner och familjeaktiviteter där barnet deltar är på. All ekonomi är av och explicit opt-in per barn. |
| D8 | Audit-loggen sparas i 24 månader. Raderade hushåll: högst 90 dagar, minimerat och anonymiserat, aldrig tokens, hemligheter eller onödiga personuppgifter. |
| D9 | Flera owners är tillåtna, men alltid minst en. Den sista ownern kan inte lämna, degradera sig själv, tas bort eller radera sitt konto utan att ägarskapet först förts över eller hushållet raderats via det uttryckliga flödet. |
| D10 | Synlighet (`private`/`adults`/`household`) genomdrivs alltid av RLS ([ADR-0008](../adr/0008-resource-visibility.md)). |

## Öppna frågor

| # | Fråga | Behövs i |
|---|---|---|
| Q1 | Slutgiltigt app-namn och bundle id (`se.famcheck.app` är en platshållare) | Första EAS-bygget (M2) |
| Q2 | Affärsmodell: freemium, provperiod, pris | Abonnemangs-milestonen |
| Q3 | Domän för universal links och avsändaradress för e-post | Före extern testning |
| Q4 | Vilken modul efter M2: ekonomi eller kalender/rutiner? | Efter M2 |
| Q5 | Synk med extern kalender (Google/iCloud/skolans iCal) | Kalender-milestonen |
| Q6 | Juridik: personuppgiftsbiträdesavtal, integritetspolicy, barns data | Före lansering |
| Q7 | Ska en användare som lämnat ett hushåll kunna gå med igen som barn (eller tvärtom)? I dag nekas det (`invitation_role_conflict`). | Vid behov |
| Q8 | Hur ska ett barn som blir vuxen hanteras (barnroll → vuxenroll)? Blockeras i M1. | Senare |
