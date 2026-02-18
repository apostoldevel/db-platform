# oauth2

> Platform module #2 | Loaded by `create.psql` line 2

OAuth2 infrastructure for client/audience management. Stores providers, applications, issuers, algorithms, and audiences (OAuth2 clients). Provides the foundation for authentication tokens -- actual token handling is done by the `admin` module's session system.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel` | `admin` (uses audiences for login/session creation) |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `oauth2` | All tables (provider, application, issuer, algorithm, audience) |
| `kernel` | Views and functions |

## Tables

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `oauth2.provider` | OAuth2 providers (internal/external) | `id serial PK`, `type char` (I/E), `code text UNIQUE(type,code)` |
| `oauth2.application` | Application types | `id serial PK`, `type char` (S=Service/W=Web/N=Native), `code text` |
| `oauth2.issuer` | Token issuers | `id serial PK`, `provider int FK`, `code text UNIQUE(provider,code)` |
| `oauth2.algorithm` | Hashing algorithms | `id serial PK`, `code text` (HS256, etc.), `name text` (pgcrypto name) |
| `oauth2.audience` | OAuth2 clients | `id serial PK`, `provider int FK`, `application int FK`, `algorithm int`, `code text`, `secret text`, `hash text` |

## Views

### kernel schema

| View | Source | Grants |
|------|--------|--------|
| `Provider` | `oauth2.provider` | `administrator` |
| `Application` | `oauth2.application` | `administrator` |
| `Issuer` | `oauth2.issuer` | `administrator` |
| `Algorithm` | `oauth2.algorithm` | `administrator` |
| `Audience` | `oauth2.audience` | `administrator` |

## Functions

### kernel schema -- CRUD

| Function | Returns | Purpose |
|----------|---------|---------|
| `AddProvider(pType, pCode, pName)` | `integer` | Create provider (admin only) |
| `GetProvider(pCode)` | `integer` | Lookup ID by code |
| `GetProviderCode(pId)` | `text` | Lookup code by ID |
| `GetProviderType(pId)` | `char` | Get provider type |
| `AddApplication(pType, pCode, pName)` | `integer` | Create application (admin only) |
| `GetApplication(pCode)` | `integer` | Lookup ID by code |
| `GetApplicationCode(pId)` | `text` | Lookup code by ID |
| `AddIssuer(pProvider, pCode, pName)` | `integer` | Create issuer (admin only) |
| `GetIssuer(pCode)` | `integer` | Lookup ID by code |
| `GetIssuerCode(pId)` | `text` | Lookup code by ID |
| `AddAlgorithm(pCode, pName)` | `integer` | Create algorithm (admin only) |
| `GetAlgorithm(pCode)` | `integer` | Lookup ID by code |
| `GetAlgorithmCode(pId)` | `text` | Lookup code by ID |
| `GetAlgorithmName(pId)` | `text` | Get pgcrypto name |
| `CreateAudience(pProvider, pApplication, pAlgorithm, pCode, pSecret, pName)` | `integer` | Create audience (hashes secret with md5 salt) |
| `GetAudience(pCode)` | `integer` | Lookup ID by code |
| `GetAudienceCode(pId)` | `text` | Lookup code by ID |

All Add/Create functions require `administrator` role or `kernel` session_user.

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `table.sql` | yes | no | 5 tables with indexes and comments |
| `view.sql` | yes | yes | 5 kernel-schema views |
| `routine.sql` | yes | yes | 17 CRUD functions |
| `create.psql` | - | - | Includes: table, view, routine |
| `update.psql` | - | - | Includes: view, routine |
