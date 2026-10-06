# ADR-0003: Hushållsmedlem (person) skild från användare (konto)

**Status:** Föreslagen

## Kontext
Barns aktiviteter, rutiner och uppgifter måste kunna knytas till barnet även om
barnet saknar konto. Om domändata refererade `auth.users` skulle barn inte kunna
representeras, och historik skulle behöva flyttas när ett barn får ett konto.

## Beslut
`household_members` representerar en *person i hushållet*, med valfri `user_id`.
All domändata som avser en person refererar `household_members.id`.
Behörighet avgörs av medlemskap där `user_id = auth.uid()`.

## Konsekvenser
- Barn utan konto stöds från dag ett.
- En person kan kopplas till ett konto senare via inbjudan (`member_id` på inbjudan).
- Visningsnamn ligger per hushåll (samma användare kan heta "Pappa" i ett hushåll).
- Personuppgifter om barn lagras – dataminimering och GDPR-dokumentation krävs.
