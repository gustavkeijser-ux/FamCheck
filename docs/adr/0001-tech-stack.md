# ADR-0001: Teknisk stack och verktyg

**Status:** Föreslagen

## Kontext
Specificerad stack: React Native, Expo, TypeScript, Supabase, Expo Notifications, GitHub, npm/pnpm.
Inga starka skäl att avvika har identifierats.

## Beslut
- Expo (managed workflow) med **development builds** (inte Expo Go) – krävs för push och Apple-inloggning.
- Expo Router för navigation (deep links för inbjudningar).
- TanStack Query för serverstate, Zustand för minimalt klientstate.
- zod + react-hook-form för validering.
- **npm** som pakethanterare: minst friktion med Expo/EAS och färre problem med
  symlänkade beroenden i Metro. Kan bytas till pnpm om repot blir monorepo.
- Supabase CLI för lokal utveckling och migreringar; pgTAP för databastester.
- EAS Build/Submit/Update för release.

## Konsekvenser
- Kräver Docker lokalt för `supabase start`.
- Kräver Apple Developer- och Google Play-konton tidigt för att testa push på riktiga enheter.
