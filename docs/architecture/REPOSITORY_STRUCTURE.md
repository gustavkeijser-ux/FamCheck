# Repository-struktur

> Status: **Godkänd 2026-10-06** (beslut D1–D10 i [OPEN_QUESTIONS](../product/OPEN_QUESTIONS.md)). Implementerad i Milestone 1.

## Översikt

Ett monorepo med pnpm workspaces. Repo-roten motsvarar `family-app/` i specifikationen.

```
FamCheck/
├─ apps/
│  └─ mobile/                         # @famcheck/mobile – Expo-appen (iOS + Android)
│     ├─ app/                         # Expo Router: ENDAST routes och layouts, tunna filer
│     │  ├─ _layout.tsx               # Providers (Query, Auth, i18n)
│     │  ├─ (auth)/                   # inloggning, engångskod
│     │  ├─ (onboarding)/             # skapa hushåll / gå med via inbjudan
│     │  ├─ (adult)/                  # vuxenläge (owner/adult)
│     │  ├─ (child)/                  # barnläge, separat och förenklat
│     │  └─ invite/[token].tsx        # deep link för inbjudan
│     ├─ src/
│     │  ├─ features/                 # en mapp per domän
│     │  │  ├─ auth/
│     │  │  │  ├─ api/                # Supabase-anrop (inga anrop i komponenter)
│     │  │  │  ├─ hooks/              # TanStack Query-hooks
│     │  │  │  ├─ components/
│     │  │  │  ├─ screens/
│     │  │  │  └─ index.ts            # featurens publika API
│     │  │  └─ household/             # (budget/, calendar/, routines/ … i senare milestones)
│     │  ├─ lib/
│     │  │  ├─ supabase.ts            # en enda typad klient
│     │  │  ├─ env.ts                 # zod-validerade EXPO_PUBLIC_*-variabler
│     │  │  ├─ secure-storage.ts      # krypterad lagring av sessionen
│     │  │  ├─ query-client.ts
│     │  │  └─ i18n.ts
│     │  ├─ providers/
│     │  └─ locales/sv.json
│     ├─ app.config.ts                # dynamisk konfiguration per EXPO_PUBLIC_APP_ENV
│     ├─ eas.json                     # bygg-profiler: development / preview / production
│     ├─ jest.config.js               # jest-expo
│     ├─ tsconfig.json
│     └─ package.json
├─ packages/
│  ├─ config/                         # @famcheck/config – tsconfig.base, ESLint, Prettier
│  ├─ types/                          # @famcheck/types – GENERERADE databastyper + domäntyper
│  ├─ validation/                     # @famcheck/validation – zod-scheman (indata, RPC-argument)
│  ├─ domain/                         # @famcheck/domain – ren affärslogik, ingen I/O
│  │                                  #   budgetperioder, rollover, familjepuls-regler, behörighetsspegel
│  ├─ utils/                          # @famcheck/utils – pengar (öre), datum/tidszon, generella hjälpare
│  └─ ui/                             # @famcheck/ui – designsystem (skapas i första UI-ticketen, inte i M1)
├─ supabase/
│  ├─ config.toml                     # lokal stack, auth-inställningar, providers via env()
│  ├─ migrations/                     # ENDA sättet att ändra schemat
│  ├─ functions/                      # Edge Functions (Deno)
│  │  └─ _shared/                     # cors, auth-hjälp, felhantering
│  ├─ tests/
│  │  └─ database/                    # pgTAP: RLS-matris, RPC:er, metatester
│  └─ seed.sql                        # endast lokalt – aldrig i produktion
├─ docs/
│  ├─ product/                        # krav, roadmap, milestones, öppna frågor
│  ├─ architecture/                   # struktur, datamodell, miljöer, risker
│  ├─ security/                       # roller, RLS, auth/identitet, audit
│  └─ adr/                            # arkitekturbeslut
├─ scripts/                           # gen-types, check-secrets m.m.
├─ .github/workflows/ci.yml
├─ package.json                       # workspace-rot (private), skript som kör allt
├─ pnpm-workspace.yaml
├─ .npmrc                             # node-linker=hoisted (Expo/Metro)
├─ .nvmrc                             # Node 22 LTS
└─ .env.example                       # dokumenterar variabler, inga riktiga värden
```

## Avvikelser från specifikationen

1. **`packages/domain` har lagts till.** Specifikationen nämner `utils`, men
   affärsregler (rollover, budgetperioder, familjepulsens varningar) är något
   annat än hjälpfunktioner. De ska vara rena funktioner med 100 % enhetstester,
   inte ligga i UI-lagret, och kunna användas både av appen och av Edge Functions.
2. **`packages/config` har lagts till** för gemensam tsconfig/ESLint, så att
   inställningarna inte kopieras mellan paketen.
3. **`packages/ui` skapas först när UI-arbetet börjar.** Tomma paket gör ingen nytta.

## Beroenderegler (kontrolleras av ESLint)

```
apps/mobile ──► ui, domain, validation, utils, types
domain      ──► utils, types
validation  ──► types
ui          ──► utils
utils, types──► (inga interna beroenden)
supabase/functions ──► domain, validation, utils (endast via relativ import, se R9)
```

- Inget paket importerar från `apps/`.
- Features importerar varandra endast via `index.ts`.
- `packages/types/src/database.ts` genereras med `supabase gen types` och
  redigeras aldrig för hand. CI fallerar om filen inte matchar migreringarna.
