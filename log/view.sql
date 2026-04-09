--------------------------------------------------------------------------------
-- VIEW EventLog ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW EventLog (Id, Type, TypeName, DateTime, TimeStamp, UserName,
  Session, Code, Scope, Event, Text, Category, Object
)
AS
  SELECT id, type,
         CASE
         WHEN type = 'M' THEN 'Message'
         WHEN type = 'W' THEN 'Warning'
         WHEN type = 'E' THEN 'Error'
         WHEN type = 'D' THEN 'Debug'
         END,
         datetime, timestamp, username, session, code, scope, event, text, category, object
    FROM db.log;

GRANT SELECT ON EventLog TO administrator;
