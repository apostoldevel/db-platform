# file

> Platform module #17 | Loaded by `create.psql` line 17

Hierarchical file system abstraction layer. Supports documents, directories, symbolic links, and external storage buckets (S3). Implements UNIX-like permissions (9-bit rwx mask), URL generation, and callbacks for async file operations (upload to S3).

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel`, `admin` (users/owners), `http` (for S3 upload via `http.fetch`), `registry` (S3 config) | `entity/object` (object_file attachments), configuration entities |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `db` | 1 table (file) + 5 triggers |
| `kernel` | 3 views, ~15 functions |
| `api` | 2 views, 5 functions |
| `rest` | `rest.file` dispatcher (5 routes) |

## Tables — 1

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.file` | File/directory/link/storage entries | `id uuid PK`, `root uuid FK(self)`, `parent uuid FK(self)`, `link uuid FK(self)`, `owner uuid FK(user)`, `type char(1)`, `mask bit(9)`, `level int`, `path text`, `name text`, `size int`, `date timestamptz`, `data bytea`, `mime text`, `text text`, `hash text`, `url text`, `done text`, `fail text` |

**Type codes:** `-` = file, `d` = directory, `l` = symbolic link, `s` = storage (S3 bucket config).

**Mask bits (9-bit):** `rwx` for user/group/other (UNIX-style). Default: `B'111110100'` (user: rw-, group: r--, other: r--).

**Unique constraints:** `(root, parent, name)`, `(path, name)`.

**Callbacks:** `done` and `fail` columns store qualified function names (`schema.function`) called after async operations.

## Triggers — 5

| Trigger | Table | Timing | Purpose |
|---------|-------|--------|---------|
| `t_file_insert` | `db.file` | BEFORE INSERT | Auto-set owner, root, normalize path/name, compute URL |
| `t_file_type` | `db.file` | BEFORE UPDATE | Recalculate URL when type changes |
| `t_file_path` | `db.file` | BEFORE UPDATE | Normalize and recalculate URL on path change |
| `t_file_name` | `db.file` | BEFORE UPDATE | Normalize name and recalculate URL on name change |
| `t_file_notify` | `db.file` | AFTER INSERT/UPDATE/DELETE | `pg_notify('file', JSON)` with `{session, operation, id, type, name, path, hash}` |

## Views — 3

| View | Description |
|------|-------------|
| `File` | Files with owner username/label, type label |
| `FileData` | Same as File but with `data` base64-encoded |
| `FileTree` | Recursive CTE hierarchy with `sortlist` array and `Index` string |

## Functions (kernel schema) — ~15

### Path Utilities

| Function | Returns | Purpose |
|----------|---------|---------|
| `NormalizeFileName(pName, pLink)` | `text` | Validate name (no `/`), optionally URL-encode |
| `NormalizeFilePath(pPath, pLink)` | `text` | Validate path (no `.`/`..`), normalize |
| `CollectFilePath(pId)` | `text` | Build full path by traversing parents to root |
| `NewFilePath(pPath, pRoot, pOwner)` | `uuid` | Create directory hierarchy for path, return leaf ID |

### CRUD

| Function | Returns | Purpose |
|----------|---------|---------|
| `NewFile(pId, pRoot, pParent, pName, pType, pOwner, pMask, ...)` | `uuid` | Low-level insert |
| `AddFile(pRoot, pParent, pName, pType, pOwner, pMask, ...)` | `uuid` | Validate callbacks, call NewFile |
| `EditFile(pId, pRoot, pParent, pName, pOwner, pMask, ...)` | `boolean` | Partial update with COALESCE |
| `SetFile(pId, pType, pMask, pOwner, ...)` | `uuid` | Upsert: AddFile if NULL, else EditFile |
| `DeleteFile(pId)` | `boolean` | Single file deletion |
| `DeleteFiles(pId)` | `void` | Recursive cascade delete (children first) |

### Query

| Function | Returns | Purpose |
|----------|---------|---------|
| `GetFile(pParent, pName)` | `uuid` | Get file ID by parent + name |
| `GetFile(pName, pPath)` | `uuid` | Get file ID by path + name |
| `FindFile(pName)` | `uuid` | Recursive path string traversal |
| `QueryFile(pFile)` | `uuid` | Find deepest existing node in path |

### S3 Integration

| Function | Returns | Purpose |
|----------|---------|---------|
| `PutFileToS3(pId, pRegion, pDone, pFail, pType, pMessage)` | `uuid` | Upload file to AWS S3 with HMAC-SHA256 signature, public-read ACL for `public` root |

S3 config read from registry: `CONFIG\S3` keys: `Region`, `Endpoint`, `AccessKey`, `SecretKey`.

## Functions (api schema) — 5

| Function | Returns | Purpose |
|----------|---------|---------|
| `api.set_file(pId, pType, pMask, ..., pPath, ...)` | `SETOF api.file` | Create/update file, handles path→root mapping, decodes base64 data |
| `api.get_file(pId)` | `SETOF api.file_data` | Get file with base64-encoded content |
| `api.get_file_id(pName, pPath)` | `uuid` | Resolve file ID by name + path |
| `api.delete_file(pId)` | `boolean` | Delete file |
| `api.list_file(pSearch, pFilter, pLimit, pOffSet, pOrderBy)` | `SETOF api.file` | List with search/filter/pagination |

## REST Routes — 5

Dispatcher: `rest.file(pPath text, pPayload jsonb)`.

| Path | Purpose |
|------|---------|
| `/file/set` | Create/update file (array/single) |
| `/file/get` | Fetch file(s) by ID or path+name with field projection |
| `/file/list` | List files (default orderby: `sortlist` for tree order) |
| `/file/count` | Count matching files |
| `/file/delete` | Delete file(s) by ID or path+name |

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `table.sql` | yes | no | 1 table + 5 triggers |
| `view.sql` | yes | yes | File, FileData, FileTree views |
| `routine.sql` | yes | yes | ~15 kernel functions |
| `api.sql` | yes | yes | 2 api views + 5 api functions |
| `rest.sql` | yes | yes | `rest.file` dispatcher (5 routes) |
| `init.sql` | yes | no | Route registration |
| `create.psql` | - | - | Includes all |
| `update.psql` | - | - | Excludes table.sql, init.sql |
