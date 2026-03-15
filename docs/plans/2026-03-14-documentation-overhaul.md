# Documentation Overhaul — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Status:** Completed (2026-03-15)

**Goal:** Rewrite all JSDoc blocks, COMMENT ON statements, and inline comments to meaningful English across 25 modules (46 sub-modules).

**Architecture:** Process modules strictly in `create.psql` order. Within each module: read `table.sql` to understand data model, then document `routine.sql`, `api.sql`, and remaining files. One commit per module (small modules grouped).

**Tech Stack:** PL/pgSQL, PostgreSQL COMMENT ON, JSDoc-style documentation blocks.

**Design doc:** `docs/plans/2026-03-14-documentation-overhaul-design.md`

---

## Reference: JSDoc Template

Every function in `routine.sql` and `api.sql` gets this block immediately before `CREATE OR REPLACE FUNCTION`:

```sql
/**
 * @brief <One sentence: what the function does as an action.>
 * @param {<type>} <pName> - <Purpose in business context>
 * ...
 * @return {<type>} - <What is returned, including structure for record/SETOF>
 * @throws <ExceptionName> - <When it fires>
 * @see <RelatedFunction1>, <RelatedFunction2>
 * @since 1.0.0
 */
```

Rules:
- `@brief` — action verb, not "returns" (e.g., "Creates a new user account" not "Returns new user")
- `@param` — explain business purpose, not just translate the name
- `@return` — describe structure for composite types
- `@throws` — only for explicit `PERFORM SomeException()` calls; omit if none
- `@see` — Edit↔Create, Get↔List, Delete↔Create, Event↔Method; omit if no obvious peers
- `@since 1.0.0` — everywhere as baseline

## Reference: COMMENT ON Template

```sql
COMMENT ON TABLE db.<table> IS '<One-two sentences: role in the system, what it stores.>';
COMMENT ON COLUMN db.<table>.<col> IS '<Purpose and constraints. Not the data type.>';
```

## Reference: Inline Comment Policy

- **Remove** — comments restating the code (`-- update value` before UPDATE)
- **Translate** — comments explaining business logic or non-obvious decisions
- **Keep Russian** — only inside string literals (business data, seed values)

## Reference: Header Block Style

Keep existing separator style:
```sql
--------------------------------------------------------------------------------
-- FunctionName ----------------------------------------------------------------
--------------------------------------------------------------------------------
```

---

## Task 1: kernel — Core Types and Utilities

**Estimated functions:** 116 (general.sql: 41, public.sql: 70, jwt.sql: 5)
**COMMENT ON:** 0
**Note:** No existing JSDoc blocks — all documentation written from scratch.

**Files:**
- Modify: `kernel/general.sql` (1040 lines, 41 functions — UUID gen, phone utils, JSON helpers, crypto, string utils)
- Modify: `kernel/public.sql` (1684 lines, 70 functions — schema introspection, column helpers, encode/decode, AWS signature, HTTP utils)
- Modify: `kernel/jwt.sql` (86 lines, 5 functions — JWT sign/verify)
- Modify: `kernel/dt.sql` (42 lines — custom type definitions, add header comment)
- Skip: `kernel/api.sql` (10 lines — schema creation, no functions)
- Skip: `kernel/schema.sql`, `database.sql`, `users.sql`, `grant.sql` (DDL only)

**Step 1:** Read `kernel/dt.sql` — understand all custom types (TVarType, Id, Cardinal, Amount, etc.). Add a file-level header comment explaining the type system.

**Step 2:** Read `kernel/general.sql` — for each of 41 functions, understand purpose from code, add JSDoc block. Key function groups:
- UUID generation: `gen_kernel_uuid()`
- Random codes: `gen_random_code()`
- Phone normalization: `TrimPhone()`
- Session variables: `SetVar()`, `GetVar()`, `DeleteVar()`
- JSON/JSONB utilities: `JsonToFields()`, `JsonbToFields()`, `JsonToArray()`, `ArrayToJson()`
- Encoding: `encode_base64url()`, `decode_base64url()`
- Crypto: `hmac256()`, various sign/hash functions
- String manipulation: `StrRight()`, `StrLeft()`, `GetCompare()`
- Clean up inline comments (translate useful, remove obvious)

**Step 3:** Read `kernel/public.sql` — for each of 70 functions, add JSDoc block. Key function groups:
- Schema introspection: `get_columns()`, `get_routines()`
- Views: `all_tab_columns`, `all_col_comments`
- Column metadata helpers
- AWS signature v4: `create_canonical_request()`, `create_string_to_sign()`, `calculate_signature()`
- HTTP utilities: URI parsing, header building
- Base64/encoding utilities
- Clean up inline comments

**Step 4:** Read `kernel/jwt.sql` — document 5 JWT functions: `url_encode`, `url_decode`, `algorithm_sign`, `sign`, `verify`.

**Step 5:** Commit.

```bash
git add kernel/
git commit -m "docs(kernel): add English JSDoc for 116 functions and clean up inline comments"
```

---

## Task 2: oauth2 — OAuth 2.0 Infrastructure

**Estimated functions:** routine.sql functions + view definitions
**COMMENT ON:** 28

**Files:**
- Modify: `oauth2/table.sql` (127 lines, 28 COMMENT ON — rewrite all)
- Modify: `oauth2/routine.sql` (298 lines — CRUD for providers, applications, issuers, audiences)
- Modify: `oauth2/view.sql` (if has comments)

**Step 1:** Read `oauth2/table.sql` — understand 5 tables (provider, application, issuer, audience, + junction). Rewrite all 28 COMMENT ON with meaningful English descriptions.

**Step 2:** Read `oauth2/routine.sql` — document all functions (Create/Edit/Get/Delete for each entity).

**Step 3:** Clean inline comments.

**Step 4:** Commit.

```bash
git add oauth2/
git commit -m "docs(oauth2): rewrite COMMENT ON (28) and add JSDoc for all functions"
```

---

## Task 3: locale — Multi-language Support

**Estimated functions:** small (25 lines routine.sql)
**COMMENT ON:** 5

**Files:**
- Modify: `locale/table.sql` (19 lines, 5 COMMENT ON)
- Modify: `locale/routine.sql` (25 lines)

**Step 1:** Rewrite 5 COMMENT ON in `table.sql`.

**Step 2:** Document functions in `routine.sql`.

**Step 3:** Commit.

```bash
git add locale/
git commit -m "docs(locale): rewrite COMMENT ON (5) and add JSDoc"
```

---

## Task 4: admin — Users, Auth, Sessions, ACL

**Estimated functions:** ~200+ (routine.sql: 5208 lines, api.sql: 2253 lines)
**COMMENT ON:** 142
**Note:** Largest module. This is the most time-consuming task.

**Files:**
- Modify: `admin/table.sql` (1172 lines, 142 COMMENT ON — 18 tables)
- Modify: `admin/routine.sql` (5208 lines — user CRUD, auth, session, scope, area, group, member, ACL)
- Modify: `admin/api.sql` (2253 lines — API wrappers)
- Modify: `admin/rest.sql` (REST dispatchers — document if JSDoc blocks exist)
- Modify: `admin/view.sql` (views — document if comments exist)
- Modify: `admin/do.sql` (configuration hooks)
- Skip: `admin/init.sql` (seed data — Russian names are business data)

**Step 1:** Read `admin/table.sql` — understand all 18 tables (user, profile, session, scope, area, group, member, member_group, member_area, ACL tables, etc.). Rewrite all 142 COMMENT ON.

**Step 2:** Read `admin/routine.sql` — document all functions. Major groups:
- User management: CreateUser, EditUser, GetUser, DeleteUser, SetPassword, ChangePassword
- Authentication: Authenticate, SignIn, SignOut, SessionIn, SessionOut
- Session: CreateSession, EditSession, GetSession, DeleteSession
- Scope/Area: CreateScope, CreateArea, membership management
- Groups/Members: CreateGroup, AddMemberToGroup, SetMemberArea
- ACL: GrantAccess, RevokeAccess, CheckAccess
- Clean up inline comments

**Step 3:** Read `admin/api.sql` — document all API wrappers. These mirror routine.sql but with JSON input/output.

**Step 4:** Read `admin/rest.sql` and `admin/do.sql` — document where blocks exist.

**Step 5:** Commit.

```bash
git add admin/
git commit -m "docs(admin): rewrite COMMENT ON (142) and add JSDoc for all functions"
```

---

## Task 5: http — Outbound HTTP Request Queue

**COMMENT ON:** 38

**Files:**
- Modify: `http/table.sql` (132 lines, 38 COMMENT ON)
- Modify: `http/routine.sql` (458 lines)
- Modify: `http/view.sql`

**Step 1:** Rewrite 38 COMMENT ON in `table.sql` (3 tables: request, response, callback).

**Step 2:** Document all functions in `routine.sql`.

**Step 3:** Commit.

```bash
git add http/
git commit -m "docs(http): rewrite COMMENT ON (38) and add JSDoc for all functions"
```

---

## Task 6: resource — Locale-aware Content Tree

**COMMENT ON:** 15

**Files:**
- Modify: `resource/table.sql` (142 lines, 15 COMMENT ON)
- Modify: `resource/routine.sql` (295 lines)
- Modify: `resource/api.sql` (211 lines)
- Modify: `resource/rest.sql`

**Step 1:** Rewrite 15 COMMENT ON.

**Step 2:** Document functions in `routine.sql` and `api.sql`.

**Step 3:** Commit.

```bash
git add resource/
git commit -m "docs(resource): rewrite COMMENT ON (15) and add JSDoc for all functions"
```

---

## Task 7: exception — Standardized Error Handling

**COMMENT ON:** 0
**Note:** 1412 lines, ~84 exception-raising functions. No tables.

**Files:**
- Modify: `exception/routine.sql` (1412 lines — all exception functions)

**Step 1:** Read `exception/routine.sql` — document each exception function. These are typically simple `RAISE EXCEPTION` wrappers, but each needs a clear `@brief` explaining when/why it's raised.

**Step 2:** Commit.

```bash
git add exception/
git commit -m "docs(exception): add JSDoc for ~84 exception functions"
```

---

## Task 8: registry — Key-value Configuration Store

**COMMENT ON:** 16

**Files:**
- Modify: `registry/table.sql` (61 lines, 16 COMMENT ON)
- Modify: `registry/routine.sql` (986 lines)
- Modify: `registry/api.sql` (386 lines)
- Modify: `registry/rest.sql`

**Step 1:** Rewrite 16 COMMENT ON (2 tables: key, value — hierarchical Windows Registry-style store).

**Step 2:** Document `routine.sql` functions (RegSetValue, RegGetValue, tree navigation, etc.).

**Step 3:** Document `api.sql` functions.

**Step 4:** Commit.

```bash
git add registry/
git commit -m "docs(registry): rewrite COMMENT ON (16) and add JSDoc for all functions"
```

---

## Task 9: log — Structured Event Logging

**COMMENT ON:** 12

**Files:**
- Modify: `log/table.sql` (86 lines, 12 COMMENT ON)
- Modify: `log/routine.sql` (142 lines)
- Modify: `log/api.sql` (192 lines)
- Modify: `log/rest.sql`

**Step 1:** Rewrite COMMENT ON, document functions.

**Step 2:** Commit.

```bash
git add log/
git commit -m "docs(log): rewrite COMMENT ON (12) and add JSDoc for all functions"
```

---

## Task 10: api — REST Routing and Request Logging

**COMMENT ON:** 13

**Files:**
- Modify: `api/table.sql` (86 lines, 13 COMMENT ON)
- Modify: `api/routine.sql` (443 lines — route registration, method spec generation)
- Modify: `api/api.sql` (439 lines — core API dispatch functions)
- Modify: `api/rest.sql` (REST entry point — `rest.api()`)
- Modify: `api/log.sql` (request logging)

**Step 1:** Rewrite COMMENT ON.

**Step 2:** Document `routine.sql` — especially important: `api.get_method_spec()` for OpenAPI generation.

**Step 3:** Document `api.sql` and `rest.sql` — the main entry point `rest.api(pPath, pPayload)`.

**Step 4:** Commit.

```bash
git add api/
git commit -m "docs(api): rewrite COMMENT ON (13) and add JSDoc for all functions"
```

---

## Task 11: replication + daemon + session + current (4 small modules)

**COMMENT ON:** 30 (replication)

**Files:**
- Modify: `replication/table.sql` (125 lines, 30 COMMENT ON)
- Modify: `replication/routine.sql` (620 lines)
- Modify: `replication/api.sql` (163 lines)
- Modify: `replication/rest.sql`
- Modify: `daemon/daemon.sql` (C++ interface functions)
- Modify: `session/api.sql` (207 lines — session context setters)
- Modify: `session/rest.sql`
- Modify: `current/api.sql` (129 lines — session context getters)
- Modify: `current/rest.sql`

**Step 1:** Replication: rewrite 30 COMMENT ON, document all functions.

**Step 2:** Daemon: document interface functions.

**Step 3:** Session: document setter functions in `api.sql`.

**Step 4:** Current: document getter functions in `api.sql`.

**Step 5:** Commit.

```bash
git add replication/ daemon/ session/ current/
git commit -m "docs(replication,daemon,session,current): rewrite COMMENT ON and add JSDoc"
```

---

## Task 12: workflow — State Machine Engine

**Estimated functions:** many (routine.sql: 2117 lines, api.sql: 1553 lines)
**COMMENT ON:** 112
**Note:** Second-largest module. 23 tables defining the state machine.

**Files:**
- Modify: `workflow/table.sql` (706 lines, 112 COMMENT ON — 23 tables)
- Modify: `workflow/routine.sql` (2117 lines)
- Modify: `workflow/api.sql` (1553 lines)
- Modify: `workflow/rest.sql`
- Modify: `workflow/view.sql`
- Skip: `workflow/init.sql` (seed data)

**Step 1:** Read `workflow/table.sql` — understand all 23 tables (entity, class, type, state, action, method, transition, event, acu, amu, etc.). Rewrite all 112 COMMENT ON.

**Step 2:** Document `routine.sql` — state machine functions: AddState, AddMethod, AddTransition, AddEvent, ExecuteMethod, ExecuteObjectAction, GetState, GetMethod, GetAction, etc.

**Step 3:** Document `api.sql` — API wrappers.

**Step 4:** Commit.

```bash
git add workflow/
git commit -m "docs(workflow): rewrite COMMENT ON (112) and add JSDoc for all functions"
```

---

## Task 13: kladr — Russian Address Classifier

**COMMENT ON:** 25

**Files:**
- Modify: `kladr/table.sql` (84 lines, 25 COMMENT ON)
- Modify: `kladr/routine.sql` (300 lines)
- Modify: `kladr/api.sql` (104 lines)
- Modify: `kladr/rest.sql`

**Step 1:** Rewrite 25 COMMENT ON. Note: KLADR is a Russian-specific address system — descriptions should explain the domain concept in English.

**Step 2:** Document all functions.

**Step 3:** Commit.

```bash
git add kladr/
git commit -m "docs(kladr): rewrite COMMENT ON (25) and add JSDoc for all functions"
```

---

## Task 14: file — Virtual File System

**COMMENT ON:** 20

**Files:**
- Modify: `file/table.sql` (219 lines, 20 COMMENT ON)
- Modify: `file/routine.sql` (561 lines)
- Modify: `file/api.sql` (166 lines)
- Modify: `file/rest.sql`

**Step 1:** Rewrite 20 COMMENT ON (1 main table with UNIX-like permissions and S3 support).

**Step 2:** Document all functions.

**Step 3:** Commit.

```bash
git add file/
git commit -m "docs(file): rewrite COMMENT ON (20) and add JSDoc for all functions"
```

---

## Task 15: entity/object — Core Object Module

**COMMENT ON:** 89
**Note:** This is the root of the entity hierarchy — 14 tables, 130+ functions.

**Files:**
- Modify: `entity/object/table.sql` (684 lines, 89 COMMENT ON)
- Modify: `entity/object/routine.sql` (1973 lines)
- Modify: `entity/object/api.sql` (1591 lines)
- Modify: `entity/object/rest.sql`
- Modify: `entity/object/event.sql`
- Modify: `entity/object/view.sql`
- Modify: `entity/object/search.sql`
- Modify: `entity/object/security.sql`

**Step 1:** Read `entity/object/table.sql` — understand all 14 tables (object, object_group, object_link, object_file, object_data, object_coordinates, object_address, etc.). Rewrite all 89 COMMENT ON.

**Step 2:** Document `routine.sql` — CRUD for objects, groups, links, files, data, coordinates, addresses.

**Step 3:** Document `api.sql`.

**Step 4:** Document `event.sql`, `search.sql`, `security.sql`, `rest.sql`.

**Step 5:** Commit.

```bash
git add entity/
git commit -m "docs(entity/object): rewrite COMMENT ON (89) and add JSDoc for all functions"
```

---

## Task 16: entity/object/reference — All Reference Entities

**COMMENT ON:** 13 (reference) + 4 (agent) + 3 (form) + 10 (form/field) + 4 (program) + 6 (scheduler) + 3 (vendor) + 3 (version) = 46

**Files (all under entity/object/reference/):**
- Modify: `table.sql`, `routine.sql`, `api.sql`, `rest.sql`, `event.sql` — for each of:
  - reference (base: 196+146 lines)
  - agent (135+174 lines)
  - form (120+175 lines)
  - form/field (198+200 lines)
  - program (117+174 lines)
  - scheduler (114+184 lines)
  - vendor (96+169 lines)
  - version (96+169 lines)

**Step 1:** Document base `reference/` module (abstract reference class).

**Step 2:** Document each concrete reference: agent, form, form/field, program, scheduler, vendor, version.

**Step 3:** Commit.

```bash
git add entity/object/reference/
git commit -m "docs(entity/reference): rewrite COMMENT ON (46) and add JSDoc for all reference entities"
```

---

## Task 17: entity/object/document — All Document Entities

**COMMENT ON:** 13 (document) + 8 (job) + 9 (message) = 30

**Files (all under entity/object/document/):**
- Modify: `table.sql`, `routine.sql`, `api.sql`, `rest.sql`, `event.sql`, `exception.sql` — for each of:
  - document (base: 180+162 lines)
  - job (120+242 lines)
  - message (833+504 lines)
  - message/inbox (api.sql: 115 lines, event.sql)
  - message/outbox (api.sql: 116 lines, event.sql)

**Step 1:** Document base `document/` module.

**Step 2:** Document `job/` — scheduled and one-time tasks.

**Step 3:** Document `message/`, `message/inbox/`, `message/outbox/`.

**Step 4:** Commit.

```bash
git add entity/object/document/
git commit -m "docs(entity/document): rewrite COMMENT ON (30) and add JSDoc for all document entities"
```

---

## Task 18: notice + comment + notification + verification (4 communication modules)

**COMMENT ON:** 10 + 10 + 11 + 8 = 39

**Files:**
- Modify: `notice/table.sql`, `notice/routine.sql` (147), `notice/api.sql` (195), `notice/rest.sql`
- Modify: `comment/table.sql`, `comment/routine.sql` (83), `comment/api.sql` (196), `comment/rest.sql`
- Modify: `notification/table.sql`, `notification/routine.sql` (127), `notification/api.sql` (116), `notification/rest.sql`
- Modify: `verification/table.sql`, `verification/routine.sql` (161), `verification/api.sql` (126), `verification/rest.sql`

**Step 1:** Document each module: table.sql COMMENT ON, then routine.sql and api.sql JSDoc.

**Step 2:** Commit.

```bash
git add notice/ comment/ notification/ verification/
git commit -m "docs(notice,comment,notification,verification): rewrite COMMENT ON (39) and add JSDoc"
```

---

## Task 19: observer — Pub/Sub Event System

**COMMENT ON:** 10

**Files:**
- Modify: `observer/table.sql` (40 lines, 10 COMMENT ON)
- Modify: `observer/routine.sql` (858 lines — publishers, listeners, filter routing)
- Modify: `observer/api.sql` (236 lines)
- Modify: `observer/rest.sql`

**Step 1:** Rewrite COMMENT ON.

**Step 2:** Document `routine.sql` — CreatePublisher, CreateListener, filter routing logic.

**Step 3:** Document `api.sql`.

**Step 4:** Commit.

```bash
git add observer/
git commit -m "docs(observer): rewrite COMMENT ON (10) and add JSDoc for all functions"
```

---

## Task 20: report — Report Framework (all sub-modules)

**COMMENT ON:** 7 (report) + 7 (tree) + 4 (form) + 6 (routine) + 4 (ready) = 28

**Files (all under report/):**
- Modify: `table.sql`, `routine.sql`, `api.sql`, `rest.sql`, `event.sql` — for each of:
  - report (base: 437+245 lines)
  - report/tree (248+161 lines)
  - report/form (133+183 lines)
  - report/routine (203+183 lines)
  - report/ready (148+234 lines)

**Step 1:** Document base `report/` module.

**Step 2:** Document sub-modules: tree, form, routine, ready.

**Step 3:** Commit.

```bash
git add report/
git commit -m "docs(report): rewrite COMMENT ON (28) and add JSDoc for all report entities"
```

---

## Task 21: reports — Pre-built Report Definitions

**COMMENT ON:** 0

**Files:**
- Modify: `reports/routine.sql` (102 lines)
- Modify: `reports/object/routine.sql` (148 lines)
- Modify: `reports/admin/user/routine.sql` (395 lines)
- Modify: `reports/admin/session/routine.sql` (390 lines)

**Step 1:** Document all report routines — these contain the SQL logic for built-in reports.

**Step 2:** Commit.

```bash
git add reports/
git commit -m "docs(reports): add JSDoc for all report routines"
```

---

## Summary

| Task | Module(s) | COMMENT ON | Est. functions | Complexity |
|-----:|-----------|----------:|---------------:|-----------:|
| 1 | kernel | 0 | 116 | Large |
| 2 | oauth2 | 28 | ~15 | Small |
| 3 | locale | 5 | ~5 | Tiny |
| 4 | admin | 142 | ~200 | XL |
| 5 | http | 38 | ~25 | Medium |
| 6 | resource | 15 | ~20 | Small |
| 7 | exception | 0 | ~84 | Medium |
| 8 | registry | 16 | ~40 | Medium |
| 9 | log | 12 | ~15 | Small |
| 10 | api | 13 | ~30 | Medium |
| 11 | replication+daemon+session+current | 30 | ~40 | Medium |
| 12 | workflow | 112 | ~80 | Large |
| 13 | kladr | 25 | ~15 | Small |
| 14 | file | 20 | ~25 | Medium |
| 15 | entity/object | 89 | ~130 | XL |
| 16 | entity/reference (8 sub-modules) | 46 | ~80 | Large |
| 17 | entity/document (5 sub-modules) | 30 | ~60 | Large |
| 18 | notice+comment+notification+verification | 39 | ~40 | Medium |
| 19 | observer | 10 | ~30 | Medium |
| 20 | report (5 sub-modules) | 28 | ~40 | Medium |
| 21 | reports (4 sub-modules) | 0 | ~30 | Small |
| **Total** | **25 modules, 46 sub-modules** | **~698** | **~1120** | **21 tasks** |
