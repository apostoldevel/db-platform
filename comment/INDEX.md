# comment

> Platform module #20 | Loaded by `create.psql` line 20

Hierarchical comment system for objects. Supports threaded replies via parent/child self-reference, ownership-based authorization, priority ordering, and optional JSONB data attachments.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel`, `admin` (users, profiles), `entity/object` (commented objects) | Client applications (object discussions) |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `db` | 1 table (comment) + 1 trigger |
| `kernel` | 1 view, 3 functions |
| `api` | 1 view (recursive CTE), 7 functions |
| `rest` | `rest.comment` dispatcher (5 routes) |

## Tables — 1

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.comment` | Threaded comments on objects | `id uuid PK`, `parent uuid FK(self)`, `object uuid FK`, `owner uuid FK(user)`, `created timestamptz`, `updated timestamptz`, `priority int`, `text text`, `data jsonb` |

## Triggers — 1

| Trigger | Table | Timing | Purpose |
|---------|-------|--------|---------|
| `t_comment_before_update` | `db.comment` | BEFORE UPDATE | Auto-set `updated := Now()` |

## Views — 1 kernel + 1 api

| View | Description |
|------|-------------|
| `Comment` (kernel) | Recursive tree with full object/entity/class/type metadata + owner profile (username, name, email, phone, picture, verified flags) |
| `api.comment` | Recursive CTE tree with hierarchical `sortlist` and `Index` string, sorted by priority DESC |

## Functions (kernel schema) — 3

| Function | Returns | Purpose |
|----------|---------|---------|
| `CreateComment(pParent, pObject, pOwner, pPriority, pText, pData)` | `uuid` | Create comment |
| `EditComment(pId, pPriority, pText, pData)` | `void` | Update (parent/owner immutable) |
| `DeleteComment(pId)` | `boolean` | Delete comment |

## Functions (api schema) — 7

| Function | Returns | Purpose |
|----------|---------|---------|
| `api.comment(pObject)` | `SETOF api.comment` | All comments for object, ordered by priority/created |
| `api.add_comment(pParent, pObject, pPriority, pText, pData)` | `uuid` | Create (auto-sets `owner := current_userid()`) |
| `api.update_comment(pId, pPriority, pText, pData)` | `void` | Update (owner or admin only) |
| `api.set_comment(pId, pParent, pObject, pPriority, pText, pData)` | `SETOF api.comment` | Upsert: add if NULL, update if exists |
| `api.get_comment(pId)` | `SETOF api.comment` | Get with `CheckObjectAccess(B'100')` |
| `api.list_comment(pSearch, pFilter, pLimit, pOffSet, pOrderBy)` | `SETOF api.comment` | List with search/filter/pagination |
| `api.delete_comment(pId)` | `boolean` | Delete (owner or admin only) |

## REST Routes — 5

Dispatcher: `rest.comment(pPath text, pPayload jsonb)`.

| Path | Purpose |
|------|---------|
| `/comment/count` | Count with search/filter |
| `/comment/set` | Create or update comment |
| `/comment/delete` | Delete by ID (ownership check) |
| `/comment/get` | Get single with field projection |
| `/comment/list` | List with search/filter/pagination |

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `table.sql` | yes | no | 1 table + 1 trigger |
| `view.sql` | yes | yes | Comment view (recursive tree) |
| `routine.sql` | yes | yes | 3 kernel functions |
| `api.sql` | yes | yes | 1 api view + 7 api functions |
| `rest.sql` | yes | yes | `rest.comment` dispatcher (5 routes) |
| `init.sql` | yes | no | Route registration |
| `create.psql` | - | - | Includes all |
| `update.psql` | - | - | Excludes table.sql, init.sql |
