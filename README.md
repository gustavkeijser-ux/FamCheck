# FamCheck

Ett gemensamt kontrollcenter för familjen: ekonomi, budget, sparande, kalender,
barns aktiviteter, rutiner, uppgifter och familjeplanering.

Byggs för produktion och kommersiell lansering i Sverige (iOS + Android).

## Status

**Milestone 1 – Foundation är klar** (se [rapporten](docs/product/MILESTONE_1_REPORT.md)).
Monorepo, Expo-app, kärnschema med RLS, behörighetsfunktioner, 270+ databastester,
inloggning med e-postkod och CI. Inga produktfunktioner (ekonomi, kalender, barn-UI) ännu.

- Kom igång: [docs/architecture/DEVELOPMENT.md](docs/architecture/DEVELOPMENT.md)
- All dokumentation: [docs/README.md](docs/README.md)

## Stack

React Native · Expo · TypeScript · Supabase (PostgreSQL, Auth, Edge Functions)
· Expo Notifications · pnpm workspaces · GitHub Actions · EAS
