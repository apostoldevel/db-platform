--------------------------------------------------------------------------------
-- REPLICATION -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ReplicationLog
AS
  SELECT * FROM replication.log;

GRANT ALL ON ReplicationLog TO administrator;

--------------------------------------------------------------------------------
-- RelayLog --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW RelayLog
AS
  SELECT * FROM replication.relay;

GRANT ALL ON RelayLog TO administrator;

--------------------------------------------------------------------------------
-- ReplicationTable ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ReplicationTable
AS
  SELECT schema, name, true AS active, updated, priority FROM replication.list
  UNION
  SELECT table_schema, table_name, false, null, null
    FROM information_schema.tables i
   WHERE table_type = 'BASE TABLE'
     AND table_schema = 'db'
     AND NOT EXISTS (SELECT FROM replication.list l WHERE l.schema = i.table_schema AND l.name = i.table_name);

GRANT ALL ON ReplicationTable TO administrator;
