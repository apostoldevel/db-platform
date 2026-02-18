# kladr

> Platform module #16 | Loaded by `create.psql` line 16

Russian Federation address classifier (КЛАДР). Provides a hierarchical address tree for regions, districts, cities, populated places, and streets. Data is loaded from the standard KLADR/street databases and transformed into a navigable tree structure.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel` | Configuration entities needing address lookup |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `db` | 3 tables (kladr, street, address_tree) |
| `kernel` | 1 view, 8 functions |
| `api` | 1 view, 4 functions |
| `rest` | `rest.kladr` dispatcher (4 routes) |

## Tables — 3

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.kladr` | KLADR address classifiers | `code varchar(13) PK`, `name`, `socr`, `index`, `gninmb`, `uno`, `ocatd`, `status` |
| `db.street` | Street classifiers | `code varchar(17) PK`, `name`, `socr`, `index`, `gninmb`, `uno`, `ocatd` |
| `db.address_tree` | Hierarchical address tree | `id serial PK`, `parent int FK(self)`, `code varchar(17) UNIQUE`, `name`, `short`, `index varchar(6)`, `level int` |

## Views — 1

| View | Description |
|------|-------------|
| `AddressTree` | Direct projection of `db.address_tree` |

## Functions (kernel schema) — 8

### Tree Building

| Function | Returns | Purpose |
|----------|---------|---------|
| `AddAddressTree(pParent, pCode, pName, pShort, pIndex, pLevel)` | `integer` | Insert/upsert address node |
| `AddKladrToTree(pParent, pCode, pLevel)` | `integer` | Add KLADR record to tree (code transformation) |
| `AddStreetToTree(pParent, pCode, pLevel)` | `integer` | Add street record to tree (code transformation) |
| `CopyFromKladr(pParent, pCode)` | `void` | Recursively build tree for a single region (2-digit code) |
| `LoadFromKladr(pCodes)` | `void` | Master loader: creates root "Российская Федерация", populates regions. NULL = all regions |

### Query

| Function | Returns | Purpose |
|----------|---------|---------|
| `GetAddressTreeId(pCode)` | `integer` | Get node ID by code |
| `GetAddressTree(pCode)` | `text[]` | Get hierarchical path as text array (recursive CTE) |
| `GetAddressTreeString(pCode, pShort, pLevel)` | `text` | Human-readable address string with postal index |

`GetAddressTreeString` options: `pShort` (0=none, 1=left abbreviation, 2=right), `pLevel` (filter depth).

## Functions (api schema) — 4

| Function | Returns | Purpose |
|----------|---------|---------|
| `api.get_address_tree(pId)` | `SETOF api.address_tree` | Fetch single address by ID |
| `api.list_address_tree(pSearch, pFilter, pLimit, pOffSet, pOrderBy)` | `SETOF api.address_tree` | List with search/filter/pagination |
| `api.get_address_tree_history(pId)` | `SETOF api.address_tree` | Recursive parent chain (ancestors) |
| `api.get_address_tree_string(pCode, pShort, pLevel)` | `text` | Wrapper for `GetAddressTreeString` |

## REST Routes — 4

Dispatcher: `rest.kladr(pPath text, pPayload jsonb)`.

| Path | Purpose |
|------|---------|
| `/kladr/get` | Fetch address(es) by ID with field projection |
| `/kladr/list` | List addresses with filtering |
| `/kladr/history` | Get address hierarchy (parent chain) |
| `/kladr/string` | Get formatted address string |

## Init / Seed Data

No `init.sql`. Data is loaded by calling `LoadFromKladr()` from application code with specific region codes.

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `table.sql` | yes | no | 3 tables + indexes |
| `view.sql` | yes | yes | `AddressTree` view |
| `routine.sql` | yes | yes | 8 kernel functions |
| `api.sql` | yes | yes | 1 api view + 4 api functions |
| `rest.sql` | yes | yes | `rest.kladr` dispatcher (4 routes) |
| `create.psql` | - | - | Includes all |
| `update.psql` | - | - | Excludes table.sql |
