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

\echo [P] call 'gateway/routine.sql'
\ir '../../gateway/routine.sql'

SELECT InitGateway();
