--------------------------------------------------------------------------------
-- db.log ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.log (
    id          bigserial PRIMARY KEY NOT NULL,
    type        char DEFAULT 'M' NOT NULL CHECK (type IN ('M', 'W', 'E', 'D')),
    datetime	timestamp DEFAULT Now() NOT NULL,
    username	text NOT NULL,
    session     char(40),
    code        integer NOT NULL,
    event		text NOT NULL,
    text        text NOT NULL,
    category    text,
    object      uuid
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
