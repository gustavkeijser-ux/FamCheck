# Beslut som behövs före implementation

Förslaget gäller som antagande tills du har svarat. Svaren förs in här och i berörd ADR.

## Behöver beslut före M1

| # | Fråga | Förslag |
|---|---|---|
| D1 | Godkänner du att `children` är en **tilläggstabell** till `household_members` (gemensam person-id), i stället för en fristående tabell? | Ja (T1, ADR-0003) |
| D2 | Ska **owner kunna läsa andra medlemmars privata konton**? | Nej – integriteten går före (T3) |
| D3 | Ska **adult kunna bjuda in** medlemmar som standard? | Nej som standard. Ni två blir båda owner (T4) |
| D4 | `owner_user_id` → `owner_member_id`, och `current_balance`/`current_amount` räknas fram i stället för att lagras? | Ja (A1–A3) |
| D5 | Monorepo med **pnpm** workspaces? | Ja (ADR-0001) |
| D6 | Supabase-region **Stockholm (`eu-north-1`)**? | Ja |
| D7 | Standardvärden för barnbehörigheter: kalender/uppgifter på, all ekonomi av? | Ja (ROLES_AND_PERMISSIONS §3) |
| D8 | Lagringstid för audit-loggen: 24 mån (raderade hushåll: 90 dagar)? | Ja, kan ändras senare |

## Kan vänta

| # | Fråga | Behövs i |
|---|---|---|
| Q1 | Slutgiltigt app-namn och bundle id (`se.famcheck.app` är en platshållare) | Första EAS-bygget |
| Q2 | Affärsmodell: freemium/provperiod/pris | Abonnemangs-milestonen |
| Q3 | Domän för universal links och e-post | Före extern testning |
| Q4 | Vilken modul efter M1: ekonomi eller kalender/rutiner först? | Efter M1 |
| Q5 | Synk med extern kalender (Google/iCloud/skolans iCal) | Kalender-milestonen |
| Q6 | Juridik: personuppgiftsbiträdesavtal, integritetspolicy, barns data | Före lansering |
