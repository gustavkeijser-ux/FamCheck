import { z } from 'zod';

export const uuidSchema = z.uuid();

/** Trimmat namn utan kontrolltecken. Gränserna speglar databasens check constraints. */
export const nameSchema = (max: number) =>
  z
    .string()
    .trim()
    .min(1, { message: 'required' })
    .max(max, { message: 'too_long' })
    // eslint-disable-next-line no-control-regex
    .refine((value) => !/[\u0000-\u001f\u007f]/.test(value), { message: 'invalid_characters' });

export const hexColorSchema = z.string().regex(/^#[0-9A-Fa-f]{6}$/, { message: 'invalid_color' });

/** ISO-datum (YYYY-MM-DD) som inte ligger i framtiden. */
export const pastOrTodayDateSchema = z.iso
  .date()
  .refine((value) => value <= new Date().toISOString().slice(0, 10), { message: 'date_in_future' });
