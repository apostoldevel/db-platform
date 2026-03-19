-- P00000003.sql — Add error module (error_catalog tables, ParseMessage signature fix)
--
-- Platform 1.2.0 introduces:
--   1) New error module with db.error_catalog and db.error_catalog_text tables
--   2) Updated ParseMessage() with OUT error parameter (requires DROP first)
--   3) Error catalog populated with 80+ platform error codes in 6 languages
--
-- See: docs/migration-1.2.0.md

\set ON_ERROR_STOP on

-- 1. Drop old ParseMessage (signature changed: added OUT error text)
DROP FUNCTION IF EXISTS ParseMessage(text);

-- 2. Create error_catalog tables
\ir '../../error/table.sql'

-- 3. Populate error catalog
\ir '../../error/init.sql'
