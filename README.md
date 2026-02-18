[![ru](https://img.shields.io/badge/lang-ru-green.svg)](https://github.com/apostoldevel/db-platform/blob/master/README.ru-RU.md)

# PostgreSQL Framework for Backend Development

A PostgreSQL framework for backend development of automated information systems. Turns PostgreSQL into a full-fledged application server with built-in REST API, authentication, workflow engine, file storage, and business logic — all in PL/pgSQL.

## Key Features

- **Workflow Engine** — state-machine-based entity lifecycle with states, actions, methods, transitions, and event handlers
- **Entity System** — hierarchical object model with inheritance: objects, references (catalogs), and documents (business records)
- **Authentication & Authorization** — OAuth 2.0, JWT tokens, session management, role-based access control
- **REST API** — auto-generated endpoints with OpenAPI specification and Swagger UI support (414+ paths)
- **File Storage** — virtual file system with UNIX-like permissions and S3 bucket support
- **Observer (Pub/Sub)** — event-driven architecture with typed publishers, listeners, and filter-based routing
- **Report Framework** — configurable reports with tree structure, input forms, generation routines, and output documents
- **Notifications & Logging** — event audit trail, user notices, threaded comments, and structured logging

## Architecture

The platform uses a **two-layer architecture**:

```
sql/
  platform/        ← Framework layer (this repo). Reusable across projects.
  configuration/   ← Application layer. Your project-specific code goes here.
```

Execution order is always platform first, then configuration. Both layers share these schemas:

| Schema | Purpose |
|--------|---------|
| `db` | All tables (always prefixed `db.table_name`) |
| `kernel` | Core business logic (in `search_path` — no prefix needed) |
| `api` | External API views and CRUD functions |
| `rest` | REST endpoint dispatchers |
| `oauth2` | OAuth 2.0 infrastructure |
| `daemon` | Background process functions |

## Modules

| # | Module | Description | Tables |
|--:|--------|-------------|-------:|
| 1 | kernel | Core types, utility functions, JWT support | — |
| 2 | oauth2 | OAuth 2.0 client and audience management | 5 |
| 3 | locale | Multi-language support (ISO 639-1) | 1 |
| 4 | admin | Users, authentication, sessions, access control | 18 |
| 5 | http | Outbound HTTP request queue and callbacks | 3 |
| 6 | resource | Hierarchical locale-aware content management | 2 |
| 7 | exception | Standardized error handling (~84 functions) | — |
| 8 | registry | Key-value configuration store | 2 |
| 9 | log | Structured event logging | 1 |
| 10 | api | REST API routing and request logging | 4 |
| 11 | replication | Multi-instance data synchronization | 4 |
| 12 | daemon | C++ application layer interface | — |
| 13 | session | Session context setters | — |
| 14 | current | Session context getters | — |
| 15 | workflow | State-machine workflow engine | 23 |
| 16 | kladr | Russian address classifier (KLADR) | 3 |
| 17 | file | Virtual file system with S3 support | 1 |
| 18 | entity | Business object hierarchy (objects, refs, docs) | 27 |
| 19 | notice | User notification and alert system | 1 |
| 20 | comment | Threaded comment system for objects | 1 |
| 21 | notification | Event audit trail and dispatch | 1 |
| 22 | verification | Email and phone verification codes | 1 |
| 23 | observer | Pub/Sub event system | 2 |
| 24 | report | Report definition and generation framework | 5 |
| 25 | reports | Pre-built report definitions and routines | — |

## Quick Start

**Prerequisites:** PostgreSQL 12+ and the `psql` command-line client.

```bash
# 1. Configure database users in ~/.pgpass
echo '*:*:*:kernel:kernel' >> ~/.pgpass
echo '*:*:*:admin:admin'   >> ~/.pgpass
echo '*:*:*:daemon:daemon' >> ~/.pgpass
chmod 600 ~/.pgpass

# 2. Add to postgresql.conf and restart PostgreSQL
#    search_path = '"$user", kernel, public'

# 3. First-time installation
cd db/
./runme.sh --init       # Creates users and database
```

**Day-to-day development:**

```bash
./runme.sh --update     # Safe: update routines and views only
./runme.sh --patch      # Update tables + routines + views
./runme.sh --install    # DESTRUCTIVE: drop and recreate with seed data
```

## Directory Structure

```
platform/
├── kernel/            Core types and utilities
├── oauth2/            OAuth 2.0 infrastructure
├── locale/            Language support
├── admin/             Users, auth, sessions
├── http/              Outbound HTTP client
├── resource/          Content management
├── exception/         Error handling
├── registry/          Configuration store
├── log/               Event logging
├── api/               REST API routing
├── replication/       Data synchronization
├── daemon/            C++ interface
├── session/           Session setters
├── current/           Session getters
├── workflow/          Workflow engine
├── kladr/             Address classifier
├── file/              File storage
├── entity/            Entity system
│   └── object/        Objects, references, documents
├── notice/            User notices
├── comment/           Comments
├── notification/      Notifications
├── verification/      Verification codes
├── observer/          Pub/Sub events
├── report/            Report framework
├── reports/           Built-in reports
├── patch/             Migration scripts
├── wiki/              Documentation source
├── create.psql        Full install script
├── update.psql        Routine/view update
├── patch.psql         Table + routine update
├── init.sql           Seed data
└── VERSION            Current version (1.1.3c)
```

## Documentation

Comprehensive documentation is available in the [Wiki](https://github.com/apostoldevel/db-platform/wiki):

- **Concepts** — [System](https://github.com/apostoldevel/db-platform/wiki/01-System), [Architecture](https://github.com/apostoldevel/db-platform/wiki/02-Architecture), [Workflow](https://github.com/apostoldevel/db-platform/wiki/04-Workflow), [Reports](https://github.com/apostoldevel/db-platform/wiki/05-Reports)
- **API Guide** — [Introduction](https://github.com/apostoldevel/db-platform/wiki/10-API-Introduction), [Access](https://github.com/apostoldevel/db-platform/wiki/11-API-Access), [Dynamic Methods](https://github.com/apostoldevel/db-platform/wiki/12-Dynamic-Methods), [Query Parameters](https://github.com/apostoldevel/db-platform/wiki/13-Query-Parameters)
- **Internals** — [Schema Overview](https://github.com/apostoldevel/db-platform/wiki/60-Schema-Overview), [Database Tables](https://github.com/apostoldevel/db-platform/wiki/61-Database-Tables), [Function Reference](https://github.com/apostoldevel/db-platform/wiki/62-Function-Reference), [Entity System](https://github.com/apostoldevel/db-platform/wiki/63-Entity-System-Internals)
- **Developer Guide** — [Configuration Guide](https://github.com/apostoldevel/db-platform/wiki/70-Configuration-Guide), [Creating an Entity](https://github.com/apostoldevel/db-platform/wiki/71-Creating-Entity), [Workflow Customization](https://github.com/apostoldevel/db-platform/wiki/74-Workflow-Customization), [REST Endpoint Guide](https://github.com/apostoldevel/db-platform/wiki/75-REST-Endpoint-Guide)
- **Operations** — [Installation](https://github.com/apostoldevel/db-platform/wiki/80-Installation)

## Projects Built on the Platform

* [Ship Safety ERP](https://ship-safety.ru) — An automated ERP safety management system for shipping companies
* [CopyFrog](https://copyfrog.ai) — An AI-powered platform for generating unique images, ad copy, video creatives, and marketing descriptions for products and services
* [Talking to AI](https://t.me/TalkingToAIBot) — A Telegram chatbot for interacting with artificial intelligence
* [OCPP CSS](http://ocpp-css.ru) — A cloud-based SaaS platform for managing EV charging stations
* [PlugMe](https://plugme.ru) — A Charging Station Management System (CSMS)
* [DEBT-Master](https://debt-master.ru) — A system for automating work with consumer accounts receivable and debt for utility services
* [BitDeals](https://testnet.bitdeals.org/info/about) — An arbitration platform for executing deals using BTC cryptocurrency

## License

[MIT](LICENSE)
