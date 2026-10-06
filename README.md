# FamCheck

Ett gemensamt kontrollcenter för familjen: ekonomi, budget, sparande, kalender,
barns aktiviteter, rutiner, uppgifter och familjeplanering.

Byggs för produktion och kommersiell lansering i Sverige (iOS + Android).

## Status

**Fas 0 – Arkitektur & planering.** Ingen applikationskod ännu. Arkitekturen
ska godkännas innan grunden (Fas 1) implementeras.

## Dokumentation

| Dokument | Innehåll |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Övergripande arkitektur, stack, kodstruktur, säkerhet |
| [docs/DATA_MODEL.md](docs/DATA_MODEL.md) | Datamodell kring hushåll, medlemskap och RLS |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Stegvis plan med faser och "definition of done" |
| [docs/OPEN_QUESTIONS.md](docs/OPEN_QUESTIONS.md) | Antaganden och frågor som behöver beslut |
| [docs/adr/](docs/adr/) | Arkitekturbeslut (Architecture Decision Records) |

## Stack

React Native · Expo · TypeScript · Supabase (PostgreSQL, Auth, Edge Functions)
· Expo Notifications · GitHub Actions · EAS Build
