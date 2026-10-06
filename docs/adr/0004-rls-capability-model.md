# ADR-0004: RLS med förmågemodell

**Status:** Accepterad (2026-10-06)

## Beslut
- Policyer kontrollerar **förmågor** (`finance.read`), inte roller.
  Kopplingen roll → förmåga finns i `private.role_permissions`.
- Hjälpfunktioner i schemat `private` (exponeras inte via API:et),
  `security definer`, `search_path = ''`. De returnerar id-mängder som används
  med `in (select …)` för prestanda (initplan).
- Tillståndsändringar (inbjudan, roll, medlemskap, hushåll) görs bara via RPC.
  Direkta UPDATE begränsas med kolumnrättigheter.
- Privat synlighet skyddar även mot owner.
- Barn får aldrig ekonomiförmågor. Barnets egna data nås via snäva policyer
  styrda av `children`-behörigheter.
- pgTAP-matris (SELECT/INSERT/UPDATE/DELETE × roll × tabell) + metatester i CI.

## Konsekvenser
- Nya roller och ändrade rättigheter kräver ingen omskrivning av policyerna.
- Varje ny tabell måste följa mönstret. Metatesterna fångar den som inte gör det.
