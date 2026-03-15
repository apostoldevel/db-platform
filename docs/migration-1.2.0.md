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

## See Also

- [Error Code Reference](error-codes.md) -- full catalog grouped by category
- `error/init.sql` -- source of truth for all error registrations
- `error/routine.sql` -- `ParseMessage()`, `RegisterError()`, and exception-raising functions
