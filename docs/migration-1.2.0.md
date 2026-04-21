# Migration Guide -- Platform 1.2.0

## Overview

Platform 1.2.0 introduces a unified, locale-aware exception system with structured error codes, a searchable error catalog, and multi-language support (en, ru, de, fr, it, es).

## Breaking Changes

None. All changes are backward compatible.

## New Features

### Structured Error Codes (ERR-GGG-CCC)

Error codes now use a dash-separated format: `ERR-GGG-CCC`

- `GGG` -- HTTP status group (400, 401, 403, 500)
- `CCC` -- unique code within group (001--999)
- Example: `ERR-400-001` (Access denied), `ERR-401-001` (Login failed)

The old format `ERR-GGGCC` (e.g., `ERR-40001`) is still supported by `ParseMessage()` and automatically converted to the new format.

### JSON Error Response

API error responses now include an `error` field:

```json
{"error": {"code": 400, "error": "ERR-400-001", "message": "Access denied."}}
```

- `code` (int) -- HTTP status code. **Unchanged.**
- `error` (string) -- Structured error identifier. **New field.**
- `message` (string) -- Human-readable, locale-aware message. **Unchanged.**

Existing frontends parsing `code` and `message` continue to work without changes.

### Error Catalog API

New REST endpoints for error lookup:

- `GET /api/v1/error/code` -- look up error by code (`{"code": "ERR-400-001"}`)
- `POST /api/v1/error/list` -- list errors with search, filter, pagination
- `POST /api/v1/error/count` -- count errors by filter

### 6-Language Support

Error messages are now available in: English, Russian, German, French, Italian, Spanish.
The system falls back to English when a translation is missing for the current locale.

## Migration Steps for Downstream Projects

### 1. Register Project-Specific Exceptions

Replace `CreateExceptionResource()` calls with `RegisterError()`:

**Before (1.1.x):**

```sql
SELECT CreateExceptionResource(GetExceptionUUID(400, 200), 'en', 'MyError', 'My custom error');
SELECT CreateExceptionResource(GetExceptionUUID(400, 200), 'ru', 'MyError', 'Моя ошибка');
```

**After (1.2.0):**

```sql
SELECT RegisterError('ERR-400-200', 400, 'E', 'validation', 'en', 'My custom error');
SELECT RegisterError('ERR-400-200', 400, 'E', 'validation', 'ru', 'Моя ошибка');
```

`CreateExceptionResource()` still works during the transition period.

### 2. Replace Hardcoded Russian Strings

Replace Russian text in `ObjectNotFound()` and `SetErrorMessage()` calls with English:

```sql
-- Before
PERFORM ObjectNotFound('объект', 'id', pId);
-- After
PERFORM ObjectNotFound('object', 'id', pId);
```

### 3. Translate Event Log Messages

Replace Russian event log strings with English:

```sql
-- Before
PERFORM WriteToEventLog('M', uId, 'create', 'Объект создан.');
-- After
PERFORM WriteToEventLog('M', uId, 'create', 'Object created.');
```

### 4. Code Mapping (Old to New)

The following table maps all 80 platform error codes from the old `ERR-GGGCC` format to the new `ERR-GGG-CCC` format.

#### Authentication (401)

| Old Code | New Code | Function | Message |
|----------|----------|----------|---------|
| ERR-40101 | ERR-401-001 | LoginFailed | Login failed |
| ERR-40102 | ERR-401-002 | AuthenticateError | Authenticate Error. %s |
| ERR-40103 | ERR-401-003 | LoginError | Check the username is correct and enter the password again |
| ERR-40104 | ERR-401-004 | UserLockError | Account is blocked |
| ERR-40105 | ERR-401-005 | UserTempLockError | Account is temporarily locked until %s |
| ERR-40106 | ERR-401-006 | PasswordExpired | Password expired |
| ERR-40107 | ERR-401-007 | SignatureError | Signature is incorrect or missing |

#### Access Control (403)

| Old Code | New Code | Function | Message |
|----------|----------|----------|---------|
| ERR-40301 | ERR-403-001 | TokenExpired | Token not FOUND or has expired |

#### Client Errors (400)

| Old Code | New Code | Function | Message |
|----------|----------|----------|---------|
| ERR-40001 | ERR-400-001 | AccessDenied | Access denied |
| ERR-40002 | ERR-400-002 | AccessDeniedForUser | Access denied for user %s |
| ERR-40003 | ERR-400-003 | ExecuteMethodError | Insufficient rights to execute method: %s |
| ERR-40004 | ERR-400-004 | NonceExpired | Request timed out |
| ERR-40005 | ERR-400-005 | TokenError | Token invalid |
| ERR-40006 | ERR-400-006 | TokenBelong | Token belongs to the other client |
| ERR-40007 | ERR-400-007 | InvalidScope | Some requested areas were invalid: {valid=[%s], invalid=[%s]} |
| ERR-40008 | ERR-400-008 | AbstractError | An abstract class cannot have objects |
| ERR-40009 | ERR-400-009 | ChangeClassError | Object class change is not allowed |
| ERR-40010 | ERR-400-010 | ChangeAreaError | Changing document area is not allowed |
| ERR-40011 | ERR-400-011 | IncorrectEntity | Object entity is set incorrectly |
| ERR-40012 | ERR-400-012 | IncorrectClassType | Invalid object type |
| ERR-40013 | ERR-400-013 | IncorrectDocumentType | Invalid document type |
| ERR-40014 | ERR-400-014 | IncorrectLocaleCode | Locale not FOUND by code: %s |
| ERR-40015 | ERR-400-015 | RootAreaError | Operations with documents in root area are prohibited |
| ERR-40016 | ERR-400-016 | AreaError | Area not FOUND by specified identifier |
| ERR-40017 | ERR-400-017 | IncorrectAreaCode | Area not FOUND by code: %s |
| ERR-40018 | ERR-400-018 | UserNotMemberArea | User "%s" does not have access to area "%s" |
| ERR-40019 | ERR-400-019 | InterfaceError | Interface not FOUND by specified identifier |
| ERR-40020 | ERR-400-020 | UserNotMemberInterface | User "%s" does not have access to interface "%s" |
| ERR-40021 | ERR-400-021 | UnknownRoleName | Unknown role name: %s |
| ERR-40022 | ERR-400-022 | RoleExists | Role "%s" already exists |
| ERR-40023 | ERR-400-023 | UserNotFound | User "%s" does not exist |
| ERR-40024 | ERR-400-024 | UserIdNotFound | User with id "%s" does not exist |
| ERR-40025 | ERR-400-025 | DeleteUserError | You cannot delete yourself |
| ERR-40026 | ERR-400-026 | AlreadyExists | %s already exists |
| ERR-40027 | ERR-400-027 | RecordExists | Entry with code "%s" already exists |
| ERR-40028 | ERR-400-028 | InvalidCodes | Some codes were invalid: {valid=[%s], invalid=[%s]} |
| ERR-40029 | ERR-400-029 | IncorrectCode | Invalid code "%s". Valid codes: [%s] |
| ERR-40030 | ERR-400-030 | ObjectNotFound | Not FOUND %s with %s: %s |
| ERR-40031 | ERR-400-031 | ObjectIdIsNull | Not FOUND %s with %s: \<null\> |
| ERR-40032 | ERR-400-032 | MethodActionNotFound | Object [%s] method not FOUND, for action: %s [%s]. Current state: %s [%s] |
| ERR-40033 | ERR-400-033 | MethodNotFound | Method "%s" of object "%s" not FOUND |
| ERR-40034 | ERR-400-034 | MethodByCodeNotFound | No method FOUND by code "%s" for object "%s" |
| ERR-40035 | ERR-400-035 | ChangeObjectStateError | Failed to change object state: %s |
| ERR-40036 | ERR-400-036 | ChangesNotAllowed | Changes are not allowed |
| ERR-40037 | ERR-400-037 | StateByCodeNotFound | No state FOUND by code "%s" for object "%s" |
| ERR-40038 | ERR-400-038 | MethodIsEmpty | Method ID must not be empty |
| ERR-40039 | ERR-400-039 | ActionIsEmpty | Action ID must not be empty |
| ERR-40040 | ERR-400-040 | ExecutorIsEmpty | The executor must not be empty |
| ERR-40041 | ERR-400-041 | IncorrectDateInterval | The end date of the period cannot be less than the start date of the period |
| ERR-40042 | ERR-400-042 | UserPasswordChange | Password change failed, password change is prohibited |
| ERR-40043 | ERR-400-043 | SystemRoleError | Change, delete operations for system roles are prohibited |
| ERR-40044 | ERR-400-044 | LoginIpTableError | Login is not possible. Limited access by IP-address: %s |
| ERR-40045 | ERR-400-045 | OperationNotPossible | Operation is not possible, there are related documents |
| ERR-40046 | ERR-400-046 | ViewNotFound | View "%s.%s" not FOUND |
| ERR-40047 | ERR-400-047 | InvalidVerificationCodeType | Invalid verification type code: %s |
| ERR-40048 | ERR-400-048 | InvalidPhoneNumber | Invalid phone number: %s |
| ERR-40049 | ERR-400-049 | ObjectIsNull | Object id not specified |
| ERR-40050 | ERR-400-050 | PerformActionError | You cannot perform this action |
| ERR-40051 | ERR-400-051 | IdentityNotConfirmed | Identity not confirmed |
| ERR-40052 | ERR-400-052 | ReadOnlyError | Modify operations for read-only roles are not allowed |
| ERR-40053 | ERR-400-053 | ActionAlreadyCompleted | You have already completed this action |
| ERR-40060 | ERR-400-060 | JsonIsEmpty | JSON must not be empty |
| ERR-40061 | ERR-400-061 | IncorrectJsonKey | (%s) Invalid key "%s". Valid keys: [%s] |
| ERR-40062 | ERR-400-062 | JsonKeyNotFound | (%s) Required key not FOUND: %s |
| ERR-40063 | ERR-400-063 | IncorrectJsonType | Invalid type "%s", expected "%s" |
| ERR-40064 | ERR-400-064 | IncorrectKeyInArray | Invalid key "%s" in array "%s". Valid keys: [%s] |
| ERR-40065 | ERR-400-065 | IncorrectValueInArray | Invalid value "%s" in array "%s". Valid values: [%s] |
| ERR-40066 | ERR-400-066 | ValueOutOfRange | Value [%s] is out of range |
| ERR-40067 | ERR-400-067 | DateValidityPeriod | The start date must not exceed the end date |
| ERR-40070 | ERR-400-070 | IssuerNotFound | OAuth 2.0: Issuer not FOUND: %s |
| ERR-40071 | ERR-400-071 | AudienceNotFound | OAuth 2.0: Client not FOUND |
| ERR-40072 | ERR-400-072 | GuestAreaError | Operations with documents in guest area are prohibited |
| ERR-40073 | ERR-400-073 | NotFound | Not found |
| ERR-40074 | ERR-400-074 | DefaultAreaDocumentError | The document can only be changed in the "Default" area |
| ERR-40080 | ERR-400-080 | IncorrectRegistryKey | Invalid key "%s". Valid keys: [%s] |
| ERR-40081 | ERR-400-081 | IncorrectRegistryDataType | Invalid data type: %s |
| ERR-40090 | ERR-400-090 | RouteIsEmpty | Path must not be empty |
| ERR-40091 | ERR-400-091 | RouteNotFound | Route not found: %s |
| ERR-40092 | ERR-400-092 | EndPointNotSet | Endpoint not set for path: %s |
| ERR-400100 | ERR-400-100 | SomethingWentWrong | Oops, something went wrong. Our engineers are already working on fixing the error |

### 5. Wrap Inline `RAISE EXCEPTION` Into Named Functions

Prior to 1.2.0 it was common to raise ad-hoc exceptions inline with generic codes:

```sql
RAISE EXCEPTION 'ERR-40000: Bank card not found.';
RAISE EXCEPTION 'ERR-40000: Not found order by code: %', orderNumber;
```

After 1.2.0 each distinct runtime error must be registered once (6 locales) and wrapped
in a named `exception.sql` function. This lets the catalog describe it, the frontend
render it in the user's locale, and future auditors find it via `error/list`.

**Example from `configuration/copyfrog/entity/object/document/client/exception.sql`:**

```sql
--------------------------------------------------------------------------------
-- FUNCTION ClientCodeExists  --------------------------------------------------
--------------------------------------------------------------------------------

SELECT RegisterError('ERR-400-210', 400, 'E', 'validation', 'en', 'Client with code "%s" already exists.');
SELECT RegisterError('ERR-400-210', 400, 'E', 'validation', 'ru', 'Клиент с кодом "%s" уже существует.');
SELECT RegisterError('ERR-400-210', 400, 'E', 'validation', 'de', 'Kunde mit Code "%s" existiert bereits.');
SELECT RegisterError('ERR-400-210', 400, 'E', 'validation', 'fr', 'Le client avec le code « %s » existe déjà.');
SELECT RegisterError('ERR-400-210', 400, 'E', 'validation', 'it', 'Il cliente con codice "%s" esiste già.');
SELECT RegisterError('ERR-400-210', 400, 'E', 'validation', 'es', 'El cliente con código "%s" ya existe.');

CREATE OR REPLACE FUNCTION ClientCodeExists (
  pCode     text
) RETURNS   void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-400-210: %', format(GetErrorCatalogMessage('ERR-400-210'), pCode);
END;
$$ LANGUAGE plpgsql STABLE STRICT;
```

**Usage at callsite becomes:**

```sql
-- Before
RAISE EXCEPTION 'ERR-40000: Client with code "%" already exists.', pCode;

-- After
PERFORM ClientCodeExists(pCode);
```

**Audit procedure:**

```bash
grep -rnE "RAISE EXCEPTION 'ERR-40000|RAISE EXCEPTION 'ERR-400[0-9]{2}[^-]" \
  configuration/<dbname>/ --include="*.sql"
```

Each match needs a named function + 6-locale `RegisterError` block (8 locales if
the project adds `cs`/`sk` or other languages beyond the platform's base six).
Allocate codes starting at `ERR-400-101` (first 100 reserved for the platform).
**Leave a gap for platform growth** — reserve `ERR-400-101..149` for project
error codes added before the wrapping pass, then start the pass itself at
`ERR-400-150` so future platform updates (`ERR-400-133..149`, etc.) don't
collide with existing project codes.

Inline `RAISE EXCEPTION` in `patch/P*.sql` scripts can stay — those are one-shot
migrations, not runtime code.

**Reference implementation — apostol-csms.** The full wrapping pass against the
ChargeMeCar configuration yielded this code layout (copyable as a starting point
for other downstream projects):

| Range | Module | Examples |
|-------|--------|----------|
| `ERR-400-101..132` | pre-existing per-entity exceptions | `AccountCodeExists`, `CardCodeExists`, `InvoiceCodeExists`, `ActionNotFound` |
| `ERR-400-150..165` | `entity/object/document/charge_point/connector/exception.sql` | `ConnectorNotActive`, `ChargePointNotActive`, `ServiceNotTariffed`, `ConnectorAlreadyReserved`, `ActiveReservationNotFound` |
| `ERR-400-166..179` | `stripe/exception.sql` | `AuthenticationRequired`, `InvalidStripeWebhookSignature`, `StripeAccountAlreadyExists`, `NoStripeCustomer`, `AutoTopupRequiresSavedCard` |
| `ERR-400-180..188` | `entity/object/document/message/exception.sql` | `ParentCannotBeNull`, `OrderNotFoundByCode`, `OrderNotFoundByNumber`, `CardNotFoundByClient` |
| `ERR-400-200..206` | `entity/object/document/transaction/exception.sql` | `ChargePointTransactionNotFound`, `TransactionNotFoundById`, `ServiceNotChargedForNetwork`, `ReservationNotFound` |
| `ERR-400-207..208` | `entity/object/document/account/exception.sql` (moved here because `account/` loads before `order/` and `payment/`) | `DebitAccountForCurrencyNotFound`, `CreditAccountForCurrencyNotFound` |
| `ERR-400-209..216` + `235..237` | `entity/object/document/client/tenant/exception.sql` | `ClientNotTenant`, `OnlyOwnerOrAdminCanInvite`, `InvitationDifferentEmail`, `CannotDeleteTenantActiveInvoices` |
| `ERR-400-217..220` + `238..239` | `entity/object/document/account/exception.sql` | `UncompletedDebitOperations`, `AccountBalanceNonZero`, `DebitAccountNotFound` |
| `ERR-400-221..224` | `entity/object/document/card/exception.sql` | `UncompletedTransactions`, `DebtDetected`, `CardAlreadyBinding`, `UnknownPaymentSystem` |
| `ERR-400-225..228` | `api/exception.sql` (new) | `AccountNameAlreadyRegistered`, `RethrowError` |
| `ERR-400-229..231` | `entity/object/document/tariff/exception.sql` (loaded **before** `table.sql` because the trigger depends on these helpers) | `NetworksDoNotMatch`, `ServicesDoNotMatch`, `ModesDoNotMatch` |
| `ERR-400-232..234` | `entity/object/document/client/driver/exception.sql` (new) | `CannotDeleteDriverActiveTransactions`, `CannotDeleteDriverUnpaidInvoices` |
| `ERR-400-240..250` | per-module one-offs | `NoFailedInvoicesToRetry`, `InvalidOrderAmount`, `CannotRemoveOwnerFromTenant`, `DataDetectedOperationAborted`, `CardNotBindingToBank`, `ClientHasNoStripeCustomer`, `ConnectorAlreadyLocked`, `TransactionsDetectedOperationAborted`, `TransactionNumberNotFound`, `NotSupported`, `DateNotFoundInCalendar` |

Scale: **85 new wrapper functions × 8 locales = 680 `RegisterError` rows** added
on top of the 32 pre-existing per-entity ones. 147 inline `RAISE EXCEPTION`
callsites rewritten to `PERFORM <Function>(...)`.

**Placement rules learned from the pass:**

- **Cross-module helpers** (e.g. debit/credit account errors used by both
  `order/` and `payment/`) must live in the **earliest-loading** module along
  the dependency chain. For apostol-csms that's `account/exception.sql`, which
  loads before `order/` and `payment/` inside `entity/object/document/create.psql`.
- **Trigger-function dependencies** (e.g. `tariff/table.sql` trigger calling
  `NetworksDoNotMatch()`) require the wrapper's `exception.sql` to be included
  in `create.psql`/`update.psql` **before** `table.sql`. PostgreSQL's
  `check_function_bodies` validates the references at `CREATE FUNCTION` time.
- **Stub `exception.sql` files** shipped empty in some modules (`payment/stripe/`,
  `transaction/`) should be filled in place — the `create.psql`/`update.psql`
  already include them.
- **New modules without `exception.sql`** (`tenant/`, `driver/`, `yookassa/`,
  `calendar/`, `stripe/`, `message/`, `api/`, `tariff/`) require the file to be
  **added and wired** into both `create.psql` and `update.psql`.
- **`RethrowError(text)`** (ERR-400-228, format `%s`) is a convenience wrapper
  for `RAISE EXCEPTION 'ERR-XXX-XXX: %', GetErrorMessage()` patterns inside
  `EXCEPTION WHEN OTHERS` blocks. Use it when re-raising a caught exception
  that already has a prepared message rather than inventing a new catalog entry.

### 6. Replace Hardcoded Runtime Strings With Localized Dictionaries

Runtime messages shown to users — push notifications, emails, SMS, view labels — must
pick the recipient's language at call time, not session locale.

> **Recommended final shape: `i18n/` resource module.** Inline jsonb patterns below
> (A–E) are **transitional**. The destination state is a per-project `configuration/<dbname>/i18n/`
> module that stores all strings in `db.resource` / `db.resource_data` (platform's
> `resource` module) and exposes two helpers:
>
> ```sql
> CreateI18NResource(pName text, pLocaleCode text, pData text) RETURNS uuid
> GetI18NResource(pName text, pLocale uuid DEFAULT current_locale()) RETURNS text
> ```
>
> Callsites then read `GetI18NResource('push.invoice.title', uLocale)` instead of
> inline `jsonb->>vLang`. Registrations live in `i18n/init.sql` — one
> `CreateI18NResource` per (key, locale). See `configuration/csms/i18n/` in the
> apostol-csms tree for a working reference (~90 keys × 8 locales).
>
> Why resource-based beats inline jsonb:
>
> | Criterion | inline jsonb | `i18n/` resource |
> |-----------|--------------|------------------|
> | Where it lives | in function bodies | `db.resource_data` rows |
> | Edit without redeploy | no | yes, via `POST /api/v1/resource/set` |
> | Audit / export | grep through sources | `POST /api/v1/resource/list` |
> | Duplication of shared phrases | duplicated across files | one key, reused everywhere |
> | Runtime check for missing locale | manual `IF NOT j ? lang` | built into `GetI18NResource` (falls back to `en`) |
> | Seed source of truth | scattered | single `i18n/init.sql` |
>
> Each pattern below (A–E) has a **resource-based equivalent** shown at the end of
> the section. Use inline jsonb only when migrating incrementally; new code should
> go straight to `GetI18NResource`.

**Pattern A: client push / SMS (recipient = client)**

```sql
-- Before
PERFORM SendPush(pConnector, 'Счёт на оплату',
  format('Сформирован счёт на сумму %s рублей.', r.amount),
  GetClientUserId(r.client));

-- After
DECLARE
  vLang     text;
  vCurrency text;
  jMsg      jsonb;
BEGIN
  vLang     := coalesce(GetLocaleCode(GetDefaultLocale(GetClientUserId(r.client))), 'en');
  vCurrency := GetCurrencyCode(r.currency);
  jMsg      := '{"en":["Invoice to pay","Invoice issued for %s %s."],
                 "ru":["Счёт на оплату","Сформирован счёт на сумму %s %s."],
                 "de":[...], "fr":[...], "it":[...], "es":[...]}'::jsonb;

  PERFORM SendPush(pConnector,
    jMsg->vLang->>0,
    format(jMsg->vLang->>1, r.amount, vCurrency),
    GetClientUserId(r.client));
END;
```

Always use `GetDefaultLocale(GetClientUserId(...))` to resolve the client's own locale
— `current_locale()` reflects the session that triggered the event, not the recipient.

**Pattern B: operator alerts (recipient = support/oncall)**

Use `current_locale()` — the session locale of whoever is receiving the notification
is not known at write time (the alert may be fanned out to multiple recipients later).

```sql
vLang := coalesce(GetLocaleCode(current_locale()), 'en');
jSubj := '{"en":"Station %s: connectivity issue", "ru":"%s: Проблемы со связью", ...}'::jsonb;
PERFORM ConnectorSendAlertMail(pObject, format(jSubj->>vLang, vIdentity), vMessage);
```

**Pattern C: multi-row logs (jsonb overload)**

When a log function writes one row per locale (e.g. `WriteToDefectLog`), add a jsonb
overload so callsites pass all 8 translations in one call:

```sql
CREATE OR REPLACE FUNCTION WriteToDefectLog (
  pDefect       uuid,
  pEvent        text,
  pNames        jsonb,           -- {"en":"Opened","ru":"Открыт",...}
  pDescription  text DEFAULT null
) RETURNS void
AS $$ ... $$;

-- Callsite:
PERFORM WriteToDefectLog(pObject, 'create',
  '{"en":"Opened","ru":"Открыт","de":"Geöffnet",...}'::jsonb,
  'Defect created.');
```

**Pattern D: VIEW-level labels**

Extract the `CASE` block into a `STABLE STRICT` function that consults a jsonb
dictionary keyed by locale code:

```sql
CREATE OR REPLACE FUNCTION GetCalendarDayFlagLabel (pFlag bit(4)) RETURNS text ...

-- Then in VIEW:
SELECT id, calendar, userid, date,
       GetCalendarDayFlagLabel(flag), ...
  FROM db.cdate;
```

**Pattern E: email/HTML templates (recipient locale passed in)**

Collapse nested `IF pLocale = 'ru' THEN ... ELSE ...` branches to a single jsonb
table + a `->>` lookup:

```sql
DECLARE
  jGreet jsonb := '{"en":"Hey","ru":"Здравствуйте","de":"Hallo",...}'::jsonb;
  jTeam  jsonb := '{"en":"- %s Team.","ru":"- Команда %s",...}'::jsonb;
BEGIN
  pLocale := coalesce(pLocale, 'en');
  IF NOT jGreet ? pLocale THEN pLocale := 'en'; END IF;

  Lines[1] := (jGreet->>pLocale) || format(', %s', pName) || '!';
  Lines[5] := format(jTeam->>pLocale, pProject);
  ...
```

Do not store the localized text in `db.<table>` description columns. Stored descriptions
are written once and outlive their locale — use English there, and localize at read time.

---

**Resource-based equivalents (target state)**

Once the project has an `i18n/` module loaded first in `configuration/<dbname>/create.psql`,
rewrite each inline-jsonb pattern against `GetI18NResource`:

```sql
-- Pattern A (client push) — resource-based
uLocale := GetDefaultLocale(GetClientUserId(r.client));
PERFORM SendPush(pConnector,
  GetI18NResource('push.invoice.title', uLocale),
  format(GetI18NResource('push.invoice.body', uLocale), r.amount, vCurrency),
  GetClientUserId(r.client));

-- Pattern B (operator alert) — resource-based
PERFORM ConnectorSendAlertMail(pObject,
  format(GetI18NResource('alert.charge_point.offline.subject'), vIdentity),
  format('%s (%s): %s', vIdentity, GetObjectLabel(pObject),
         GetI18NResource('alert.charge_point.offline.message')));

-- Pattern C (multi-row log) — dedicated i18n overload
CREATE OR REPLACE FUNCTION WriteToDefectLogI18N (
  pDefect  uuid, pEvent text, pI18NKey text, pDescription text DEFAULT null
) RETURNS void AS $$
DECLARE l record; uLog uuid;
BEGIN
  uLog := NewDefectLog(pDefect, Now(), pEvent,
            GetI18NResource(pI18NKey, GetLocale('en')), pDescription, null);
  FOR l IN SELECT id FROM db.locale LOOP
    PERFORM EditDefectLogText(uLog, GetI18NResource(pI18NKey, l.id), pDescription, l.id);
  END LOOP;
  PERFORM WriteToEventLog('M', 5010, 'notification', pEvent, pDescription, pDefect);
END; $$ LANGUAGE plpgsql;

-- Callsite:
PERFORM WriteToDefectLogI18N(pObject, 'create', 'defect.status.opened', 'Defect created.');

-- Pattern D (VIEW label) — dispatch by code, resolve via i18n
CREATE OR REPLACE FUNCTION GetCalendarDayFlagLabel (pFlag bit(4)) RETURNS text AS $$
DECLARE vCode text;
BEGIN
  vCode := CASE WHEN pFlag & B'1000' = B'1000' THEN 'reduced'
                WHEN pFlag & B'0100' = B'0100' THEN 'holiday'
                WHEN pFlag & B'0010' = B'0010' THEN 'dayoff'
                WHEN pFlag & B'0001' = B'0001' THEN 'non_working'
                ELSE 'working' END;
  RETURN GetI18NResource('calendar.day_flag.' || vCode);
END; $$ LANGUAGE plpgsql STABLE STRICT;

-- Pattern E (email template) — per-line i18n lookup
Lines[1] := GetI18NResource('email.common.greet', pLocale)
  || coalesce(format(', %s', coalesce(pFullName, pUserName)), '') || '!';
Lines[2] := format(GetI18NResource('email.confirm.text.intro', pLocale), pProject);
Lines[5] := format(GetI18NResource('email.common.team', pLocale), pProject);
```

**Circular-dependency caveat for Pattern D.** When a view calls an i18n-resolving
function and the module's `routine.sql` depends on the view's type (e.g. `RETURNS
SETOF calendar_date`), keep the helper function **inside `view.sql`** — before the
VIEW that uses it. Do not try to reorder `view.sql` / `routine.sql` in
`create.psql`; both directions break.

**Circular-dependency caveat for any i18n callsite inside DDL.** PostgreSQL's
`check_function_bodies` (on by default) verifies that referenced functions exist
at `CREATE FUNCTION` time. Therefore `configuration/<dbname>/i18n/` must load
**first** in `configuration/<dbname>/create.psql` and `update.psql`.

**Re-seed semantics.** `CreateI18NResource(name, locale, data)` is idempotent: it
looks up the resource by `name` and upserts `(resource, locale)` via
`SetResourceData`. Running `i18n/init.sql` on every `--update` ensures new keys
are picked up, but **also overwrites any runtime edits made via the REST
`/resource/set` endpoint**. Treat `init.sql` as the canonical source of truth;
REST edits are transient until the next deploy.

---

**Audit command:**

```bash
# Russian text outside seed/reference files
grep -rnP "[А-Яа-яЁё]" configuration/<dbname>/ --include="*.sql" \
  | grep -vE "Register[A-Z][a-z]*|Edit[A-Z][a-z]*Text|CreateCountry|CreateCurrency|CreateMeasure|CreateRegion|CreatePaymentMethod|CreateCharger|CreateMode" \
  | grep -vE '/init\.sql|/country/|/currency/|/measure/|/region/|/payment_method/|/kladr' \
  | grep -vE '"en":|"ru":|"de":|"fr":|"it":|"es":'
```

## See Also

- [Error Code Reference](error-codes.md) -- full catalog grouped by category
- [Platform 1.2.1 Migration Guide](migration-1.2.1.md) -- entity/class/type locale expansion
- `error/init.sql` -- source of truth for all error registrations
- `error/routine.sql` -- `ParseMessage()`, `RegisterError()`, and exception-raising functions
