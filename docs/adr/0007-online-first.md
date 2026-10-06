# ADR-0007: Online-först

**Status:** Föreslagen

## Beslut
Online-först med en TanStack Query-cache som persisteras lokalt (data kan läsas
offline). Skrivningar kräver uppkoppling. Supabase Realtime (som respekterar RLS)
uppdaterar vyerna när en annan familjemedlem ändrar något.

## Motivering
Full offline-synk kräver konfliktlösning och en synkmotor som också måste följa
RLS. Det är för mycket risk för v1. UUID-nycklar och `updated_at` överallt gör
att det kan införas senare.
