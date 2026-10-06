# Utvecklingsmiljö

## Förutsättningar
- Node 22 (`.nvmrc`), pnpm 10 (`corepack enable`)
- Docker (för lokal Supabase)

## Kom igång
```bash
pnpm install
pnpm db:start            # lokal Supabase (Postgres, Auth, REST, Mailpit)
pnpm db:reset            # alla migreringar från tom databas + seed
cp apps/mobile/.env.example apps/mobile/.env.local   # fyll i nyckeln från `supabase status`
pnpm --filter @famcheck/mobile start:dev-client
```
E-post (engångskoder) hamnar i Mailpit: http://127.0.0.1:54324

## Kontroller (samma som CI)
| Kommando | Vad |
|---|---|
| `pnpm lint` / `pnpm format:check` / `pnpm typecheck` | Kodkvalitet |
| `pnpm test` | Enhetstester (Vitest i paketen, jest-expo i appen) |
| `pnpm check:secrets` | Söker efter hemligheter i klientkod |
| `pnpm db:test` | pgTAP: RLS-matris, RPC-flöden, metatester, integritetstriggers |
| `pnpm db:lint` | plpgsql_check på `public` och `private` |
| `pnpm check:types-drift` | Genererade typer stämmer med migreringarna |
| `SUPABASE_PUBLISHABLE_KEY=… pnpm test:integration` | Auth-flödet mot den lokala stacken |

## Ändra databasen
1. `pnpm exec supabase migration new <namn>` – skriv SQL. Ny tabell = RLS + uttryckliga GRANTs + tester.
2. `pnpm db:reset && pnpm db:test && pnpm db:lint`
3. `pnpm gen:types` och checka in `packages/types/src/database.ts`
4. Ändras `private.role_permissions`: uppdatera även `packages/domain/src/roles.ts` (paritetstest).

Migreringar som har applicerats på staging eller produktion ändras **aldrig**. Rätta
med en ny migrering. (Före första deploy har M1-migreringarna rättats på plats.)
