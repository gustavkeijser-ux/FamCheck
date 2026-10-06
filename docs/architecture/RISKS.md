# Arkitekturrisker

> Identifierade före implementationen. Uppdateras löpande.
> Sannolikhet/Konsekvens: L = låg, M = medel, H = hög.

| # | Risk | S/K | Åtgärd |
|---|---|---|---|
| R1 | **Dubbla konton via olika inloggningsmetoder** (Apple Dölj min e-post, Facebook utan e-post, Microsoft med overifierad e-post) | H/M | Länka bara på verifierad e-post, manuell länkning i appen, onboarding som frågar "har du redan ett konto?". Ingen sammanslagning av konton i v1. Se AUTH_AND_IDENTITY |
| R2 | **Barn med egna konton: GDPR och butikernas regler.** I Sverige gäller 13 år som åldersgräns för samtycke till informationssamhällets tjänster. Apple och Google har regler för appar som riktar sig till barn | H/H | Barnkonton skapas bara via förälderns inbjudan (förälderns samtycke dokumenteras i audit). Ingen spårning eller reklam. Juridisk granskning före lansering. Appen kategoriseras som familje-/ekonomiapp, inte "Kids" |
| R3 | **Owner vs privata konton** – specifikationen säger "full behörighet" men också att privata konton ska skyddas | M/H | Integriteten går före (T3). Kräver ditt beslut |
| R4 | **Komplexa RLS-policyer** ger luckor eller dålig prestanda (särskilt ekonomi med synlighet) | M/H | Förmågemodell med centrala funktioner, metatester, testmatris per tabell, prestandatest med seed-data, Security Advisor i CI |
| R5 | **Rollover blir retroaktiv** – en ändrad gammal transaktion ändrar alla senare perioder | M/M | Rollover räknas dynamiskt för öppna perioder och fryses när en period stängs. Paritetstest mellan TS och SQL |
| R6 | **Klientens "aktiva hushåll" används som behörighet** av misstag | L/H | Aldrig. Varje fråga anger `household_id` och RLS kontrollerar det. Kodgranskningsregel |
| R7 | **Härledda värden** (saldo, spenderat, sparat) som lagras och glider isär | M/M | Avvikelser A2–A4. Värdena räknas fram, banksaldo lagras med tidpunkt |
| R8 | **pnpm-monorepo + Expo/Metro** (symlänkar, dubbla React-instanser) | M/M | `node-linker=hoisted`, Expos inbyggda monorepostöd, `expo-doctor` i CI |
| R9 | **Delad kod mellan Node (app) och Deno (Edge Functions)** | M/L | `domain`/`validation`/`utils` hålls fria från plattforms-API:er, Edge Functions importerar med relativ sökväg, zod via `npm:`. Verifieras med ett test i M1 |
| R10 | **Radering av konto och hushåll** – sista owner, historik, GDPR | M/H | Kontrollerat flöde via Edge Function, anonymisering av medlemsrader, `on delete restrict` på `user_id` |
| R11 | **E-postleverans** (OTP, inbjudningar) med Supabases inbyggda SMTP | H/M | Egen SMTP i EU före extern testning |
| R12 | **Deep links för inbjudningar** kräver en domän (universal links/app links) | M/M | M1: token kan klistras in manuellt + custom scheme. Domän och universal links före lansering |
| R13 | **Tidszoner och sommartid** i rutiner, heldagar och budgetperioder | M/M | Hushållets tidszon, `date` för heldagar och perioder, tester över sommartidsövergångar |
| R14 | **Kostnad**: två Supabase-projekt (staging + prod) på Pro-plan, EAS, Apple/Google-konton | H/L | Medvetet val. Staging kan pausas. Alternativ: Supabase Branching |
| R15 | **Open Banking-leverantörens villkor och licens** (AIS-licens, hur länge samtycket gäller) | M/M | Ingen påverkan på MVP. Utreds innan bank-milestonen. Modellen är källoberoende |
| R16 | **Validering av native-inloggning** kräver Apple Developer- och Google Play-konton samt riktiga enheter, vilket inte går i den här molnmiljön | H/L | M1 validerar e-post-OTP end-to-end. Native providers blir en egen ticket |
| R17 | **Gamla appversioner** i omlopp när schemat ändras | M/M | Expand/contract-migreringar, RPC:er versioneras vid brytande ändringar |
