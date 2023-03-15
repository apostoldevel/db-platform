CREATE OR REPLACE FUNCTION db.ft_notification_after_insert()
RETURNS     trigger
AS $$
DECLARE
  vClass    text;
  vEntity   text;
  vAction   text;
BEGIN
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

--

\connect :dbname admin

SELECT SignIn(CreateSystemOAuth2(), 'admin', :'admin');

SELECT GetErrorMessage();

SELECT EditType(GetType('private.report_ready'), null, 'sync.report_ready', 'Синхронный', 'Синхронный отчёт');
SELECT EditType(GetType('public.report_ready'), null, 'async.report_ready', 'Асинхронный', 'Асинхронный отчёт');

SELECT SignOut();

\connect :dbname kernel
