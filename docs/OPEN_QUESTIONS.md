# Öppna frågor & antaganden

Antaganden används tills de besvaras. Ändrade svar uppdateras här och i berörd ADR.

## Öppna frågor

| # | Fråga | Antagande tills vidare | Påverkar |
|---|---|---|---|
| Q1 | Ursprungliga specifikationen bröts av mitt i en mening ("…om den"). Finns fler krav/principer? | Gemensam data knyts alltid till hushållet | Allt |
| Q2 | Ska vuxna kunna ha **privata** konton/transaktioner som den andra vuxna inte ser? | Ja, via `visibility = private` på ekonomiska konton | Ekonomi-RLS |
| Q3 | Ska barn kunna få **egna konton** och logga in? När? | Barn är personer utan konto i v1; modellen stödjer koppling senare | Roller, RLS, GDPR |
| Q4 | Vilken modul först efter grunden: kalender eller ekonomi? | Kalender → uppgifter/rutiner → notiser → ekonomi | Roadmap |
| Q5 | Inloggningsmetoder? | E-post (OTP/magic link) + Sign in with Apple; Google på Android | Fas 1 |
| Q6 | Behövs offline-redigering i v1? | Nej – online-först med lokal cache | ADR-0002 |
| Q7 | Synk med extern kalender (Google/iCloud, skolans/klubbens iCal)? | Inte i v1; ev. import av iCal-länk senare | Kalender |
| Q8 | Bankkoppling (open banking) – önskemål på sikt? | Ja på sikt; förbered datamodell, bygg inte | Ekonomi |
| Q9 | Affärsmodell: freemium, prenumeration, gratis provperiod? | Prenumeration per hushåll, freemium-gräns | Fas 7 |
| Q10 | Supabase-region: Stockholm (`eu-north-1`) eller Frankfurt? | Stockholm om tillgängligt för planen, annars Frankfurt | Drift, GDPR |
| Q11 | Finns befintligt Supabase-projekt, Apple Developer- och Google Play-konto? | Nej – skapas i Fas 1 | Fas 1 |
| Q12 | Varumärke/namn "FamCheck" slutgiltigt? Bundle id? | Arbetsnamn; `se.famcheck.app` som platshållare | Fas 1 |

## Dokumenterade antaganden

- A1: Ett hushåll kan ha flera vuxna med lika rättigheter (`adult`) och minst en `owner`.
- A2: En användare kan tillhöra flera hushåll; appen visar ett aktivt hushåll i taget.
- A3: Valuta per hushåll, default SEK. Ingen valutaomräkning i v1.
- A4: Svenska är primärt språk; all UI-text går ändå via i18n från start.
