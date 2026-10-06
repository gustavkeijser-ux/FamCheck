# Miljöstrategi

> Status: **Förslag – väntar på godkännande.**

## Miljöer

| Miljö | Supabase | App (EAS) | Bundle id / package | Data |
|---|---|---|---|---|
| `local` | `supabase start` (Docker) | dev client, `APP_ENV=development` | `se.famcheck.app.dev` | `seed.sql` |
| `staging` | Eget Supabase-projekt, region `eu-north-1` (Stockholm) | profil `preview`, kanal `preview` | `se.famcheck.app.preview` | Testdata, aldrig riktig data |
| `production` | Eget Supabase-projekt, `eu-north-1` | profil `production`, kanal `production` | `se.famcheck.app` | Riktig data |

Separata bundle id:n gör att alla tre varianterna kan ligga installerade
samtidigt på samma telefon. Bundle id är en platshållare tills namnet är bestämt.

## Variabler

| Variabel | Var | Hemlig? |
|---|---|---|
| `APP_ENV` | EAS / lokal `.env` | Nej |
| `EXPO_PUBLIC_SUPABASE_URL` | EAS env / `.env` | Nej |
| `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | EAS env / `.env` | Nej (publik, skyddas av RLS) |
| `SUPABASE_SECRET_KEY` (service role) | **Bara** Edge Function-secrets och CI-secrets | **Ja** |
| OAuth-hemligheter (Apple/Google/FB/MS) | Supabase Auth-inställningar, `config.toml` via `env()` lokalt | **Ja** |
| `SENTRY_AUTH_TOKEN` | EAS secret | Ja |
| `ENABLE_BANKING_*` (framtid) | Bara Edge Function-secrets | Ja |

Regler:
- Allt med prefixet `EXPO_PUBLIC_` byggs in i appen och är därför **publikt**.
- `apps/mobile/src/lib/env.ts` validerar variablerna med zod när appen startar
  och kraschar med ett tydligt fel om något saknas eller är felaktigt.
- CI söker igenom `apps/` och `packages/` efter `service_role`, `sb_secret_`
  och JWT-liknande strängar och fallerar om något hittas.
- `.env` checkas aldrig in. `.env.example` dokumenterar alla nycklar.

## Databasändringar

1. Migreringen skrivs lokalt (`supabase migration new`) och testas med
   `supabase db reset` + `supabase test db`.
2. PR → CI kör alla migreringar från en tom databas + pgTAP + typdrift.
3. Merge till `main` → CI applicerar på **staging** (`supabase db push`).
4. Produktion: manuellt godkänd GitHub-environment → `supabase db push`.
   Ingen manuell SQL i produktion, någonsin.
5. Migreringar ska vara framåtkompatibla med den app-version som redan är ute
   (expand → migrate → contract), eftersom gamla appversioner lever kvar länge.

## App-releaser

- EAS Build för binärer. EAS Update (OTA) bara för JS-ändringar, per kanal.
- `runtimeVersion` med policyn `fingerprint`, så att en OTA-uppdatering aldrig
  hamnar i en binär som den inte är kompatibel med.
