# Audit log

> Status: **Godkänd 2026-10-06** (beslut D1–D10 i [OPEN_QUESTIONS](../product/OPEN_QUESTIONS.md)). Implementerad i Milestone 1.

## Händelser

| `action` | När | `metadata` (exempel) | M1 |
|---|---|---|---|
| `household.created` | `create_household` | `{}` | ✅ |
| `household.updated` | `update_household` | `{ "fields": ["name"] }` | ✅ |
| `household.deleted` | `delete_household` | `{}` | ✅ |
| `member.invited` | `create_invitation` | `{ "invitation_id", "role", "has_email": true }` | ✅ |
| `invitation.revoked` | `revoke_invitation` | `{ "invitation_id" }` | ✅ |
| `member.joined` | `accept_invitation` | `{ "invitation_id", "role" }` | ✅ |
| `member.role_changed` | `change_member_role` | `{ "from": "adult", "to": "owner" }` | ✅ |
| `member.removed` | `remove_member` | `{ "role": "adult" }` | ✅ |
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
- **Lagringstid (D8):** 24 månader. När ett hushåll raderas nollställs aktör,
  mål och metadata på alla dess händelser direkt. Händelsetyp och tidpunkt sparas
  i högst 90 dagar. `private.purge_audit_log()` gallrar (testad). **Schemaläggning
  med `pg_cron` återstår** och görs när staging finns (M2).
- Händelsen `household.created` saknar metadata, eftersom hushållets namn är
  onödig persondata i en logg.
