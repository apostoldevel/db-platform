# registry

> Platform module #8 | Loaded by `create.psql` line 8

Hierarchical key-value configuration registry with typed values (integer, numeric, datetime, string, boolean). Provides a Windows Registry-like API: `RegCreateKey`, `RegOpenKey`, `RegSetValueString`, `RegGetValueString`, etc. Two trees: one for kernel-level config, one per user.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel`, `admin` (for current user context) | All modules using `RegSetValue*`/`RegGetValue*` for runtime configuration; `init.sql` files heavily use registry |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `registry` | Own schema (AUTHORIZATION kernel). 2 tables |
| `kernel` | 5 views, ~41 functions |
| `api` | API views and functions |
| `rest` | `rest.registry` dispatcher (~21 routes) |

## Tables

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `registry.key` | Key hierarchy | `id uuid PK`, `root uuid FK(self)`, `parent uuid FK(self)`, `key text`, `level int`; UNIQUE(`root`,`parent`,`key`) |
| `registry.value` | Typed values | `id uuid PK`, `key uuid FK`, `vname text`, `vtype int` (0=integer, 1=numeric, 2=datetime, 3=string, 4=boolean), `vinteger`, `vnumeric`, `vdatetime`, `vstring`, `vboolean`; UNIQUE(`key`,`vname`) |

## Views

### kernel schema

| View | Description |
|------|-------------|
| `Registry` | Combined kernel + user registry keys/values |
| `RegistryEx` | Extended registry with additional details |
| `RegistryKey` | Key hierarchy |
| `RegistryValue` | Values |
| `RegistryValueEx` | Extended values with full details |

## Functions — ~41 total

### Key Management

| Function | Returns | Purpose |
|----------|---------|---------|
| `RegCreateKey(pRoot, pPath)` | `uuid` | Create key hierarchy from backslash-delimited path |
| `RegOpenKey(pRoot, pPath)` | `uuid` | Open existing key by path |
| `RegDeleteKey(pKey)` | `void` | Delete single key |
| `RegDeleteTree(pKey)` | `void` | Recursively delete key and children |
| `AddRegKey(pRoot, pParent, pKey, pLevel)` | `uuid` | Low-level key creation |
| `GetRegRoot(pUserId)` | `uuid` | Get root key for user (or kernel root) |
| `GetRegKey(pParent, pKey)` | `uuid` | Find key by parent+name |
| `DelRegKey(pId)` | `void` | Delete key by ID |
| `DelTreeRegKey(pId)` | `void` | Recursive delete |

### Value Getters (type-specific)

| Function | Returns | Purpose |
|----------|---------|---------|
| `RegGetValue(pKey, pName)` | `Variant` | Get value as Variant composite |
| `RegGetValueEx(pKey, pName)` | `Variant` | Extended get with details |
| `RegGetValueInteger(pKey, pName)` | `integer` | Get integer value |
| `RegGetValueNumeric(pKey, pName)` | `numeric` | Get numeric value |
| `RegGetValueDate(pKey, pName)` | `timestamp` | Get datetime value |
| `RegGetValueString(pKey, pName)` | `text` | Get string value |
| `RegGetValueBoolean(pKey, pName)` | `boolean` | Get boolean value |
| `RegGetValueType(pKey, pName)` | `integer` | Get value data type code |

### Value Setters (type-specific)

| Function | Returns | Purpose |
|----------|---------|---------|
| `RegSetValue(pKey, pName, pValue Variant)` | `uuid` | Set value from Variant |
| `RegSetValueEx(pKey, pName, pType, ...)` | `uuid` | Set value with explicit type |
| `RegSetValueInteger(pKey, pName, pValue)` | `uuid` | Set integer |
| `RegSetValueNumeric(pKey, pName, pValue)` | `uuid` | Set numeric |
| `RegSetValueDate(pKey, pName, pValue)` | `uuid` | Set datetime |
| `RegSetValueString(pKey, pName, pValue)` | `uuid` | Set string |
| `RegSetValueBoolean(pKey, pName, pValue)` | `uuid` | Set boolean |

### Enumeration

| Function | Returns | Purpose |
|----------|---------|---------|
| `RegEnumKey(pKey)` | `SETOF record` | List child keys |
| `RegEnumValue(pKey)` | `SETOF record` | List values for key |
| `RegEnumValueEx(pKey)` | `SETOF record` | List values with extended details |
| `RegQueryValue(pId)` | `Variant` | Get value by ID |
| `RegQueryValueEx(pId)` | `Variant` | Extended get by ID |

### Utilities

`registry.reg_key_to_array`, `registry.get_reg_key`, `registry.get_reg_value` — internal path parsing and value retrieval.

## Common Usage Pattern

```sql
-- Write config
SELECT RegSetValueString(
  RegCreateKey('CURRENT_CONFIG', 'CONFIG\MyModule\Settings'),
  'ApiKey', 'abc123'
);

-- Read config
SELECT RegGetValueString(
  RegOpenKey('CURRENT_CONFIG', 'CONFIG\MyModule\Settings'),
  'ApiKey'
);
```

## REST Routes — ~21

Dispatcher: `rest.registry(pPath text, pPayload jsonb)`.

| Path Pattern | Purpose |
|------|---------|
| `/registry/list` | List registry entries |
| `/registry/key` | Get key info |
| `/registry/value` | Get value |
| `/registry/value/set` | Set value |
| `/registry/value/delete` | Delete value |
| `/registry/tree/delete` | Delete subtree |
| + ~15 additional read/write/enum operations | |

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `schema.sql` | yes* | no | CREATE SCHEMA registry |
| `table.sql` | yes | no | `registry.key`, `registry.value` tables |
| `routine.sql` | yes | yes | ~41 registry functions |
| `view.sql` | yes | yes | 5 kernel views |
| `api.sql` | yes | yes | API layer views and functions |
| `rest.sql` | yes | yes | `rest.registry` dispatcher (~21 routes) |
| `create.psql` | - | - | Includes all |
| `update.psql` | - | - | Includes routine, view, api, rest |
