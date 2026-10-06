/**
 * Pengar representeras alltid som heltal i minsta valutaenhet (öre för SEK).
 * Se ADR-0006. Flyttal används aldrig för belopp.
 */

/** Belopp i minsta valutaenhet, t.ex. 12 345 öre = 123,45 kr. */
export type MinorUnits = number & { readonly __brand: 'MinorUnits' };

export type CurrencyCode = string & { readonly __brand: 'CurrencyCode' };

const CURRENCY_PATTERN = /^[A-Z]{3}$/;

export function toCurrencyCode(value: string): CurrencyCode {
  if (!CURRENCY_PATTERN.test(value)) {
    throw new RangeError(`Ogiltig valutakod: ${value}`);
  }
  return value as CurrencyCode;
}

export function toMinorUnits(value: number): MinorUnits {
  if (!Number.isSafeInteger(value)) {
    throw new RangeError(`Belopp i minsta enhet måste vara ett säkert heltal: ${value}`);
  }
  return value as MinorUnits;
}

/**
 * Tolkar ett belopp som användaren skrivit in, t.ex. "1 234,50", "1234.5" eller "-99".
 * Returnerar null om strängen inte är ett giltigt belopp med högst två decimaler.
 * Räknar med strängar hela vägen för att undvika flyttalsfel.
 */
export function parseAmountToMinor(input: string): MinorUnits | null {
  const normalized = input
    .trim()
    .replace(/[\s\u00a0\u202f]/g, '')
    .replace(/kr$/i, '')
    .replace(',', '.');

  const match = /^(-)?(\d+)(?:\.(\d{1,2}))?$/.exec(normalized);
  if (!match) return null;

  const [, sign, whole = '', fraction = ''] = match;
  const minor = Number(whole) * 100 + Number(fraction.padEnd(2, '0'));
  if (!Number.isSafeInteger(minor)) return null;

  return toMinorUnits(sign && minor !== 0 ? -minor : minor);
}

/** Formaterar ett belopp för visning, t.ex. 123450 → "1 234,50 kr". */
export function formatMinor(
  amount: MinorUnits,
  currency: CurrencyCode = toCurrencyCode('SEK'),
  locale = 'sv-SE',
): string {
  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount / 100);
}
