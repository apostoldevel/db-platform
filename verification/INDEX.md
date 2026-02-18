# verification

> Platform module #22 | Loaded by `create.psql` line 22

Code-based email and phone verification. Generates time-bounded verification codes (UUID for email/1 day, 6-digit numeric for phone/5 minutes), validates them, and marks user profiles as verified upon confirmation. Integrates with OAuth2 for triggering application-level confirmation workflows.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel`, `admin` (users, profiles), `oauth2` (secret lookup for confirmation) | `entity/object/document/message` (sends verification codes via email/SMS) |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `db` | 1 table (verification_code) + 1 trigger |
| `kernel` | 1 view, 5 functions |
| `api` | 1 view, 5 functions |
| `rest` | `rest.verification` dispatcher (6 routes) |

## Tables — 1

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.verification_code` | Time-bounded verification codes | `id uuid PK`, `userid uuid FK`, `type char(1)` (`'M'`=email, `'P'`=phone), `code text`, `used timestamptz`, `validFromDate timestamptz`, `validToDate timestamptz` |

**Type behavior:**
- `'M'` (email): UUID code, 1 day validity
- `'P'` (phone): 6-digit random number, 5 minute validity

**Unique constraint:** `(type, userid, validFromDate, validToDate)`.

## Triggers — 1

| Trigger | Table | Timing | Purpose |
|---------|-------|--------|---------|
| `t_verification_code_before` | `db.verification_code` | BEFORE INSERT/UPDATE/DELETE | Auto-generate code, set validity window, prevent type/code modification (logs "Hacking alert") |

## Views — 1

| View | Description |
|------|-------------|
| `VerificationCode` | Codes for `current_userid()`, type mapped: `'M'`→`'email'`, `'P'`→`'phone'` |

## Functions (kernel schema) — 5

| Function | Returns | Purpose |
|----------|---------|---------|
| `NewVerificationCode(pUserId, pType, pCode)` | `uuid` | Generate new code (auto-generates if NULL) |
| `AddVerificationCode(pUserId, pType, pCode, pDateFrom, pDateTo)` | `uuid` | Low-level: handles existing code overlap (marks old as used) |
| `GetVerificationCode(pId)` | `text` | Get code value by ID |
| `CheckVerificationCode(pType, pCode)` | `uuid` | Validate code: check type, validity window, not-used. Returns userid or NULL |
| `ConfirmVerificationCode(pType, pCode)` | `uuid` | Check + mark `email_verified`/`phone_verified` on `db.profile` |

## Functions (api schema) — 5

| Function | Returns | Purpose |
|----------|---------|---------|
| `api.new_verification_code(pType, pCode, pUserId)` | `SETOF api.verification_code` | Generate code, return record |
| `api.confirm_verification_code(pType, pCode)` | `record(result bool, message text)` | Confirm code + trigger `DoConfirmEmail`/`DoConfirmPhone` via apibot substitution |
| `api.get_verification_code(pId)` | `SETOF api.verification_code` | Get by ID |
| `api.list_verification_code(pSearch, pFilter, pLimit, pOffSet, pOrderBy)` | `SETOF api.verification_code` | List (admin only) |

## REST Routes — 6

Dispatcher: `rest.verification(pPath text, pPayload jsonb)`.

| Path | Purpose |
|------|---------|
| `/verification/email/code` | Generate email verification code |
| `/verification/phone/code` | Generate phone verification code |
| `/verification/email/confirm` | Confirm email with code |
| `/verification/phone/confirm` | Confirm phone with code |
| `/verification/code/get` | Get verification code by ID |
| `/verification/code/list` | List codes (admin only) |

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `table.sql` | yes | no | 1 table + 1 trigger |
| `view.sql` | yes | yes | VerificationCode view |
| `routine.sql` | yes | yes | 5 kernel functions |
| `api.sql` | yes | yes | 1 api view + 5 api functions |
| `rest.sql` | yes | yes | `rest.verification` dispatcher (6 routes) |
| `create.psql` | - | - | Includes all |
| `update.psql` | - | - | Excludes table.sql |
