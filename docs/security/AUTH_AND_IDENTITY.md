# Inloggning och identitet

> Status: **Godkänd 2026-10-06** (beslut D1–D10 i [OPEN_QUESTIONS](../product/OPEN_QUESTIONS.md)). Implementerad i Milestone 1.

## 1. Metoder

| Metod | Teknik i appen | Supabase | M1 |
|---|---|---|---|
| E-post | Engångskod (OTP, 6 siffror) | `signInWithOtp` + `verifyOtp` | **Implementeras** |
| Apple | `expo-apple-authentication` (native) | `signInWithIdToken('apple')` | Konfig förbereds |
| Google | `@react-native-google-signin/google-signin` (native) | `signInWithIdToken('google')` | Konfig förbereds |
| Facebook | OAuth i systemets webbläsare (`expo-web-browser`, PKCE) | `signInWithOAuth('facebook')` | Konfig förbereds |
| Microsoft | OAuth i systemets webbläsare (PKCE) | `signInWithOAuth('azure')` | Konfig förbereds |

- **E-post med kod i stället för magisk länk:** länkar som öppnar appen kräver
  universal links/app links och en egen domän, och de krånglar i
  webbmejl-klienter. En kod fungerar överallt.
- **Apple-kravet:** App Store kräver Sign in with Apple om appen erbjuder andra
  sociala inloggningar.
- Native-inloggning (Apple/Google) kräver development builds samt konton hos
  Apple och Google. Därför kopplas de i en egen ticket efter M1.

## 2. Identity linking – risk och strategi

**Problemet:** samma person kan logga in med Google ena dagen och Apple nästa,
och få två konton med varsitt (tomt) hushåll.

| Situation | Vad Supabase gör | Risk |
|---|---|---|
| Samma **verifierade** e-post från två providers | Länkar automatiskt till samma användare | Låg |
| Apple "Dölj min e-post" (`…@privaterelay.appleid.com`) | Ny användare | **Hög** – dubbelkonto |
| Facebook utan e-post / med overifierad e-post | Ny användare | Hög |
| Microsoft (Azure) – e-postclaim är inte alltid verifierad | Länkar inte (korrekt, annars kan konton kapas) | Medel – dubbelkonto |

**Strategi:**

1. **Automatisk länkning bara på verifierad e-post** (Supabases standard). Vi
   länkar aldrig själva på overifierad e-post, eftersom det öppnar för
   kontokapning.
2. **Manuell länkning i appen** (`supabase.auth.linkIdentity`). Funktionen
   "Inloggningsmetoder" i inställningar låter en inloggad användare lägga till
   Apple/Google/… på sitt konto. Kräver att *manual linking* slås på i Auth.
3. **Förebygg dubbelkonton i onboarding:**
   - Inloggningsskärmen påminner om den metod som senast användes på enheten
     (sparas lokalt, ingen persondata på servern).
   - En ny användare utan hushåll får först frågan *"Har du blivit inbjuden
     eller har du redan ett konto?"* innan hen kan skapa ett hushåll.
4. **Sammanslagning av konton** (två användare med data) byggs **inte**. Det är
   komplext och riskabelt. Med steg 1–3 blir det sällsynt. En supportrutin
   dokumenteras.
5. **Inbjudningar knutna till e-post** kräver att e-posten matchar en verifierad
   e-post i användarens identiteter. Annars får användaren ett tydligt fel
   ("logga in med kontot för x@…").

## 3. Session och lagring

- Sessionen sparas krypterad: AES-nyckeln ligger i `expo-secure-store`
  (Keychain/Keystore) och den krypterade sessionen i AsyncStorage.
  SecureStore har en storleksgräns (cirka 2 KB) som en Supabase-session kan
  överskrida. Mönstret kommer från Supabases egen Expo-guide.
- `autoRefreshToken` startas och stoppas med `AppState`.
- Utloggning tömmer TanStack Query-cachen och lokalt aktivt hushåll.

## 4. Produktionskrav (dokumenteras, åtgärdas före lansering)

- Egen SMTP (t.ex. Resend/Postmark i EU). Supabases inbyggda e-post har låga
  gränser och är inte avsedd för produktion.
- Auth rate limits, CAPTCHA (hCaptcha/Turnstile) på OTP-begäran.
- Kortlivade JWT (standard 1 h). Möjlighet att logga ut alla sessioner.
- Radering av konto i appen (krav från App Store och Google Play) → Edge
  Function `delete-account` (kräver service role, se DATA_MODEL_CORE §2.3).
