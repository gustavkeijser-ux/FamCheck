/**
 * Inloggningsmetoder (AUTH_AND_IDENTITY.md §1). M1 implementerar bara e-post.
 * Övriga är förberedda i supabase/config.toml och kopplas i M2 när utvecklar-
 * konton för Apple/Google/Meta/Microsoft finns. Supabase-namnet för Microsoft är 'azure'.
 */
export const IDENTITY_PROVIDERS = ['email', 'apple', 'google', 'facebook', 'azure'] as const;
export type IdentityProvider = (typeof IDENTITY_PROVIDERS)[number];

const ENABLED_PROVIDERS: readonly IdentityProvider[] = ['email'];

export function isProviderEnabled(provider: IdentityProvider): boolean {
  return ENABLED_PROVIDERS.includes(provider);
}
