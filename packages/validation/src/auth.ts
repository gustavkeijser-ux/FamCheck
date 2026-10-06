import { z } from 'zod';

export const emailSchema = z
  .string()
  .trim()
  .toLowerCase()
  .pipe(z.email({ message: 'invalid_email' }));

export const requestEmailOtpSchema = z.object({
  email: emailSchema,
});
export type RequestEmailOtpInput = z.infer<typeof requestEmailOtpSchema>;

export const verifyEmailOtpSchema = z.object({
  email: emailSchema,
  token: z
    .string()
    .trim()
    .regex(/^\d{6}$/, { message: 'invalid_code' }),
});
export type VerifyEmailOtpInput = z.infer<typeof verifyEmailOtpSchema>;
