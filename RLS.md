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

An Access view answers exactly one question: **which object ids may the current
user read?** It returns a single column, `object`. It is never joined into
`Object{Class}`; the join is added **at runtime** by `api.sql()`, and is skipped
entirely for administrators, who by definition have full access and would only
pay for the check.

### The `Access{Entity}` view

**Configuration layer** — one view per entity, filtered through the denormalised
`db.aou.entity` column (indexed by `db.aou (entity, userid, mask)`):

```sql
CREATE OR REPLACE VIEW AccessAccount
AS
WITH _membergroup AS (
  SELECT current_userid() AS userid UNION SELECT userid FROM db.member_group WHERE member = current_userid()
) SELECT object
    FROM db.aou t INNER JOIN _membergroup m ON t.userid = m.userid
   WHERE t.entity = GetEntity('account')
   GROUP BY object
  HAVING (bit_or(t.allow) & ~bit_or(t.deny)) & B'100' = B'100';

GRANT SELECT ON AccessAccount TO administrator;
```

**Platform layer** — generic, no entity filter, scope filter instead
(`entity/object/view.sql`, `entity/object/document/view.sql`):

```sql
CREATE OR REPLACE VIEW AccessDocument
AS
WITH _membergroup AS (
  SELECT current_userid() AS userid UNION SELECT userid FROM db.member_group WHERE member = current_userid()
) SELECT a.object
    FROM db.aou a INNER JOIN _membergroup m ON a.userid = m.userid
                  INNER JOIN db.document  d ON a.object = d.object
   WHERE d.scope = current_scope()
   GROUP BY a.object
  HAVING (bit_or(a.allow) & ~bit_or(a.deny)) & B'100' = B'100';
```

Two details of the `HAVING` clause are not decorative:

- **Aggregate, do not filter per row.** `bit_or(allow) & ~bit_or(deny)` unions
  the user's own entry with every entry of the groups they belong to, so a deny
  in one group overrides an allow in another. A per-row `WHERE a.mask …` cannot
  express that.
- **Test the bit, never compare the mask.** `& B'100' = B'100'` passes anyone
  who may read. `WHERE a.mask = B'100'` is a different, wrong condition: it
  excludes every user whose mask is wider — including the **owner**, whose
  `B'111'` row is inserted automatically by `t_object_after_insert`. On one
  production database that single mistake would hide 4.8 million of 9.6 million
  AOU rows.

### Rule: `Object{Class}` must NOT join `Access{Class}`

`Object{Class}` carries denormalisation and the organisational gates only —
`DocumentAreaTree` for documents, `scope = current_scope()` for references. It
must contain **no reference to an Access view**:

```sql
FROM db.{entity} t INNER JOIN db.document          d ON t.document = d.id
                   ...
                   INNER JOIN DocumentAreaTree     a ON d.area = a.id
                   INNER JOIN db.scope            sc ON o.scope = sc.id;
```

> Earlier versions of db-platform required the opposite — an
> `INNER JOIN Access{Entity}` as the first join of `Object{Class}`, with the
> Access view returning all columns of the entity table. That model is
> superseded. A project still carrying it, or carrying half of the conversion,
> is not protected: see the migration guide below.

### Where the join comes from

`api/api.sql`, function `api.sql()`:

```sql
  IF pScheme = 'kernel' AND GetAccessMode() THEN
    SELECT table_name INTO vTable
      FROM information_schema.tables
     WHERE table_catalog = current_database()
       AND table_schema = 'kernel'
       AND table_name = replace(lower(pTable), 'object', 'access')
       AND table_type = 'VIEW';

    IF FOUND THEN
      vJoin := format('INNER JOIN %s.%s aou ON t.id = aou.object', pScheme, vTable);
      PERFORM set_config('enable_nestloop', 'off', true);
    END IF;
  END IF;
```

Three preconditions, and the join is silently absent if any of them fails:

| Precondition | If violated |
|---|---|
| `pScheme = 'kernel'` | passing `'api'` never adds the join — the usual bug |
| `GetAccessMode()` is true | administrators get no join, by design |
| a view named `replace(lower(pTable),'object','access')` exists **in schema `kernel`** | no view, no join, no error |

`GetAccessMode()` is `coalesce(SafeGetVar('access')::boolean, true)` — it
defaults to **true**, so an unauthenticated session is filtered rather than
exempt. It is set on sign-in:

```sql
PERFORM SetAccessMode(NOT IsUserRole(GetGroup('administrator'), uUserId));
```

Note that `SignIn` and `SessionIn` set it, while `SubstituteUser` does **not** —
substituting a user does not re-evaluate the access mode.

The `set_config('enable_nestloop','off', true)` alongside the join is
transaction-local, and exists because the `HAVING` aggregate cannot be estimated
by the planner: combined with `ORDER BY … LIMIT` it used to collapse into a
Nested Loop two orders of magnitude slower than the correct plan.

Name derivation is textual and case-insensitive: `ObjectChargePoint →
accesschargepoint`, `ObjectSLA → accesssla`. A subclass with its own
`Object{Sub}` view therefore needs its own `Access{Sub}` view — the lookup will
not fall back to the parent's.

### The four pieces every entity must have

| # | Where | What |
|---|---|---|
| 1 | `view.sql` | `Access{Entity}` returning a single `object` column, in schema `kernel` |
| 2 | `view.sql` | `Object{Entity}` with **no** reference to `Access{Entity}` |
| 3 | `api.sql` | `api.{entity}` = `SELECT t.* FROM Object{Entity} t INNER JOIN Access{Entity} a ON t.id = a.object` — the static join, used by the by-id read path |
| 4 | `api.sql` | `api.count_{entity}` / `api.list_{entity}` calling `api.sql('kernel', 'Object{Entity}', …)` |

Point 4 reads oddly — `api.list_{entity}` returns `SETOF api.{entity}` while
querying `Object{Entity}`. It is correct: the row types are identical, because
`api.{entity}` is `SELECT t.*` from that very view, and the ACL arrives from the
runtime join instead of a static one.

Auxiliary and derived lists that are not entity objects — `tariff_schedule`,
`defect_log`, `object_address`, `model_property`, dashboards, protocol logs —
stay on `api.sql('api', '<name>', …)`.

### Migrating a project off the old model

Converting `Access{Entity}` from the wide form to the narrow one changes the
view's column count, which `CREATE OR REPLACE VIEW` cannot do:

```
ERROR: cannot drop columns from view
```

So the change ships as a patch that drops the old views with `CASCADE` (which
takes `api.{entity}` and every function returning `SETOF api.{entity}` with it,
all recreated by `update.psql`), plus an explicit
`DROP FUNCTION IF EXISTS api.get_{entity}(uuid)` for each, because their return
type changes.

Verify the result by reading the generated statement rather than by inspection:

```sql
SELECT api.sql('kernel','ObjectAccount', null, null, 5);
-- administrator      → FROM kernel.ObjectAccount t
-- everyone else      → FROM kernel.ObjectAccount t INNER JOIN kernel.accessaccount aou ON t.id = aou.object
```

### Why NOT `CheckObjectAccess` in `get_*` functions

`api.get_{entity}(pId)` reads the `api.{entity}` view, which already carries the
static `INNER JOIN Access{Entity}`. Adding `CheckObjectAccess(id, B'100')` to the
`WHERE` clause is redundant and harmful:

1. **Double check** — access is already verified by the join.
2. **N+1** — `CheckObjectAccess` calls `aou()` once per row.
3. **Inconsistency** — list/count would then use one path and get another.

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

1. **`view.sql`**: create the `Access{Entity}` view — CTE with `_membergroup`,
   `SELECT object FROM db.aou`, filter `WHERE t.entity = GetEntity('{entity}')`,
   and `HAVING (bit_or(allow) & ~bit_or(deny)) & B'100' = B'100'`. One column,
   `object`.
2. **`view.sql`**: `Object{Entity}` must **not** reference `Access{Entity}` — it
   carries denormalisation plus the organisational gate only
   (`DocumentAreaTree` for documents, `scope = current_scope()` for references).
3. **`api.sql`**: `api.{entity}` =
   `SELECT t.* FROM Object{Entity} t INNER JOIN Access{Entity} a ON t.id = a.object`
   — the static join, for reads by id.
4. **`api.sql`**: `api.count_{entity}` and `api.list_{entity}` call
   `api.sql('kernel', 'Object{Entity}', …)`. Passing `'api'` and `'{entity}'`
   applies **no** filtering and raises nothing.
5. **`init.sql`**: configure `acu` via `AddClass()` / `AddType()` — define which
   groups get access when objects are created.
6. **Do NOT add** `CheckObjectAccess()` to `api.get_*` — the static join already
   did it, and the call costs one `aou()` per row.
7. **Verify**: `SELECT api.sql('kernel','Object{Entity}', null, null, 5);` must
   show the `accessentity` join for a non-administrator and no join for an
   administrator.

---

## Related documentation

- [wiki/64-Access-Control.md](wiki/64-Access-Control.md) — Detailed Access Control API guide
- [wiki/63-Entity-System-Internals.md](wiki/63-Entity-System-Internals.md) — Entity system internals
- [wiki/71-Creating-Entity.md](wiki/71-Creating-Entity.md) — Step-by-step entity creation guide
- [entity/object/INDEX.md](entity/object/INDEX.md) — entity/object module reference
