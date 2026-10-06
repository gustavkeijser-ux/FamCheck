# ADR-0002: Online-först i stället för offline-först

**Status:** Föreslagen

## Kontext
Full offline-synk (t.ex. PowerSync, WatermelonDB) ger bra UX men kräver
konfliktlösning, synkschema och mer komplex RLS-hantering. Två vuxna som redigerar
samma data samtidigt gör konflikter realistiska.

## Beslut
Online-först. TanStack Query-cache persisteras lokalt så att senast hämtad data
kan visas offline. Skrivningar kräver uppkoppling (med tydligt felmeddelande).
Supabase Realtime används för att uppdatera vyer när den andra vuxna ändrar något.

## Konsekvenser
- Enklare och säkrare v1.
- Om offline-skrivning blir ett krav utvärderas en synkmotor; datamodellen
  (UUID-nycklar genererade på klienten möjligt, `updated_at` överallt) gör det möjligt.
