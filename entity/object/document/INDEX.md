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

### Views — 7

`DocumentAreaTree`, `DocumentAreaTreeId`, `Document`, `CurrentDocument`, `AccessDocument`, `ObjectDocument`, and `FileAccess` — the read set of the `file` module's pair `FileObject` / `FileAccess`, defined here because its group clause reads `db.object_file` and `db.document` (since 1.2.24; see `file/INDEX.md`).

### Functions — 14

CRUD: `CreateDocument`, `EditDocument`. Text: `NewDocumentText`, `EditDocumentText`. Getters: `GetDocumentDescription`, `GetDocumentArea`. Special: `ChangeDocumentArea` (recursive tree update).

### API — 7 functions

`api.add_document`, `api.update_document`, `api.set_document`, `api.get_document`, `api.count_document`, `api.list_document`, `api.change_document_area`.

`api.add_document` / `api.update_document` (and `api.set_document` through them) refuse every connection but `kernel`'s (since 1.2.36; see `../INDEX.md`, REST Routes).

### REST Routes — 6

`/document/type`, `/document/method`, `/document/count`, `/document/get`, `/document/list`, `/document/change/area`.

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

`CreateJob`, `EditJob`, `GetJob`. API: `api.add_job` (default type `'periodic.job'`), `api.update_job`, `api.set_job`, `api.get_job`, `api.list_job`, `api.get_job_id`, `api.job(pStateType, pDateFrom)` (jobs due to run). `api.add_job` / `api.update_job` (and `api.set_job` through them) — platform administrator only, `kernel` passes (since 1.2.34, T848): a job makes the TaskScheduler run raw SQL as the system. `api.job` — the TaskScheduler's feed — hands out only a job and a program both owned by an administrator. **On `notify` (since 1.2.38, T1104):** `api.job_due()` hands the jobs that are due and can be started (`enabled`/`aborted`/`failed`, same filters as `api.job`) and an `executed` job nobody holds (no row of its run, and its state older than the channel's `lease`: a younger one is a body that a poller of `api.job` is running) to the channel `job` — `SELECT … FOR UPDATE SKIP LOCKED`, `notify.send('job', {id, scope}, JobRunKey)`, no transition to offer, nothing unless the channel is `single` (an error when it is `single` without `on_abandon`); before it offers, `ReleaseJob` aborts a `canceled` job and fails an `executed` one whose row was closed and whose state is at least as old as the `lease` (what the old poller did to orphans; a younger run may be alive); `api.job_claim(pId, pKey)` is the executor's first, own transaction after `notify.take` (re-reads the job through the same gates, `execute`, returns the type and the body; a stale key, a foreign scope or owner, a state that cannot start, a job not due → nothing; `executed` → the body again, but only for a repeat — the taken row of the key is on its second delivery (`attempts >= 2`) or the state is at least as old as the `lease` — otherwise nothing, a poller is running it; `canceled` → `abort`). `JobRunKey(job, dateRun)` = `<id>:<planned time, UTC, µs>`; `JobStateStart(job)` = the start of the LATEST row of the job's state history — the age of a run (`api.job_due`, `api.job_claim`, `ReleaseJob`) is measured from it, not from a row valid at `Now()`; `RearmJob` (from the `enable` and `abort` events) gives a job that becomes runnable again a new planned time — moved by a microsecond, which keeps the phase of a periodic job — or its key would still be held by the kept row; `JobAbandon` is the `on_abandon` of the channel — a row closed without a confirmation: `executed` → `fail`, `canceled` → `abort`, due → `RescheduleJob`, in the system context (the sweep has no session). Both `api.*` functions: `apibot` only. `enable` on a `completed` job has a method and no transition.

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

### Functions — 1 (`outbox/routine.sql`)

`OutboxAbandon(pId, pKey, pPayload, pReason)` — `on_abandon` of the notify channel `outbox`, called by `notify.close` when a delivery row ends without a confirmation. `sending` → fixed label "outcome unknown" ("not sent" for an `unsent:` reason) + `fail`, never sent again; `prepared` → a new row, at most 5 rows per stay in `prepared` (the fifth closed row fails the message with the label "not sent", T1157); any other state or class, or a message with another open row → untouched. The label is a fixed word, never the reason (the reason goes to the event log). System context; not open to `PUBLIC`. Registered by `outbox/init.sql` and patch `P00000039`.

`ReleaseOutbox(pSwitch, pLimit)` — `on_release` of the same channel (T1158 + T1165): the messages that stand in the delivery and hold no open row of the queue, handed to `OutboxAbandon` (one body, no copy of its logic) — `prepared` older than the `grace` of the channel (3 s: the time the old path has to take it) goes to the queue, `sending` older than the `lease` fails as "outcome unknown"; younger ones are left for the next look. A failure of one message is a line of the event log (`workflow.outbox`, `release`); with `pSwitch` it refuses the switch of the channel to `single` with the number, the first three ids and the first reason. Taken `FOR UPDATE SKIP LOCKED`; no system context of its own (`OutboxAbandon` opens one per message); not open to `PUBLIC`. Registered by `outbox/init.sql` and patch `P00000040`.

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
| document | 2 | 6 | 14 | 7 | 6 | 9 | default |
| job | 1 | 4 | 7 | 10 | 7+ | 14 | 9 complex |
| message | 1 | 4 | 29 | 17 | 14+ | 11 | default |
| inbox | 0 | 1 | 0 | 5 | 0 | 9 | 4 |
| outbox | 0 | 1 | 0 | 5 | 0 | 14 | 7 |
