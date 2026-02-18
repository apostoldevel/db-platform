# entity/object

> Platform module #18 (part of entity system) | Loaded by `entity/object/create.psql`

**The foundational object module.** Every business entity in the platform (documents, references, messages, jobs) is ultimately an `object`. Provides: 14 core tables (object, text, access control, state history, groups, links, references, files, data, coordinates), ~130 kernel functions, ~65 REST routes, full-text search (EN/RU), and three-layer access control (AOM/AOU/OMA).

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel`, `workflow` (entity/class/type/state/method/action/event), `admin` (users/groups/scope) | `reference/`, `document/` (all concrete entities inherit from object) |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `db` | 14 tables + ~8 triggers |
| `kernel` | 13 views, ~130 functions (routine.sql + security.sql) |
| `api` | 10 views, ~70 functions |
| `rest` | `rest.object` dispatcher (~65 routes) |

## Loading Order (create.psql)

```
table.sql → security.sql → view.sql → routine.sql → api.sql → rest.sql → event.sql → init.sql
  → reference/create.psql
  → document/create.psql
  → search.sql
```

## Tables — 14

### Core

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.object` | Central object table | `id uuid PK`, `parent uuid FK(self)`, `scope uuid FK`, `entity uuid FK`, `class uuid FK`, `type uuid FK`, `state_type uuid FK`, `state uuid FK`, `suid uuid FK`, `owner uuid FK`, `oper uuid FK`, `pdate`, `ldate`, `udate` |
| `db.object_text` | Localized label/text per locale | PK(`object`, `locale`), `label`, `text`, `searchable_en tsvector`, `searchable_ru tsvector` (GIN indexed) |

### Access Control (AOU — third layer, complements ACU/AMU from workflow)

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.aom` | Object access mask (UNIX-style) | `object uuid`, 9-bit mask: `user/group/other × select/update/delete` |
| `db.aou` | Object-user access | PK(`object`, `userid`), `deny bit(3)`, `allow bit(3)`, `mask bit(3)` (computed = allow & ~deny) |
| `db.oma` | Object-method-user access | PK(`object`, `method`, `userid`), 3-bit mask: `{execute, visible, enable}` |

### State & Execution

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.object_state` | Temporal state history | `id uuid PK`, `object uuid FK`, `state uuid FK`, `validFromDate`, `validToDate` |
| `db.method_stack` | Method execution context | PK(`object`, `method`), `result jsonb` |

### Grouping & Relationships

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.object_group` | Named object groups per owner | `id uuid PK`, `owner uuid FK`, `code text`, `name`, `description` |
| `db.object_group_member` | Group membership | PK(`gid`, `object`) |
| `db.object_link` | Object-to-object relationships | `id uuid PK`, `object uuid FK`, `linked uuid FK`, `key text`, `validFromDate`, `validToDate` |
| `db.object_reference` | External string references | `id uuid PK`, `object uuid FK`, `key text`, `reference text`, temporal validity |

### Attachments

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.object_file` | File attachments | PK(`object`, `file`), `updated timestamptz` |
| `db.object_data` | Arbitrary data (text/json/xml/base64) | PK(`object`, `type`, `code`), `data text` |
| `db.object_coordinates` | Geolocation | `id uuid PK`, `object uuid FK`, `code text`, `latitude`, `longitude`, `accuracy`, `label`, `data jsonb`, temporal |

## Triggers — ~8

| Trigger | Table | Purpose |
|---------|-------|---------|
| `ft_object_before_insert` | `db.object` | Generate UUID, validate class/type, set ownership |
| `ft_object_after_insert` | `db.object` | Add AOM/AOU records, message-specific permissions |
| `ft_object_before_update` | `db.object` | Access checks, entity validation, state transitions |
| `ft_object_before_delete` | `db.object` | Access checks, cleanup AOM/AOU |
| `ft_object_state_change` | `db.object_state` | Validate temporal date ranges |
| `t_aou_before` | `db.aou` | Compute mask = allow & ~deny |

## Views — 13 kernel + 10 api

### Kernel Views

| View | Description |
|------|-------------|
| `Object` | Full object with entity/class/type/state/owner/scope metadata |
| `AccessObject` | Filtered by aou `SELECT` permission + current_scope |
| `AccessObjectId` | IDs only of accessible objects |
| `ObjectMembers` | AOU entries with user info (deny/allow/mask as integers) |
| `ObjectState` | Temporal state history with state labels |
| `ObjectGroup` | Groups for current_userid + current_scope |
| `ObjectGroupMember` | Objects in groups |
| `ObjectLink` | Active object relationships |
| `ObjectFile` | Files with owner/size/path/MIME info |
| `ObjectFileData` | Files with base64-encoded data |
| `ObjectData` | Arbitrary object data entries |
| `ObjectCoordinates` | Geolocation with full object context |
| `AOU` | Complete access audit view |

## Security (security.sql) — Object-Level Access Control

### AOU Functions

| Function | Returns | Purpose |
|----------|---------|---------|
| `aou(pUserId)` | `SETOF record` | All objects accessible to user/groups (bit_or aggregation) |
| `aou(pUserId, pObject)` | `SETOF record` | Specific object access |
| `access_entity(pUserId, pEntity)` | `SETOF record` | All accessible objects of entity type |
| `GetObjectAccessMask(pObject, pUserId)` | `bit` | Computed mask from aou |
| `CheckObjectAccess(pObject, pMask, pUserId)` | `boolean` | Test permission (falls back to aom) |
| `DecodeObjectAccess(pObject, pUserId)` | `record(s,u,d)` | Boolean select/update/delete |
| `chmodo(pObject, pMask, pUserId)` | `void` | Set AOU from 6-bit mask (admin only) |
| `AccessObjectUser(pEntity, pUserId, pScope)` | `TABLE(object)` | All accessible objects in scope |

### OMA Functions (Object-Method Access)

| Function | Returns | Purpose |
|----------|---------|---------|
| `GetObjectMethodAccessMask(pObject, pMethod, pUserId)` | `bit` | Method mask from oma |
| `CheckObjectMethodAccess(pObject, pMethod, pMask, pUserId)` | `boolean` | Auto-populates oma from amu on first check |

## Functions (kernel schema) — ~130

### Object CRUD

`CreateObject`, `EditObject`, `SetObjectParent`, `SetObjectLabel`, `SetObjectOwner`.

### Object Property Getters

`GetObjectEntity`, `GetObjectParent`, `GetObjectLabel`, `GetObjectClass`, `GetObjectType`, `GetObjectTypeCode`, `GetObjectState`, `GetObjectStateCode`, `GetObjectStateType`, `GetObjectStateTypeCode`, `GetObjectOwner`, `GetObjectOper`.

### State Management

`AddObjectState`, `GetObjectState(pObject, pDate)` (historical), `GetNewState`, `ChangeObjectState`, `GetObjectMethod`.

### Method Execution Engine

| Function | Returns | Purpose |
|----------|---------|---------|
| `ExecuteAction(pClass, pAction)` | `void` | Recursive event handler chain |
| `ExecuteMethod(pObject, pMethod, pParams)` | `jsonb` | Full method dispatch with method_stack |
| `ExecuteMethodForAllChild(pObject, pClass, pMethod, pAction, pParams)` | `jsonb` | Execute on all children |
| `ExecuteObjectAction(pObject, pAction, pParams)` | `jsonb` | Find method for action, execute |

### State Query (Boolean)

`IsCreated`, `IsEnabled`, `IsDisabled`, `IsDeleted`, `IsActive` (created OR enabled).

### Action Convenience (Do* Functions)

`DoAction`, `DoTryAction` (exception-safe), `DoSave`, `DoCreate`, `DoEnable`, `DoDisable`, `DoDelete`, `DoComplete`, `DoDone`, `DoFail`, `DoCancel`, `DoUpdate`, `DoRestore`, `DoDrop`.

### Object Groups

`CreateObjectGroup`, `EditObjectGroup`, `GetObjectGroup`, `ObjectGroup`, `AddObjectToGroup`, `DeleteObjectFromGroup`.

### Object Links / References

`SetObjectLink`, `GetObjectLink`, `SetObjectReference`, `GetObjectReference`, `GetReferenceObject`.

### File Operations

`NewObjectFile`, `EditObjectFile`, `DeleteObjectFile`, `ClearObjectFiles`, `SetObjectFile`, `GetObjectFiles`, `GetObjectFilesJson`, `GetObjectFilesJsonb`.

### Arbitrary Data

`NewObjectData`, `EditObjectData`, `DeleteObjectData`, `SetObjectData`, `SetObjectDataJSON`, `SetObjectDataXML`, `GetObjectData`, `GetObjectDataJSON`, `GetObjectDataXML`, `GetObjectDataJson`, `GetObjectDataJsonb`.

### Coordinates

`NewObjectCoordinates`, `DeleteObjectCoordinates`, `GetObjectCoordinates`, `GetObjectCoordinatesJson`, `GetObjectCoordinatesJsonb`, `ObjectCoordinates(pDateFrom)`.

## Full-Text Search (search.sql)

| Function | Returns | Purpose |
|----------|---------|---------|
| `api.search_en(pText)` | `SETOF api.object` | English FTS on `searchable_en` + reference code prefix |
| `api.search_ru(pText)` | `SETOF api.object` | Russian FTS on `searchable_ru` + reference code prefix |
| `api.search(pText, pEntities, pLocaleCode)` | `SETOF api.object` | Auto-delegates to _en/_ru by locale, filter by entity |

## Events — 9

| Event | Handler | Cleanup on Drop |
|-------|---------|-----------------|
| create | `EventObjectCreate` | — |
| open | `EventObjectOpen` | — |
| edit | `EventObjectEdit` | — |
| save | `EventObjectSave` | — |
| enable | `EventObjectEnable` | — |
| disable | `EventObjectDisable` | — |
| delete | `EventObjectDelete` | — |
| restore | `EventObjectRestore` | — |
| drop | `EventObjectDrop` | Cascades: comment, notice, object_link, object_file, object_data, object_state, method_stack, notification, log; nulls parent in children; deletes object |

## REST Routes — ~65

Dispatcher: `rest.object(pPath text, pPayload jsonb)`.

| Group | Routes | Operations |
|-------|--------|------------|
| Metadata | 7 | class, type, state, method, access, access/set, access/decode |
| CRUD | 4 | set, get, list, count, delete/force |
| State History | 3 | state/history/get, list, count |
| Method/Action | 5 | method/execute, action/execute, method/history/get, list, count |
| Groups | 7 | group/set, get, list, count, member, member/add, member/delete |
| Links | 6 | link, unlink, link/set, get, list, count |
| Files | 7 | file, file/set, get, list, count, delete, clear |
| Data | 4 | data, data/set, get, list |
| Addresses | 4 | address, address/set, get, list |
| Geolocation | 5 | geolocation, geolocation/set, get, list, count |

## Init (init.sql)

| Function | Purpose |
|----------|---------|
| `AddObjectEvents(pClass)` | Register 9 event handlers + `ChangeObjectState` for state-changing actions |
| `CreateClassObject(pParent, pEntity)` | Create abstract class `'object'`, register events, add default methods |
| `CreateEntityObject(pParent)` | Create entity `'object'`, class, register REST route `rest.object` |

## Key Design Patterns

1. **Temporal validity**: object_state, object_link, object_reference, object_coordinates all use `validFromDate/validToDate`
2. **Three-layer access**: AOM (default mask), AOU (user-specific override, deny/allow), OMA (method-level per user)
3. **Method stack**: Execution context stored in `method_stack`, result accumulation via JSONB merge
4. **Event cascade**: `ExecuteAction` walks parent classes via `'parent'` event type
5. **Batch REST**: All routes accept both single JSON objects and arrays

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `table.sql` | yes | no | 14 tables + ~8 triggers |
| `security.sql` | yes | yes | AOU/OMA access control functions |
| `view.sql` | yes | yes | 13 kernel views |
| `routine.sql` | yes | yes | ~130 kernel functions |
| `api.sql` | yes | yes | 10 api views + ~70 api functions |
| `rest.sql` | yes | yes | `rest.object` dispatcher (~65 routes) |
| `event.sql` | yes | yes | 9 event handlers |
| `init.sql` | yes | no | Entity/class/event registration |
| `search.sql` | yes | yes | Full-text search (EN/RU) |
| `create.psql` | - | - | Includes all + reference/ + document/ + search |
| `update.psql` | - | - | Excludes table.sql, init.sql |
