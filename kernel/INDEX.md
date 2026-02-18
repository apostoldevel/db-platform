# kernel

> Platform module #1 | Loaded by `create.psql` line 1

Foundation module providing custom data types, schemas, database users, utility functions (type conversion, JSON handling, binary math, AWS signatures), session variable system, and JWT support. Every other module depends on kernel.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| _(none)_ | All 24 other modules |

## Schemas Created

| Schema | Owner | Purpose |
|--------|-------|---------|
| `db` | kernel | All tables |
| `kernel` | kernel | Core business logic functions |
| `oauth2` | kernel | OAuth2 authentication |
| `api` | kernel | API views and functions |
| `rest` | kernel | REST dispatchers |
| `daemon` | kernel | Background daemon functions |

## Database Users & Roles

| User/Role | Type | Purpose |
|-----------|------|---------|
| `administrator` | ROLE | App admin role (WITH CREATEROLE) |
| `kernel` | USER | DB owner, all privileges |
| `admin` | USER | IN ROLE administrator |
| `daemon` | USER | Background processing |
| `apibot` | USER | API bot access |

## Custom Types (`dt.sql`)

### Enum

| Type | Values |
|------|--------|
| `TVarType` | `'kernel'`, `'context'`, `'object'` |

### Scalar Wrappers

| Type | Inner | Purpose |
|------|-------|---------|
| `Id` | uuid | Identifier |
| `Cardinal` | NUMERIC(14) | Integer cardinal |
| `Amount` | NUMERIC(15,5) | Monetary amount |
| `Const` | NUMERIC(5) | Small constant |
| `Symbol` | VARCHAR(1) | Single character |
| `Code` | VARCHAR(30) | Short code |
| `Name` | VARCHAR(50) | Name |
| `Label` | VARCHAR(65) | Label |
| `Description` | VARCHAR(260) | Description |
| `String` | TEXT | Arbitrary text |
| `Status` | VARCHAR(1) | Single-char status |

### Composite

| Type | Fields |
|------|--------|
| `Variant` | `vType int, vInteger int, vNumeric numeric, vDateTime timestamp, vString text, vBoolean boolean` |

### Array Wrappers

`TIdList`, `TCardinalList`, `TAmountList`, `TConstList`, `TSymbolList`, `TCodeList`, `TNameList`, `TLabelList`, `TDescList`, `TStringList`, `TTextList`, `TStatusList`, `TBoolList`, `TDateList`, `TVariantList` -- one per scalar type.

## Views (`public.sql`)

| View | Columns | Purpose |
|------|---------|---------|
| `all_tab_columns` | table_name, column_id, column_name, data_type, udt_name | Column metadata from kernel schema |
| `all_col_comments` | table_name, table_description, column_name, column_description | Column comments |

## Functions

### public.sql -- Metadata & Conversion Utilities

| Function | Returns | Purpose |
|----------|---------|---------|
| `GetColumns(pTable, pSchema, pAlias)` | `text[]` | Get column names from a table |
| `GetRoutines(pRoutine, pSchema, pDataType, pAlias, pNameFrom)` | `text[]` | Get function parameter names/types |
| `array_pos(text[], text)` | `int` | Find element position in array |
| `string_to_array_trim(str, sep)` | `text[]` | Split with trimming |
| `path_to_array(pPath)` | `text[]` | Convert `/a/b/c` to array |
| `str_to_inet(str)` | `record(host, range)` | Parse IP address/range |
| `IntToStr(pValue, pFormat)` | `text` | Numeric to formatted string |
| `StrToInt(pValue, pFormat)` | `numeric` | String to numeric |
| `DateToStr(pValue, pFormat)` | `text` | Date/timestamp to string (3 overloads) |
| `StrToDate(pValue, pFormat)` | `date` | String to date |
| `StrToTimeStamp(pValue, pFormat)` | `timestamp` | String to timestamp |
| `StrToTimeStampTZ(pValue, pFormat)` | `timestamptz` | String to timestamptz |
| `StrToTime(pValue)` | `time` | String to time |
| `StrToInterval(pValue)` | `interval` | String to interval |
| `MINDATE()` | `date` | Returns `1970-01-01` |
| `MAXDATE()` | `date` | Returns `4433-12-31` |
| `CheckNull(...)` | _(varies)_ | 8 overloads: converts "empty" values to NULL |
| `GetCompare(pCompare)` | `text` | Maps code (EQL/NEQ/LSS/GEQ/LKE/ISN...) to SQL operator |
| `UTC()` | `timestamptz` | Current UTC time |
| `GetISOTime(pTime)` | `text` | ISO 8601 format |
| `GetEpoch(pTime)` | `double` | Unix epoch (seconds) |
| `GetEpochMs(pTime)` | `double` | Unix epoch (milliseconds) |
| `Dow(pDateTime)` | `int` | Day of week (1=Mon, 7=Sun) |
| `null_uuid()` | `uuid` | Returns `00000000-0000-4000-8000-000000000000` |
| `URLEncode(url)` | `text` | RFC 3986 URL encoding |
| `is_valid_email(email)` | `boolean` | Email validation |
| `generate_aws_signature(...)` | `text` | AWS4-HMAC-SHA256 for S3 |
| `random_between(low, high)` | `int` | Random integer in range |
| `result_success()` | `record(result, message)` | Standard success result |
| `error_success()` | `record(result, message)` | Standard success error code |

**Binary/Hex Math:** `bin_to_dec`, `dec_to_bin`, `bit_to_dec`, `hex_to_bit`, `hex_to_int`, `hex_to_dec`, `dec_to_hex`, `hex_to_num64`, `hex_to_bigint`, `bit_copy`, `to_little_endian` (3 overloads), `IEEE754_32`, `IEEE754_64`.

**Array Helpers:** `array_add_text`, `min_array`, `max_array`, `inet_to_array`, `CheckCodes`.

**JSON Quoting:** `quote_literal_json`, `array_quote_literal_json`, `find_value_in_array`.

**Misc:** `word_count`, `get_hostname_from_uri`, `get_input_value`, `IntervalArrayToStr`.

### general.sql -- Core Business Logic

| Function | Returns | Purpose |
|----------|---------|---------|
| `gen_kernel_uuid(prefix)` | `uuid` | Generate UUID with optional char at position 20 |
| `gen_random_code()` | `text` | Random base64 code (12 bytes, URL-safe) |
| `TrimPhone(pPhone)` | `text` | Extract digits, validate 10-12 digit range |
| `SetVar(pType, pName, pValue)` | `void` | Set session variable (6 type overloads) |
| `GetVar(pType, pName)` | `text` | Get session variable |
| `SetErrorMessage(pMessage)` | `void` | Store error message in session |
| `GetErrorMessage()` | `text` | Retrieve error message from session |
| `InitContext(pObject, pClass, pMethod, pAction)` | `void` | Initialize context variables |
| `InitParams(pParams)` | `void` | Store context params as JSONB |
| `SetContextMethod(pMethod)` | `void` | Set context method UUID |
| `ClearContextMethod()` | `void` | Clear context method |
| `context_object()` | `uuid` | Get context object |
| `context_class()` | `uuid` | Get context class |
| `context_method()` | `uuid` | Get context method |
| `context_action()` | `uuid` | Get context action |
| `context_params()` | `jsonb` | Get context params |
| `JsonToIntArray(json)` | `integer[]` | JSON to integer array |
| `JsonToNumArray(json)` | `numeric[]` | JSON to numeric array |
| `JsonToStrArray(json)` | `text[]` | JSON to text array |
| `JsonToUUIDArray(json)` | `uuid[]` | JSON to UUID array |
| `JsonToBoolArray(json)` | `boolean[]` | JSON to boolean array |
| `JsonToIntervalArray(json)` | `interval[]` | JSON to interval array |
| `JsonbToIntArray(jsonb)` | `integer[]` | JSONB versions of all above |
| `jsonb_array_to_string(jsonb, sep)` | `text` | Join JSONB array elements |
| `jsonb_compare_value(pOld, pNew)` | `jsonb` | Keys in old not in new |
| `CheckJsonKeys(pRoute, pKeys, json)` | `void` | Validate JSON keys |
| `CheckJsonbKeys(pRoute, pKeys, jsonb)` | `void` | Validate JSONB keys |
| `CheckJsonValues(pArrayName, pArray, json)` | `void` | Validate JSON array values |
| `CheckJsonbValues(pArrayName, pArray, jsonb)` | `void` | Validate JSONB array values |
| `JsonToFields(json, pFields)` | `text` | JSON field list to SQL SELECT clause |
| `JsonbToFields(jsonb, pFields)` | `text` | JSONB field list to SQL SELECT (supports aggregates) |

### jwt.sql -- JWT Token Functions

| Function | Returns | Purpose |
|----------|---------|---------|
| `url_encode(bytea)` | `text` | Base64 URL-safe encode |
| `url_decode(text)` | `bytea` | Base64 URL-safe decode |
| `algorithm_sign(signables, secret, algorithm)` | `text` | HMAC sign (HS256/384/512) |
| `sign(payload, secret, algorithm)` | `text` | Create JWT |
| `verify(token, secret, algorithm)` | `table(header, payload, valid)` | Verify JWT |

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `schema.sql` | yes* | no | CREATE SCHEMA (db, kernel, oauth2, api, rest, daemon) + pgcrypto |
| `database.sql` | yes* | no | CREATE DATABASE with UTF8 |
| `users.sql` | yes* | no | CREATE ROLE/USER (kernel, admin, daemon, apibot) |
| `grant.sql` | yes* | no | Database-level GRANT statements |
| `api.sql` | yes* | no | Drop/recreate api + rest schemas |
| `dt.sql` | yes | no | Custom composite & enum types |
| `public.sql` | yes | yes | Views + utility functions |
| `general.sql` | yes | yes | Core business logic functions |
| `jwt.sql` | yes | no | JWT encode/decode/sign/verify |
| `create.psql` | - | - | Includes: dt, public, general, jwt |
| `update.psql` | - | - | Includes: public, general |

_*Files marked with asterisk are loaded by higher-level install scripts, not by kernel/create.psql directly._
