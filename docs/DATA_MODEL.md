# Datamodell – kärna (hushåll & medlemskap)

> Status: **Förslag**. Detta är designunderlag, inte en migrering. Den faktiska
> SQL:en skrivs i Fas 1 under `supabase/migrations/` tillsammans med pgTAP-tester.

## 1. Kärntabeller

### `profiles`
1:1 med `auth.users`. Endast användarens egna uppgifter.

| Kolumn | Typ | Not |
|---|---|---|
| `id` | `uuid` PK, FK → `auth.users.id` `on delete cascade` | |
| `display_name` | `text` | |
| `locale` | `text` default `'sv-SE'` | |
| `last_active_household_id` | `uuid` null, FK → `households` | Bekvämlighet, inte behörighet |
| `created_at`, `updated_at` | `timestamptz` | |

RLS: användaren läser/ändrar endast sin egen rad. Medhushållsmedlemmar ser
`display_name` via `household_members`, inte via `profiles`.

### `households`
Tenant. Allt gemensamt hänger här.

| Kolumn | Typ | Not |
|---|---|---|
| `id` | `uuid` PK | |
| `name` | `text` not null | |
| `timezone` | `text` default `'Europe/Stockholm'` | |
| `currency` | `char(3)` default `'SEK'` | |
| `created_by` | `uuid` null, FK → `auth.users` `on delete set null` | |
| `created_at`, `updated_at` | `timestamptz` | |

Skapas **endast** via RPC `create_household(name)` som atomiskt skapar hushållet
och en `owner`-medlem för anroparen.

### `household_members`
En *person* i hushållet – med eller utan konto.

| Kolumn | Typ | Not |
|---|---|---|
| `id` | `uuid` PK | Refereras av all domändata |
| `household_id` | `uuid` not null, FK → `households` `on delete cascade` | |
| `user_id` | `uuid` null, FK → `auth.users` `on delete set null` | `NULL` = person utan konto (t.ex. barn) |
| `role` | enum `member_role`: `owner`, `adult`, `child` | Se §2 |
| `display_name` | `text` not null | Namn i familjen ("Mamma", "Elsa") |
| `color` | `text` null | Färg i kalendern |
| `birth_date` | `date` null | Valfritt, endast om det behövs (dataminimering) |
| `status` | enum: `active`, `removed` | Behåller historik när någon lämnar |
| `created_at`, `updated_at` | `timestamptz` | |

Constraints:
- `unique (household_id, user_id)` där `user_id is not null`.
- Minst en aktiv `owner` per hushåll (säkras i RPC för rolländring/utträde).

### `household_invitations`

| Kolumn | Typ | Not |
|---|---|---|
| `id` | `uuid` PK | |
| `household_id` | `uuid` not null FK | |
| `member_id` | `uuid` null FK → `household_members` | Om inbjudan kopplar konto till befintlig person |
| `role` | `member_role` | |
| `email` | `citext` null | Valfritt – kan även delas som länk |
| `token_hash` | `text` not null unique | SHA-256; klartext visas en gång |
| `expires_at` | `timestamptz` not null | t.ex. 7 dagar |
| `accepted_at`, `revoked_at` | `timestamptz` null | |
| `created_by` | `uuid` FK | |

Accepteras via RPC/Edge Function `accept_invitation(token)` som verifierar hash,
utgång och engångsanvändning.

### `push_tokens`
| `id`, `user_id`, `expo_push_token` (unique), `platform`, `last_seen_at` |

## 2. Roller och rättigheter (förslag)

| Rättighet | owner | adult | child (med konto) |
|---|:-:|:-:|:-:|
| Läsa kalender, uppgifter, rutiner | ✅ | ✅ | ✅ (egna + delade) |
| Skapa/ändra kalender, uppgifter | ✅ | ✅ | Begränsat (bocka av egna) |
| Läsa ekonomi | ✅ | ✅ | ❌ (ev. egen veckopeng) |
| Ändra ekonomi | ✅ | ✅ | ❌ |
| Bjuda in / ta bort medlemmar | ✅ | ✅ (ej owner) | ❌ |
| Hushållsinställningar, prenumeration, radera hushåll | ✅ | ❌ | ❌ |

Implementeras som SQL-hjälpfunktioner:

```sql
-- Skissa, ej slutlig
create function private.is_household_member(hh uuid) returns boolean
  language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.household_members m
    where m.household_id = hh and m.user_id = (select auth.uid()) and m.status = 'active'
  );
$$;

create function private.has_household_role(hh uuid, roles public.member_role[])
  returns boolean ... -- samma mönster, med m.role = any(roles)
```

Mönster för en domäntabell:

```sql
alter table public.tasks enable row level security;

create policy tasks_select on public.tasks for select to authenticated
  using ((select private.is_household_member(household_id)));

create policy tasks_write on public.tasks for insert to authenticated
  with check ((select private.has_household_role(household_id, '{owner,adult}')));
```

(`(select …)`-wrappern gör att Postgres cachar resultatet per query – viktigt för prestanda.)

## 3. Konventioner för alla domäntabeller

- `id uuid primary key default gen_random_uuid()`
- `household_id uuid not null references households on delete cascade` + index
- `created_by uuid references auth.users on delete set null`
- `created_at timestamptz not null default now()`, `updated_at` via trigger
- Referenser till personer går till `household_members.id`
- Belopp: `amount_minor bigint not null`, `currency char(3) not null`
- Korsreferenser mellan domäntabeller måste tillhöra **samma hushåll**
  (säkras med sammansatta FK `(household_id, id)` eller trigger)

## 4. Domänmoduler – översikt (detaljeras per fas)

| Modul | Huvudtabeller (preliminärt) |
|---|---|
| Kalender & aktiviteter | `calendar_events` (rrule, all_day, starts_at, ends_at), `event_participants` (→ members), `event_exceptions` |
| Uppgifter | `tasks` (assignee_member_id, due_at, status), `task_lists` |
| Rutiner | `routines` (rrule, member), `routine_steps`, `routine_completions` |
| Budget & ekonomi | `financial_accounts` (visibility, owner_member_id), `categories`, `budgets`, `budget_lines`, `transactions` (source, external_id) |
| Sparande | `savings_goals`, `savings_contributions` |
| Planering | `notes`/`plans` – definieras senare |
| Kommersiellt | `household_subscriptions` (entitlement, provider, expires_at) |
