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

COMMENT ON TABLE db.message IS 'Message record dispatched via SMTP, FCM, SMS, or API agents.';

COMMENT ON COLUMN db.message.id IS 'Primary key (same as document.id).';
COMMENT ON COLUMN db.message.document IS 'Reference to the parent document record.';
COMMENT ON COLUMN db.message.agent IS 'Delivery agent (SMTP, FCM, M2M, etc.).';
COMMENT ON COLUMN db.message.code IS 'Unique message code (MsgId), auto-generated if empty.';
COMMENT ON COLUMN db.message.profile IS 'Sender identity / profile name.';
COMMENT ON COLUMN db.message.address IS 'Recipient address (email, phone, device token, etc.).';
COMMENT ON COLUMN db.message.subject IS 'Message subject line.';
COMMENT ON COLUMN db.message.content IS 'Message body content.';

CREATE INDEX ON db.message (document);
CREATE INDEX ON db.message (agent);
CREATE INDEX ON db.message (code);
CREATE INDEX ON db.message (profile);
CREATE INDEX ON db.message (address);

CREATE INDEX ON db.message (subject);
CREATE INDEX ON db.message (subject text_pattern_ops);

--------------------------------------------------------------------------------

/**
 * @brief Auto-set id from parent document and generate a random hex code for new message rows.
 * @return {trigger}
 * @since 1.0.0
 */
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

/**
 * @brief Emit pg_notify on the message channel with class, type, agent, and address details after insert.
 * @return {trigger}
 * @since 1.0.0
 */
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

/**
 * @brief Prevent modification of the message code after creation.
 * @return {trigger}
 * @since 1.0.0
 */
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
