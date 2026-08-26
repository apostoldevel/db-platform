--------------------------------------------------------------------------------
-- mq -- store-and-forward message transport ------------------------------------
--------------------------------------------------------------------------------

-- A new module rather than a change to replication. The two are not variants of
-- one idea: replication carries ROWS and applies them by raw DML with the
-- triggers switched off, mq carries MESSAGES and applies them through a handler
-- registered per message type. Projects using replication keep it exactly as it
-- is -- this patch adds a schema beside it and touches nothing of theirs.
--
-- What arrives: mq.channel (a lane with an enumerated policy), mq.peer (the
-- nodes, including this one), mq.binding (which class publishes where),
-- mq.message (the log, both directions), mq.watermark (the cursor on the pair
-- node+channel), mq.ingest (the reception registry), mq.dead (refused, with the
-- reason), mq.session (what an exchange carried).
--
-- The module's own create.psql is included rather than copied: a second copy of
-- three hundred lines of DDL is a second copy that drifts, and the difference
-- would show up as a database migrated into a shape no fresh install has.

DO $$
DECLARE
  present   integer;
BEGIN
  -- Two different situations put an "mq" schema here before this patch runs,
  -- and they need opposite answers.
  --
  -- One: the database was built by install.sh --init, whose create.psql already
  -- carries this module, and nobody ran migrate.sh --baseline afterwards. Then
  -- the schema is ours, complete, and re-running the module would fail on
  -- CreateGroup('mq') -- a failure that says "role exists" and means "you are
  -- looking at the wrong problem". Skipped below, quietly.
  --
  -- Two: somebody's own schema happens to be called mq. That one must not be
  -- written over, and CREATE SCHEMA IF NOT EXISTS would say nothing while the
  -- tables below failed one at a time, halfway through.

  SELECT count(*) INTO present
    FROM information_schema.tables
   WHERE table_schema = 'mq'
     AND table_name IN ('channel', 'peer', 'binding', 'message', 'watermark', 'ingest', 'dead', 'session');

  IF EXISTS (SELECT FROM information_schema.schemata WHERE schema_name = 'mq') AND present <> 8 THEN
    RAISE EXCEPTION 'A schema named "mq" already exists here and is not the platform''s (% of 8 tables)', present
      USING HINT = 'Reconcile it by hand before this patch is recorded as applied.';
  END IF;
END $$;

SELECT NOT EXISTS (SELECT FROM information_schema.schemata WHERE schema_name = 'mq') AS mq_absent \gset

\if :mq_absent
\ir '../../mq/create.psql'
\else
\echo '[M] mq: schema already present, module skipped (built by create.psql, not yet baselined)'
\endif

--------------------------------------------------------------------------------
-- What a deployment must do next -----------------------------------------------
--------------------------------------------------------------------------------

-- init.sql registered THIS database as a node named after itself, with the hub
-- role, because a single installation is a hub until somebody says otherwise.
-- An edge node -- a ship, a branch, an appliance -- is renamed and re-roled at
-- setup:
--
--   SELECT mq.edit_peer(mq.get_peer(current_database()), 'Vessel 9123456', 'edge');
--
-- and the node at the other end is registered with mq.create_peer, together
-- with the area its incoming facts are written into. Leaving the area NULL is
-- not neutral: db.ft_object_before_insert refuses an object whose scope does
-- not match the session area, so reception either fails outright or writes into
-- whatever area the receiving session happened to be in.
--
-- Channels are created by whoever owns the data that travels on them, with the
-- three axes stated explicitly -- priority, delivery guarantee, lifetime. There
-- is no default channel on purpose: a lane created implicitly is a lane whose
-- policy nobody chose.
