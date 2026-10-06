# Arkitektur

> Status: **Förslag** – väntar på godkännande innan implementation av Fas 1.

## 1. Grundprincip: hushållet är centralt

```
auth.users (Supabase Auth)
   └─ profiles            (1:1, användarens egna uppgifter)
        └─ household_members   (medlemskap + roll)
             └─ households     (tenant – äger all gemensam data)
                  ├─ calendar_events, tasks, routines …
                  └─ accounts, budgets, transactions, savings_goals …
```

- **Hushållet är tenant-gränsen.** All gemensam data har en `household_id NOT NULL`.
- Data knyts **aldrig enbart** till en användare om den är gemensam. Användaren
  förekommer som *metadata* (`created_by`, `assigned_to`, `owner_member_id`),
  inte som ägare av raden.
- En användare kan vara medlem i flera hushåll (t.ex. separerade föräldrar,
  framtida delad vårdnad). Klienten har ett *aktivt hushåll* i taget.
- Behörighet avgörs i databasen med **Row Level Security (RLS)** – aldrig enbart
  i klienten.

### 1.1 Viktigt arkitekturbeslut: *person* ≠ *användare*

Barn (och ibland en vuxen) i familjen har ofta inget eget konto, men de måste
kunna ha aktiviteter, rutiner, uppgifter och veckopeng. Därför separeras:

| Begrepp | Tabell | Har inloggning? |
|---|---|---|
| Användare | `auth.users` + `profiles` | Ja |
| Hushållsmedlem | `household_members` | Valfritt (`user_id` kan vara `NULL`) |

En hushållsmedlem är alltså en *person i familjen*. Den kan senare kopplas till
ett konto (t.ex. när ett barn får egen telefon) utan att historik flyttas.
Alla domäntabeller refererar `household_members.id`, inte `auth.users.id`, när
det handlar om *vem något gäller*. Se [ADR-0003](adr/0003-person-vs-user.md).

## 2. Teknisk stack

| Område | Val | Kommentar |
|---|---|---|
| App | React Native + Expo (managed, senaste SDK) | Dev builds, inte Expo Go, för push & native moduler |
| Språk | TypeScript `strict` | |
| Navigation | Expo Router | Filbaserad, deep links för inbjudningar |
| Serverstate | TanStack Query | Cache, retries, optimistiska uppdateringar |
| Klientstate | Zustand (minimalt) | Aktivt hushåll, UI-state |
| Formulär/validering | react-hook-form + zod | Samma zod-scheman för indata |
| Backend | Supabase: Postgres, Auth, Storage, Edge Functions (Deno) | EU-region |
| Schemalagda jobb | `pg_cron` + Edge Functions | Påminnelser, återkommande transaktioner |
| Push | Expo Notifications + Expo Push Service | Tokens per enhet |
| i18n | i18next + expo-localization | Svenska först, engelska förberett |
| Test | Jest + React Native Testing Library; pgTAP för RLS | |
| Lint/format | ESLint + Prettier, `tsc --noEmit` | |
| CI | GitHub Actions | Lint, typecheck, test, DB-tester |
| Build/release | EAS Build + EAS Submit + EAS Update | |
| Felrapportering | Sentry (förslag) | Kräver PII-scrubbing |
| Pakethanterare | npm | Se [ADR-0001](adr/0001-tech-stack.md) |

## 3. Kodstruktur (förslag)

Ett repo, en app, Supabase-projektet versionshanteras bredvid:

```
/
├─ app/                      # Expo Router – endast routes/layouts, tunna filer
│  ├─ (auth)/                # inloggning, registrering
│  ├─ (app)/                 # inloggat läge, kräver aktivt hushåll
│  └─ invite/[token].tsx     # deep link för inbjudan
├─ src/
│  ├─ features/              # en mapp per domän – modulär utveckling
│  │  ├─ auth/
│  │  ├─ household/
│  │  ├─ calendar/
│  │  ├─ tasks/
│  │  ├─ routines/
│  │  ├─ budget/
│  │  ├─ savings/
│  │  └─ notifications/
│  │     ├─ api/             # Supabase-anrop + TanStack Query-hooks
│  │     ├─ components/
│  │     ├─ screens/
│  │     ├─ schemas.ts       # zod
│  │     └─ index.ts         # publikt API för featuren
│  ├─ shared/                # UI-komponenter, hooks, utils (pengar, datum)
│  ├─ lib/                   # supabase-klient, query-klient, i18n, logger
│  └─ types/database.ts      # GENERERAD från Supabase – redigeras inte för hand
├─ supabase/
│  ├─ migrations/            # SQL-migreringar – enda sättet att ändra schemat
│  ├─ functions/             # Edge Functions
│  ├─ tests/                 # pgTAP (RLS-tester)
│  └─ seed.sql               # endast lokal utveckling
└─ docs/
```

Regler:
- En feature importerar bara andra features via deras `index.ts`.
- Inga Supabase-anrop direkt i komponenter – alltid via `features/*/api`.
- Databastyper genereras (`supabase gen types`) och checkas in; CI kontrollerar
  att de är i synk med migreringarna.

## 4. Säkerhet

- **RLS på alla tabeller i `public`**, utan undantag. En CI-kontroll fallerar om
  en tabell saknar RLS.
- Behörighetskontroll via `SECURITY DEFINER`-hjälpfunktioner i ett separat
  schema (`private.is_household_member(hh uuid)`, `private.has_household_role(hh, roles[])`)
  för att undvika rekursiv RLS på `household_members`.
- Känsliga flöden (skapa hushåll, inbjudningar, ta bort konto, byta ägare) körs
  som Postgres-funktioner (RPC) eller Edge Functions, inte som fria inserts.
- `service_role`-nyckeln finns **endast** i Edge Functions, aldrig i appen.
- Inbjudningstokens lagras **hashade**, har utgångstid och är engångs.
- Sessioner lagras i `expo-secure-store` (Keychain/Keystore).
- Varje RLS-policy ska ha pgTAP-tester: medlem i A kan inte läsa/skriva i B.

## 5. Data & domänprinciper

- **Pengar:** heltal i minsta enhet (`bigint`, öre) + `currency char(3)` (default `SEK`).
  Aldrig flyttal. Se [ADR-0004](adr/0004-money-and-time.md).
- **Tid:** `timestamptz` för tidpunkter, `date` för heldagar/budgetperioder.
  Hushållet har en tidszon (default `Europe/Stockholm`). Återkommande händelser
  lagras som RRULE (RFC 5545) + undantag och expanderas vid läsning.
- **Spårbarhet:** `created_at`, `updated_at`, `created_by` på alla domäntabeller.
- **Synlighet inom hushållet:** vissa ekonomiska data kan vara privata för en
  vuxen (eget konto) men ändå höra till hushållet. Modelleras med
  `visibility` (`household` | `private`) + `owner_member_id`, och hanteras i RLS.
  *Kräver beslut – se OPEN_QUESTIONS.*
- **Radering:** hård radering av användare (krav från App Store/Google Play och
  GDPR). Hushållsdata som skapats av en raderad användare behålls, `created_by`
  sätts till `NULL`.

## 6. Online-först, inte offline-först

Första versionerna är **online-först** med TanStack Query-cache (persisterad
lokalt för snabb start och läsning offline). Full offline-synk med
konfliktlösning är dyr och skjuts upp tills behovet är bevisat.
Se [ADR-0002](adr/0002-online-first.md).

## 7. Miljöer

| Miljö | Supabase | App |
|---|---|---|
| local | `supabase start` (Docker) | dev build mot lokal stack |
| staging | eget Supabase-projekt (EU) | EAS-kanal `preview` |
| production | eget Supabase-projekt (EU) | EAS-kanal `production` |

Migreringar appliceras via CI från `main` → staging, och manuellt godkänt → production.

## 8. Kommersiell beredskap (designas in, byggs senare)

- **Prenumeration knyts till hushållet**, inte till användaren (en betalar, alla
  i hushållet får tillgång). In-app-köp via App Store/Google Play krävs för
  digitala tjänster; RevenueCat föreslås som abstraktion.
- **GDPR:** EU-region, personuppgiftsbiträdesavtal, integritetspolicy, export och
  radering av data, särskild hänsyn till barns uppgifter (dataminimering).
- **Bankintegration (PSD2/open banking)** kräver licensierad aggregator (t.ex.
  Tink, Enable Banking). Transaktionsmodellen förbereds med `source` och
  `external_id` men integrationen byggs inte nu.
