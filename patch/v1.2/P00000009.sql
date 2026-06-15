DROP VIEW IF EXISTS api.service_job CASCADE;
DROP VIEW IF EXISTS AccessReference CASCADE;
DROP VIEW IF EXISTS AccessDocument CASCADE;
DROP VIEW IF EXISTS AccessObject CASCADE;
DROP VIEW IF EXISTS AccessObjectId CASCADE;

DROP FUNCTION IF EXISTS GetOperDate(varchar);
DROP FUNCTION IF EXISTS SetOperDate(timestamptz, varchar);

CREATE OR REPLACE FUNCTION db.ft_notification_after_insert()
RETURNS     trigger
AS $$
DECLARE
  vClass    text;
  vEntity   text;
  vAction   text;
BEGIN
  IF NOT GetNotificationMode() THEN
	RETURN NEW;
  END IF;

  PERFORM pg_notify('notify', row_to_json(NEW)::text);

  vEntity := GetEntityCode(NEW.entity);

  IF vEntity = 'message' THEN

    vClass := GetClassCode(NEW.class);
    vAction := GetActionCode(NEW.action);

    IF vClass = 'inbox' THEN
      IF vAction = 'create' THEN
        PERFORM pg_notify('inbox', NEW.object::text);
      END IF;
    ELSIF vClass = 'outbox' THEN
      IF vAction = 'submit' OR vAction = 'repeat' THEN
        PERFORM pg_notify('outbox', NEW.object::text);
      END IF;
    END IF;

  ELSIF vEntity = 'report_ready' THEN

    vAction := GetActionCode(NEW.action);

    IF vAction = 'execute' THEN
      PERFORM pg_notify('report', json_build_object('session', current_session(), 'id', NEW.object)::text);
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
