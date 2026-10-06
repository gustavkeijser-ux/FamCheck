# Datamodell – framtida moduler (översiktlig design)

> Status: **Skiss.** Den här filen implementeras **inte** i M1. Syftet är att
> visa att kärnmodellen och RLS-strategin håller för kommande moduler. Varje
> modul får en detaljerad design i sin egen milestone.

Gemensamt: `household_id NOT NULL` + sammansatt FK till personer
`(household_id, *_member_id)`. Belopp lagras som `*_minor bigint` (öre) +
`currency char(3)`.

## Ekonomi

### `financial_accounts`
`id, household_id, owner_member_id null, name, account_type, currency, source,
visibility, external_account_id null, bank_connection_id null,
opening_balance_minor, opening_balance_date, reported_balance_minor null,
reported_balance_at null, archived_at null, created_by, created_at, updated_at`

- `account_type`: text + check (`checking`, `savings`, `food`, `vacation`, `allowance`, `other`)
- `source`: text + check (`manual`, `csv`, `enable_banking`, …)
- `visibility public.resource_visibility`: `household` | `adults` | `private` (D10). `private` kräver `owner_member_id`. RLS: `finance.read` **och** `private.can_view_resource(...)`
- `unique (household_id, source, external_account_id) where external_account_id is not null`
- Saldot räknas fram i vyn `account_balances` (security invoker, alltså RLS-skyddad)

### `transactions`
`id, household_id, account_id, amount_minor, currency, transaction_date,
booking_status (pending|booked), description, merchant_name null,
category_id null, source, external_id null, import_batch_id null, created_by,
created_at, updated_at`

- Sammansatt FK `(household_id, account_id)`
- **Deduplicering:** `unique (account_id, source, external_id) where external_id is not null`
- CSV saknar id. `external_id` = hash av (datum, belopp, beskrivning, löpnummer
  för identiska rader samma dag) räknad vid import
- Utgift negativ, inkomst positiv
- `import_batches` (källa, fil, antal) gör det möjligt att ångra en import

### `income_sources`
`id, household_id, owner_member_id null (null = gemensam), name, amount_minor,
currency, frequency, next_payment_date, is_active, category_id null`

### `recurring_expenses` (fasta kostnader)
`id, household_id, name, amount_minor, currency, category_id, payment_day,
frequency, responsible_member_id null, scope (household|private),
owner_member_id null, is_active`

`frequency` (inkomster och kostnader): `once`, `weekly`, `monthly`, `quarterly`,
`yearly` + `interval int default 1`. Delas med rutinernas schemamodell där det går.

### Budget
- `budget_settings (household_id PK, period_type calendar_month|pay_cycle, cycle_start_day 1–28)`
- `budget_categories (id, household_id, name, color, icon, sort_order, rollover_mode none|positive|positive_and_negative, archived_at)`
- `budget_periods (id, household_id, start_date, end_date, closed_at null)` –
  explicita datumintervall, `exclusion constraint` mot överlapp. Skapas av en
  funktion utifrån inställningarna
- `budget_allocations (period_id, category_id, amount_minor)` – budgeterat belopp per period
- `budget_period_carryovers (period_id, category_id, carryover_minor)` – **bara
  för stängda perioder** (fryst rollover)
- Spenderat och kvar räknas fram. Rollover räknas av `packages/domain`
  (`computeRollover`) och av en SQL-funktion med samma tester (paritetstest)

Rollover, exempel som ska bli enhetstester:
| Budget | Utfall | Läge | Nästa period |
|---|---|---|---|
| 1 500 | 1 000 | positive | 2 000 |
| 1 500 | 1 900 | positive_and_negative | 1 100 |
| 1 500 | 1 900 | positive | 1 500 |
| 1 500 | 1 000 | none | 1 500 |

### Sparande
- `savings_goals (id, household_id, owner_member_id null, scope, name, target_amount_minor, target_date null, monthly_target_minor null, status active|paused|completed|archived, icon, linked_account_id null)`
- `savings_contributions (id, goal_id, household_id, amount_minor, contributed_on, created_by)`
- Sparat belopp räknas fram. Prognosen är en ren funktion i `packages/domain`

### Veckopeng
- `allowances (id, household_id, child_member_id, amount_minor, frequency, next_payment_date, account_id null, is_active)`

## Kalender
- `calendar_events (id, household_id, title, description, starts_at, ends_at, all_day, location, category, responsible_member_id null, visible_to_children bool, recurrence_rule null, created_by)`
- `calendar_event_participants (event_id, household_id, member_id)` – tomt = hela hushållet
- `calendar_event_exceptions` – när återkommande händelser införs
- Heldagar tolkas i hushållets tidszon

## Uppgifter
- `tasks (id, household_id, title, description, due_at null, assignee_member_id null, related_child_member_id null, status todo|done|cancelled, priority low|normal|high, completed_at, completed_by_member_id)`

## Rutiner
- `routines (id, household_id, member_id null, name, schedule_type daily|weekdays|weekly|custom, by_weekday smallint[] null, interval int, time_of_day null, starts_on, ends_on null, is_active)`
- `routine_steps (id, routine_id, household_id, title, sort_order)`
- `routine_runs (id, routine_id, household_id, member_id, occurs_on date, completed_at null)` + `routine_step_completions`
- Genomföranden sparas separat från mallen, precis som specifikationen kräver

## Notiser
- `devices (id, user_id, expo_push_token unique, platform, app_version, last_seen_at, disabled_at)` – användarens, inte hushållets
- `notification_preferences (user_id, household_id null, category, enabled)` – `category`: `budget`, `calendar`, `routines`, `tasks`, `children`, `invitations`
- Utskick: `pg_cron` → Edge Function → Expo Push API. Kvitton sparas för att
  rensa ogiltiga tokens

## Open Banking (Enable Banking)
- `bank_connections (id, household_id, provider, provider_session_id, status, consent_expires_at, created_by)` – tokens och nycklar finns **inte** i tabellen. Leverantörens privata nyckel finns bara som Edge Function-secret. Eventuella sessionshemligheter lagras i Supabase Vault
- Flöde: app → Edge Function `bank-connect` → Enable Banking → bankens
  autentisering → callback till Edge Function → synkjobb som skriver till
  `financial_accounts`/`transactions` med `source = 'enable_banking'`

## Abonnemang
- `household_subscriptions (household_id, provider, product_id, entitlement, status, current_period_end, original_transaction_id)` – skrivs bara av en webhook-Edge Function (RevenueCat). Läses via `subscription.manage`/`household.read`
