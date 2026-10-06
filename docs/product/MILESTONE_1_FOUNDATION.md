# Milestone 1 – Foundation

> Status: **Klar 2026-10-06.** Se [MILESTONE_1_REPORT.md](MILESTONE_1_REPORT.md). Inget UI utöver det som behövs för
> att verifiera inloggningen. Inga ekonomi-, kalender- eller rutinfunktioner.

## Mål

Ett monorepo där:
- en Expo-app startar på iOS och Android, är typad och testad, och har säker miljöhantering
- databasen har kärnschemat med RLS, och alla behörighetsregler är bevisade med automatiska tester
- en användare kan logga in med en e-postkod och få en session
- CI stoppar varje ändring som bryter typer, tester, RLS eller läcker hemligheter

## Tickets

Varje ticket görs i ordning: planera → implementera → validera → testa → dokumentera.

| # | Ticket | Acceptanskriterier |
|---|---|---|
| **M1-01** | **Monorepo-skelett**: pnpm workspaces, `packages/config` (tsconfig strict, ESLint, Prettier), `.nvmrc`, rotskript (`lint`, `typecheck`, `test`) | `pnpm install && pnpm lint && pnpm typecheck` grönt på ren checkout |
| **M1-02** | **CI-grund** (GitHub Actions): install, lint, typecheck, enhetstester, sökning efter hemligheter | Workflow grönt. En medvetet inlagd `service_role`-sträng får CI att fallera (testas en gång) |
| **M1-03** | **Expo-app** i `apps/mobile`: senaste SDK, Expo Router, TypeScript strict, jest-expo, i18n-grund (sv), en enda platshållarskärm | `expo-doctor` utan fel, `tsc` grönt, ett enhetstest körs. Appen startar i dev build/simulator |
| **M1-04** | **Miljöstrategi**: `app.config.ts` per `EXPO_PUBLIC_APP_ENV`, `env.ts` med zod, `eas.json` (development/preview/production), `.env.example`, separata bundle id:n | Appen vägrar starta med ett tydligt fel om en variabel saknas (enhetstest). Dokumenterat i ENVIRONMENTS.md |
| **M1-05** | **Supabase lokalt**: `supabase init`, `config.toml` (auth: OTP, manual linking på, providers via `env()` men avstängda), `seed.sql` | `supabase start` + `supabase db reset` fungerar lokalt och i CI |
| **M1-06** | **Migrering 1 – kärnschema**: extensions (`pgcrypto`, `citext`), schemat `private`, enums, de sex tabellerna, constraints, index, `updated_at`-triggers, profil-trigger vid registrering | `db reset` grönt. Schemat stämmer med DATA_MODEL_CORE |
| **M1-07** | **Migrering 2 – behörighet & RLS**: `private.role_permissions` + seed, `household_ids_with`, `my_member_ids`, RLS på alla tabeller, tabell- och kolumnrättigheter, `private.write_audit` | Metatester gröna: RLS påslaget överallt, `anon` saknar åtkomst, `search_path` satt |
| **M1-08** | **Migrering 3 – RPC:er**: hushåll, barn, inbjudningar, roller, lämna/ta bort, med audit | Varje RPC har minst ett lyckat test och ett nekat test |
| **M1-09** | **RLS-testsvit (pgTAP)**: testpersoner A/B/multi/outsider/anon, matris SELECT/INSERT/UPDATE/DELETE per tabell och roll, flödestester för inbjudningar och sista owner | `supabase test db` grönt lokalt och i CI. Matrisen är dokumenterad i RLS_STRATEGY |
| **M1-10** | **Typgenerering**: `supabase gen types` → `packages/types`, kontroll av typdrift i CI. Zod-scheman för RPC-argument i `packages/validation` | CI fallerar om migreringar och typer inte stämmer överens |
| **M1-11** | **Supabase-klient i appen**: typad singleton, krypterad sessionslagring, auto-refresh via AppState, TanStack Query-provider | Enhetstester för lagringsadaptern och felhanteringen |
| **M1-12** | **Auth-grund**: `features/auth` (service + hooks + sessionprovider), e-post-OTP, utloggning, routeskydd (auth → onboarding → app), *minimala oformgivna* skärmar för OTP. Providers för Apple/Google/FB/MS abstraherade men inte kopplade | Inloggning med kod fungerar mot den lokala stacken (manuellt verifierat + enhetstester av logiken). Utloggning tömmer cachen |
| **M1-13** | **CI – databasjobb**: Supabase CLI i Actions, `db reset`, `test db`, `db lint`, typdrift | Grönt på PR. Rött om RLS saknas på en ny tabell |
| **M1-14** | **Dokumentation & sammanfattning**: uppdaterade docs, ADR:er ändrade till "Accepterad", rapport: vad som skapats, beslut, risker, nästa ticket | Sammanfattningen levererad. **Stopp** |

## Definition of Done för M1

- [ ] Alla acceptanskriterier ovan uppfyllda
- [ ] CI grönt på `main`
- [ ] Inga `any` i egen kod (ESLint-regel `no-explicit-any: error`)
- [ ] Inga hemligheter, hårdkodade användar-id:n eller hushålls-id:n i koden
- [ ] Varje tabell har RLS och tester för SELECT/INSERT/UPDATE/DELETE per relevant roll
- [ ] Dokumentation och ADR:er uppdaterade
- [ ] Sammanfattning med risker och förslag på nästa ticket

## Utanför M1 (kandidater till nästa tickets)

1. Inloggning med Apple + Google (native), kräver utvecklarkonton
2. Onboarding-UI: skapa hushåll / gå med via inbjudan / lägga till barn
3. `delete-account` (Edge Function) + radering av hushåll i appen
4. Staging-projekt i Supabase + EAS-byggen
5. Facebook + Microsoft + manuell länkning av identiteter
6. Notisgrund (devices, preferences)
7. Ekonomimodulen, del 1 (konton, transaktioner, synlighet)

## Förutsättningar från dig

- Godkännande av arkitekturen och svar på frågorna i [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md)
- M1 kräver **inga** externa konton. Allt körs lokalt och i GitHub Actions
- För staging/produktion behövs senare: Supabase-organisation, Apple Developer,
  Google Play Console, Expo-konto, domän
