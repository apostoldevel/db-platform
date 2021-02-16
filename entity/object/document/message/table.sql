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
    content         text NOT NULL
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

CREATE UNIQUE INDEX ON db.message (agent, code);

CREATE INDEX ON db.message (document);
CREATE INDEX ON db.message (agent);
CREATE INDEX ON db.message (profile);
CREATE INDEX ON db.message (address);

CREATE INDEX ON db.message (subject);
CREATE INDEX ON db.message (subject text_pattern_ops);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_message_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.id IS NULL THEN
    SELECT NEW.document INTO NEW.id;
  END IF;

  IF NULLIF(NEW.code, '') IS null THEN
    NEW.code := encode(gen_random_bytes(12), 'hex');
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE TRIGGER t_message_insert
  BEFORE INSERT ON db.message
  FOR EACH ROW
  EXECUTE PROCEDURE ft_message_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_message_update()
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

CREATE TRIGGER t_message_update
  BEFORE UPDATE ON db.message
  FOR EACH ROW
  EXECUTE PROCEDURE ft_message_update();
