# workflow

> Platform module #15 | Loaded by `create.psql` line 15

**The conceptual heart of the platform.** Implements a full state-machine workflow engine: entities → classes (inheritance tree) → types, states, actions, methods, transitions, events. Every business object in the system is governed by this workflow. Also manages three access-control layers: ACU (class-level), AMU (method-level), and AOU (object-level, defined in the entity module).

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel`, `locale`, `admin` (users/groups for ACU/AMU) | `entity/object` (all objects use workflow states/methods/events), all configuration entities |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `db` | 20 tables (10 core + 10 `_text` i18n) |
| `kernel` | 18 views, 89 functions |
| `api` | 12 views, 49 functions |
| `rest` | `rest.workflow` dispatcher (52 routes) |

## Core Concepts

### Entity → Class → Type

```
Entity (e.g., "object")
  └── Class tree (inheritance, can be abstract)
        ├── "object" (abstract root)
        │   ├── "document" (abstract)
        │   │   ├── "client" (concrete)
        │   │   └── "station" (concrete)
        │   └── "reference" (abstract)
        │       ├── "region" (concrete)
        │       └── "currency" (concrete)
        └── Types per class (e.g., client has "individual", "legal")
```

- **Entity**: top-level business concept (code only: `object`, `message`, `job`)
- **Class**: hierarchical classification with inheritance (`class_tree`). Parent's ACU/events propagate to children. `abstract=true` means no objects instantiate directly.
- **Type**: concrete subtypes within a class (e.g., class `station` has types `base`, `rover`)

### State Machine

```
        ┌─────── restore ────────┐
        ▼                        │
   ┌─────────┐  enable   ┌─────────┐  disable  ┌──────────┐
   │ Created  │──────────▶│ Enabled │──────────▶│ Disabled │
   │(created) │           │(enabled)│           │(disabled)│
   └────┬─────┘           └────┬────┘           └────┬─────┘
        │ disable              │ enable              │ enable
        ▼                      │  ▲                  │  ▲
   ┌──────────┐                │  │                  │  │
   │ Disabled │◀───────────────┘  └──────────────────┘  │
   └────┬─────┘                                         │
        │ delete    delete ──┐  delete ──┐              │
        ▼           ▼        │  ▼        │              │
   ┌─────────┐              ┌┘          ┌┘              │
   │ Deleted  │◀────────────┘◀──────────┘               │
   │(deleted) │                                         │
   └────┬─────┘                                         │
        │ restore                                       │
        └───────────────────────────────────────────────┘
```

Four **state types** (fixed): `created`, `enabled`, `disabled`, `deleted`.
Each class gets its own **state** instances per state type.

### Methods & Actions

- **Action**: a named operation (54 seed values: `create`, `enable`, `disable`, `delete`, `restore`, `drop`, `open`, `edit`, `save`, `update`, `send`, `pay`, `approve`, etc.)
- **Method**: binds an action to a class+state. Code is auto-generated as `"{state_code}:{action_code}"` (e.g., `"created:enable"`). Methods without a state are "global" (can execute from any state).
- **Transition**: maps `(current_state, method) → new_state`. This is what drives the state machine.

### Events

- **Event type**: `parent` (inherit from parent class), `event` (PL/pgSQL function call), `plpgsql` (inline code)
- **Event**: bound to a class+action. When a method fires, the engine finds all events for that action on the class (and parent classes via `parent` event type) and executes them in sequence order.

### Default Workflow Setup

`AddDefaultMethods(pClass)` creates the standard lifecycle:
1. 10 global methods (create, open, edit, save, update, enable, disable, delete, restore, drop)
2. 4 states (created → enabled → disabled → deleted)
3. State-specific methods (e.g., `created:enable`, `created:disable`, `created:delete`)
4. All transitions between states

## Tables — 20 total (10 core + 10 i18n `_text`)

### Core Tables

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.entity` | Business entities | `id uuid PK`, `code text UNIQUE` |
| `db.class_tree` | Class hierarchy | `id uuid PK`, `parent uuid FK(self)`, `entity uuid FK`, `level int`, `code text UNIQUE`, `abstract bool` |
| `db.acu` | Class access control | PK(`class uuid FK`, `userid uuid FK`), `deny bit(5)`, `allow bit(5)`, `mask bit(5)` — bits: `{a,c,s,u,d}` = access, create, select, update, delete |
| `db.type` | Object types per class | `id uuid PK`, `class uuid FK`, `code text`; UNIQUE(`class`,`code`) |
| `db.state_type` | State type catalogue | `id uuid PK`, `code text UNIQUE` (created/enabled/disabled/deleted) |
| `db.state` | States per class | `id uuid PK`, `class uuid FK`, `type uuid FK`, `code text`, `sequence int`; UNIQUE(`class`,`code`) |
| `db.action` | Action catalogue | `id uuid PK`, `code text UNIQUE` |
| `db.method` | Methods (class+state+action) | `id uuid PK`, `parent uuid FK(self)`, `class uuid FK`, `state uuid FK` (NULL=global), `action uuid FK`, `code text`, `sequence int`, `visible bool`; UNIQUE(`class`,`code`) |
| `db.amu` | Method access control | PK(`method uuid FK`, `userid uuid FK`), `deny bit(3)`, `allow bit(3)`, `mask bit(3)` — bits: `{x,v,e}` = execute, visible, enable |
| `db.transition` | State transitions | `id uuid PK`, `state uuid FK` (current, NULL=any), `method uuid FK UNIQUE`, `newState uuid FK` |
| `db.event_type` | Event type catalogue | `id uuid PK`, `code text UNIQUE` (parent/event/plpgsql) |
| `db.event` | Events per class+action | `id uuid PK`, `class uuid FK`, `type uuid FK`, `action uuid FK`, `text text` (function/code), `sequence int`, `enabled bool` |
| `db.priority` | Priority levels | `id uuid PK`, `code text UNIQUE` |

### Internationalization Tables (`_text`)

Each core table (except acu, amu, transition) has a companion `_text` table with PK(`entity_id`, `locale uuid FK`) providing localized `name`/`label`/`description`:

`db.entity_text`, `db.class_text`, `db.type_text`, `db.state_type_text`, `db.state_text`, `db.action_text`, `db.method_text`, `db.event_type_text`, `db.event_text`, `db.priority_text`.

## ACU Mask Bits (5-bit: `{a c s u d}`)

| Bit | Permission |
|-----|------------|
| `a` | access — can see the class exists |
| `c` | create — can create objects of this class |
| `s` | select — can read/list objects |
| `u` | update — can edit objects |
| `d` | delete — can delete objects |

Default ACU on class creation (via trigger):
- Root class: administrator=`11111`, apibot=`01110`
- `document` subclass: +user group=`11000`
- `reference` subclass: +user group=`10100`
- `message` subclass: +mailbot=`01110`

## AMU Mask Bits (3-bit: `{x v e}`)

| Bit | Permission |
|-----|------------|
| `x` | execute — can invoke the method |
| `v` | visible — method appears in UI |
| `e` | enable — method is active/clickable |

## Views — 18 kernel views

| View | Description |
|------|-------------|
| `Entity` | Entities with localized name/description |
| `Class` | Classes with entity info and localized label |
| `ClassTree` | Recursive CTE class hierarchy (sorted) |
| `ClassMembers` | ACU entries with user info |
| `Type` | Types with class and entity info |
| `StateType` | State types with localized name |
| `State` | States with class, state type, entity info |
| `Action` | Actions with localized name |
| `Method` | Methods with class, state, action info |
| `AccessMethod` | Methods filtered by current user's AMU permissions (execute/visible/enable) |
| `MethodMembers` | AMU entries with user info |
| `Transition` | Transitions with state/method/newstate labels |
| `EventType` | Event types with localized name |
| `Event` | Events with type, action, localized label |
| `AMU` | Full AMU view with class, method, user info |
| `Priority` | Priorities with localized name |

### api schema — 12 views

`api.entity`, `api.type`, `api.class` (with access filtering), `api.class_access`, `api.state_type`, `api.state`, `api.action`, `api.method` (based on AccessMethod), `api.method_access`, `api.transition`, `api.event_type`, `api.event`, `api.priority`.

## Functions (kernel schema) — 89 total

### Entity CRUD (5)

`AddEntity`, `EditEntity`, `DeleteEntity`, `GetEntity`, `GetEntityCode`.

### Class Management (9)

`AddClass`, `EditClass`, `DeleteClass`, `GetClass`, `GetClassEntity`, `GetClassCode`, `GetClassLabel`, `CloneClass` (create + copy parent config), `CopyClass` (copy events/methods/states between classes).

### Type Management (9)

`AddType`, `EditType`, `DeleteType`, `GetType` (2 overloads), `SetType` (upsert), `GetTypeCode`, `GetTypeName`, `GetTypeCodes`, `CodeToType`.

### State Type (2)

`GetStateType`, `GetStateTypeCode`.

### State Management (9)

`AddState`, `EditState`, `SetState` (upsert), `DeleteState`, `GetState` (2 overloads — searches parent classes), `GetStateTypeByState`, `GetStateTypeCodeByState`, `GetStateCode`, `GetStateLabel`.

### Action Management (7)

`AddAction`, `EditAction`, `DeleteAction`, `SetAction` (upsert), `GetAction`, `GetActionCode`, `GetActionName`.

### Method Management (6)

`AddMethod` (auto-generates code as `state:action`), `EditMethod`, `DeleteMethod`, `GetMethod` (searches parent classes, skips abstract), `IsVisibleMethod`, `IsHiddenMethod`.

### Transition (3)

`AddTransition`, `EditTransition`, `DeleteTransition`.

### Event (4)

`GetEventType`, `AddEvent`, `EditEvent`, `DeleteEvent`.

### Priority (7)

`AddPriority`, `EditPriority`, `DeletePriority`, `SetPriority` (upsert), `GetPriority`, `GetPriorityCode`, `GetPriorityName`.

### ACU — Class Access Control (7)

`acu(userid)`, `acu(userid, class)`, `GetClassAccessMask`, `CheckClassAccess`, `DecodeClassAccess` → `(a,c,s,u,d)`, `chmodc` (set access, supports recursive + propagate to objects), `GetClassMembers`.

### AMU — Method Access Control (7)

`amu(userid)`, `amu(userid, method)`, `GetMethodAccessMask`, `CheckMethodAccess`, `DecodeMethodAccess` → `(x,v,e)`, `chmodm`, `GetMethodMembers`.

### Text Editing — Multilingual (16)

`New*Text` / `Edit*Text` for: Entity, Class, Type, State, Action, Method, Event, Priority (2 functions each).

## Functions (api schema) — 49 total

Standard CRUD pattern per entity: `add_*`, `update_*`, `set_*` (upsert), `delete_*`, `get_*`, `list_*` (with search/filter/pagination).

Plus: `api.class()`, `api.copy_class()`, `api.clone_class()`, `api.decode_class_access()`, `api.class_access()`, `api.state()`, `api.state_by_type()`, `api.method()`, `api.get_methods()`, `api.get_object_methods()`, `api.get_methods_json()`, `api.get_methods_jsonb()`, `api.decode_method_access()`, `api.method_access()`.

## REST Routes — 52

Dispatcher: `rest.workflow(pPath text, pPayload jsonb)`.

| Group | Count | Operations |
|-------|-------|------------|
| Entity | 3 | count, get, list |
| Type | 5 | count, set, get, list, delete |
| Class | 10 | count, set, copy, clone, get, list, delete, access, access/set, access/list, access/decode |
| State | 6 | type, count, set, get, list, delete |
| Action | 3 | count, get, list |
| Method | 9 | count, set, get, list, delete, access, access/set, access/list, access/decode |
| Transition | 5 | count, set, get, list, delete |
| Event | 6 | type, count, set, get, list, delete |
| Priority | 3 | count, get, list |

## Triggers

| Trigger | Table | Timing | Purpose |
|---------|-------|--------|---------|
| `t_class_tree_insert` | `db.class_tree` | AFTER INSERT | Auto-populate ACU: inherit from parent or set defaults (administrator, apibot, user, mailbot) |
| `t_class_tree_before_delete` | `db.class_tree` | BEFORE DELETE | Cascade delete ACU entries |
| `t_acu_before` | `db.acu` | BEFORE INSERT/UPDATE | Compute mask = allow & ~deny |
| `t_method_before_insert` | `db.method` | BEFORE INSERT | Auto-generate code as `"{state}:{action}"` |
| `t_method_after_insert` | `db.method` | AFTER INSERT | Auto-populate AMU from class ACU (visible→`111`, hidden→`101`) |
| `t_method_before_delete` | `db.method` | BEFORE DELETE | Cascade delete transitions + AMU |
| `t_amu_before` | `db.amu` | BEFORE INSERT/UPDATE | Compute mask = allow & ~deny |

## Init / Seed Data (`InitWorkFlow()`)

### 4 State Types
`created`, `enabled`, `disabled`, `deleted` (bilingual ru/en).

### 3 Event Types
`parent` (inherit parent class events), `event` (PL/pgSQL function call), `plpgsql` (inline code).

### 54 Actions
`anything`, `abort`, `accept`, `add`, `alarm`, `approve`, `available`, `cancel`, `check`, `complete`, `confirm`, `create`, `delete`, `disable`, `done`, `drop`, `edit`, `enable`, `execute`, `expire`, `fail`, `faulted`, `finishing`, `heartbeat`, `invite`, `open`, `plan`, `post`, `postpone`, `preparing`, `reconfirm`, `remove`, `repeat`, `reserve`, `reserved`, `restore`, `return`, `save`, `send`, `sign`, `start`, `stop`, `submit`, `unavailable`, `update`, `reject`, `pay`, `continue`, `agree`, `close`, `activate`, `refund`, `download`, `prepare`.

### 4 Priorities
`low`, `medium`, `high`, `critical` (bilingual).

### Helper Functions (in init.sql)

| Function | Purpose |
|----------|---------|
| `DefaultMethods(pClass)` | Create 10 global methods: create, open, edit, save, update, enable, disable, delete, restore, drop |
| `DefaultTransition(pClass)` | Create transitions for global (stateless) methods |
| `AddDefaultMethods(pClass, pNamesRU, pNamesEN)` | Full setup: DefaultMethods + 4 states + state-specific methods + all transitions |
| `UpdateDefaultMethods(pClass, pLocale, pNames)` | Update localized labels for default methods/states |

## Entity Registration Pattern

To register a new entity in the workflow system (done in each entity's `init.sql`):

```sql
-- 1. Create entity
PERFORM AddEntity('myentity', 'My Entity');

-- 2. Create class hierarchy
uClass := AddClass(GetClass('document'), GetEntity('object'), 'myentity', 'My Entity', false);

-- 3. Set up default workflow (states, methods, transitions)
PERFORM AddDefaultMethods(uClass);

-- 4. Add events (link actions to handler functions)
PERFORM AddEvent(uClass, GetEventType('parent'), GetAction('create'), 'EventMyEntityCreate');
PERFORM AddEvent(uClass, GetEventType('parent'), GetAction('edit'), 'EventMyEntityEdit');

-- 5. Add types
PERFORM AddType(uClass, 'default', 'Default');

-- 6. Register REST route
PERFORM RegisterRoute('myentity', 'rest.myentity');
```

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `table.sql` | yes | no | 20 tables (10 core + 10 _text) + 7 triggers |
| `view.sql` | yes | yes | 18 kernel views |
| `routine.sql` | yes | yes | 89 kernel functions |
| `api.sql` | yes | yes | 12 api views + 49 api functions |
| `rest.sql` | yes | yes | `rest.workflow` dispatcher (52 routes) |
| `init.sql` | yes | no | `InitWorkFlow()` + `DefaultMethods` + `DefaultTransition` + `AddDefaultMethods` + `UpdateDefaultMethods` |
| `create.psql` | - | - | Includes all |
| `update.psql` | - | - | Includes view, routine, api, rest |
