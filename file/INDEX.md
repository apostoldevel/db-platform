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
| `kernel` | 4 views (+ `FileAccess`, defined in `entity/object/document`), ~16 functions |
| `api` | 2 views, 7 functions |
| `rest` | `rest.file` dispatcher (5 routes) |

## Tables — 1

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.file` | File/directory/link/storage entries | `id uuid PK`, `root uuid FK(self)`, `parent uuid FK(self)`, `link uuid FK(self)`, `owner uuid FK(user)`, `type char(1)`, `mask bit(9)`, `level int`, `path text`, `name text`, `size int`, `date timestamptz`, `data bytea`, `mime text`, `text text`, `hash text`, `url text`, `done text`, `fail text` |

**Type codes:** `-` = file, `d` = directory, `l` = symbolic link, `s` = storage (S3 bucket config).

**Mask bits (9-bit):** `rwx` for owner/group/other (UNIX-style); "group" is the branch of the area tree the owner belongs to (see `GetFileMask`). Default: `B'111110000'` (owner: rwx, group: rw-, other: ---) — since 1.2.22 (P00000022); before that `B'111110100'`, and nothing read the mask. Since 1.2.24 the `r` bit gates `api.get_file`, `api.list_file` / `api.count_file` and the `api.file` views; the `w` bit gates `api.set_file` / `api.delete_file` on an existing file and, on a directory under the `public` root, who may publish there (`CheckFilePublish`).

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

## Views — 4 (+1 in the entity module)

| View | Description |
|------|-------------|
| `File` | Files with owner username/label, type label |
| `FileData` | Same as File but with `data` base64-encoded |
| `FileTree` | Recursive CTE hierarchy with `sortlist` array and `Index` string |
| `FileObject` | `FileTree` under the name shape `api.sql()` pairs: `api.sql('kernel', 'FileObject', …)` attaches `FileAccess` at run time (skipped for the administrator) — the list side of the read barrier (since 1.2.24) |
| `FileAccess` | The set of files the session may read (`object` = file id), set-based; the same verdict as `CheckFileAccess(id, B'100')` in one query. Lives in `entity/object/document/view.sql`: reads `db.object_file` / `db.document`, created after this module |

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
| `NewFile(pId, pRoot, pParent, pName, pType, pOwner, pMask, ...)` | `uuid` | Low-level insert; `CheckFilePublish` gate — `AccessDenied` under the `public` root (since 1.2.24) |
| `AddFile(pRoot, pParent, pName, pType, pOwner, pMask, ...)` | `uuid` | Validate callbacks, call NewFile |
| `EditFile(pId, pRoot, pParent, pName, pOwner, pMask, ...)` | `boolean` | Partial update with COALESCE; same gate at the destination (a move into `/public` or new bytes there) |
| `SetFile(pId, pType, pMask, pOwner, ...)` | `uuid` | Upsert: AddFile if NULL, else EditFile |
| `DeleteFile(pId)` | `boolean` | Single file deletion |
| `DeleteFiles(pId)` | `void` | Recursive cascade delete (children first) |

### Access

| Function | Returns | Purpose |
|----------|---------|---------|
| `GetFileMask(pId, pUserId)` | `bit(3)` | Mask segment for the user: owner / user at or above an owner's area (root, system, guest excluded), or sees the area of an attached document of the same owner / other; mirror of `GetObjectMask` |
| `DecodeFileAccess(pId, pUserId)` | `record (r, w, x)` | Effective access as booleans, bypasses included — the verdict without the bytes |
| `CheckFileAccess(pId, pMask, pUserId)` | `boolean` | Permission check; bypass for `kernel`, administrators, `system` (bot sessions), read under the `public` root; mirror of `CheckObjectAccess` |
| `CheckFilePublish(pRoot, pParent, pName)` | `boolean` | May the session write an entry under the `public` root: the `w` bit of the directory it lands in (`CheckFileAccess`, bypasses included) — delegation goes by directories; creating or changing the root — bypasses only. Anything outside `/public` passes (since 1.2.24) |

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

## Functions (api schema) — 7

| Function | Returns | Purpose |
|----------|---------|---------|
| `api.set_file(pId, pType, pMask, ..., pPath, ...)` | `SETOF api.file` | Create/update file, handles path→root mapping, decodes base64 data; an existing file needs the `w` bit (`AccessDenied` otherwise, since 1.2.24) |
| `api.get_file(pId)` | `SETOF api.file_data` | Get file with base64-encoded content; empty set when not readable by the current session (`CheckFileAccess`) |
| `api.get_file_id(pName, pPath)` | `uuid` | Resolve file ID by name + path |
| `api.decode_file_access(pId, pUserId)` | `record (r, w, x)` | Effective access verdict; contract for FileServer's disk-cache path (since 1.2.22) |
| `api.delete_file(pId)` | `boolean` | Delete file; `false` when there is none, `AccessDenied` without the `w` bit (since 1.2.24) |
| `api.count_file(pSearch, pFilter)` | `SETOF bigint` | Count with search/filter — of the files the session may read: `api.sql('kernel', 'FileObject', …)` + `FileAccess` (since 1.2.24; before, the whole tree) |
| `api.list_file(pSearch, pFilter, pLimit, pOffSet, pOrderBy)` | `SETOF api.file` | List with search/filter/pagination — same barrier as `api.count_file` |

## REST Routes — 5

Dispatcher: `rest.file(pPath text, pPayload jsonb)`.

| Path | Purpose |
|------|---------|
| `/file/set` | Create/update file (array/single) |
| `/file/get` | Fetch file(s) by ID or path+name with field projection |
| `/file/list` | List files (default orderby: `sortlist` for tree order) |
| `/file/count` | Count matching files |
| `/file/delete` | Delete file(s) by ID or path+name (resolved through `api.get_file_id`, as `/file/get`; a name is required — a missing one would default to `index.html`) |

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `table.sql` | yes | no | 1 table + 5 triggers |
| `view.sql` | yes | yes | File, FileData, FileTree, FileObject views |
| `routine.sql` | yes | yes | ~15 kernel functions |
| `api.sql` | yes | yes | 2 api views + 6 api functions |
| `rest.sql` | yes | yes | `rest.file` dispatcher (5 routes) |
| `init.sql` | yes | no | Route registration |
| `create.psql` | - | - | Includes all |
| `update.psql` | - | - | Excludes table.sql, init.sql |
