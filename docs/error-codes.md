# Error Code Reference

All platform error codes follow the `ERR-GGG-CCC` format, where `GGG` is the HTTP status group and `CCC` is the unique code within the group.

JSON response format:

```json
{"error": {"code": 400, "error": "ERR-400-001", "message": "Access denied."}}
```

The old format `ERR-GGGCC` (e.g., `ERR-40001`) is still accepted by `ParseMessage()` and automatically converted to the new dash-separated format.

Downstream projects register custom errors via `RegisterError()`:

```sql
SELECT RegisterError('ERR-400-200', 400, 'E', 'validation', 'en', 'My custom error');
SELECT RegisterError('ERR-400-200', 400, 'E', 'validation', 'ru', 'Моя ошибка');
```

---

## Authentication Errors (ERR-401-xxx)

| Code | Function | Message | Category |
|------|----------|---------|----------|
| ERR-401-001 | LoginFailed | Login failed | auth |
| ERR-401-002 | AuthenticateError | Authenticate Error. %s | auth |
| ERR-401-003 | LoginError | Check the username is correct and enter the password again | auth |
| ERR-401-004 | UserLockError | Account is blocked | auth |
| ERR-401-005 | UserTempLockError | Account is temporarily locked until %s | auth |
| ERR-401-006 | PasswordExpired | Password expired | auth |
| ERR-401-007 | SignatureError | Signature is incorrect or missing | auth |

## Access Control Errors (ERR-403-xxx)

| Code | Function | Message | Category |
|------|----------|---------|----------|
| ERR-403-001 | TokenExpired | Token not FOUND or has expired | access |

## Client Errors (ERR-400-xxx)

### Access & Permissions

| Code | Function | Message | Category |
|------|----------|---------|----------|
| ERR-400-001 | AccessDenied | Access denied | access |
| ERR-400-002 | AccessDeniedForUser | Access denied for user %s | access |
| ERR-400-003 | ExecuteMethodError | Insufficient rights to execute method: %s | access |
| ERR-400-015 | RootAreaError | Operations with documents in root area are prohibited | access |
| ERR-400-018 | UserNotMemberArea | User "%s" does not have access to area "%s" | access |
| ERR-400-020 | UserNotMemberInterface | User "%s" does not have access to interface "%s" | access |
| ERR-400-025 | DeleteUserError | You cannot delete yourself | access |
| ERR-400-042 | UserPasswordChange | Password change failed, password change is prohibited | access |
| ERR-400-043 | SystemRoleError | Change, delete operations for system roles are prohibited | access |
| ERR-400-044 | LoginIpTableError | Login is not possible. Limited access by IP-address: %s | access |
| ERR-400-050 | PerformActionError | You cannot perform this action | access |
| ERR-400-052 | ReadOnlyError | Modify operations for read-only roles are not allowed | access |
| ERR-400-072 | GuestAreaError | Operations with documents in guest area are prohibited | access |
| ERR-400-074 | DefaultAreaDocumentError | The document can only be changed in the "Default" area | access |

### Authentication & Token

| Code | Function | Message | Category |
|------|----------|---------|----------|
| ERR-400-004 | NonceExpired | Request timed out | auth |
| ERR-400-005 | TokenError | Token invalid | auth |
| ERR-400-006 | TokenBelong | Token belongs to the other client | auth |
| ERR-400-007 | InvalidScope | Some requested areas were invalid: {valid=[%s], invalid=[%s]} | auth |
| ERR-400-051 | IdentityNotConfirmed | Identity not confirmed | auth |

### Entity & Object

| Code | Function | Message | Category |
|------|----------|---------|----------|
| ERR-400-008 | AbstractError | An abstract class cannot have objects | entity |
| ERR-400-009 | ChangeClassError | Object class change is not allowed | entity |
| ERR-400-010 | ChangeAreaError | Changing document area is not allowed | entity |
| ERR-400-011 | IncorrectEntity | Object entity is set incorrectly | entity |
| ERR-400-012 | IncorrectClassType | Invalid object type | entity |
| ERR-400-013 | IncorrectDocumentType | Invalid document type | entity |
| ERR-400-016 | AreaError | Area not FOUND by specified identifier | entity |
| ERR-400-017 | IncorrectAreaCode | Area not FOUND by code: %s | entity |
| ERR-400-019 | InterfaceError | Interface not FOUND by specified identifier | entity |
| ERR-400-021 | UnknownRoleName | Unknown role name: %s | entity |
| ERR-400-022 | RoleExists | Role "%s" already exists | entity |
| ERR-400-023 | UserNotFound | User "%s" does not exist | entity |
| ERR-400-024 | UserIdNotFound | User with id "%s" does not exist | entity |
| ERR-400-026 | AlreadyExists | %s already exists | entity |
| ERR-400-027 | RecordExists | Entry with code "%s" already exists | entity |
| ERR-400-030 | ObjectNotFound | Not FOUND %s with %s: %s | entity |
| ERR-400-031 | ObjectIdIsNull | Not FOUND %s with %s: \<null\> | entity |
| ERR-400-046 | ViewNotFound | View "%s.%s" not FOUND | entity |
| ERR-400-073 | NotFound | Not found | entity |

### Workflow

| Code | Function | Message | Category |
|------|----------|---------|----------|
| ERR-400-032 | MethodActionNotFound | Object [%s] method not FOUND, for action: %s [%s]. Current state: %s [%s] | workflow |
| ERR-400-033 | MethodNotFound | Method "%s" of object "%s" not FOUND | workflow |
| ERR-400-034 | MethodByCodeNotFound | No method FOUND by code "%s" for object "%s" | workflow |
| ERR-400-035 | ChangeObjectStateError | Failed to change object state: %s | workflow |
| ERR-400-036 | ChangesNotAllowed | Changes are not allowed | workflow |
| ERR-400-037 | StateByCodeNotFound | No state FOUND by code "%s" for object "%s" | workflow |
| ERR-400-045 | OperationNotPossible | Operation is not possible, there are related documents | workflow |
| ERR-400-053 | ActionAlreadyCompleted | You have already completed this action | workflow |

### Validation

| Code | Function | Message | Category |
|------|----------|---------|----------|
| ERR-400-014 | IncorrectLocaleCode | Locale not FOUND by code: %s | validation |
| ERR-400-028 | InvalidCodes | Some codes were invalid: {valid=[%s], invalid=[%s]} | validation |
| ERR-400-029 | IncorrectCode | Invalid code "%s". Valid codes: [%s] | validation |
| ERR-400-038 | MethodIsEmpty | Method ID must not be empty | validation |
| ERR-400-039 | ActionIsEmpty | Action ID must not be empty | validation |
| ERR-400-040 | ExecutorIsEmpty | The executor must not be empty | validation |
| ERR-400-041 | IncorrectDateInterval | The end date of the period cannot be less than the start date of the period | validation |
| ERR-400-047 | InvalidVerificationCodeType | Invalid verification type code: %s | validation |
| ERR-400-048 | InvalidPhoneNumber | Invalid phone number: %s | validation |
| ERR-400-049 | ObjectIsNull | Object id not specified | validation |
| ERR-400-066 | ValueOutOfRange | Value [%s] is out of range | validation |
| ERR-400-067 | DateValidityPeriod | The start date must not exceed the end date | validation |

### JSON Payload

| Code | Function | Message | Category |
|------|----------|---------|----------|
| ERR-400-060 | JsonIsEmpty | JSON must not be empty | validation |
| ERR-400-061 | IncorrectJsonKey | (%s) Invalid key "%s". Valid keys: [%s] | validation |
| ERR-400-062 | JsonKeyNotFound | (%s) Required key not FOUND: %s | validation |
| ERR-400-063 | IncorrectJsonType | Invalid type "%s", expected "%s" | validation |
| ERR-400-064 | IncorrectKeyInArray | Invalid key "%s" in array "%s". Valid keys: [%s] | validation |
| ERR-400-065 | IncorrectValueInArray | Invalid value "%s" in array "%s". Valid values: [%s] | validation |

### OAuth 2.0

| Code | Function | Message | Category |
|------|----------|---------|----------|
| ERR-400-070 | IssuerNotFound | OAuth 2.0: Issuer not FOUND: %s | auth |
| ERR-400-071 | AudienceNotFound | OAuth 2.0: Client not FOUND | auth |

### Registry

| Code | Function | Message | Category |
|------|----------|---------|----------|
| ERR-400-080 | IncorrectRegistryKey | Invalid key "%s". Valid keys: [%s] | validation |
| ERR-400-081 | IncorrectRegistryDataType | Invalid data type: %s | validation |

### Routing

| Code | Function | Message | Category |
|------|----------|---------|----------|
| ERR-400-090 | RouteIsEmpty | Path must not be empty | validation |
| ERR-400-091 | RouteNotFound | Route not found: %s | entity |
| ERR-400-092 | EndPointNotSet | Endpoint not set for path: %s | entity |

### System

| Code | Function | Message | Category |
|------|----------|---------|----------|
| ERR-400-100 | SomethingWentWrong | Oops, something went wrong. Our engineers are already working on fixing the error | system |
