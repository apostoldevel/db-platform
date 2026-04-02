-- P00000005.sql — DROP and recreate views with changed column order
--
-- Commits 47638a9..4e219bd reordered columns in several views (added Access*
-- JOINs, moved StateType before AgentType in ServiceMessage, etc.).
-- CREATE OR REPLACE VIEW cannot rename/reorder existing columns — need DROP first.
--
-- Affected views:
--   ServiceMessage (column reorder: StateType moved before AgentType)
--   ObjectMessage  (alias ac → aou)
--   ObjectJob      (alias ac → aou, removed Access JOIN in one variant)
--   ObjectReport   (added Access JOIN)
--   ObjectReportRoutine (added Access JOIN, reordered FROM)

\set ON_ERROR_STOP on

-- 1. ServiceMessage depends on ObjectMessage, drop from top down
DROP VIEW IF EXISTS ServiceMessage CASCADE;

-- 2. ObjectMessage
DROP VIEW IF EXISTS ObjectMessage CASCADE;

-- 3. ObjectJob
DROP VIEW IF EXISTS ObjectJob CASCADE;

-- 4. Report views (ObjectReportRoutine depends on ObjectReport chain)
DROP VIEW IF EXISTS ObjectReportRoutine CASCADE;
DROP VIEW IF EXISTS ObjectReport CASCADE;

-- Views will be recreated by the subsequent update.psql run
-- (patch.psql always runs before update.psql)
