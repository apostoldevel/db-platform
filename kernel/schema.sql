CREATE SCHEMA IF NOT EXISTS db AUTHORIZATION kernel;
CREATE SCHEMA IF NOT EXISTS kernel AUTHORIZATION kernel;
CREATE SCHEMA IF NOT EXISTS oauth2 AUTHORIZATION kernel;
CREATE SCHEMA IF NOT EXISTS api AUTHORIZATION kernel;
CREATE SCHEMA IF NOT EXISTS rest AUTHORIZATION kernel;
CREATE SCHEMA IF NOT EXISTS daemon AUTHORIZATION kernel;

CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA public;

GRANT USAGE ON SCHEMA kernel TO administrator;
GRANT USAGE ON SCHEMA api TO administrator;
GRANT USAGE ON SCHEMA rest TO administrator;
GRANT USAGE ON SCHEMA daemon TO daemon;
GRANT USAGE ON SCHEMA api TO apibot;
GRANT USAGE ON SCHEMA daemon TO apibot;
GRANT USAGE ON SCHEMA rest TO apibot;

-- apibot is the helper-pool role: it reaches api.* as itself, not through a
-- SECURITY DEFINER rest.* wrapper. Functions are EXECUTE-able by PUBLIC by
-- default; views are not — a view created here by kernel would stay closed to
-- apibot (permission denied → 500 in the caller). Grant SELECT at creation
-- time instead of per view. Existing bases: patch/v1.2/P00000019.
ALTER DEFAULT PRIVILEGES FOR ROLE kernel IN SCHEMA api GRANT SELECT ON TABLES TO apibot;
