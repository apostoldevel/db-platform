--------------------------------------------------------------------------------
-- db.log ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.log (
    id          bigserial PRIMARY KEY NOT NULL,
    type        char DEFAULT 'M' NOT NULL,
    datetime	timestamp DEFAULT Now() NOT NULL,
    username	text NOT NULL,
    session     varchar(40),
    code        integer NOT NULL,
    event		text NOT NULL,
    text        text NOT NULL,
    category    text,
    object      numeric(12),
    CONSTRAINT ch_log_type CHECK (type IN ('M', 'W', 'E', 'D'))
);

COMMENT ON TABLE db.log IS 'Журнал событий.';

COMMENT ON COLUMN db.log.id IS 'Идентификатор';
COMMENT ON COLUMN db.log.type IS 'Тип события';
COMMENT ON COLUMN db.log.datetime IS 'Дата и время события';
COMMENT ON COLUMN db.log.username IS 'Имя пользователя';
COMMENT ON COLUMN db.log.session IS 'Сессия';
COMMENT ON COLUMN db.log.code IS 'Код события';
COMMENT ON COLUMN db.log.event IS 'Событие';
COMMENT ON COLUMN db.log.text IS 'Текст';
COMMENT ON COLUMN db.log.category IS 'Категория';
COMMENT ON COLUMN db.log.object IS 'Идентификатор объекта';

CREATE INDEX ON db.log (type);
CREATE INDEX ON db.log (datetime);
CREATE INDEX ON db.log (username);
CREATE INDEX ON db.log (code);
CREATE INDEX ON db.log (event);
CREATE INDEX ON db.log (category);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_log_insert()
RETURNS trigger AS $$
BEGIN
  IF NULLIF(NEW.username, '') IS NULL THEN
     NEW.username := coalesce(current_username(), session_user);
  END IF;

  IF NEW.session IS NULL THEN
    NEW.session := current_session();
  END IF;

  IF NEW.session IS NOT NULL THEN
    NEW.session := SubStr(NEW.session, 1, 8) || '...' || SubStr(NEW.session, 33);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_log_insert
  BEFORE INSERT ON db.log
  FOR EACH ROW
  EXECUTE PROCEDURE ft_log_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_log_after_insert()
RETURNS trigger AS $$
BEGIN
  PERFORM pg_notify('log', json_build_object('id', NEW.id, 'type', NEW.type, 'code', NEW.code, 'username', NEW.username, 'event', NEW.event, 'category', NEW.category)::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_log_after_insert
  AFTER INSERT ON db.log
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_log_after_insert();

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

--------------------------------------------------------------------------------
-- AddEventLog -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddEventLog (
  pType		char,
  pCode		integer,
  pEvent	text,
  pText		text,
  pCategory text DEFAULT null,
  pObject   numeric DEFAULT null
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  INSERT INTO db.log (type, code, event, text, category, object)
  VALUES (pType, pCode, pEvent, pText, pCategory, pObject)
  RETURNING id INTO nId;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewEventLog -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NewEventLog (
  pType		char,
  pCode		integer,
  pEvent	text,
  pText		text,
  pCategory text DEFAULT null,
  pObject   numeric DEFAULT null
) RETURNS	void
AS $$
DECLARE
  nId		numeric;
BEGIN
  nId := AddEventLog(pType, pCode, pEvent, pText, pCategory, pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- WriteToEventLog -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION WriteToEventLog (
  pType		char,
  pCode		integer,
  pEvent	text,
  pText		text,
  pObject   numeric DEFAULT null
) RETURNS	void
AS $$
DECLARE
  vCategory text;
BEGIN
  IF pType IN ('M', 'W', 'E', 'D') THEN

    IF pObject IS NOT NULL THEN
      SELECT GetClassCode(class) INTO vCategory FROM db.object WHERE id = pObject;
    END IF;

    PERFORM NewEventLog(pType, pCode, pEvent, pText, vCategory, pObject);
  END IF;

  IF pType = 'D' AND GetDebugMode() THEN
    pType := 'N';
  END IF;

  IF pType = 'N' THEN
    RAISE NOTICE '[%] [%] [%] [%] %', pType, pCode, pEvent, pObject, pText;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- WriteToEventLog -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION WriteToEventLog (
  pType		char,
  pCode		integer,
  pText		text,
  pObject   numeric DEFAULT null
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog(pType, pCode, 'log', pText, pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteEventLog --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteEventLog (
  pId		numeric
) RETURNS	void
AS $$
BEGIN
  DELETE FROM db.log WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
