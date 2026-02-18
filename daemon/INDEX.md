# daemon

> Platform module #12 | Loaded by `create.psql` line 12

Server-side functions in the `daemon` schema for the C++ application layer. Handles JWT validation, OAuth2 token exchange (6 grant types), session open/close, signed request verification, and event observer dispatch. No tables or views — pure function library called by the C++ workers.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel`, `oauth2`, `admin` (sessions/tokens/auth), `api` (route lookup), `log` | C++ Workers: AuthServer, AppServer, MessageServer |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `daemon` | All functions (~15) |

## Tables

None.

## Views

None.

## Functions

### Token Validation

| Function | Returns | Purpose |
|----------|---------|---------|
| `daemon.validation(pToken)` | `json` | Validate JWT access token; returns error JSON on failure |
| `daemon.refresh_token(pToken, pRefresh)` | `json` | Validate and refresh JWT tokens |
| `daemon.identifier(pToken, pValue)` | `json` | Check identifier (username/email/phone); returns user profile + status |

### Session Management

| Function | Returns | Purpose |
|----------|---------|---------|
| `daemon.session_open(pToken, pAgent, pHost)` | `json` | Open session from JWT token |
| `daemon.session_close(pToken, pCloseAll, pMessage)` | `json` | Close session(s); pCloseAll closes all user sessions |
| `daemon.authorize(pSession, pAgent, pHost)` | `json` | Authorize session code → access token + expiry |
| `daemon.login(pToken, pAgent, pHost, pScope)` | `json` | OAuth2 JWT Bearer login; handles external providers (Google, etc.), auto-creates user/profile |

### OAuth2 Token Endpoint

`daemon.token(pClientId, pSecret, pPayload, pAgent, pHost)` → `json`

Core OAuth2 token endpoint supporting 7 grant types:

| Grant Type | Purpose |
|------------|---------|
| `authorization_code` | Exchange auth code for tokens |
| `refresh_token` | Refresh access token |
| `password` | Username/password authentication |
| `ticket` | Recovery ticket exchange |
| `client_credentials` | Service account authentication |
| `urn:ietf:params:oauth:grant-type:jwt-bearer` | JWT bearer assertion |
| `urn:ietf:params:oauth:grant-type:token-exchange` | Token exchange with subject token |

### API Fetch Methods

| Function | Returns | Purpose |
|----------|---------|---------|
| `daemon.unauthorized_fetch(pMethod, pPath, pPayload, pAgent, pHost)` | `SETOF json` | Unauthenticated API request |
| `daemon.authorized_fetch(pUsername, pPassword, pMethod, pPath, ...)` | `SETOF json` | API request with username/password |
| `daemon.session_fetch(pSession, pSecret, pMethod, pPath, ...)` | `SETOF json` | API request with session code + secret |
| `daemon.signed_fetch(pMethod, pPath, pJson, pSession, pNonce, pSignature, ...)` | `SETOF json` | HMAC-SHA256 signed request with nonce/time window validation |
| `daemon.fetch(pToken, pMethod, pPath, pPayload, ...)` | `SETOF json` | API request with JWT Bearer token |

### Event System

| Function | Returns | Purpose |
|----------|---------|---------|
| `daemon.observer(pPublisher, pSession, pIdentity, pData, pAgent, pHost)` | `json` | Event listener dispatcher; validates session, calls EventListener |
| `daemon.init_listen()` | `void` | Initialize all listeners |

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `daemon.sql` | yes | yes | All ~15 daemon functions |
| `create.psql` | - | - | Includes daemon.sql |
| `update.psql` | - | - | Includes daemon.sql |
