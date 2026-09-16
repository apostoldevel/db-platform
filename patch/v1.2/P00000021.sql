--------------------------------------------------------------------------------
-- P00000021 -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- SELECT on api.* views for the administrator group, by default privilege.
--
-- Every module grants each api.* view to administrator by hand — 173 GRANT
-- statements — and the list rots: measured 16.09.2026 on a live base,
-- administrator (and so the admin login) lacked SELECT on api.users and
-- api.whoami, 172 of 174. Invisible through rest.*/api.* SECURITY DEFINER,
-- visible to a direct SELECT under the role (psql, pgweb, reports, pgTAP).
--
-- Same mechanism as P00000019 for apibot (T304): a default privilege for every
-- view kernel creates in api from now on (kernel/schema.sql and kernel/api.sql
-- carry the same rule for fresh installs) and a one-time catch-up for the views
-- that already exist — CREATE OR REPLACE VIEW keeps the ACL. Idempotent.

ALTER DEFAULT PRIVILEGES FOR ROLE kernel IN SCHEMA api GRANT SELECT ON TABLES TO administrator;

GRANT SELECT ON ALL TABLES IN SCHEMA api TO administrator;

--------------------------------------------------------------------------------
-- api.set_object_data: pType becomes text (T308). The parameter was declared
-- uuid while db.object_data.type holds the format code (text | json | xml |
-- base64): lower(uuid) does not exist, and the only caller,
-- api.set_object_data_json, passes text — /object/data/set never worked.
-- update.psql creates the text signature; the uuid one has to go, or both
-- coexist and the call becomes an overload nobody wanted — a signature change
-- without a DROP of the old one is how a project patch once left two functions
-- behind (apostol-csms P00000040, T196).

DROP FUNCTION IF EXISTS api.set_object_data(uuid, uuid, text, text);
