TRUNCATE db.api_log;
DROP VIEW ApiLog CASCADE;
ALTER TABLE db.api_log ALTER COLUMN datetime TYPE timestamptz;

CREATE OR REPLACE VIEW apiLog (Id, DateTime, su, Session, UserName,
  Path, JSON, Nonce, NonceTime, Signature, RunTime, EventId, Error)
AS
  SELECT id, datetime, su, session, username,
         path, json, nonce, to_timestamp(nonce / 1000000), signature,
         round(extract(second from runtime)::numeric, 3), eventid, null
    FROM db.api_log;

GRANT SELECT ON apiLog TO administrator;