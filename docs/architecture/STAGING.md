# Staging

> Status 2026-10-06: projektet finns och är verifierat i `eu-north-1` (D6). Migreringar
> deployas av CI. **Production-projekt ska inte skapas ännu.**

## Projekt

| Egenskap | Värde |
|---|---|
| Namn | `famvy-staging` |
| Ref | `dawzbqjnasbkllsstcky` |
| Region | `eu-north-1` (Stockholm) – verifierad via Supabase Management API |
| Postgres | 17 |
| URL | `https://dawzbqjnasbkllsstcky.supabase.co` |
| Organisation | `gustavkeijser-ux's Org`, **gratisplan** (se risker) |
| Publishable key | `sb_publishable_pEGx…` (publik, skyddas av RLS) |

Projektet fanns redan, tomt (inga tabeller och inga migreringar), när M2-01
påbörjades, och används som staging. Gratisplanen tillåter två aktiva projekt och
båda platserna är upptagna, så ett nytt projekt kunde inte skapas utan beslut.

## Deploy-flöde (GitHub Actions, jobbet `deploy-staging`)

Körs bara när `quality` **och** `database` är gröna, vid push till `main` eller
manuellt (`workflow_dispatch` med `deploy_staging = true`).

1. Kontrollerar att alla variabler finns och att ref:en är stagings
2. `supabase link` → `supabase db push --dry-run` → `supabase db push`
3. `supabase config push` (auth/API enligt `config.toml` + `[remotes.staging]`)
4. `supabase db lint --linked` (plpgsql_check, fallerar på varningar)
5. `supabase test db --linked` – hela pgTAP-sviten mot staging, inklusive
   metatesterna för privilegier (anon/authenticated, TRUNCATE, kolumnrättigheter,
   RPC-vitlista, search_path). `999_teardown` tar bort testschemat efteråt.
6. `scripts/check-advisors.mjs` – Supabase Security Advisor, fallerar på ERROR/WARN
7. Integrationstest mot staging. Engångskoden skapas via admin-API:t, så inga mejl
   skickas till påhittade adresser. Testanvändarna raderas efteråt.
8. `expo export` med preview-konfiguration + `scripts/check-bundle.mjs`: den byggda
   appbundeln söks igenom efter `sb_secret_`, service_role-JWT:er, testhjälpare och
   de faktiska hemliga värdena från CI

## Konfiguration i GitHub (miljön `staging`)

| Namn | Typ | Innehåll |
|---|---|---|
| `SUPABASE_ACCESS_TOKEN` | secret | Personlig åtkomsttoken (Supabase → Account → Access Tokens) |
| `SUPABASE_DB_PASSWORD` | secret | Stagings databaslösenord |
| `SUPABASE_SECRET_KEY` | secret | Stagings `sb_secret_…` – **endast** för integrationstestets admin-OTP |
| `SUPABASE_PROJECT_REF` | variable | `dawzbqjnasbkllsstcky` |
| `SUPABASE_URL` | variable | `https://dawzbqjnasbkllsstcky.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY` | variable | stagings `sb_publishable_…` |

Hemligheterna finns aldrig i repot, aldrig i `EXPO_PUBLIC_*` och aldrig i appen.

## Appen mot staging

EAS-profilen `preview` (`EXPO_PUBLIC_APP_ENV=preview`). `EXPO_PUBLIC_SUPABASE_URL`
och `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY` sätts som EAS Environment Variables för
miljön `preview`.

## Kända begränsningar

- **E-post:** staging använder Supabases inbyggda SMTP tills M2-06. Den skickar bara
  till organisationens medlemmar och har en mycket låg gräns per timme.
- **Gratisplan:** projektet pausas efter en veckas inaktivitet, ingen point-in-time-
  återställning och inga backups att lita på. Det är okej för staging, inte för production.
- Data i staging är alltid testdata.
