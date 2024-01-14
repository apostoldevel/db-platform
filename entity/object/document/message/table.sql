--------------------------------------------------------------------------------
-- MESSAGE ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.message ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.message (
    id              uuid PRIMARY KEY,
    document        uuid NOT NULL REFERENCES db.document(id) ON DELETE CASCADE,
    agent           uuid NOT NULL REFERENCES db.agent(id) ON DELETE RESTRICT,
    code            text NOT NULL,
    profile         text NOT NULL,
    address         text NOT NULL,
    subject         text,
    content         text
);

COMMENT ON TABLE db.message IS 'Сообщение.';

COMMENT ON COLUMN db.message.id IS 'Идентификатор';
COMMENT ON COLUMN db.message.document IS 'Документ';
COMMENT ON COLUMN db.message.agent IS 'Идентификатор агента';
COMMENT ON COLUMN db.message.code IS 'Код';
COMMENT ON COLUMN db.message.profile IS 'Профиль отправителя';
COMMENT ON COLUMN db.message.address IS 'Адрес получателя';
COMMENT ON COLUMN db.message.subject IS 'Тема';
COMMENT ON COLUMN db.message.content IS 'Содержимое';

CREATE INDEX ON db.message (document);
CREATE INDEX ON db.message (agent);
CREATE INDEX ON db.message (code);
CREATE INDEX ON db.message (profile);
CREATE INDEX ON db.message (address);

CREATE INDEX ON db.message (subject);
CREATE INDEX ON db.message (subject text_pattern_ops);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_message_before_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.id IS NULL THEN
    SELECT NEW.document INTO NEW.id;
  END IF;

  IF NULLIF(NEW.code, '') IS null THEN
    NEW.code := encode(gen_random_bytes(32), 'hex');
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

CREATE TRIGGER t_message_before_insert
  BEFORE INSERT ON db.message
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_message_before_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_message_after_insert()
RETURNS trigger AS $$
DECLARE
  vClass    text;
  vType     text;
  vAgent    text;
BEGIN
  SELECT c.code INTO vClass
    FROM db.object o INNER JOIN db.class_tree c ON c.id = o.class
   WHERE o.id = NEW.id;

  SELECT t.code, a.code INTO vType, vAgent
    FROM db.reference a INNER JOIN db.type t ON t.id = a.type
   WHERE a.id = NEW.agent;

  PERFORM pg_notify('message', json_build_object('id', NEW.id, 'class', vClass, 'type', vType, 'agent', vAgent, 'code', NEW.code, 'profile', NEW.profile, 'address', NEW.address, 'subject', NEW.subject)::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_message_after_insert
  AFTER INSERT ON db.message
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_message_after_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_message_before_update()
RETURNS trigger AS $$
BEGIN
  IF NEW.code IS DISTINCT FROM OLD.code THEN
    RAISE DEBUG 'Hacking alert: message code (% <> %).', OLD.code, NEW.code;
    RETURN NULL;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_message_before_update
  BEFORE UPDATE ON db.message
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_message_before_update();
