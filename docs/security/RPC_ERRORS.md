# Felkoder från databasens RPC:er

RPC:erna kastar stabila felnycklar i `message`. Appen översätter dem via i18n och
visar aldrig serverns råa text. HTTP-status kommer från PostgREST:s mappning av SQLSTATE.

| SQLSTATE | `message` | Betydelse |
|---|---|---|
| 42501 | `not_authenticated` | Ingen inloggad användare |
| 42501 | `forbidden` | Saknar förmåga **eller** resursen finns inte. Samma svar avslöjar inte andra hushålls id:n |
| 22023 | `invalid_household_name`, `invalid_display_name`, `invalid_color`, `invalid_role`, `invalid_expiry`, `invalid_email`, `invalid_target_member`, `invalid_timezone`, `birth_date_in_future` | Ogiltig indata |
| P0001 | `last_owner` | D9: åtgärden skulle lämna hushållet utan owner |
| P0001 | `use_leave_household` | Man tar inte bort sig själv via `remove_member` |
| P0001 | `role_change_not_supported` | Byte mellan barn- och vuxenroll stöds inte |
| P0001 | `confirmation_mismatch` | Hushållets namn bekräftades inte korrekt vid radering |
| P0001 | `household_limit_reached`, `member_limit_reached`, `invitation_limit_reached` | Gränser mot missbruk (10 egna hushåll, 30 medlemmar, 20 öppna inbjudningar) |
| P0001 | `invitation_not_found` | Okänd token eller felaktigt format |
| P0001 | `invitation_expired`, `invitation_revoked`, `invitation_accepted` | Inbjudan kan inte längre användas |
| P0001 | `invitation_email_mismatch` | Inbjudan gäller en annan (eller overifierad) e-post |
| P0001 | `invitation_target_unavailable`, `invitation_role_conflict`, `already_member` | Inbjudan kan inte tillämpas på den här användaren |
| P0001 | `invitation_not_pending` | Endast öppna inbjudningar kan återkallas |
| 23514 | `household_requires_owner`, `child_member_requires_children_row`, `adult_member_cannot_have_children_row`, `children_row_requires_child_role` | Integritetsregler vid commit. Ska aldrig nås via RPC:erna, de är sista skyddsnätet |
