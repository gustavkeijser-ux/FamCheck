# Roadmap

Varje fas följer: **planera → implementera → validera → testa → dokumentera**.
Nästa fas påbörjas först när föregående uppfyller sin *Definition of Done*.

## Fas 0 – Arkitektur & planering ← *nu*
- [x] Arkitekturförslag, datamodell för kärnan, ADR:er
- [ ] Beslut på öppna frågor ([OPEN_QUESTIONS.md](OPEN_QUESTIONS.md))
- [ ] Godkännande av arkitekturen

## Fas 1 – Grund (inga domänfunktioner)
**Mål:** en tom men produktionsredo app där två vuxna kan logga in och dela ett hushåll.

1. Expo-projekt (TypeScript strict, Expo Router), ESLint/Prettier, Jest
2. Supabase lokalt (`supabase init`), staging-projekt i EU
3. GitHub Actions: lint, typecheck, unit-test, DB-tester (pgTAP), RLS-kontroll
4. Migreringar: `profiles`, `households`, `household_members`, `household_invitations`
5. RPC: `create_household`, `create_invitation`, `accept_invitation`, `leave_household`
6. Auth: e-post (magic link/OTP) + Sign in with Apple (krav på iOS om annan social login finns), ev. Google
7. Onboarding: skapa hushåll eller gå med via inbjudningslänk
8. Lägga till person utan konto (barn)
9. i18n-grund, tema, felhantering, Sentry
10. Radera konto (krav från App Store)

**DoD:** pgTAP visar att hushåll A inte kan läsa/skriva B; E2E-flöde testat på
iOS och Android via dev build; dokumentation uppdaterad.

## Fas 2 – Kalender & barns aktiviteter
Händelser, återkommande (RRULE), deltagare, färg per person, vecko-/dagsvy.

## Fas 3 – Uppgifter & rutiner
Uppgifter med ansvarig och deadline; rutiner (morgon/kväll) med avbockning.

## Fas 4 – Push-notiser
Push-tokens, påminnelser via `pg_cron` + Edge Function, inställningar per användare.

## Fas 5 – Budget & ekonomi
Konton, kategorier, månadsbudget, transaktioner (manuell inmatning + CSV-import), översikt.

## Fas 6 – Sparande
Sparmål, insättningar, prognos.

## Fas 7 – Kommersiell lansering
Prenumeration per hushåll (IAP via RevenueCat), integritetspolicy, villkor,
dataexport, App Store/Google Play-listning, support.

> Ordningen mellan Fas 2–6 är ett förslag – se öppen fråga om prioritering.
