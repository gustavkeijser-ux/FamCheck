# RLS-strategi

> Status: **Godkänd 2026-10-06** (beslut D1–D10 i [OPEN_QUESTIONS](../product/OPEN_QUESTIONS.md)). Implementerad i Milestone 1.

## 1. Hotmodell

Appen pratar direkt med PostgREST med en publik nyckel. Vi utgår från att:

- vem som helst kan ta ut nyckeln ur appen och anropa API:et direkt
- en inloggad användare kan skicka valfria `household_id`, `member_id` eller filter
- ett barn med eget konto kan göra samma sak som en vuxen tekniskt sett kan göra
  med API:et

**Därför är RLS + kolumnrättigheter + RPC:er hela säkerhetsgränsen.** Appens kod
är det inte.

## 2. Försvar i flera lager

| Lager | Vad | Exempel |
|---|---|---|
| 1. Schema | `private` exponeras inte via API:et | Behörighetsfunktioner och `role_permissions` |
| 2. Tabellrättigheter | `anon` saknar alla rättigheter till hushållsdata. `authenticated` får bara de operationer som behövs | `audit_log`: ingen insert/update/delete |
| 3. Kolumnrättigheter | UPDATE tillåts bara på ofarliga kolumner | `household_members`: bara `display_name`, `color`, `avatar_path`, aldrig `role`/`status`/`user_id` |
| 4. RLS-policyer | Rader filtreras på förmåga + hushåll (+ ägare/synlighet) | Se §3 |
| 5. RPC:er | Flerstegsflöden och tillståndsändringar görs bara i `security definer`-funktioner som kontrollerar behörigheten själva | Inbjudningar, rollbyten, att skapa hushåll |
| 6. Constraints | Sammansatta FK:er `(household_id, member_id)` | En post kan aldrig peka på en person i ett annat hushåll |
| 7. Tester | pgTAP-matris + metatester i CI | §5 |

## 3. Policymönster

### 3.1 Vanliga hushållstabeller

```sql
alter table public.X enable row level security;
-- FORCE används inte: tabellägaren postgres har BYPASSRLS i Supabase, så FORCE
-- skulle inte göra någon skillnad. Skyddet gäller API-rollerna anon/authenticated.
revoke all on table public.X from anon, authenticated;   -- neka som standard (inkl. TRUNCATE)

create policy x_select on public.X for select to authenticated
  using (household_id in (select private.household_ids_with('calendar.read')));

create policy x_insert on public.X for insert to authenticated
  with check (household_id in (select private.household_ids_with('calendar.write')));

create policy x_update on public.X for update to authenticated
  using      (household_id in (select private.household_ids_with('calendar.write')))
  with check (household_id in (select private.household_ids_with('calendar.write')));
  -- with check förhindrar att en rad "flyttas" till ett annat hushåll

create policy x_delete on public.X for delete to authenticated
  using (household_id in (select private.household_ids_with('calendar.write')));
```

### 3.2 Ekonomi med synlighet (framtida, men utformad nu)

```sql
-- financial_accounts
using (
  household_id in (select private.household_ids_with('finance.read'))
  and (
    private.can_view_resource(household_id, visibility, owner_member_id)   -- D10
  )
)
```

- Transaktioner ärver kontots synlighet:
  `account_id in (select private.readable_account_ids())`. Synligheten
  dupliceras **inte** på transaktionerna.
- Barn har inte `finance.read` och träffas därför inte av någon av dessa policyer.
  Barnets egna saldon och sparmål läses via en egen, snäv policy, t.ex.
  `owner_member_id in (select private.my_child_member_ids_with('can_view_own_balance'))`.
  Den kan bara returnera poster som tillhör barnet självt.

### 3.3 Inbjudningar

- Ingen insert/update/delete via API:et. Allt går genom RPC:er.
- SELECT bara för `members.invite` i hushållet. `token_hash` kan inte läsas
  (kolumnrättighet).
- Den som tar emot en inbjudan har **ingen** läsrätt till tabellen. Hen anropar
  `preview_invitation(token)`, som returnerar ett minimum av information.

### 3.4 Funktionsregler

Alla `security definer`-funktioner ska:
- ha `set search_path = ''` och fullt kvalificerade namn
- ha `revoke execute ... from public, anon` och `grant` endast till `authenticated`
- hämta användaren med `auth.uid()`, aldrig från en parameter
- kasta fel med stabila felkoder (`P0001` + kod i `message`) som appen kan översätta

## 4. Prestanda

- `household_id in (select private.household_ids_with(...))` gör att mängden
  räknas ut **en gång per fråga** (initplan), inte en gång per rad.
- Index på `household_members(user_id) where status = 'active'` och på
  `household_id` i varje domäntabell.
- Undvik joins i policyer. Lägg dem i `security definer`-funktioner som
  returnerar id-mängder.
- Prestandatestas med seed-data (1 000 hushåll, 100 000 transaktioner) när
  ekonomimodulen byggs.

## 5. Testning (pgTAP, `supabase test db`)

### 5.1 Testpersoner (fixtures)

| Testperson | Beskrivning |
|---|---|
| `owner_a` | owner i hushåll A |
| `adult_a` | adult i hushåll A |
| `child_a` | child (eget konto) i A |
| `managed_child_a` | managed_child i A (ingen inloggning, bara data) |
| `owner_b` | owner i hushåll B |
| `outsider` | inloggad, ingen medlem någonstans |
| `anon` | ej inloggad |
| `multi` | adult i A **och** owner i B (kontroll av behörighet per hushåll) |

Inloggning simuleras med `set local role authenticated` +
`set local request.jwt.claims = '{"sub": "...", "role": "authenticated"}'`.

### 5.2 Matris (per tabell × roll × operation)

Exempel för `household_members`:

| | SELECT A | INSERT A | UPDATE A (name) | UPDATE A (role) | DELETE A | SELECT B |
|---|---|---|---|---|---|---|
| owner_a | ✅ | ❌ (RPC) | ✅ | ❌ (RPC) | ❌ (RPC) | ❌ 0 rader |
| adult_a | ✅ | ❌ | ✅ egen rad / barn | ❌ | ❌ | ❌ |
| child_a | ✅ (begränsade kolumner) | ❌ | ❌ | ❌ | ❌ | ❌ |
| outsider | ❌ 0 rader | ❌ | ❌ | ❌ | ❌ | ❌ |
| anon | ❌ fel (rättighet) | ❌ | ❌ | ❌ | ❌ | ❌ |

Varje tabell i M1 får en liknande matris i sin testfil. "❌ 0 rader" för SELECT
och "0 rader påverkade" för UPDATE/DELETE testas uttryckligen, eftersom RLS
filtrerar tyst i stället för att ge fel.

### 5.3 Flödestester för RPC:er

- Inbjudan: giltig, utgången, återkallad, redan använd, fel e-post, okänd token,
  ett barn försöker bjuda in, adult försöker bjuda in (standard nej), barnkoppling
  via `target_member_id`
- Den sista ownern kan inte lämna, degraderas eller tas bort
- Adult kan inte ta bort owner eller ändra roller
- `create_household` skapar exakt en owner + en audit-rad
- Inget RPC-anrop kan skapa en medlem i ett hushåll där anroparen saknar rätt

### 5.4 Metatester (skyddsnät)

- Alla tabeller i `public` har RLS påslaget (och `force`)
- `anon` har inga tabellrättigheter i `public`
- Alla `security definer`-funktioner har `search_path` satt
- Ingen funktion i `public` går att köra av `anon`, utom en uttrycklig vitlista
- `audit_log` saknar insert/update/delete för `authenticated`
- `supabase db lint` / Security Advisor ger inga varningar

### 5.5 Uppskjutna kontroller i tester

pgTAP-filerna rullas tillbaka, så uppskjutna constraint-triggers (D9, barn ↔
children-rad) körs annars aldrig. Därför avslutas varje testfil med
`SET CONSTRAINTS ALL IMMEDIATE`, och `090_integrity_triggers` testar triggarna
direkt. Två buggar hittades på det sättet i M1 och rättades före första deploy.

### 5.6 Integrationstest

`apps/mobile/src/features/auth/api/auth-service.integration.test.ts` kör mot den
lokala stacken via PostgREST och GoTrue: e-postkod (hämtas från Mailpit) → session
→ `create_household` → isolering mellan användare → inbjudan → utloggning.

### 5.7 Faktisk testmatris (M1)

Se [docs/product/MILESTONE_1_REPORT.md](../product/MILESTONE_1_REPORT.md#rls-testmatris).
