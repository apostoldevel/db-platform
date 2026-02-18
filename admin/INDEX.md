# admin

> Platform module #4 | Loaded by `create.psql` line 4

User management, authentication, authorization, sessions, and access control. The largest platform module by API surface: 159 kernel functions, 73 api functions, 13 api views, 64 REST routes. Manages the full lifecycle from login through session creation, token management, and ACL enforcement.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel`, `oauth2`, `locale` | `session`, `current`, `entity`, `workflow`, and all higher modules (provides user/group/area/session context) |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `db` | 15 tables (scope, area, user, profile, session, token, acl, etc.) |
| `kernel` | 14 views, 159 functions |
| `api` | 13 views, 73 functions |
| `rest` | `rest.admin` dispatcher (64 routes) |

## Tables

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.scope` | Database visibility scope | `id uuid PK`, `code text UNIQUE`, `name text` |
| `db.scope_alias` | Scope aliases | `scope uuid FK`, `code text`, PK(scope,code) |
| `db.area_type` | Area type classification | `id uuid PK`, `code text UNIQUE` (root/system/guest/all/default/main/subsidiary/mobile) |
| `db.area` | Document visibility areas (tree) | `id uuid PK`, `parent uuid FK(self)`, `type uuid FK`, `scope uuid FK`, `code text`, `level int`, `sequence int` |
| `db.interface` | UI workplaces | `id uuid PK`, `code text`, `name text` |
| `db.user` | Users and groups | `id uuid PK`, `type char` (G/U), `username text UNIQUE(type)`, `secret bytea`, `hash text`, `status bit(4)`, `email text`, `phone text` |
| `db.profile` | User profile per scope | PK(`userid`,`scope`), `family_name`, `given_name`, `patronymic_name`, `locale uuid FK`, `area uuid FK`, `interface uuid FK`, `state bit(3)`, `session_limit int`, `email_verified bool`, `phone_verified bool` |
| `db.member_group` | Group membership | PK(`userid`, `member`) |
| `db.member_area` | Area membership | PK(`area`, `member`) |
| `db.member_interface` | Interface membership | PK(`interface`, `member`) |
| `db.recovery_ticket` | Password recovery tickets | `ticket uuid PK`, `userId uuid`, `securityAnswer text`, 1-hour validity |
| `db.auth` | External auth records | PK(`userId`, `audience`), `code text` (external user ID) |
| `db.iptable` | IP whitelist/blacklist | `id serial PK`, `type char` (A=allow/D=deny), `userid uuid FK`, `addr inet`, `range int` |
| `db.oauth2` | OAuth2 authorization params | `id bigserial PK`, `audience int FK`, `scopes text[]`, `access_type text` (online/offline), `redirect_uri text` |
| `db.token_header` | Token headers | `id bigserial PK`, `oauth2 bigint FK`, `session varchar(40)`, `salt text`, `agent text`, `host inet` |
| `db.token` | Tokens | `id bigserial PK`, `header bigint FK`, `type char` (C=code/A=access/R=refresh/I=id), `token text`, `hash varchar(40)`, validity range |
| `db.session` | Active sessions | `code varchar(40) PK`, `oauth2 bigint FK`, `token bigint FK`, `suid uuid FK`, `userid uuid FK`, `locale/area/interface/scope uuid FKs`, `pwkey text`, `secret text`, `salt text`, `agent text`, `host inet` |
| `db.acl` | Access control list | `userId uuid PK`, `deny bit varying`, `allow bit varying`, `mask bit varying` (14-bit: `sLlEIDUCpducoi`) |

## User Status Bits

| Bit Pattern | Status |
|-------------|--------|
| `B'0001'` | open (initial) |
| `B'0010'` | active |
| `B'0100'` | locked |
| `B'1000'` | expired |

## ACL Mask Bits (14-bit, MSB to LSB)

`s L l E I D U C p d u c o i` — substitute user, unlock, lock, exclude from group, include in group, delete group, update group, create group, set password, delete user, update user, create user, logout, login.

## Views

### kernel schema

| View | Source | Description |
|------|--------|-------------|
| `Scope` | `db.scope` | All scopes |
| `AreaType` | `db.area_type` | Area type catalogue |
| `Area` | `db.area` + type + scope | Areas with type/scope names |
| `AreaTree` | recursive CTE on `Area` | Hierarchical area tree |
| `Interface` | `db.interface` | All interfaces |
| `users` | `db.user` + profile + locale + area + interface + pg_roles | Full user details (type='U') |
| `groups` | `db.user` + pg_roles | Groups (type='G') |
| `MemberGroup` | `db.member_group` + user | Group membership with names |
| `MemberArea` | `db.member_area` + area + user | Area membership with names |
| `MemberInterface` | `db.member_interface` + interface + user | Interface membership with names |
| `IPTable` | `db.iptable` | IP restrictions |
| `Auth` | `db.auth` | External auth records |
| `Tokens` | `db.token_header` + `db.token` | Tokens with grant type labels |
| `Session` | `db.session` + area + users | Active sessions with user info |

### api schema

| View | Source |
|------|--------|
| `api.session` | `Session` view |
| `api.user` | `users` (current scope) |
| `api.users` | `users` (all scopes) |
| `api.group` | `groups` |
| `api.area_type` | `AreaType` |
| `api.area` | `AreaTree` |
| `api.interface` | `Interface` |
| `api.member_group` | `MemberGroup` |
| `api.member_area` | `MemberArea` |
| `api.member_interface` | `MemberInterface` |
| `api.locale` | `Locale` |
| `api.event_log` | `EventLog` (from log module) |
| `api.log` | `ApiLog` (from api module) |

## Functions (kernel schema) — 159 total

### Scope & Context (~12)

`CreateScope`, `EditScope`, `DeleteScope`, `GetScope`, `GetScopeName`, `ScopeToArray`, `current_scope`, `current_scope_code`, `GetOAuth2Scopes`, `current_scopes`, `current_application`, `current_application_code`.

### Area Management (~20)

`CreateArea`, `EditArea`, `DeleteArea`, `GetArea`, `GetAreaRoot`, `GetAreaSystem`, `GetAreaGuest`, `GetAreaDefault`, `GetAreaCode`, `GetAreaName`, `GetAreaScope`, `GetAreaType/Code/Name`, `AreaTree`, `SetAreaSequence`, `SortArea`, `AddMemberToArea`, `DeleteAreaForMember`, `DeleteMemberFromArea`, `SetArea`, `IsMemberArea`, `SetDefaultArea`, `GetDefaultArea`.

### Interface Management (~14)

`CreateInterface`, `UpdateInterface`, `DeleteInterface`, `GetInterface`, `GetInterfaceName`, `AddMemberToInterface`, `DeleteInterfaceForMember`, `DeleteMemberFromInterface`, `SetInterface`, `IsMemberInterface`, `SetDefaultInterface`, `GetDefaultInterface`, `SetSessionInterface`, `GetSessionInterface`, `current_interface`.

### User & Group Management (~16)

`CreateUser`, `UpdateUser`, `DeleteUser`, `GetUser`, `GetUsername`, `GetUserFullName`, `CreateGroup`, `UpdateGroup`, `DeleteGroup`, `GetGroup`, `GetGroupUsername`, `GetGroupName`, `AddMemberToGroup`, `DeleteGroupForMember`, `DeleteMemberFromGroup`, `UserLock`, `UserUnLock`.

### Profile (~3)

`CreateProfile`, `UpdateProfile`, `CheckUserProfile`.

### Authentication & Login (~10)

`Login`, `SignIn`, `Authenticate`, `Authorize`, `GetSession`, `CheckPassword` (2 overloads), `SetPassword`, `ChangePassword`, `CreateAuth`.

### Session Management (~10)

`SetCurrentSession`, `GetCurrentSession`, `current_session`, `session_secret`, `SessionIn`, `SessionOut`, `ValidSession`, `CheckSession`, `CheckOffline`, `UpdateSessionStats`, `CheckSessionLimit`.

### Token & Cryptography (~20)

`CreateAccessToken`, `CreateIdToken`, `CreateToken`, `UpdateToken`, `GetToken`, `GetAccessToken`, `AddToken`, `NewTokenCode`, `NewToken`, `ExchangeToken`, `TokenValidation`, `RefreshToken`, `DoubleSHA256`, `GetHashCash`, `HashCash`, `SessionKey`, `GetTokenHash`, `GenSecretKey`, `GenTokenKey`, `GetSignature`, `GetSecretKey`, `StrPwKey`.

### OAuth2 Client (~8)

`CreateOAuth2`, `CreateSystemOAuth2`, `CreateTokenHeader`, `oauth2_system_client_id`, `SetOAuth2ClientId`, `GetOAuth2ClientId`, `oauth2_current_client_id`, `oauth2_current_code`.

### Recovery (~4)

`AddRecoveryTicket`, `NewRecoveryTicket`, `GetRecoveryTicket`, `CheckRecoveryTicket`.

### ACL & Roles (~8)

`acl`, `GetAccessControlListMask`, `CheckAccessControlList`, `chmod`, `SubstituteUser`, `IsUserRole`, `IsAdmin`, `is_admin`.

### Locale/Date Context (~10)

`SetOperDate`, `GetOperDate`, `oper_date`, `SetSessionLocale`, `GetSessionLocale`, `locale_code`, `current_locale`, `SetDefaultLocale`, `GetDefaultLocale`, `SetLocale`.

### User Context (~6)

`SetCurrentUserId`, `GetCurrentUserId`, `session_userid`, `current_userid`, `session_username`, `current_username`.

### IP Table (~3)

`GetIPTableStr`, `SetIPTableStr`, `CheckIPTable`.

### Logging (~4)

`SetLogMode`, `GetLogMode`, `SetDebugMode`, `GetDebugMode`.

## Functions (api schema) — 73 functions, 13 views

### Auth (5)

`api.login`, `api.signin`, `api.signout`, `api.authenticate`, `api.authorize`.

### Session (6)

`api.session(userid,username)`, `api.get_session`, `api.list_session`, `api.get_sessions`, `api.check_session`, `api.check_offline`.

### User (14)

`api.add_user`, `api.update_user`, `api.set_user`, `api.delete_user`, `api.get_user`, `api.list_user`, `api.change_password`, `api.recovery_password`, `api.check_recovery_ticket`, `api.reset_password`, `api.registration_code*` (3), `api.check_registration_code`, `api.update_profile`, `api.set_user_profile`, `api.su`, `api.user_lock`, `api.user_unlock`, `api.get_user_iptable`, `api.set_user_iptable`.

### Group (7)

`api.add_group`, `api.update_group`, `api.set_group`, `api.delete_group`, `api.get_group`, `api.list_group`.

### Members (16)

`api.user_member`, `api.member_user`, `api.member_group`, `api.group_member`, `api.group_member_add/delete`, `api.member_group_add/delete`, `api.area_member`, `api.member_area`, `api.area_member_add/delete`, `api.member_area_add/delete`, `api.interface_member`, `api.member_interface`, `api.interface_member_add/delete`, `api.member_interface_add/delete`, `api.get_groups_json`, `api.is_user_role`.

### Area (11)

`api.get_area_type`, `api.add_area`, `api.update_area`, `api.set_area`, `api.delete_area`, `api.safely_delete_area`, `api.clear_area`, `api.get_area`, `api.get_area_id`, `api.list_area`.

### Interface (8)

`api.add_interface`, `api.update_interface`, `api.set_interface`, `api.delete_interface`, `api.get_interface`, `api.list_interface`.

### ACL (3)

`api.chmodc` (class), `api.chmodm` (method), `api.chmodo` (object).

## Do-Functions (Configuration Hooks)

| Function | Purpose |
|----------|---------|
| `DoLogin(pUserId)` | Called after successful login (stub — override in configuration) |
| `DoLogout(pUserId)` | Called after logout |
| `DoCreateArea(pArea)` | Called after area creation |
| `DoUpdateArea(pArea)` | Called after area update |
| `DoDeleteArea(pArea)` | Called before area deletion |
| `DoCreateRole(pRole)` | Called after role/group creation |
| `DoUpdateRole(pRole)` | Called after role/group update |
| `DoDeleteRole(pRole)` | Called before role/group deletion |

## REST Routes — 64 total

Dispatcher: `rest.admin(pPath text, pPayload jsonb)`. Requires `administrator` role.

| Group | Count | Paths |
|-------|-------|-------|
| Session | 4 | `/admin/session`, `/count`, `/get`, `/list` |
| Event Log | 5 | `/admin/event/log`, `/set`, `/get`, `/count`, `/list` |
| API Log | 4 | `/admin/api/log`, `/get`, `/count`, `/list` |
| User | 10 | `/admin/user/count`, `/set`, `/get`, `/list`, `/delete`, `/profile/set`, `/member`, `/password`, `/lock`, `/unlock` |
| User IP | 2 | `/admin/user/iptable/get`, `/set` |
| Group | 8 | `/admin/group/count`, `/set`, `/get`, `/list`, `/delete`, `/member`, `/member/add`, `/member/delete` |
| Area | 11 | `/admin/area/type`, `/count`, `/set`, `/get`, `/list`, `/delete`, `/delete/safely`, `/clear`, `/member`, `/member/add`, `/member/delete` |
| Interface | 8 | `/admin/interface/count`, `/set`, `/get`, `/list`, `/delete`, `/member`, `/member/add`, `/member/delete` |
| Member | 12 | `/admin/member/user`, `/group`, `/group/add`, `/group/delete`, `/area`, `/area/add`, `/area/delete`, `/interface`, `/interface/add`, `/interface/delete` |

## Triggers

| Trigger | Table | Timing | Purpose |
|---------|-------|--------|---------|
| `t_area_before_insert` | `db.area` | BEFORE INSERT | Default id, scope, parent |
| `t_user_before_insert` | `db.user` | BEFORE INSERT | Generate id, secret, hash; trim phone; set readonly |
| `t_user_after_insert` | `db.user` | AFTER INSERT | Insert default ACL bits by username |
| `t_user_after_update` | `db.user` | AFTER UPDATE | Reset email/phone verified on change |
| `t_user_before_delete` | `db.user` | BEFORE DELETE | Cascade delete iptable + profile |
| `t_profile_before` | `db.profile` | BEFORE INSERT/UPDATE | Validate area/interface membership |
| `t_profile_login_state` | `db.profile` | BEFORE UPDATE | Compute login state from IP (local/trusted/external) |
| `t_recovery_ticket_before` | `db.recovery_ticket` | BEFORE INSERT/UPDATE | Generate ticket UUID, set validity |
| `t_token_header_before_delete` | `db.token_header` | BEFORE DELETE | Cascade delete tokens |
| `t_token_before` | `db.token` | BEFORE INSERT/UPDATE/DELETE | Hash token, set validity by type (C=10min, A/I=60min, R=60day) |
| `t_session_before` | `db.session` | BEFORE INSERT/UPDATE/DELETE | Generate code/secret/salt/pwkey; validate area/interface; rotate salt hourly |
| `t_session_after` | `db.session` | AFTER UPDATE/DELETE | Cascade delete token_header; update current user |
| `t_acl_before` | `db.acl` | BEFORE INSERT/UPDATE | Compute mask = allow & ~deny |

## Init / Seed Data

- **8 area types**: root, system, guest, all, default, main, subsidiary, mobile
- **1 scope**: current database name
- **5 areas**: root → system, guest, all → {dbname} (default)
- **4 interfaces**: all, administrator, user, guest
- **6 groups**: system, administrator, user, guest, message, replication
- **4 system users**: admin (in administrator group), daemon, apibot (in system group), mailbot

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `table.sql` | yes | no | 18 tables + 13 triggers |
| `view.sql` | yes | yes | 14 kernel views |
| `do.sql` | yes | yes | 8 configuration hook stubs |
| `routine.sql` | yes | yes | 159 kernel functions |
| `api.sql` | yes | yes | 13 api views + 73 api functions |
| `rest.sql` | yes | yes | `rest.admin` dispatcher (64 routes) |
| `init.sql` | yes | no | Seed area types, scope, areas, interfaces, groups, system users |
| `create.psql` | - | - | Includes all 7 files |
| `update.psql` | - | - | Includes view, do, routine, api, rest |
