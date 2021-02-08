--------------------------------------------------------------------------------
-- VIEW EventLog ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW EventLog (Id, Type, TypeName, DateTime, UserName,
  Session, Code, Event, Text, Category, Object
)
AS
  SELECT id, type,
         CASE
         WHEN type = 'M' THEN 'Информация'
         WHEN type = 'W' THEN 'Предупреждение'
         WHEN type = 'E' THEN 'Ошибка'
         WHEN type = 'D' THEN 'Отладка'
         END,
         datetime, username, session, code, event, text, category, object
    FROM db.log;

GRANT SELECT ON EventLog TO administrator;
