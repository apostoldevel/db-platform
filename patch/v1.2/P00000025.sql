--------------------------------------------------------------------------------
-- P00000025 -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- ERR-401-009 SessionIpTableError: a session refused on re-entry by the
-- user's IP table now answers 401 (CheckSessionUser — SessionIn and the warm
-- path of daemon.observer), so a WebSocket closes on it. A refused password
-- login keeps ERR-400-044.
--
-- RegisterError only fills in what is missing, and init.sql is not re-run on a
-- database in service, so the code is registered here — from the catalogue
-- itself, as P00000013 does, so the translations cannot drift from a copy.
-- Re-runnable.
--
-- Everything else in 1.2.27 — UnspecifiedHost() and the daemon.* entries that
-- turn a missing client host into it (a user with an IP table is no longer let
-- through by an absent address), SessionIpTableError — is routines, carried by
-- update.psql; no schema moves.
--------------------------------------------------------------------------------

\ir '../../error/init.sql'
