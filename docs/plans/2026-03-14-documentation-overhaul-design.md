# Documentation Overhaul — Design

**Date:** 2026-03-14
**Status:** Approved
**Scope:** Cosmetic / documentation only — no business logic changes

## Goal

Transform db-platform from an internal codebase into a professionally documented
open-source framework. Rewrite all function documentation and database object
descriptions in English with meaningful, context-aware content.

## Scope

| Asset | Count | Action |
|-------|------:|--------|
| JSDoc blocks in `routine.sql` + `api.sql` | ~471 | Rewrite in English: `@brief`, `@param`, `@return`, `@throws`, `@see`, `@since 1.0.0` |
| `COMMENT ON` in `table.sql` | ~852 | Rewrite with meaningful English descriptions (tables + columns) |
| Inline comments in `.sql` | hundreds | Remove obvious ones, translate useful ones to English |
| JSDoc blocks in `rest.sql`, `event.sql`, etc. | varies | Same format where blocks exist |

## JSDoc Format

```sql
/**
 * @brief Authenticates a virtual user by username and password.
 * @param {text} pUserName - Login name of the virtual user
 * @param {text} pPassword - Plain-text password (verified against salted hash)
 * @return {record} - Session record: session token, HMAC-256 secret, OAuth2 authorization code
 * @throws LoginFailed - If credentials are invalid or account is locked
 * @see SignOut, Authenticate
 * @since 1.0.0
 */
```

### Rules

- `@brief` — one sentence describing what the function does (action, not "returns")
- `@param` — purpose in business-logic context, not a translation of the parameter name
- `@return` — concrete description including structure for record/SETOF types
- `@throws` — only when the function explicitly calls `PERFORM SomeException()`
- `@see` — related functions (Edit for Create, Get for List, etc.)
- `@since 1.0.0` — everywhere as a baseline; real tracking starts with new functions

## COMMENT ON Format

```sql
COMMENT ON TABLE db.session IS 'Active user sessions with JWT tokens and expiration tracking.';
COMMENT ON COLUMN db.session.token IS 'Unique session token (UUID). Used as the primary session identifier in HTTP headers.';
```

### Rules

- Table: one or two sentences about its role in the system
- Column: describe **purpose** and **constraints** (data type is obvious from DDL)

## Processing Order

Strictly follows `create.psql` (25 modules):

```
kernel -> oauth2 -> locale -> admin -> http -> resource -> exception ->
registry -> log -> api -> replication -> daemon -> session -> current ->
workflow -> kladr -> file -> entity -> notice -> comment ->
notification -> verification -> observer -> report -> reports
```

Within each module:

1. `table.sql` — `COMMENT ON` (understand data structure first)
2. `routine.sql` — JSDoc (core business logic)
3. `api.sql` — JSDoc (API wrappers)
4. `rest.sql`, `event.sql`, others — JSDoc where blocks exist
5. Inline comments — cleanup along the way

## Inline Comment Policy

- **Remove** comments that restate the code (`-- update the value` before `UPDATE`)
- **Translate** comments that explain business logic (`-- For all RF regions`)
- **Keep Russian** only where it is part of business data or system constants

## Out of Scope

- Code refactoring or business logic changes
- SQL auto-formatting tools
- `init.sql` seed data (Russian state/method names are business data)
- `INDEX.md` files (already in English)
- String literals inside functions (data, not documentation)

## Deliverables

One commit per module (or group of small modules). Each commit contains a fully
documented module with no business logic changes.
