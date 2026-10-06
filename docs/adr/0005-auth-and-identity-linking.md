# ADR-0005: Inloggning och identity linking

**Status:** Föreslagen

## Beslut
- Supabase Auth. E-post via engångskod (OTP). Apple/Google native via
  `signInWithIdToken`. Facebook/Microsoft via OAuth + PKCE i systemets webbläsare.
- Automatisk länkning bara på verifierad e-post (Supabases standard).
  Manuell länkning (`linkIdentity`) i appen.
- Ingen sammanslagning av konton i v1. Dubbelkonton förebyggs i onboarding.
- M1 implementerar bara e-post-OTP. Övriga providers konfigureras men kopplas i M2.
- Sessionen lagras krypterad (nyckel i SecureStore).

## Konsekvenser
Se AUTH_AND_IDENTITY.md och risk R1.
