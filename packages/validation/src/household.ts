import { z } from 'zod';

import { hexColorSchema, nameSchema, pastOrTodayDateSchema, uuidSchema } from './common';

export const householdNameSchema = nameSchema(80);
export const memberDisplayNameSchema = nameSchema(50);

export const createHouseholdSchema = z.object({
  name: householdNameSchema,
});
export type CreateHouseholdInput = z.infer<typeof createHouseholdSchema>;

export const createChildSchema = z.object({
  householdId: uuidSchema,
  displayName: memberDisplayNameSchema,
  birthDate: pastOrTodayDateSchema.optional(),
  color: hexColorSchema.optional(),
});
export type CreateChildInput = z.infer<typeof createChildSchema>;

export const updateChildPermissionsSchema = z
  .object({
    memberId: uuidSchema,
    canViewCalendar: z.boolean().optional(),
    canViewFamilyEvents: z.boolean().optional(),
    canUseTasksAndRoutines: z.boolean().optional(),
    canViewAllowance: z.boolean().optional(),
    canViewOwnBalance: z.boolean().optional(),
    canViewSavingsGoals: z.boolean().optional(),
  })
  .refine((value) => Object.keys(value).length > 1, { message: 'no_changes' });
export type UpdateChildPermissionsInput = z.infer<typeof updateChildPermissionsSchema>;

export const invitableRoleSchema = z.enum(['adult', 'child']);

export const createInvitationSchema = z
  .object({
    householdId: uuidSchema,
    role: invitableRoleSchema,
    email: z
      .string()
      .trim()
      .toLowerCase()
      .pipe(z.email({ message: 'invalid_email' }))
      .optional(),
    targetMemberId: uuidSchema.optional(),
  })
  .refine((value) => value.targetMemberId === undefined || value.role === 'child', {
    message: 'target_member_requires_child_role',
    path: ['role'],
  });
export type CreateInvitationInput = z.infer<typeof createInvitationSchema>;

/** Inbjudningstoken: 32 slumpbytes kodade som base64url (43 tecken). */
export const invitationTokenSchema = z
  .string()
  .trim()
  .regex(/^[A-Za-z0-9_-]{43}$/, { message: 'invalid_token' });

export const changeMemberRoleSchema = z.object({
  memberId: uuidSchema,
  role: z.enum(['owner', 'adult']),
});
export type ChangeMemberRoleInput = z.infer<typeof changeMemberRoleSchema>;
