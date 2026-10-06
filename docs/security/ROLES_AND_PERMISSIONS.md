# Roller och behörigheter

> Status: **Godkänd 2026-10-06** (beslut D1–D10 i [OPEN_QUESTIONS](../product/OPEN_QUESTIONS.md)). Implementerad i Milestone 1.

## 0. Beslut (2026-10-06)

| # | Beslut |
|---|---|
| D2 | Owner kan **inte** läsa andra vuxnas privata data. Administrativ behörighet ≠ läsrätt till privat ekonomi. |
| D3 | Adult kan inte bjuda in som standard. Owner kan. Flera owners är tillåtna. Individuella tilldelningar (t.ex. `members.invite` till en viss adult) är en förberedd utbyggnadspunkt i `private.household_ids_with()`. |
| D7 | Barn: kalender, familjeaktiviteter och uppgifter/rutiner på; all ekonomi av och opt-in per barn. |
| D9 | Minst en aktiv owner per hushåll. Blockeras i RPC:er, i en uppskjuten constraint-trigger och för kontoradering via `ON DELETE RESTRICT`. |
| D10 | Synlighet (`private`/`adults`/`household`) är en databasregel via `private.can_view_resource()`, se [ADR-0008](../adr/0008-resource-visibility.md). |

## 1. Princip

1. **Behörigheten avgörs i databasen.** UI:t döljer bara saker. Det skyddar ingenting.
2. **Behörighet bygger på förmågor (capabilities), inte på roller i policyerna.**
   RLS-policyer och RPC:er frågar "har anroparen `finance.read` i det här
   hushållet?", inte "är anroparen adult?". Kopplingen roll → förmåga finns på
   **ett enda ställe** (`private.role_permissions`). Ändrade rättigheter blir då
   en dataändring i en migrering, inte en omskrivning av femtio policyer.
3. **Neka som standard.** Saknas en förmåga är svaret nej. Nya tabeller saknar
   åtkomst tills någon uttryckligen öppnar den.
4. **Integritet går före roll.** `visibility = private` skyddar även mot owner.
5. **Barn får aldrig ekonomiförmågor via sin roll.** Det som ett barn får se
   (egen veckopeng, eget saldo, egna sparmål) styrs av barnbehörigheterna i
   `children` och gäller **bara barnets egna** poster.
6. **Inget är tillåtet för att klienten säger det.** Aktivt hushåll, roll och
   member-id hämtas alltid från `auth.uid()` och databasen, aldrig från indata.

## 2. Förmågor per roll (standard)

| Förmåga | owner | adult | child | managed_child |
|---|:-:|:-:|:-:|:-:|
| `household.read` (namn, inställningar) | ✅ | ✅ | ✅ | – |
| `household.update` | ✅ | ❌ | ❌ | – |
| `household.delete` | ✅ | ❌ | ❌ | – |
| `members.read` (namn, färg, roll) | ✅ | ✅ | ✅ | – |
| `members.invite` / återkalla inbjudan | ✅ | ⚙️ standard ❌ | ❌ | – |
| `members.remove` | ✅ | ❌ | ❌ | – |
| `members.manage_roles` | ✅ | ❌ | ❌ | – |
| `children.manage` (skapa barn, behörigheter, koppla konto) | ✅ | ✅ | ❌ | – |
| `audit.read` | ✅ | ❌ | ❌ | – |
| `subscription.manage` (framtid) | ✅ | ❌ | ❌ | – |
| `bank.manage` (framtid) | ✅ | ⚙️ | ❌ | – |
| `finance.read` | ✅ | ✅ | ❌ | – |
| `finance.write` (konton, transaktioner, budget, inkomster, kostnader) | ✅ | ✅ | ❌ | – |
| `savings.write` | ✅ | ✅ | ❌ | – |
| `calendar.read` | ✅ | ✅ | 🔸 | – |
| `calendar.write` | ✅ | ✅ | ❌ | – |
| `routines.write` / `tasks.write` | ✅ | ✅ | ❌ (🔸 bocka av egna) | – |

- ✅ ja · ❌ nej · ⚙️ kan ändras per hushåll (förberett, se §4) · 🔸 begränsat till egna/tillåtna poster via barnbehörigheter
- `managed_child` loggar aldrig in och har därför inga förmågor. Personen finns
  bara som data.

## 3. Barnets åtkomst ("egna poster")

| Data | Regel för `child` |
|---|---|
| Kalender | Egna aktiviteter om `can_view_calendar` (standard på) |
| Familjeaktiviteter | Händelser där barnet är deltagare om `can_view_family_events` (standard på) |
| Uppgifter och rutiner | Där barnet är ansvarig. Får bocka av om `can_use_tasks_and_routines` (standard på) |
| Veckopeng | Bara egen, om `can_view_allowance` |
| Saldo | Bara konton där `owner_member_id` = barnet, om `can_view_own_balance` |
| Sparmål | Bara där ägaren är barnet, om `can_view_savings_goals` |
| Vuxnas inkomster, transaktioner, budget, privata och gemensamma konton | **Aldrig.** Ingen policy ger barn läsrätt till dessa |

## 4. Förmågor som kan ändras per hushåll (förberett)

Specifikationen säger att "vissa owner-funktioner ska kunna reserveras för owner".
Modellen: `private.role_permissions` är standard. En senare tabell
`household_role_overrides (household_id, role, permission, granted)` kan
**ge eller ta bort** förmågor för `adult` i ett visst hushåll.

Begränsningar som gäller oavsett:
- `household.delete`, `members.manage_roles` och `subscription.manage` kan
  aldrig ges till någon annan än owner.
- Barnroller kan aldrig få `finance.*`.

I M1 införs bara standardmappningen. Overrides byggs när de behövs.

## 5. Regler för medlemskap

| Händelse | Regel |
|---|---|
| Skapa hushåll | Skaparen blir `owner` |
| Inbjudan | Som `adult` eller `child`. Owner blir man genom rollbyte efteråt |
| Rollbyte | Bara owner. Det måste alltid finnas ≥ 1 aktiv owner. Barnroll ↔ vuxenroll kräver ett eget flöde (förhindrar misstag) |
| Ta bort medlem | Owner kan ta bort alla utom den sista ownern |
| Lämna | Alla kan lämna. Den sista ownern måste först utse en ny owner eller radera hushållet |
| Koppla konto till barn | Inbjudan med `target_member_id`. När den accepteras sätts `user_id` och `managed_child` blir `child` |
| Flera hushåll | Tillåtet. Behörigheten gäller per hushåll |

## 6. Teknisk implementation (skiss)

```sql
-- Schemat 'private' exponeras INTE via API:et.
-- private.role_permissions(role member_role, permission text) – data, primärnyckel (role, permission)

-- Hushåll där anroparen har en viss förmåga. Räknas ut en gång per fråga.
create function private.household_ids_with(p_permission text)
returns setof uuid
language sql stable security definer set search_path = ''
as $$
  select m.household_id
  from public.household_members m
  join private.role_permissions rp on rp.role = m.role
  where m.user_id = (select auth.uid())
    and m.status = 'active'
    and rp.permission = p_permission
$$;

-- Anroparens egen medlem i ett visst hushåll (för "egna poster" och privata konton)
create function private.my_member_ids() returns setof uuid ...
```

Policymönster:

```sql
create policy households_select on public.households
  for select to authenticated
  using (id in (select private.household_ids_with('household.read')));
```

Se [RLS_STRATEGY.md](RLS_STRATEGY.md) för fullständig strategi och testning.
