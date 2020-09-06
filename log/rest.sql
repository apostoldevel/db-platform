--------------------------------------------------------------------------------
-- REST EVENT LOG --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запрос данных в формате REST JSON API (Журнал событий).
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - JSON
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION rest.event (
  pPath       text,
  pPayload    jsonb default null
) RETURNS     SETOF json
AS $$
DECLARE
  r           record;
  e           record;

  arKeys      text[];
BEGIN
  IF pPath IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  CASE pPath
  WHEN '/event/log' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, GetRoutines('event_log', 'api', false));
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(type char, code numeric, datefrom timestamp, dateto timestamp)
    LOOP
      FOR e IN SELECT * FROM api.event_log(current_username(), r.type, r.code, r.datefrom, r.dateto)
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/event/log/set' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('write_to_log', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(type char, code integer, text text)
    LOOP
      FOR e IN SELECT * FROM api.write_to_log(coalesce(r.type, 'M'), coalesce(r.code, 9999), r.text) AS success
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/event/log/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_event_log($1)', JsonbToFields(r.fields, GetColumns('event_log', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_event_log($1)', JsonbToFields(r.fields, GetColumns('event_log', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  ELSE
    PERFORM RouteNotFound(pPath);
  END CASE;

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;
