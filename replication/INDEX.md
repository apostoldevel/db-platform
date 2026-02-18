# replication

> Platform module #11 | Loaded by `create.psql` line 11

Data replication between database instances. Logs all INSERT/UPDATE/DELETE operations on configured tables into `replication.log`, sends pg_notify, and provides a relay queue for applying changes on remote instances. Supports bidirectional sync with source tracking.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel`, `admin`, `api` | Configurations that enable multi-instance sync |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `replication` | Own schema (AUTHORIZATION kernel). 4 tables |
| `kernel` | `ReplicationLog`, `RelayLog`, `ReplicationTable` views |
| `api` | API wrapper functions |
| `rest` | `rest.replication` dispatcher (11 routes) |

## Tables

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `replication.log` | Change audit log | `id bigserial PK`, `datetime timestamptz`, `action char` (I/U/D), `schema text`, `name text` (table), `key jsonb`, `data jsonb`, `source text` |
| `replication.relay` | Relay queue | PK(`source text`, `id bigint`), `state int` (0=pending, 1=success, 2=error), `action char`, `schema text`, `name text`, `key jsonb`, `data jsonb` |
| `replication.list` | Replicated tables config | PK(`schema text`, `name text`), `updated timestamptz` |
| `replication.pkey` | Primary key metadata | PK(`schema text`, `name text`, `field text`) |

## Views

### kernel schema

| View | Description |
|------|-------------|
| `ReplicationLog` | `replication.log` |
| `RelayLog` | `replication.relay` |
| `ReplicationTable` | Combined active + inactive tables |

## Functions

### Trigger & Logging

| Function | Returns | Purpose |
|----------|---------|---------|
| `replication.ft_log()` | `trigger` | Main trigger: logs I/U/D to replication.log, filters sensitive columns |
| `replication.log(pFrom, pSource, pLimit)` | `SETOF record` | Retrieve log entries after ID |
| `replication.add_log(...)` | `bigint` | Insert log entry |

### Relay Processing

| Function | Returns | Purpose |
|----------|---------|---------|
| `replication.add_relay(...)` | `void` | Add entry to relay queue |
| `replication.apply_relay(pSource, pId)` | `void` | Execute single relay entry (dynamic INSERT/UPDATE/DELETE) |
| `replication.apply(pSource)` | `void` | Process up to 1000 pending relay entries |

### Table Configuration

| Function | Returns | Purpose |
|----------|---------|---------|
| `replication.set_table(pSchema, pName, pActive)` | `void` | Add/remove table from replication |
| `replication.set_key(pSchema, pName)` | `void` | Extract and store PK fields |
| `replication.delete_key(pSchema, pName)` | `void` | Remove PK metadata |
| `replication.table(pSchema, pName, pActive)` | `void` | Full setup (key + trigger) |
| `replication.create_trigger(pSchema, pName)` | `text` | Generate trigger CREATE SQL |
| `replication.drop_trigger(pSchema, pName)` | `text` | Generate trigger DROP SQL |

### Control

| Function | Returns | Purpose |
|----------|---------|---------|
| `replication.on()` | `void` | Enable replication for all configured tables |
| `replication.off()` | `void` | Disable all replication triggers |

### API Wrappers

`api.replication_log`, `api.get_max_log_id`, `api.get_max_relay_id`, `api.add_to_relay_log`, `api.get_replication_log`, `api.list_replication_log`, `api.list_relay_log`, `api.replication_apply_relay`, `api.replication_apply`.

## REST Routes — 11

Dispatcher: `rest.replication(pPath text, pPayload jsonb)`.

| Path | Purpose |
|------|---------|
| `/replication/apply` | Apply pending relay entries (batch) |
| `/replication/log` | Fetch log entries by ID range/source |
| `/replication/log/max` | Get maximum log ID |
| `/replication/log/get` | Get single log entry |
| `/replication/log/count` | Count logs with filter |
| `/replication/log/list` | List logs with pagination |
| `/replication/relay/count` | Count relay entries |
| `/replication/relay/add` | Add relay entry |
| `/replication/relay/max` | Get max relay ID by source |
| `/replication/relay/apply` | Apply single relay entry |
| `/replication/relay/list` | List relay entries |

## Triggers

| Trigger | Table | Timing | Purpose |
|---------|-------|--------|---------|
| `t_replication_log` | `replication.log` | AFTER INSERT | pg_notify with log entry details |
| _(dynamic per table)_ | configured tables | AFTER I/U/D | `replication.ft_log()` — log changes |

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `schema.sql` | yes* | no | CREATE SCHEMA replication |
| `table.sql` | yes | no | 4 tables + notify trigger |
| `view.sql` | yes | yes | 3 kernel views |
| `routine.sql` | yes | yes | ~15 replication functions |
| `api.sql` | yes | yes | 9 API wrapper functions |
| `rest.sql` | yes | yes | `rest.replication` dispatcher (11 routes) |
| `init.sql` | yes | no | RegisterRoute for replication |
| `create.psql` | - | - | Includes all |
| `update.psql` | - | - | Includes view, routine, api, rest |
