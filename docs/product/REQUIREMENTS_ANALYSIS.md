# Kravanalys

> Status: **Godkänd 2026-10-06** (beslut D1–D10 i [OPEN_QUESTIONS](OPEN_QUESTIONS.md)). Implementerad i Milestone 1.
> Tolkningar och avvikelser är markerade **[T]** (tolkning) och **[A]** (avvikelse
> från specifikationen, med motivering).

## 1. Sammanfattning

FamCheck är ett kontrollcenter för hushållet. Hushållet är den centrala enheten
(tenant). All gemensam data – ekonomi, kalender, rutiner, uppgifter, barn – ägs
av ett hushåll och nås via ett medlemskap. Produkten ska vara säker för många
hushåll från dag ett och klara en kommersiell lansering i Sverige.

## 2. Krav som styr arkitekturen mest

| # | Krav | Konsekvens för arkitekturen |
|---|---|---|
| K1 | Hushållet är centralt: User → Membership → Household | `household_id NOT NULL` på all gemensam data; RLS utgår alltid från medlemskap |
| K2 | Fyra roller: owner, adult, child, managed_child | Rollen sitter på medlemskapet; behörighet slås upp centralt i databasen |
| K3 | managed_child ska senare kopplas till ett konto **utan att historik försvinner** | All domändata måste referera en **stabil person-id** som inte byter id när ett konto kopplas → `household_members.id` |
| K4 | Barn får aldrig läsa vuxnas ekonomi, inte ens genom att gå förbi UI | Barn får **inga** direkta läsrättigheter på ekonomitabeller; barnets ekonomi exponeras via snävt avgränsade regler |
| K5 | Privata konton syns inte automatiskt för andra | `visibility = private` slår igenom även för owner **[T]** |
| K6 | Fem inloggningsmetoder + identity linking | Supabase Auth med verifierad e-post som länknyckel och manuell länkning i appen |
| K7 | Säkra, utgående, återkallbara engångsinbjudningar | Hashade tokens, statusflöden endast via databasfunktioner |
| K8 | Bank (Enable Banking) i framtiden, inget beroende i MVP | Källoberoende transaktionsmodell (`source`, `external_id`), bankhemligheter bara på servern |
| K9 | Budgetperioder ≠ kalendermånad, rollover +/−/ingen | Perioder som explicita datumintervall; rollover som ren, testad funktion |
| K10 | Undvik lagrade härledda värden | Saldo, "spenderat", "kvar" och sparat belopp räknas fram (se §4) |
| K11 | RLS-tester för SELECT/INSERT/UPDATE/DELETE per roll | pgTAP-testmatris i CI |
| K12 | Audit log utan hemligheter | Append-only-tabell som bara skrivs av databasfunktioner |
| K13 | Alla schemaändringar via migreringar | Supabase CLI-migreringar, CI applicerar från tom databas varje gång |

## 3. Tolkningar och avvikelser

| # | Specifikation | Förslag | Motivering |
|---|---|---|---|
| T1 | Tabell `children` | `children` blir en **tilläggstabell** (1:1) till `household_members`, inte en fristående persontabell | Kalenderdeltagare, ansvariga och uppgifter kan vara både vuxna och barn. Om barn låg i en egen tabell skulle varje referens behöva vara polymorf (antingen användare eller barn). En gemensam person-id löser K3 utan att historik flyttas. |
| T2 | `household_members` = medlemsrelation för användare | Ett medlemskap kan ha `user_id = NULL` (endast `managed_child`) | Samma rad finns kvar när barnet senare får ett konto; bara `user_id` och `role` ändras. |
| A1 | Konto: `owner_user_id` | `owner_member_id` (→ `household_members.id`) | Ett barns konto/veckopeng ska kunna ägas av ett managed_child som saknar användar-id. Samma princip för inkomster, fasta kostnader och sparmål. |
| A2 | Konto: `current_balance` | `opening_balance` + datum för manuella konton; saldot räknas fram. För bankkonton: `reported_balance` + `reported_balance_at` från banken. | K10 – ett lagrat saldo som också uppdateras av transaktioner blir förr eller senare fel. |
| A3 | Sparmål: `current_amount` | Räknas fram ur `savings_contributions` (eller ett länkat sparkontos saldo) | K10 |
| A4 | Budget: "spenderat" och "kvar" | Lagras inte; räknas fram per period. Rollover kan **frysas** (sparas som en ögonblicksbild) när en period stängs. | Annars ändras alla senare perioder retroaktivt varje gång en gammal transaktion ändras (se risk R5). |
| T3 | Owner har "full behörighet" | Full **administrativ** behörighet, men **inte** läsrätt till andra medlemmars privata konton | Konflikt mellan K5 och owner-definitionen; integriteten går före. Kräver ditt godkännande. |
| T4 | Två vuxna i första hushållet | Rekommendation: båda blir `owner` (det kan finnas flera owners) | Annars kan partnern inte bjuda in, ändra roller m.m. |

## 4. Härledda värden – vad som lagras och vad som räknas fram

| Värde | Lagras? | Hur det räknas fram |
|---|---|---|
| Kontosaldo (manuellt) | Nej | `opening_balance + sum(transactions efter opening_balance_date)` |
| Kontosaldo (bank) | Ja, banken är källan | `reported_balance` + tidpunkt |
| Spenderat per budgetkategori | Nej | Summan av transaktioner i kategorin under perioden |
| Rollover | Bara när perioden stängs | Ren funktion i `packages/domain`; resultatet sparas när perioden stängs |
| Sparat belopp | Nej | Summan av insättningar, eller länkat kontos saldo |
| Inbjudans status | Nej | Från `accepted_at`, `revoked_at` och `expires_at` |

## 5. Avgränsning för Milestone 1

**Med i M1:** monorepo, Expo-app utan riktigt UI, miljöstrategi, Supabase-klient,
kärnschemat (profiles, households, household_members, children,
household_invitations, audit_log), behörighetsfunktioner, RLS, RPC:er för
hushåll/inbjudan/barn, pgTAP-tester, auth-grund (e-post med engångskod), CI och
dokumentation.

**Inte med i M1:** ekonomi, kalender, rutiner, uppgifter, notiser, familjepuls,
UI/designsystem, inloggning med Apple/Google/Facebook/Microsoft (förberedd men
inte kopplad), radering av konto (se nästa tickets).

Ekonomi, kalender m.fl. är redan **utformade i grova drag**
([../architecture/DATA_MODEL_FUTURE.md](../architecture/DATA_MODEL_FUTURE.md)),
för att visa att kärnmodellen och RLS-strategin håller för dem.
