# exception

> Platform module #7 | Loaded by `create.psql` line 7

Centralized exception handling with ~84 standardized error-raising functions. Each exception has a numeric group:code (e.g., 401:1 for LoginFailed, 400:5 for JsonIsEmpty), a UUID derived from the code, and multilingual resource messages (ru, en, nl, fr, it). No tables or views — functions only.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel`, `resource` (stores error messages as resources) | All modules that raise business-logic exceptions |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `kernel` | All 84 exception functions |

## Tables

None.

## Views

None.

## Functions — ~84 total

### Core Infrastructure (4)

| Function | Returns | Purpose |
|----------|---------|---------|
| `ParseMessage(pMessage)` | `record` | Parse "ERR-XXXX" format into group + code |
| `GetExceptionUUID(pErrGroup, pErrCode)` | `uuid` | Deterministic UUID from error group:code |
| `GetExceptionStr(pErrGroup, pErrCode, pMessage)` | `text` | Format complete exception string |
| `CreateExceptionResource(pRoot, pErrGroup, pErrCode, pName, ...)` | `uuid` | Create multilingual resource for error |

### Authentication (5)

`LoginFailed`, `AuthenticateError`, `LoginError`, `TokenExpired`, `SignatureError`.

### Authorization & Access (6)

`AccessDenied` (with optional path), `AccessDeniedForUser`, `UserLockError`, `UserTempLockError`, `TokenError`, `TokenBelong`.

### User Management (6)

`UserNotFound` (uuid + text overloads), `DeleteUserError`, `UserNotMemberArea`, `UserNotMemberInterface`, `IdentityNotConfirmed`, `UserPasswordChange`.

### Roles & Permissions (4)

`UnknownRoleName`, `RoleExists`, `SystemRoleError`, `ExecuteMethodError`.

### Entity & Object (7)

`ObjectNotFound` (uuid + text overloads), `IncorrectEntity`, `IncorrectClassType`, `IncorrectDocumentType`, `ObjectIsNull`, `NotFound`, `ChangeObjectStateError`.

### Area & Domain (6)

`RootAreaError`, `AreaError`, `GuestAreaError`, `DefaultAreaDocumentError`, `ChangeAreaError`, `IncorrectAreaCode`.

### State & Workflow (6)

`ChangeClassError`, `StateByCodeNotFound`, `MethodActionNotFound`, `MethodNotFound`, `MethodByCodeNotFound`, `ActionAlreadyCompleted`.

### Validation & Input (10)

`InvalidCodes`, `IncorrectCode`, `IncorrectLocaleCode`, `IncorrectKeyInArray`, `IncorrectValueInArray`, `InvalidScope`, `InvalidPhoneNumber`, `IncorrectDateInterval`, `IncorrectJsonKey`, `IncorrectJsonType`.

### Registry & Config (3)

`IncorrectRegistryKey`, `IncorrectRegistryDataType`, `ValueOutOfRange`.

### Data Operations (4)

`AlreadyExists`, `RecordExists`, `ChangesNotAllowed`, `ReadOnlyError`.

### Route & Interface (4)

`RouteIsEmpty`, `RouteNotFound`, `InterfaceError`, `ViewNotFound`.

### Method & Execution (4)

`MethodIsEmpty`, `PerformActionError`, `AbstractError`, `ExecutorIsEmpty`.

### Data Issues (5)

`JsonIsEmpty`, `JsonKeyNotFound`, `SomethingWentWrong`, `OperationNotPossible`, `EndPointNotSet`.

### OAuth2 (3)

`AudienceNotFound`, `IssuerNotFound`, `InvalidVerificationCodeType`.

### Misc (3)

`PasswordExpired`, `NonceExpired`, `LoginIpTableError`.

## Init / Seed Data

`routine.sql` creates exception resources for root error codes in 5 locales:
- Root (0,0): "System error codes" / "Коды системных ошибок"
- Auth (401,1): "LoginFailed"
- Auth (401,2): "AuthenticateError"

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `routine.sql` | yes | yes | All ~84 exception functions + seed resources |
| `create.psql` | - | - | Includes routine.sql |
| `update.psql` | - | - | Includes routine.sql |
