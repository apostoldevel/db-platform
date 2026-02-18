# entity/object/document

> Part of entity module #18 | Loaded by `entity/object/document/create.psql`

**Abstract document class** extending `object`. Adds priority, area (organizational unit), and localized description. Concrete subclasses: **job** (scheduled tasks) and **message** (with inbox/outbox). Documents are scoped to areas and support area transfer.

## Class Hierarchy

```
object (abstract)
  └── document (abstract)
        ├── job (concrete) — periodic/disposable scheduled tasks
        └── message (abstract)
              ├── inbox (concrete) — incoming messages (4-state)
              └── outbox (concrete) — outgoing messages (7-state)
```

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `entity/object` (inherits), `workflow`, `admin` (areas/scope/priority) | Configuration document entities (client, station, subscription, payment, etc.) |

---

## DOCUMENT (base)

### Tables — 2

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.document` | Document specialization | `id uuid PK`, `object uuid FK`, `entity uuid FK`, `class uuid FK`, `type uuid FK`, `priority uuid FK`, `area uuid FK`, `scope uuid FK` |
| `db.document_text` | Localized description | PK(`document`, `locale`), `description text` |

### Triggers — 3

| Trigger | Purpose |
|---------|---------|
| `t_document_insert` | Set id, validate area, default priority, set scope |
| `t_document_before_update_type` | Validate entity consistency |
| `t_document_update_area` | Validate area/scope match |

### Views — 6

`DocumentAreaTree`, `DocumentAreaTreeId`, `Document`, `CurrentDocument`, `AccessDocument`, `ObjectDocument`.

### Functions — 14

CRUD: `CreateDocument`, `EditDocument`. Text: `NewDocumentText`, `EditDocumentText`. Getters: `GetDocumentDescription`, `GetDocumentArea`. Special: `ChangeDocumentArea` (recursive tree update).

### API — 7 functions

`api.add_document`, `api.update_document`, `api.set_document`, `api.get_document`, `api.list_document`, `api.change_document_area`.

### REST Routes — 7

`/document/type`, `/document/method`, `/document/count`, `/document/set`, `/document/get`, `/document/list`, `/document/change/area`.

### Events — 9

Standard lifecycle: Create, Open, Edit, Save, Enable, Disable, Delete, Restore, Drop.

---

## JOB

### Table — 1

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.job` | Scheduled job | `id uuid PK`, `document uuid FK(CASCADE)`, `scope uuid FK`, `code text UNIQUE(scope,code)`, `scheduler uuid FK`, `program uuid FK`, `dateRun timestamptz` |

Auto-generates hex code, calculates `dateRun = Now() + scheduler.period`.

### Views — 4

`Job`, `AccessJob`, `ObjectJob`, `ServiceJob` (daemon-accessible, scope-filtered).

### Functions — 7

`CreateJob`, `EditJob`, `GetJob`. API: `api.add_job` (default type `'periodic.job'`), `api.update_job`, `api.set_job`, `api.get_job`, `api.list_job`, `api.get_job_id`, `api.job(pStateType, pDateFrom)` (jobs due to run).

### Types — 2

| Type | Purpose |
|------|---------|
| `periodic.job` | Recurring scheduled execution |
| `disposable.job` | One-time execution |

### State Machine (complex)

```
created ──enable──▶ enabled ──execute──▶ executed
                        ▲                    │
                        │ done (reschedule)   ├──complete──▶ completed (disabled)
                        └────────────────────┤
                                             ├──fail──▶ failed ──execute──▶ executed
                                             ├──cancel──▶ canceled ──abort──▶ aborted
                                             └──                              ──execute──▶ executed
```

**Key:** `EventJobDone` updates `dateRun` to next scheduled time.

### Events — 14

Standard 9 + `EventJobExecute`, `EventJobComplete`, `EventJobDone` (reschedule), `EventJobFail`, `EventJobAbort`, `EventJobCancel`.

### REST Routes — 7+

`/job/type`, `/job/method`, `/job/count`, `/job/set`, `/job/get`, `/job/list` + dynamic methods.

---

## MESSAGE (base)

### Table — 1

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.message` | Message with delivery info | `id uuid PK`, `document uuid FK(CASCADE)`, `agent uuid FK(agent)`, `code text UNIQUE` (auto hex), `profile text`, `address text`, `subject text`, `content text` |

### Triggers — 3

| Trigger | Purpose |
|---------|---------|
| `t_message_before_insert` | Auto-generate 32-byte hex code |
| `t_message_after_insert` | `pg_notify` with message details |
| `t_message_before_update` | Prevent code modification |

### Views — 4

`Message`, `AccessMessage`, `ObjectMessage`, `ServiceMessage` (daemon/apibot-accessible).

### Functions — 29

**Core CRUD:** `CreateMessage`, `EditMessage`, `GetMessageCode`, `GetMessageState`.

**Email/MIME:** `GetEncodedTextRFC1342`, `EncodingSubject`, `CreateMailBody`.

**Send functions:** `SendMessage`, `SendMail`, `SendM2M`, `SendFCM`, `SendSMS` (MTS API), `SendPush` (Firebase), `SendPushData`.

**Recovery/Registration:** `RecoveryPasswordByEmail`, `RecoveryPasswordByPhone`, `RegistrationCodeByPhone`, `RegistrationCodeByEmail`.

### API — 17 functions

Standard CRUD + `api.send_message`, `api.send_mail`, `api.send_sms`, `api.send_push`, `api.send_push_data`, `api.send_push_to_role` (broadcast), `api.send_push_all`.

### REST Routes — 14+

`/message/type`, `/method`, `/count`, `/set`, `/get`, `/list`, `/send`, `/send/mail`, `/send/sms`, `/send/push`, `/send/push/data`, `/send/push/to/role`, `/send/push/all` + dynamic methods.

### Events — 11

Standard 9 + `EventMessageConfirmEmail` (verification code email), `EventMessageAccountInfo` (HMAC-SHA512 secret email).

---

## INBOX (message subclass)

### Tables — 0 (inherits message)

### API — 5 functions

`api.inbox(pState)`, `api.add_inbox`, `api.get_inbox`, `api.list_inbox`.

### State Machine — 4 states

```
created (Новое) ──enable──▶ enabled (Открыто) ──disable──▶ disabled (Прочитано)
     │                            │                              │
     └──disable/delete──▶        └──delete──▶                  └──enable/delete──▶
```

### Events — 9

Standard lifecycle with inbox-specific labels.

### Type — `message.inbox`

---

## OUTBOX (message subclass)

### Tables — 0 (inherits message)

### API — 5 functions

`api.outbox(pState)`, `api.add_outbox`, `api.get_outbox`, `api.list_outbox`.

### State Machine — 7 states (reliable delivery)

```
created ──submit──▶ prepared ──send──▶ sending ──done──▶ submitted (disabled)
   ▲                    │                  │
   └──cancel────────────┘                  ├──fail──▶ failed
                                           │              │
                                           └──delete──▶   ├──repeat──▶ prepared
                                                          └──delete──▶ deleted
```

Hidden methods: `send`, `done`, `fail` (driven by C++ MessageServer, not user-facing).

### Events — 14

Standard 9 + `EventOutboxSubmit`, `EventOutboxSend`, `EventOutboxCancel`, `EventOutboxDone`, `EventOutboxFail`, `EventOutboxRepeat`.

### Type — `message.outbox`

---

## Loading Order (create.psql)

```
document/
  table.sql → view.sql → routine.sql → api.sql → rest.sql → event.sql → init.sql
  → job/create.psql
  → message/create.psql
      → message/table.sql → view.sql → routine.sql → api.sql → rest.sql → event.sql → init.sql
      → inbox/create.psql
      → outbox/create.psql
```

## Summary

| Entity | Tables | Views | Functions | API Functions | REST Routes | Events | States |
|--------|--------|-------|-----------|---------------|-------------|--------|--------|
| document | 2 | 6 | 14 | 7 | 7 | 9 | default |
| job | 1 | 4 | 7 | 10 | 7+ | 14 | 9 complex |
| message | 1 | 4 | 29 | 17 | 14+ | 11 | default |
| inbox | 0 | 1 | 0 | 5 | 0 | 9 | 4 |
| outbox | 0 | 1 | 0 | 5 | 0 | 14 | 7 |
