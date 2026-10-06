/**
 * Åtkomstnivå för resurser (beslut D10). Genomdrivs alltid av RLS via
 * `private.can_view_resource()` – UI:t får aldrig vara det enda skyddet.
 *
 * - private:   endast ägaren (owner_member_id). Inte heller owner-rollen.
 * - adults:    hushållets owner- och adult-medlemmar.
 * - household: alla aktiva medlemmar. Barn kan ändå sakna förmågan att läsa
 *              resurstypen, t.ex. ekonomi.
 */
export const RESOURCE_VISIBILITIES = ['private', 'adults', 'household'] as const;
export type ResourceVisibility = (typeof RESOURCE_VISIBILITIES)[number];
