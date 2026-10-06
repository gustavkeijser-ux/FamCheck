import { describe, expect, it } from 'vitest';

import { formatMinor, parseAmountToMinor, toCurrencyCode, toMinorUnits } from './money';

describe('parseAmountToMinor', () => {
  it.each([
    ['0', 0],
    ['1', 100],
    ['1234,5', 123450],
    ['1 234,50', 123450],
    ['1\u00a0234,50 kr', 123450],
    ['1234.05', 123405],
    ['-99', -9900],
    ['-0', 0],
    ['0,1', 10],
    ['  42  ', 4200],
  ])('tolkar %j som %d öre', (input, expected) => {
    expect(parseAmountToMinor(input)).toBe(expected);
  });

  it.each(['', 'abc', '1,234', '1.2.3', '12,345', '--1', '1e5', '١٢'])('avvisar %j', (input) => {
    expect(parseAmountToMinor(input)).toBeNull();
  });

  it('undviker flyttalsfel', () => {
    // 0.1 + 0.2 som flyttal blir 0.30000000000000004
    expect(parseAmountToMinor('0,29')).toBe(29);
    expect(parseAmountToMinor('1,15')).toBe(115);
  });

  it('avvisar belopp utanför säkert heltalsintervall', () => {
    expect(parseAmountToMinor('9999999999999999999')).toBeNull();
  });
});

describe('toMinorUnits', () => {
  it('avvisar decimaler', () => {
    expect(() => toMinorUnits(1.5)).toThrow(RangeError);
  });
});

describe('toCurrencyCode', () => {
  it('kräver tre versaler', () => {
    expect(toCurrencyCode('SEK')).toBe('SEK');
    expect(() => toCurrencyCode('sek')).toThrow(RangeError);
  });
});

describe('formatMinor', () => {
  it('formaterar svenska kronor', () => {
    // Intl använder hårda mellanslag; normalisera för jämförelse.
    expect(formatMinor(toMinorUnits(123450)).replace(/\s/g, ' ')).toBe('1 234,50 kr');
  });
});
