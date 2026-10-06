# Milestone 1 – Foundation: rapport

> Datum: 2026-10-06 · Gren: `claude/familjeapp-architecture-setup-nkvh3v`
> Status: **Klar – väntar på validering.** Inga produktfunktioner har byggts.

## 1. Vad som implementerats

| Ticket | Innehåll |
|---|---|
| M1-01 | pnpm-monorepo (`apps/`, `packages/`), TypeScript 6 strict, ESLint flat config (inga `any`, plattformsneutrala paket), Prettier |
| M1-02/13 | GitHub Actions: `quality` (hemligheter, format, lint, typer, enhetstester) och `database` (Supabase i Docker, migreringar från tom databas, plpgsql_check, pgTAP, typdrift, auth-integrationstest) |
| M1-03 | Expo SDK 57-app (`apps/mobile`), Expo Router, jest-expo, i18n (sv). JS-bundle byggs för iOS och Android |
| M1-04 | Miljöstrategi: `EXPO_PUBLIC_APP_ENV` styr bundle id/scheme och runtime, `eas.json`-profiler, zod-validerad `env.ts` som avvisar hemliga nycklar och service role-JWT:er |
| M1-05 | Lokal Supabase: neka som standard (`auto_expose_new_tables = false`), e-postkod (6 siffror, 10 min), manuell identity linking, Apple/Google/Facebook/Microsoft förberedda men avstängda |
| M1-06 | Kärnschema: `profiles`, `households`, `household_members`, `children`, `household_invitations`, `audit_log` |
| M1-07 | Förmågemodell (`private.role_permissions`) och behörighetsfunktioner, RLS och kolumnrättigheter på alla tabeller, `can_view_resource` (D10) |
| M1-08 | 12 RPC:er för känsliga operationer, med audit |
| M1-09 | 271 pgTAP-kontroller i 10 filer |
| M1-10 | Genererade databastyper + driftkontroll, paritet TS ↔ SQL för förmågor och enums |
| M1-11 | Typad Supabase-klient, sessionen krypterad (AES-nyckel i Keychain/Keystore) |
| M1-12 | `features/auth`: e-postkod, session, utloggning, routeskydd, minimala oformgivna skärmar |
| M1-14 | Dokumentation uppdaterad, ADR:er accepterade, ADR-0008 (synlighet) |

### RPC:er (alla `security definer`, `search_path = ''`, med audit)
`create_household`, `update_household`, `delete_household`, `create_child`,
`update_child_permissions`, `create_invitation`, `preview_invitation`,
`accept_invitation`, `revoke_invitation`, `change_member_role`, `remove_member`,
`leave_household`. Felkoder: [RPC_ERRORS.md](../security/RPC_ERRORS.md).

## 2. Migreringar

| Fil | Innehåll |
|---|---|
| `20261006120000_core_schema.sql` | Extensions, `private`-schema, enums (`member_role`, `member_status`, `resource_visibility`), sex tabeller med constraints och index, triggers (`updated_at`, profil vid registrering, barnkonsistens, **minst en owner (D9)**), RLS påslaget, standardrättigheter utan TRUNCATE |
| `20261006120100_permissions_and_rls.sql` | `private.role_permissions` (+ checks: barn aldrig ekonomi, owner-reserverade förmågor), `household_ids_with`, `my_member_ids`, `has_permission`, `my_membership`, `can_view_resource`, `write_audit`, policyer + tabell- och kolumnrättigheter |
| `20261006120200_household_functions.sql` | RPC:er, inbjudningslogik (256-bitars token, SHA-256, utgång, engångs, återkallelse), owner-skydd, `purge_audit_log` (D8) |

Migreringarna har **inte** applicerats någonstans utom lokalt och i CI. Två buggar
i uppskjutna triggers rättades i migrering 1 före första deploy (se §5).

## 3. Testresultat

| Svit | Resultat |
|---|---|
| pgTAP (`pnpm db:test`) | **271/271** i 10 filer |
| `supabase db lint` (plpgsql_check, public + private) | 0 varningar |
| Vitest – `@famcheck/utils` | 23/23 |
| Vitest – `@famcheck/domain` (inkl. paritet TS ↔ SQL) | 8/8 |
| Vitest – `@famcheck/validation` | 13/13 |
| jest-expo – `@famcheck/mobile` | 31/31 |
| Integration – auth mot lokal Supabase | 3/3 (kod via Mailpit → session → RPC → RLS → inbjudan → utloggning) |
| Typkontroll, lint, format, hemlighetssökning | Grönt |
| `expo export` iOS/Android | Bundlar byggs (1 352 moduler) |
| GitHub Actions | `quality` grön. `database`: se den senaste körningen på grenen |

pgTAP per fil: 000 setup 1 · 010 metatester 13 · 020 households/profiles 32 ·
030 members/children 37 · 040 invitations/audit 27 · 050 RPC hushåll/barn 39 ·
060 RPC inbjudningar 48 · 070 roller/D9 36 · 080 synlighet/D10 23 · 090 integritet 15.

## 4. RLS-testmatris

Testpersoner: **O** = owner_a, **A** = adult_a, **C** = child_a (eget konto),
**M** = multi (adult i A och owner i B), **B** = owner_b, **X** = outsider (inloggad, utan
hushåll), **anon**. "0" = RLS filtrerar bort raderna, "nekad" = behörighetsfel (42501).
Alla kolumner gäller hushåll A om inget annat anges.

### SELECT

| Tabell | O | A | C | M | B | X | anon |
|---|---|---|---|---|---|---|---|
| households | A | A | A | A+B | bara B | 0 | nekad |
| profiles | egen | egen | egen | egen | egen | egen | nekad |
| household_members | 5 (A) | 5 | 5 | 7 (A+B) | 2 (B) | 0 | nekad |
| children | 2 | 2 | **bara egen** | 2 | 0 | 0 | nekad |
| household_invitations | A:s | **0 (D3)** | 0 | bara B:s | bara B:s | 0 | nekad |
| ↳ kolumnen token_hash | nekad | nekad | nekad | nekad | nekad | nekad | nekad |
| audit_log | A:s | **0** | 0 | bara B:s | bara B:s | 0 | nekad |

### INSERT / DELETE (direkt)

Nekad för **alla** roller på alla sex tabeller. Allt går via RPC (metatest 4 + matris).

### UPDATE (direkt)

| Mål | O | A | C | B | X |
|---|---|---|---|---|---|
| households (alla kolumner) | nekad (RPC) | nekad | nekad | nekad | – |
| egen profil: namn, språk, aktivt hushåll | ✅ | ✅ | ✅ | ✅ | ✅ |
| profil: aktivt hushåll = hushåll man inte tillhör | nekad | – | – | – | – |
| annans profil | 0 | – | – | 0 | – |
| egen medlemsrad: namn/färg/avatar | ✅ | ✅ | **0** | – | – |
| annan vuxens medlemsrad | – | 0 | 0 | 0 | – |
| barns medlemsrad: namn/färg | ✅ | ✅ | 0 | 0 | – |
| medlemsrad: role/status/user_id/household_id | nekad | nekad | nekad | nekad | – |
| children.birth_date | ✅ | ✅ | **0** | 0 | – |
| children-behörigheter (`can_view_*`) | nekad (RPC) | nekad | **nekad** | – | – |
| household_invitations | nekad | – | – | – | nekad |
| audit_log | nekad | nekad | nekad | nekad | nekad |

### RPC-behörighet

| RPC | O | A | C | annat hushålls owner | anon |
|---|---|---|---|---|---|
| create_household | ✅ | ✅ | ✅ | ✅ | nekad |
| update/delete_household | ✅ | forbidden | forbidden | forbidden | nekad |
| create_child, update_child_permissions | ✅ | ✅ | forbidden | forbidden | nekad |
| create/revoke_invitation | ✅ | **forbidden (D3)** | forbidden | forbidden | nekad |
| accept/preview_invitation | med giltig token (+ verifierad e-post om bunden) | | | | nekad |
| change_member_role, remove_member | ✅ (D9-skydd) | forbidden | forbidden | forbidden | nekad |
| leave_household | ✅ om inte sista owner | ✅ | **forbidden** | – | nekad |

### Synlighet (D10) via `can_view_resource`

| Nivå | O | A | C | B | X |
|---|---|---|---|---|---|
| private (egen) | ✅ | ✅ | ✅ | – | – |
| private (annans) | **❌ (D2)** | ❌ | ❌ | ❌ | ❌ |
| adults | ✅ | ✅ | **❌** | ❌ | ❌ |
| household | ✅ | ✅ | ✅ | ❌ | ❌ |

Borttagna medlemmar förlorar all åtkomst direkt, även till sina egna privata resurser.

### D9 – minst en owner

Blockeras och är testat: sista owner lämnar (`last_owner`), degraderar sig själv
(`last_owner`), tas bort (`use_leave_household` / `last_owner`), raderar sitt konto
(FK RESTRICT, 23503). Direkt SQL som går förbi RPC:erna stoppas av en uppskjuten
trigger (`household_requires_owner`). Hushållet kan bara avvecklas via
`delete_household` med bekräftat namn.

## 5. Avvikelser från arkitekturen

1. **`FORCE ROW LEVEL SECURITY` används inte.** `postgres` har BYPASSRLS i Supabase, så FORCE gör ingen skillnad. Skyddet gäller API-rollerna. Dokumenterat i RLS_STRATEGY.
2. **Barnflaggor justerade efter D7:** `can_view_calendar`, `can_view_family_events`, `can_use_tasks_and_routines` (på) och `can_view_allowance`, `can_view_own_balance`, `can_view_savings_goals` (av). `can_create_tasks` togs bort. "Ekonomi generellt" är ingen flagga – det är permanent spärrat.
3. **Synlighetsnivån heter `adults`** (D10), inte `adults_only`.
4. **Individuella förmågor (D3) är inte byggda**, bara förberedda som en utbyggnadspunkt i `household_ids_with()`. Inget behov så länge båda vuxna är owner.
5. **`households` kan inte uppdateras direkt.** Även namnbyte går via `update_household` för att få audit.
6. **Begränsningar:** barn kan inte lämna själva, barn med konto kan inte ändra sitt namn, rollbyte barn ↔ vuxen är blockerat (Q7, Q8).
7. **Gränser mot missbruk** som inte fanns i specifikationen: 10 egna hushåll per användare, 30 medlemmar per hushåll, 20 öppna inbjudningar.
8. **Fel och utgången engångskod ger samma felkod** (`invalid_code`), eftersom Supabase Auth inte skiljer på dem.
9. **Integrationstester har en egen Jest-konfiguration** (ren Node), eftersom jest-expo ersätter `fetch`.
10. **Migrering 1 rättades på plats** (två triggerbuggar som integrationstestet hittade). Det var tillåtet eftersom inget deployats. Från och med nu ändras migreringar aldrig i efterhand.
11. **`APP_ENV` döptes om till `EXPO_PUBLIC_APP_ENV`** så att bygg och runtime aldrig kan peka på olika miljöer.
12. **Ej verifierat i den här miljön:** native-byggen på simulator/enhet (bara JS-bundlar), två `expo-doctor`-kontroller som kräver expo.dev (blockerade av nätverkspolicyn), Supabase Security Advisor (kräver ett hostat projekt).

## 6. Säkerhetsrisker som återstår

| # | Risk | Åtgärd |
|---|---|---|
| S1 | **Kontoradering saknas** (krav från App Store/Google Play). Med medlemskap blockeras radering helt av FK RESTRICT. | Edge Function `delete-account` i M2 |
| S2 | **Inbyggd e-post och ingen CAPTCHA**: låga gränser, risk för missbruk av kodutskick | Egen SMTP i EU + Turnstile/hCaptcha före extern testning |
| S3 | **Dubbla konton** när fler providers kopplas (R1) | Manuell länkning i UI + onboarding-fråga (M2) |
| S4 | **Gallring av audit-loggen är inte schemalagd** (funktionen finns och är testad) | `pg_cron` när staging finns |
| S5 | **Inbjudningstoken delas som text/länk.** Den kan hamna i chattloggar. Den är engångs, utgår och kan återkallas, men den som får tag i en icke e-postbunden token kan gå med. | Rekommendera e-postbundna inbjudningar i UI:t, kort utgångstid, universal links |
| S6 | `preview_invitation` visar hushållets namn och inbjudarens namn för den som har token | Medvetet val, dokumenterat |
| S7 | `members.read` ger barn och vuxna se även tidigare medlemmar och medlemmarnas opaka `user_id` | Acceptabelt. Kan begränsas med en vy senare |
| S8 | Sessionen krypteras med AES-CTR utan autentiseringstagg (Supabases mönster). Det kräver åtkomst till enheten. | Byt till AES-GCM om ett lämpligt bibliotek finns |
| S9 | **Metatesterna körs bara lokalt/CI**, inte mot staging/produktion | Kör `supabase test db` mot staging i deploy-pipelinen + Security Advisor |
| S10a | Roller gäller per hushåll: ett barnkonto kan skapa ett eget, separat hushåll. Ingen data läcker, men det kan vara oönskat | Besluta om användare som bara är barn ska få skapa hushåll (M2-04) |
| S10 | Barns personuppgifter och samtycke (GDPR, 13 år) är juridiskt oklart | Juridisk granskning före lansering (Q6) |

## 7. Rekommenderad Milestone 2 – "Från lokal grund till riktig miljö"

Ordningen nedan minimerar risk. Första ticketen är **M2-01**.

| # | Ticket | Varför nu |
|---|---|---|
| **M2-01** | **Staging-projekt i `eu-north-1`** (stoppa enligt D6 om regionen saknas), CI som applicerar migreringar till staging, pgTAP + Security Advisor mot staging | All vidare validering kräver en riktig miljö |
| M2-02 | **`delete-account`** (Edge Function, service role bara på servern): överför ägarskap eller radera hushållet, anonymisera medlemsrader, radera användaren | Butikskrav och D9-flödet för kontoradering |
| M2-03 | Egen SMTP (EU), CAPTCHA, `pg_cron` för audit-gallring | Krävs innan någon utanför teamet testar |
| M2-04 | `packages/ui` + onboarding: skapa hushåll, bjuda in (dela länk), acceptera via deep link, lägga till barn | Första riktiga användarflödet för er två |
| M2-05 | EAS development builds på riktiga enheter + Sign in with Apple och Google (native) + manuell identity linking | Kräver Apple Developer- och Google Play-konton (Q1) |

Därefter M3: ekonomi del 1 (konton, transaktioner, kategorier) med synlighet enligt D10.
