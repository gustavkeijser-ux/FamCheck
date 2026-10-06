# ADR-0004: Representation av pengar och tid

**Status:** Föreslagen

## Beslut – pengar
- `amount_minor bigint` (öre) + `currency char(3)`. Aldrig `float`/`real`.
- Utgifter negativa, inkomster positiva i `transactions`.
- Formatering i klienten med `Intl.NumberFormat('sv-SE', { style: 'currency' })`.
- Delad hjälpmodul `src/shared/money.ts` med enhetstester.

## Beslut – tid
- `timestamptz` för tidpunkter; `date` för heldagar och budgetperioder.
- Hushållets tidszon (`households.timezone`) används för att tolka heldagar och
  återkommande händelser (sommartid!).
- Återkommande händelser/rutiner: RRULE (RFC 5545) + undantagstabell; expanderas
  vid läsning (klient eller SQL-funktion) – inga förgenererade rader.

## Konsekvenser
- Inga avrundningsfel i budgetsummor.
- Återkommande logik kräver ett väl testat bibliotek (t.ex. `rrule`) och tester över sommartidsövergångar.
