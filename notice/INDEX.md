# notice

> Platform module #19 | Loaded by `create.psql` line 19

User notification/alert system. Stores per-user notices with status tracking (created → delivered → read → accepted/refused), optional object association, and category-based filtering. Broadcasts PostgreSQL NOTIFY events on creation.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel`, `admin` (users), `entity/object` (optional object association) | Client applications (real-time alerts) |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `db` | 1 table (notice) + 1 trigger |
| `kernel` | 1 view, 3 functions |
| `api` | 1 view, 9 functions |
| `rest` | `rest.notice` dispatcher (6 routes) |

## Tables — 1

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.notice` | User notices/alerts | `id uuid PK`, `userid uuid FK`, `object uuid FK(optional)`, `text text`, `category text` (default `'notice'`), `status int` (0-4), `created timestamptz`, `updated timestamptz`, `data jsonb` |

**Status codes:** 0 = created, 1 = delivered, 2 = read, 3 = accepted, 4 = refused.

## Triggers — 1

| Trigger | Table | Timing | Purpose |
|---------|-------|--------|---------|
| `t_notice_after_insert` | `db.notice` | AFTER INSERT | `pg_notify('notice', JSON)` with `{id, userid, object, category}` |

## Views — 1

| View | Description |
|------|-------------|
| `Notice` | Notices for `current_userid()`, LEFT JOIN Object for entity/class/type metadata, status→StatusCode mapping |

## Functions (kernel schema) — 3

| Function | Returns | Purpose |
|----------|---------|---------|
| `CreateNotice(pUserId, pObject, pText, pCategory, pStatus, pData)` | `uuid` | Create notice |
| `EditNotice(pId, pUserId, pObject, pText, pCategory, pStatus, pData)` | `void` | Update notice |
| `SetNotice(pId, ...)` | `uuid` | Upsert: CreateNotice if NULL, else EditNotice |
| `DeleteNotice(pId)` | `boolean` | Delete notice |
| `MarkNotice(pId)` | `boolean` | Mark as read (status=2). NULL pId = mark all unread for current user |

## Functions (api schema) — 9

| Function | Returns | Purpose |
|----------|---------|---------|
| `api.notice()` | `SETOF api.notice` | All notices for current user |
| `api.notice(pCategory)` | `SETOF api.notice` | Filter by category |
| `api.add_notice(...)` | `uuid` | Create notice |
| `api.update_notice(...)` | `void` | Update notice |
| `api.set_notice(...)` | `SETOF api.notice` | Upsert |
| `api.get_notice(pId)` | `SETOF api.notice` | Get by ID |
| `api.list_notice(pSearch, pFilter, pLimit, pOffSet, pOrderBy)` | `SETOF api.notice` | List with search/filter/pagination |
| `api.delete_notice(pId)` | `boolean` | Delete |
| `api.mark_notice(pId)` | `boolean` | Mark as read |

## REST Routes — 6

Dispatcher: `rest.notice(pPath text, pPayload jsonb)`.

| Path | Purpose |
|------|---------|
| `/notice/count` | Count with search/filter |
| `/notice/set` | Create or update notice |
| `/notice/delete` | Delete by ID |
| `/notice/get` | Get single with field projection |
| `/notice/list` | List with search/filter/pagination |
| `/notice/mark` | Mark notice(s) as read |

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `table.sql` | yes | no | 1 table + 1 trigger |
| `view.sql` | yes | yes | Notice view |
| `routine.sql` | yes | yes | 5 kernel functions |
| `api.sql` | yes | yes | 1 api view + 9 api functions |
| `rest.sql` | yes | yes | `rest.notice` dispatcher (6 routes) |
| `init.sql` | yes | no | Route registration |
| `create.psql` | - | - | Includes all |
| `update.psql` | - | - | Excludes table.sql, init.sql |
