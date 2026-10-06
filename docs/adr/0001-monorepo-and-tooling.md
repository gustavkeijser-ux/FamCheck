# ADR-0001: Monorepo med pnpm, Expo och verktyg

**Status:** Föreslagen

## Kontext
Specifikationen önskar `apps/` + `packages/` + `supabase/` och tillåter npm eller pnpm.
Affärslogiken ska kunna delas mellan appen, tester och Edge Functions.

## Beslut
- **pnpm workspaces** med `node-linker=hoisted`. Strikt beroendehantering och
  snabb installation. Hoisted-läget undviker kända problem med Metro och symlänkar.
- Ingen Turborepo i början. Rotskript (`pnpm -r`) räcker. Det kan läggas till
  när byggtiderna kräver det.
- Expo (managed) med **development builds**, Expo Router, TypeScript strict.
- TanStack Query (serverdata), Zustand (minimal klientdata), zod, react-hook-form, i18next.
- Tester: **Vitest** för rena paket (`domain`, `utils`, `validation`),
  **jest-expo** för appen, **pgTAP** för databasen.
- Supabase CLI för lokal stack, migreringar och typgenerering.
- `packages/domain` och `packages/config` läggs till utöver specifikationen
  (se REPOSITORY_STRUCTURE).

## Konsekvenser
- Två testverktyg (Vitest och Jest). Ett medvetet val: React Native kräver Jest
  och rena paket är snabbare med Vitest.
- Edge Functions (Deno) importerar delade paket med relativa sökvägar, så paketen
  måste vara plattformsneutrala (R9).
