DROP INDEX IF EXISTS db.message_agent_code_idx;
CREATE INDEX ON db.message (code);

DROP INDEX IF EXISTS db.area_code_idx;
CREATE UNIQUE INDEX ON db.area (scope, code);

DROP FUNCTION IF EXISTS GetArea(text);
DROP FUNCTION IF EXISTS GetMessage(uuid, text);
DROP FUNCTION IF EXISTS SendFCM(uuid, text, text, text, text, text, uuid);
DROP FUNCTION IF EXISTS SendM2M(uuid, text, text, text, text, text, uuid);
DROP FUNCTION IF EXISTS SendMail(uuid, text, text, text, text, text, uuid);
DROP FUNCTION IF EXISTS SendMessage(uuid, uuid, text, text, text, text, text, uuid);
DROP FUNCTION IF EXISTS SendPush(uuid, text, text, uuid, jsonb, jsonb, jsonb);
DROP FUNCTION IF EXISTS SendPushData(uuid, text, json, uuid, text, text);
--
DROP FUNCTION IF EXISTS api.send_message(text, text, text, text, text, text);
--
DROP TRIGGER IF EXISTS t_message_after_insert ON db.message;
--
CREATE OR REPLACE FUNCTION ft_message_before_insert()
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
   SET search_path = kernel, pg_temp;
--
CREATE OR REPLACE FUNCTION db.ft_notification_after_insert()
RETURNS     trigger
AS $$
DECLARE
  vAction   text;
BEGIN
  PERFORM pg_notify('notify', row_to_json(NEW)::text);

  IF GetEntityCode(NEW.entity) = 'message' THEN
    vAction := GetActionCode(NEW.action);
    IF vAction = 'create' THEN
      PERFORM pg_notify('message', NEW.object::text);
    ELSIF vAction = 'submit' THEN
      PERFORM pg_notify('outbox', NEW.object::text);
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
