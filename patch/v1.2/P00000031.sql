--------------------------------------------------------------------------------
-- P00000031 -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- The gateway registration moves from update-time to install-time
-- (apostol-csms T757). gateway/update.psql no longer calls InitGateway() on
-- every script update; a fresh base registers its routes and allow-list
-- functions from gateway/init.sql (gateway/create.psql). An existing base has
-- the routes of the older shape only, so the new prefixes (jobs, messages,
-- references, agents, programs, schedulers, vendors, versions) and the new
-- allow-list functions stay closed there until they are registered once —
-- this patch is that once.
--
-- migrate.sh runs every patch before update.psql, so the new routine is
-- loaded here, from the patch itself (a self-contained relative \ir is fine:
-- this patch has no \connect, so the phase split does not rewrite its path —
-- see the P00000024 / P00000025 pair for the rule). The closing update.psql
-- then CREATE OR REPLACEs the same body again — idempotent. InitGateway()
-- re-registers the unchanged routes of older shapes too: RegisterRoute /
-- RegisterGatewayFunction are upserts, and InitGateway ran at every update
-- before this change, so a re-run is a no-op for them.
--
-- Single phase, kernel, no SignIn (registration writes db.route /
-- db.endpoint, the kernel phase owns them at install as well).
--------------------------------------------------------------------------------

\set ON_ERROR_STOP on

-- On a base older than 1.2.31 the statements at the end of this patch are not
-- enough on their own. InitGateway() registers the routes and the allow-list,
-- and what it calls does not exist there yet: migrate.sh runs every patch
-- BEFORE update.psql, and update.psql is what brings the current routines of
-- the other modules. Two things stop the patch otherwise:
--   * AddEndPoint (api/routine.sql) of an older base still refuses the
--     three-argument guard form, e.g. SELECT GuardAdministrator($1, $2, $3):
--     "Invalid endpoint definition format";
--   * the allow-list names 11 api.* functions that exist only after the module
--     api.sql files have run: list_area_type, list_locale and is_administrator
--     (admin/api.sql), list_state_type (workflow/api.sql),
--     set_session_area_by_code (session/api.sql), *_my_notification
--     (notification/api.sql) and *_my_listener (observer/api.sql).
-- The files they come from are therefore loaded first, in this order:
--   api/routine.sql             the current AddEndPoint
--   admin/routine.sql           RegisterProtectedGroup (see below)
--   entity/object/security.sql  CheckObjectArea, called by notification/api.sql
--   session/api.sql, workflow/api.sql, notification/api.sql, admin/api.sql,
--   observer/api.sql            the allow-listed api.* functions
-- admin/routine.sql is not needed by this patch itself. It is loaded here
-- because P00000016 (mq/init.sql) calls RegisterProtectedGroup, and on a base
-- where P00000016 has not been applied yet that function does not exist when it
-- runs. A consumer must run P00000016 after this patch on such a base.
--
-- The set is deliberately smaller than the whole update.psql, and was found by
-- trial on bases at 1.2.10b and 1.2.18e and on a copy of a production dump.
-- Leaving out any file other than admin/routine.sql stops this patch on a
-- missing function; leaving out admin/routine.sql stops P00000016. A base with
-- another history may need one more file: the error names the missing function,
-- and the file that defines it belongs before gateway/routine.sql. On an
-- up-to-date base these files change nothing (measured: 0 of 3061 function
-- bodies differ after loading them), so a re-run is a no-op.
\echo [P] call 'api/routine.sql'
\ir '../../api/routine.sql'
\echo [P] call 'admin/routine.sql'
\ir '../../admin/routine.sql'
\echo [P] call 'entity/object/security.sql'
\ir '../../entity/object/security.sql'
\echo [P] call 'session/api.sql'
\ir '../../session/api.sql'
\echo [P] call 'workflow/api.sql'
\ir '../../workflow/api.sql'
\echo [P] call 'notification/api.sql'
\ir '../../notification/api.sql'
\echo [P] call 'admin/api.sql'
\ir '../../admin/api.sql'
\echo [P] call 'observer/api.sql'
\ir '../../observer/api.sql'

\echo [P] call 'gateway/routine.sql'
\ir '../../gateway/routine.sql'

SELECT InitGateway();
