--------------------------------------------------------------------------------
-- Scope -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Scope
AS
  SELECT * FROM db.scope;

GRANT SELECT ON Scope TO administrator;

--------------------------------------------------------------------------------
-- AreaType --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AreaType
AS
  SELECT * FROM db.area_type;

GRANT SELECT ON AreaType TO administrator;

--------------------------------------------------------------------------------
-- Area ------------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Area (Id, Parent, Level, Sequence,
  Type, TypeCode, TypeName,
  Scope, ScopeCode, ScopeName, ScopeDescription,
  Code, Name, Description, validFromDate, validToDate
)
AS
  SELECT a.id, a.parent, a.level, a.sequence,
         a.type, t.code, t.name,
         a.scope, s.code, s.name, s.description,
         a.code, a.name, a.description, a.validFromDate, a.validToDate
    FROM db.area a INNER JOIN db.area_type t ON t.id = a.type
                   INNER JOIN db.scope s ON s.id = a.scope;

GRANT SELECT ON Area TO administrator;

--------------------------------------------------------------------------------
-- AreaTree --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AreaTree
AS
  WITH RECURSIVE tree AS (
    SELECT *, ARRAY[row_number() OVER (ORDER BY level, sequence)] AS sortlist FROM Area WHERE parent IS NULL
    UNION ALL
      SELECT a.*, array_append(t.sortlist, row_number() OVER (ORDER BY a.level, a.sequence))
        FROM Area a INNER JOIN tree t ON a.parent = t.id
    )
    SELECT * FROM tree
     ORDER BY sortlist;

GRANT SELECT ON AreaTree TO administrator;

--------------------------------------------------------------------------------
-- Interface -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Interface
as
  SELECT * FROM db.interface;

GRANT SELECT ON Interface TO administrator;

--------------------------------------------------------------------------------
-- users -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW users
AS
  SELECT u.id, u.username, u.name, p.given_name, p.family_name, p.patronymic_name,
         u.email, p.email_verified, u.phone, p.phone_verified, p.session_limit,
         u.created,
         l.id AS locale, l.code AS locale_code,
         a.id AS area, a.code AS area_code,
         i.id AS interface, i.code AS interface_code,
         u.description, p.picture, u.passwordchange, u.passwordnotchange,
         r.rolname IS NOT NULL AS system,
         readonly,
         status::int,
         CASE
         WHEN u.status & B'1100' = B'1100' THEN 'expired & locked'
         WHEN u.status & B'1000' = B'1000' THEN 'expired'
         WHEN u.status & B'0100' = B'0100' THEN 'locked'
         WHEN u.status & B'0010' = B'0010' THEN 'active'
         WHEN u.status & B'0001' = B'0001' THEN 'open'
         ELSE 'undefined'
         END AS statustext,
         state::int,
         CASE
         WHEN p.state & B'111' = B'111' THEN 'online (all)'
         WHEN p.state & B'110' = B'110' THEN 'online (local & trusted)'
         WHEN p.state & B'101' = B'101' THEN 'online (external & trusted)'
         WHEN p.state & B'011' = B'011' THEN 'online (external & local)'
         WHEN p.state & B'100' = B'100' THEN 'online (trusted)'
         WHEN p.state & B'010' = B'010' THEN 'online (local)'
         WHEN p.state & B'001' = B'001' THEN 'online (external)'
         ELSE 'offline'
         END AS statetext,
         u.lock_date, u.expiry_date, p.lc_ip,
         p.input_count, p.input_last, p.input_error, p.input_error_last, p.input_error_all,
         p.scope, s.code AS scope_code, s.name AS scope_name, s.description AS scope_description
    FROM db.user u INNER JOIN db.profile   p ON p.userid = u.id
                   INNER JOIN db.scope     s ON s.id = p.scope
                   INNER JOIN db.locale    l ON l.id = p.locale
                   INNER JOIN db.area      a ON a.id = p.area
                   INNER JOIN db.interface i ON i.id = p.interface
                    LEFT JOIN pg_roles     r ON r.rolname = u.username
   WHERE u.type = 'U';

GRANT SELECT ON users TO administrator;

--------------------------------------------------------------------------------
-- groups ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW groups (Id, UserName, Name, Description, System)
AS
  SELECT u.id, u.username, u.name, u.description, r.rolname IS NOT NULL
    FROM db.user u LEFT JOIN pg_roles r ON r.rolname = lower(u.username)
   WHERE u.type = 'G';

GRANT SELECT ON groups TO administrator;

--------------------------------------------------------------------------------
-- MemberGroup -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW MemberGroup (
  UserId, UserType, UserName, UserFullName, UserDescription,
  MemberId, MemberType, MemberName, MemberFullName, MemberDescription
)
AS
  SELECT mg.userid,
         CASE g.type
         WHEN 'G' THEN 'group'
         WHEN 'U' THEN 'user'
         END, g.username, g.name, g.description,
         mg.member,
         CASE u.type
         WHEN 'G' THEN 'group'
         WHEN 'U' THEN 'user'
         END, u.username, u.name, u.description
    FROM db.member_group mg INNER JOIN db.user g ON g.id = mg.userid
                            INNER JOIN db.user u ON u.id = mg.member;

GRANT SELECT ON MemberGroup TO administrator;

--------------------------------------------------------------------------------
-- MemberArea ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW MemberArea (
  Area, Code, Name, Description,
  MemberId, MemberType, MemberName, MemberFullName, MemberDesc
)
AS
  SELECT md.area, d.code, d.name, d.description,
         md.member, u.type, u.username, u.name, u.description
    FROM db.member_area md INNER JOIN db.area d ON d.id = md.area
                           INNER JOIN db.user u ON u.id = md.member;

GRANT SELECT ON MemberArea TO administrator;

--------------------------------------------------------------------------------
-- MemberInterface -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW MemberInterface (
  Interface, InterfaceName, InterfaceDesc,
  MemberId, MemberType, MemberName, MemberFullName, MemberDesc
)
AS
  SELECT mwp.interface, wp.name, wp.description,
         mwp.member, u.type, u.username, u.name, u.description
    FROM db.member_interface mwp INNER JOIN db.interface wp ON wp.id = mwp.interface
                                 INNER JOIN db.user u ON u.id = mwp.member;

GRANT SELECT ON MemberInterface TO administrator;

--------------------------------------------------------------------------------
-- VIEW IPTable ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW IPTable
AS
  SELECT * FROM db.iptable;

GRANT SELECT ON IPTable TO administrator;

--------------------------------------------------------------------------------
-- VIEW Auth -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Auth
AS
  SELECT * FROM db.auth;

GRANT SELECT ON Auth TO administrator;

--------------------------------------------------------------------------------
-- Tokens ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Tokens
AS
  SELECT h.id, h.created, h.updated, t.id as tokenId,
         CASE
         WHEN type = 'C' THEN 'authorization_code'
         WHEN type = 'A' THEN 'access_token'
         WHEN type = 'R' THEN 'refresh_token'
         WHEN type = 'I' THEN 'id_token'
         END AS grant_type,
         t.token, t.used, t.hash, h.session, h.agent, h.host, t.validFromDate, t.validToDate
    FROM db.token_header h INNER JOIN db.token t ON h.id = t.header;

GRANT SELECT ON Tokens TO administrator;

--------------------------------------------------------------------------------
-- Session ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Session
AS
  SELECT s.code, s.token, s.userid, s.suid, u.username, u.name,
         s.agent, s.host, s.locale, s.area, s.interface, s.created, s.updated,
         u.input_last, u.lc_ip, u.status, u.state
    FROM db.session s INNER JOIN db.area a ON s.area = a.id
                      INNER JOIN users   u ON s.userid = u.id AND u.scope = a.scope;

GRANT SELECT ON Session TO administrator;

