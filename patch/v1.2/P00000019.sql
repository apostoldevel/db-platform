--------------------------------------------------------------------------------
-- P00000019 -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- SELECT on api.* views for apibot, the helper-pool role.
--
-- apibot calls api.* as itself: functions are EXECUTE-able by PUBLIC by
-- default (1050 of 1051 SECURITY DEFINER), views are not — measured 16.09.2026
-- on a live base: has_table_privilege('apibot', api.<view>, 'SELECT') true on
-- 17 of 174, the rest only where a module had granted it by hand (mq,
-- replication, and a few project modules). A caller that reads the view directly under
-- the pool role gets `permission denied` → 500; rest.* never saw it because it
-- reads under its own SECURITY DEFINER owner.
--
-- The data model does not lean on the grant: row visibility is decided inside
-- the views by Access<Entity> against the session context, and the same views
-- are already readable to apibot through api.list_*/api.get_* — the grant
-- opens no data the role could not reach before, it removes a 500.
--
-- Two statements: default privileges for every view kernel creates in api from
-- now on (kernel/schema.sql, kernel/api.sql carry the same rule for fresh
-- installs), and a one-time catch-up for the views that already exist —
-- CREATE OR REPLACE VIEW keeps the ACL and would not pick the default up.
-- Idempotent: a second run is a no-op.

ALTER DEFAULT PRIVILEGES FOR ROLE kernel IN SCHEMA api GRANT SELECT ON TABLES TO apibot;

GRANT SELECT ON ALL TABLES IN SCHEMA api TO apibot;
