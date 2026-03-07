# Access Control in db-platform

> Reference for AI agents and developers.
> Explains how db-platform implements object-level access control.

---

## Why this document

db-platform **does not use PostgreSQL RLS** (Row-Level Security). Instead, it implements its own mechanism: ACL tables + Access views. This document describes the entire system — tables, functions, views, triggers, and development rules.

---

## Why not PostgreSQL RLS

1. **SECURITY DEFINER**: all functions execute as `kernel` (schema owner). PostgreSQL does not apply RLS policies to table owners without `FORCE ROW LEVEL SECURITY`.
2. **Session-based identity**: the actual user is determined via `current_userid()` (session setting), not via PostgreSQL role. The system has only 3-4 database roles (`kernel`, `daemon`, `apibot`, `admin`), but thousands of application users.
3. **Historical**: db-platform architecture predates widespread RLS adoption (PostgreSQL 9.5+).

Conclusion: db-platform uses **application-level ACL** via `acu` → `aou` + `aom` tables and filtering through `Access{Class}` views.

---

## Architecture: four layers of control

```
┌─────────────────────────────────────────────────────────────┐
│  1. ACU (Class-User)        On object CREATION              │
│     db.acu                  permissions are copied to AOU   │
│     5 bits: access, create, select, update, delete          │
├─────────────────────────────────────────────────────────────┤
│  2. AOU (Object-User)       Primary permissions table       │
│     db.aou                  allow & ~deny = mask            │
│     3 bits: select, update, delete                          │
├─────────────────────────────────────────────────────────────┤
│  3. AOM (Object Mask)       UNIX-style fallback             │
│     db.aom                  owner/group/other × sud         │
│     9 bits: {user:sud}{group:sud}{other:sud}                │
├─────────────────────────────────────────────────────────────┤
│  4. OMA (Object-Method-User) Method access per object       │
│     db.oma                  lazily cached from AMU          │
│     3 bits: execute, visible, enable                        │
└─────────────────────────────────────────────────────────────┘
```

Check priority: **AOU → AOM** (fallback). If `aou` has an entry for the user/group — it is used. Otherwise — `aom` (UNIX mask) is checked.

---

## Tables

### db.acu — Class-User Access (permission template)

**File**: `workflow/table.sql`

```sql
CREATE TABLE db.acu (
    class       uuid NOT NULL REFERENCES db.class_tree(id),
    userid      uuid NOT NULL REFERENCES db.user(id),
    deny        bit(5) NOT NULL,   -- {a c s u d}
    allow       bit(5) NOT NULL,   -- {a c s u d}
    mask        bit(5) DEFAULT B'00000' NOT NULL,  -- auto: allow & ~deny
    PRIMARY KEY (class, userid)
);
```

**Bits (5)**: `a` — access, `c` — create, `s` — select, `u` — update, `d` — delete.

**Purpose**: permission template for a class. When a new object of this class is created, bits `s`, `u`, `d` (positions 3-5) are copied into `aou`.

**Trigger**: `t_acu_before` — auto-computes `mask = allow & ~deny`.

### db.aou — Object-User Access (primary permissions table)

**File**: `entity/object/table.sql`

```sql
CREATE TABLE db.aou (
    object      uuid NOT NULL REFERENCES db.object(id) ON DELETE CASCADE,
    userid      uuid NOT NULL REFERENCES db.user(id) ON DELETE CASCADE,
    deny        bit(3) NOT NULL,   -- {s u d}
    allow       bit(3) NOT NULL,   -- {s u d}
    mask        bit(3) DEFAULT B'000' NOT NULL,  -- auto: allow & ~deny
    entity      uuid NOT NULL REFERENCES db.entity(id),
    PRIMARY KEY (object, userid)
);
```

**Bits (3)**: `s` — select (`B'100'`), `u` — update (`B'010'`), `d` — delete (`B'001'`).

**Column `entity`**: auto-filled by trigger from `db.object.entity`. Enables fast lookup of all objects of a given type accessible to a user.

**Indexes**: `(object)`, `(userid)`, `(entity)`, `(entity, userid, mask)`.

**Trigger**: `t_aou_before` — on INSERT auto-fills `entity` from `db.object` and computes `mask = allow & ~deny`.

### db.aom — Object Access Mask (UNIX-style fallback)

**File**: `entity/object/table.sql`

```sql
CREATE TABLE db.aom (
    object      uuid NOT NULL REFERENCES db.object(id) ON DELETE CASCADE,
    mask        bit(9) DEFAULT B'111100000' NOT NULL,
    PRIMARY KEY (object)
);
```

**Bits (9)**: `{user:sud}{group:sud}{other:sud}` — three triplets, like UNIX `rwx`.

**Default** `B'111100000'` = owner: full access, group: full access, other: nothing.

**Purpose**: if no `aou` entry exists for the user, `GetObjectMask()` checks `aom` and determines permissions by role (owner → bits 1-3, group → bits 4-6, other → bits 7-9).

### db.oma — Object-Method-User Access

**File**: `entity/object/table.sql`

```sql
CREATE TABLE db.oma (
    object      uuid NOT NULL REFERENCES db.object(id) ON DELETE CASCADE,
    method      uuid NOT NULL REFERENCES db.method(id) ON DELETE CASCADE,
    userid      uuid NOT NULL REFERENCES db.user(id) ON DELETE CASCADE,
    mask        bit(3) DEFAULT B'000' NOT NULL,
    PRIMARY KEY (object, method, userid)
);
```

**Bits (3)**: `x` — execute (`B'100'`), `v` — visible (`B'010'`), `e` — enable (`B'001'`).

**Purpose**: cached method permissions per object. Lazily populated from `db.amu` on first `CheckObjectMethodAccess()` call.

### db.amu — Method-User Access (method permission template)

**File**: `workflow/table.sql`

```sql
CREATE TABLE db.amu (
    method      uuid NOT NULL REFERENCES db.method(id) ON DELETE CASCADE,
    userid      uuid NOT NULL REFERENCES db.user(id) ON DELETE CASCADE,
    deny        bit(3) NOT NULL,   -- {x v e}
    allow       bit(3) NOT NULL,   -- {x v e}
    mask        bit(3) DEFAULT B'000' NOT NULL,
    PRIMARY KEY (method, userid)
);
```

### db.member_group — Group membership

**File**: `admin/table.sql`

```sql
CREATE TABLE db.member_group (
    userid        uuid NOT NULL REFERENCES db.user(id),  -- group
    member        uuid NOT NULL REFERENCES db.user(id),  -- user
    PRIMARY KEY (userid, member)
);
```

`userid` — group (user.type = 'G'), `member` — user (user.type = 'U'). A user can belong to multiple groups.

---

## Permission assignment on object creation

**Trigger**: `t_object_after_insert` on `db.object` → function `db.ft_object_after_insert()`.

**File**: `entity/object/table.sql`

What happens on `INSERT INTO db.object`:

```
1. INSERT INTO db.aom (object) — UNIX mask created (default B'111100000')

2. INSERT INTO db.aou (object, userid, deny, allow)
     SELECT object, userid, SubString(deny FROM 3 FOR 3), SubString(allow FROM 3 FOR 3)
       FROM db.acu WHERE class = NEW.class
     — permissions copied from ACU (bits 3-5 = select/update/delete)

3. INSERT INTO db.aou (object, owner, B'000', B'111')
     ON CONFLICT DO UPDATE SET deny = B'000', allow = B'111'
     — owner ALWAYS gets full permissions (select + update + delete)

4. If entity = 'message' and parent exists:
     — parent.owner gets SELECT access to the child message
```

### Example: what goes into AOU when creating a Trader

Assuming `db.acu` contains entries for the `trader` class (configured in `init.sql`):
- `(class=trader, userid=administrators, deny=00000, allow=11111)` → into AOU: `allow=B'111'`
- `(class=trader, userid=operators, deny=00000, allow=10100)` → into AOU: `allow=B'100'` (select only)

Plus the owner (creator) automatically gets `allow=B'111'`.

---

## Access check functions

**File**: `entity/object/security.sql`

### CheckObjectAccess(pObject, pMask, pUserId) → boolean

**Primary check function**. Used in UPDATE/DELETE triggers on `db.object`.

```sql
RETURN coalesce(
  coalesce(GetObjectAccessMask(pObject, pUserId), GetObjectMask(pObject, pUserId))
    & pMask = pMask,
  false
);
```

**Logic**:
1. Look up mask in `aou` (via `GetObjectAccessMask` → `aou(pUserId, pObject)`)
2. If not found — fallback to `aom` (via `GetObjectMask`)
3. Check: `(mask & required_bits) == required_bits`

**Used in triggers** (automatically, in platform):
```sql
-- ft_object_before_update:
IF NOT CheckObjectAccess(NEW.id, B'010') THEN  -- update
  PERFORM AccessDenied();
END IF;

-- ft_object_before_delete:
IF NOT CheckObjectAccess(OLD.id, B'001') THEN  -- delete
  PERFORM AccessDenied();
END IF;
```

### aou(pUserId) → SETOF (object, deny, allow, mask)

Returns ALL objects accessible to the user (or their groups).

```sql
WITH member_group AS (
    SELECT pUserId AS userid
    UNION
    SELECT userid FROM db.member_group WHERE member = pUserId
)
SELECT a.object, bit_or(a.deny), bit_or(a.allow), bit_or(a.allow) & ~bit_or(a.deny)
  FROM db.aou a INNER JOIN member_group m ON a.userid = m.userid
 GROUP BY a.object;
```

**Key mechanic**: `bit_or()` aggregates permissions from all user groups. Deny overrides allow via `allow & ~deny`.

### aou(pUserId, pObject) → SETOF (object, deny, allow, mask)

Same, but for a single object.

### GetObjectMask(pObject, pUserId) → bit(3)

Fallback via `aom`. Determines user role:
- `pUserId == owner` → bits 1-3 (user)
- `user.type = 'G'` → bits 4-6 (group)
- otherwise → bits 7-9 (other)

### DecodeObjectAccess(pObject, pUserId) → (s, u, d)

Decodes mask into three booleans:
- `s` = select (B'100')
- `u` = update (B'010')
- `d` = delete (B'001')

### chmodo(pObject, pMask, pUserId) → void

Sets permissions (administrators only).

```sql
-- pMask: 6 bits = {deny:sud}{allow:sud}
-- Example: B'000111' = deny=000, allow=111 (full access)
-- Example: B'000100' = deny=000, allow=100 (select only)
-- B'000000' = remove entry from AOU
```

### AccessObjectUser(pEntity, pUserId, pScope) → TABLE(object)

Returns IDs of objects of a given entity accessible to the user in the current scope.

```sql
HAVING (bit_or(a.allow) & ~bit_or(a.deny)) & B'100' = B'100'
```

---

## Access Views — view-level filtering mechanism

### Two Access view patterns

db-platform uses **two patterns** for Access views in different contexts:

#### Pattern 1: Entity-specific Access view (for configuration layer)

Used in `Object{Class}` views **in the configuration layer**. Each entity defines its own Access view:

```sql
CREATE OR REPLACE VIEW AccessTrader
AS
WITH _access AS (
   WITH _membergroup AS (
     SELECT current_userid() AS userid
     UNION
     SELECT userid FROM db.member_group WHERE member = current_userid()
   ) SELECT object
       FROM db.aou AS a INNER JOIN db.entity    e ON a.entity = e.id AND e.code = 'trader'
                        INNER JOIN _membergroup m ON a.userid = m.userid
      GROUP BY object
      HAVING (bit_or(a.allow) & ~bit_or(a.deny)) & B'100' = B'100'
) SELECT t.* FROM db.trader t INNER JOIN _access ac ON t.id = ac.object;
```

**Key points**:
- Filters by `e.code = 'trader'` — only objects of this entity
- `HAVING ... & B'100' = B'100'` — requires SELECT permission
- Returns rows from the entity table (e.g. `db.trader`)

#### Pattern 2: Platform-level Access view

In the **platform layer** (`entity/object/view.sql`):

```sql
CREATE OR REPLACE VIEW AccessObject AS
  WITH access AS (
    SELECT * FROM aou(current_userid())
  )
  SELECT o.* FROM Object o INNER JOIN access ac ON o.id = ac.object
  WHERE o.scope = current_scope();
```

Uses `aou()` function — checks ALL objects (no entity filter).

### Rule: Object{Class} INNER JOIN Access{Class}

**MANDATORY**: in every `Object{Class}` view, the first JOIN must be:

```sql
FROM db.{entity} t INNER JOIN Access{Entity} ac ON t.id = ac.object
                   ...remaining JOINs...
```

This ensures automatic filtering by the current user's permissions. Without this JOIN, objects the user has no access to will be visible through the API.

### Examples

**Document entity** (ObjectTrader):
```sql
FROM db.trader    t INNER JOIN AccessTrader          ac ON t.id = ac.object
                    INNER JOIN db.document          d ON t.document = d.id
                     LEFT JOIN db.document_text    dt ON ...
```

**Reference entity** (ObjectVenue):
```sql
FROM db.venue     t INNER JOIN AccessVenue           ac ON t.id = ac.object
                    INNER JOIN db.reference          r ON t.reference = r.id
                     LEFT JOIN db.reference_text    rt ON ...
```

### Why NOT CheckObjectAccess in get_* functions

`api.get_{entity}(pId)` reads from the `api.{entity}` view, which is built on `Object{Entity}`. If `Object{Entity}` already contains `INNER JOIN Access{Entity}` — filtering happens automatically. Adding `CheckObjectAccess(id, B'100')` to WHERE is **redundant and harmful**:

1. **Double check** — access is already verified via JOIN
2. **N+1 problem** — `CheckObjectAccess` calls `aou()` separately for each row
3. **Inconsistency** — list/count use the view (with JOIN), while get uses a separate check

---

## User identification

### current_userid()

Returns UUID of the current user from session settings. Set when a session is created (`db.session`).

### current_scope()

Returns UUID of the current scope (organization/branch).

### How they are set

Functions `SetSessionUserId()`, `SetSessionScope()` etc. from the `session` module call `SET_CONFIG('context.userid', ...)`. Functions `current_userid()`, `current_scope()` from the `current` module read these settings.

Trigger `ft_session_before` on `db.session` sets the context on session creation.

---

## Bitmask summary

| Table | Bit 1 | Bit 2 | Bit 3 | Bit 4 | Bit 5 |
|-------|-------|-------|-------|-------|-------|
| **acu** (5 bits) | access | create | **select** | **update** | **delete** |
| **aou** (3 bits) | **select** | **update** | **delete** | — | — |
| **amu** (5 bits) | access | create | execute | visible | enable |
| **oma** (3 bits) | execute | visible | enable | — | — |
| **aom** (9 bits) | user:s | user:u | user:d | group:s | group:u | group:d | other:s | other:u | other:d |

When copying `acu → aou`: bits 3-5 are taken (`SubString(allow FROM 3 FOR 3)`), i.e. select/update/delete.

When copying `amu → oma`: bits 3-5 are taken (execute/visible/enable).

---

## Common masks

```sql
-- AOU (3 bits)
B'100'  -- SELECT (read)
B'010'  -- UPDATE (modify)
B'001'  -- DELETE (remove)
B'110'  -- SELECT + UPDATE
B'111'  -- Full access

-- chmodo (6 bits: deny + allow)
B'000111'  -- deny=000, allow=111 (full access)
B'000100'  -- deny=000, allow=100 (read only)
B'000000'  -- remove entry from AOU

-- ACU (5 bits)
B'11111'  -- access + create + select + update + delete
B'10100'  -- access + select (view only)
```

---

## Source files

| File | Contents |
|------|----------|
| `entity/object/table.sql` | DDL: `db.aom`, `db.aou`, `db.oma`; triggers `ft_object_after_insert`, `ft_aou_before` |
| `entity/object/security.sql` | `aou()`, `CheckObjectAccess()`, `GetObjectMask()`, `GetObjectAccessMask()`, `DecodeObjectAccess()`, `chmodo()`, `AccessObjectUser()`, `CheckObjectMethodAccess()` |
| `entity/object/view.sql` | `AccessObject`, `AccessObjectId`, `ObjectMembers`, `AOU` view |
| `workflow/table.sql` | DDL: `db.acu`, `db.amu`; triggers `ft_acu_before`, `ft_amu_before`, `ft_method_after_insert` |
| `admin/table.sql` | DDL: `db.member_group`, `db.user` |

---

## Checklist for creating an entity

When creating a new entity in the configuration layer:

1. **`view.sql`**: create `Access{Entity}` view using the pattern (CTE with `_membergroup` + `_access`, filter by `e.code`)
2. **`view.sql`**: in `Object{Entity}` view — first JOIN: `INNER JOIN Access{Entity} ac ON t.id = ac.object`
3. **`init.sql`**: configure `acu` via `AddClass()` / `AddType()` — define which groups get access when objects are created
4. **`api.sql`**: `api.{entity}` view is built on `Object{Entity}` — filtering is automatic
5. **Do NOT add** `CheckObjectAccess()` to `api.get_*` — this is duplication

---

## Related documentation

- [wiki/64-Access-Control.md](wiki/64-Access-Control.md) — Detailed Access Control API guide
- [wiki/63-Entity-System-Internals.md](wiki/63-Entity-System-Internals.md) — Entity system internals
- [wiki/71-Creating-Entity.md](wiki/71-Creating-Entity.md) — Step-by-step entity creation guide
- [entity/object/INDEX.md](entity/object/INDEX.md) — entity/object module reference
