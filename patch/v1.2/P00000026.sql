--------------------------------------------------------------------------------
-- P00000026 -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- The /api/v2 road through the database (ship-safety T260 + T288):
--
-- - gateway.request: the verified identity of one open /api/v2 request, what
--   daemon.call restores the session context from (UNLOGGED: a request lives
--   one transaction; nothing to replay after a crash);
-- - gateway.function: the allow list of daemon.call;
-- - db.route.method takes PATCH (/api/v2 routes carry route guards);
-- - db.protected_group: groups only an administrator includes into or
--   excludes from (AddMemberToGroup and the two exclusions, CheckGroupChange);
-- - group 403 of the error catalogue (ERR-403-010…015), registered from the
--   catalogue itself as P00000025 does.
--
-- Routes, guards and the allow list are data written by InitGateway, which
-- update.psql runs after this patch (migrate.sh: patches, then update).
--
-- Re-runnable.
--------------------------------------------------------------------------------

CREATE UNLOGGED TABLE IF NOT EXISTS gateway.request (
    pid         integer NOT NULL,
    xid         bigint NOT NULL,
    session     text NOT NULL,
    context     jsonb NOT NULL,
    method      text NOT NULL,
    path        text NOT NULL,
    agent       text,
    host        inet,
    request_id  uuid,
    started     timestamptz NOT NULL DEFAULT clock_timestamp(),
    log         bigint,
    PRIMARY KEY (pid, xid)
);

COMMENT ON TABLE gateway.request IS 'One /api/v2 request opened by daemon.begin and not yet closed by daemon.end — the verified identity of the transaction. daemon.call restores the session context from here on every call instead of trusting the current.* GUCs, which the daemon connection can set itself. No role but kernel writes it; a rolled-back transaction takes its row with it.';

CREATE TABLE IF NOT EXISTS gateway.function (
    signature   text PRIMARY KEY,
    name        text NOT NULL,
    level       text NOT NULL DEFAULT 'session' CHECK (level IN ('session', 'administrator'))
);

COMMENT ON TABLE gateway.function IS 'The functions of schema api that daemon.call may reach — closed by default. Filled by RegisterGatewayFunction, re-run on every update.';

CREATE INDEX IF NOT EXISTS function_name_idx ON gateway.function (name);

ALTER TABLE db.route DROP CONSTRAINT IF EXISTS route_method_check;
ALTER TABLE db.route ADD CONSTRAINT route_method_check CHECK (method IN ('GET', 'POST', 'PUT', 'PATCH', 'DELETE'));

COMMENT ON COLUMN db.route.method IS 'HTTP method (GET, POST, PUT, PATCH, DELETE; PATCH since 1.2.31 for /api/v2).';

CREATE TABLE IF NOT EXISTS db.protected_group (
    id            uuid PRIMARY KEY REFERENCES db.user(id) ON DELETE CASCADE
);

COMMENT ON TABLE db.protected_group IS 'Groups whose membership grants rights by itself (administrator, system, message, replication, mq; a configuration adds its own with RegisterProtectedGroup): only an administrator includes into or excludes from them.';

INSERT INTO db.protected_group (id)
SELECT id FROM db.user WHERE type = 'G' AND username IN ('system', 'administrator', 'message', 'replication', 'mq')
ON CONFLICT (id) DO NOTHING;

\ir '../../error/init.sql'
