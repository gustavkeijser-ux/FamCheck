# Audit log

> Status: **Förslag – väntar på godkännande.**

## Händelser

| `action` | När | `metadata` (exempel) | M1 |
|---|---|---|---|
| `household.created` | `create_household` | `{ "name_length": 12 }` | ✅ |
| `household.updated` | `update_household` | `{ "fields": ["name"] }` | ✅ |
| `household.deleted` | `delete_household` | `{}` | ✅ |
| `member.invited` | `create_invitation` | `{ "invitation_id", "role", "has_email": true }` | ✅ |
| `invitation.revoked` | `revoke_invitation` | `{ "invitation_id" }` | ✅ |
| `member.joined` | `accept_invitation` | `{ "invitation_id", "role" }` | ✅ |
| `member.role_changed` | `change_member_role` | `{ "from": "adult", "to": "owner" }` | ✅ |
| `member.removed` | `remove_member` | `{ "role" }` | ✅ |
| `member.left` | `leave_household` | `{}` | ✅ |
| `child.created` | `create_child` | `{}` | ✅ |
| `child.permissions_changed` | `update_child_permissions` | `{ "changed": { "can_view_allowance": [false, true] } }` | ✅ |
| `child.account_linked` | `accept_invitation` med `target_member_id` | `{ "invitation_id" }` | ✅ |
| `account.visibility_changed` | ekonomi (M2+) | `{ "account_id", "from", "to" }` | – |
| `bank.connected` / `bank.disconnected` | Open Banking (framtid) | `{ "provider", "connection_id" }` | – |
| `subscription.changed` | abonnemang (framtid) | `{ "entitlement" }` | – |

## Regler

- **Får aldrig lagras:** tokens (inte heller hashar), lösenord, OAuth-koder,
  API-nycklar, bank-tokens, fullständiga e-postadresser, belopp, namn i fritext.
  Hänvisa med id i stället.
- Skrivs bara av `private.write_audit()`, som anropas av RPC:er och triggers.
- Kan inte ändras eller tas bort via API:et (append-only).
- Läsrätt: `audit.read` (owner) i hushållet.
- **Lagringstid (förslag):** 24 månader. Händelser för raderade hushåll gallras
  efter 90 dagar. Gallringen görs av ett `pg_cron`-jobb i en senare ticket.
  *Kräver ditt beslut, se OPEN_QUESTIONS.*
