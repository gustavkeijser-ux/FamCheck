# ADR-0006: Pengar, tid och härledda värden

**Status:** Accepterad (2026-10-06)

## Beslut
- Belopp: `*_minor bigint` (öre) + `currency char(3)`. Aldrig flyttal.
  Utgifter negativa, inkomster positiva.
- Tid: `timestamptz` för tidpunkter, `date` för heldagar och budgetperioder,
  tolkade i hushållets tidszon.
- Budgetperioder är explicita datumintervall (`calendar_month` eller `pay_cycle`).
- **Härledda värden lagras inte**: manuellt saldo, spenderat, kvar, sparat
  belopp, inbjudans status. Undantag: banksaldo (banken är källan) och rollover
  för **stängda** perioder (fryst ögonblicksbild).
- Rollover och prognoser är rena funktioner i `packages/domain` med enhetstester.

## Konsekvenser
- Ingen risk att lagrade summor glider isär.
- Framräknade värden kräver vyer och index som är prestandatestade (M3–M4).
