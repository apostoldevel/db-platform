# resource

> Platform module #6 | Loaded by `create.psql` line 6

Hierarchical, locale-aware content/resource management. Stores tree-structured resources (each node has a MIME type) with per-locale data (name, description, encoding, content). Used by the exception module for multilingual error messages and by configurations for UI labels and templates.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel`, `locale` (for `current_locale()`) | `exception` (error message resources), configurations (UI content) |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `db` | `db.resource`, `db.resource_data` tables |
| `kernel` | `Resource`, `ResourceTree` views; CRUD functions |
| `api` | `api.resource`, `api.resource_tree` views; 6 API functions |
| `rest` | `rest.resource` dispatcher (5 routes) |

## Tables

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.resource` | Resource tree nodes | `id uuid PK`, `root uuid FK(self)`, `node uuid FK(self)` (parent), `type text` (MIME, default 'text/plain'), `level int`, `sequence int` |
| `db.resource_data` | Locale-specific content | PK(`resource uuid FK`, `locale uuid FK`), `name text`, `description text`, `encoding text`, `data text`, `updated timestamptz`; UNIQUE(`name`,`locale`) |

## Views

### kernel schema

| View | Source | Description |
|------|--------|-------------|
| `Resource` | `db.resource` + `db.resource_data` + `db.locale` | Resources with locale data (filtered by `current_locale()`) |
| `ResourceTree` | recursive CTE on `Resource` | Tree with dot-notation index ("1.2.3"), sorted by level/sequence |

### api schema

| View | Source |
|------|--------|
| `api.resource` | `Resource` |
| `api.resource_tree` | `ResourceTree` |

## Functions

### kernel schema — Core CRUD

| Function | Returns | Purpose |
|----------|---------|---------|
| `CreateResource(pId, pRoot, pNode, pType, pName, ...)` | `uuid` | Create resource node + locale data |
| `UpdateResource(pId, ...)` | `void` | Partial update (coalesce with existing) |
| `SetResource(pId, ...)` | `uuid` | Upsert: create or update |
| `GetResource(pResource, pLocale)` | `text` | Get resource data content |
| `DeleteResource(pId)` | `void` | Delete resource (raises NotFound) |
| `SetResourceData(pResource, pLocale, pName, ...)` | `void` | Upsert locale-specific data |
| `SetResourceSequence(pId, pSequence, pDelta)` | `void` | Reorder sibling (recursive conflict resolution) |
| `SortResource(pNode)` | `void` | Renumber all children sequentially |

### api schema — Wrappers (accept locale code instead of UUID)

| Function | Returns | Purpose |
|----------|---------|---------|
| `api.create_resource(...)` | `uuid` | Create with locale code |
| `api.update_resource(...)` | `void` | Update with locale code |
| `api.set_resource(...)` | `SETOF api.resource` | Upsert, returns row |
| `api.get_resource(pId)` | `SETOF api.resource` | Get by ID |
| `api.delete_resource(pId)` | `void` | Delete |
| `api.list_resource(pSearch, pFilter, pLimit, pOffSet, pOrderBy)` | `SETOF api.resource` | Dynamic list with search/filter/pagination |

## REST Routes — 5

Dispatcher: `rest.resource(pPath text, pPayload jsonb)`.

| Path | Purpose |
|------|---------|
| `/resource/count` | Count with search/filter |
| `/resource/set` | Create or update resource |
| `/resource/get` | Get by ID (with field projection via `JsonbToFields`) |
| `/resource/delete` | Delete by ID |
| `/resource/list` | List with search/filter/pagination/field projection |

## Triggers

| Trigger | Table | Timing | Purpose |
|---------|-------|--------|---------|
| `t_resource_before` | `db.resource` | BEFORE INSERT | Auto-gen UUID, set root/node defaults, default type/sequence |
| `t_resource_data_before` | `db.resource_data` | BEFORE INSERT/UPDATE | Default locale to `current_locale()`, normalize empty→NULL |

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `table.sql` | yes | no | 2 tables + 2 triggers |
| `view.sql` | yes | yes | `Resource`, `ResourceTree`, api pass-through views |
| `routine.sql` | yes | yes | 8 kernel CRUD + ordering functions |
| `api.sql` | yes | yes | 6 API wrapper functions |
| `rest.sql` | yes | yes | `rest.resource` dispatcher (5 routes) |
| `create.psql` | - | - | Includes all |
| `update.psql` | - | - | Includes view, routine, api, rest |
