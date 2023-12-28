--------------------------------------------------------------------------------
-- REST SESSION ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запрос данных в формате REST JSON API (Сессия).
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - JSON
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION rest.session (
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

  IF current_session() IS NULL THEN
    PERFORM LoginFailed();
  END IF;

  CASE pPath
  WHEN '/session/set/area' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'code']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, code text)
    LOOP
      PERFORM api.set_session_area(coalesce(r.id, GetArea(r.code)));
      FOR e IN SELECT * FROM api.current_area()
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/session/set/interface' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'code']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, code text)
    LOOP
      PERFORM api.set_session_interface(coalesce(r.id, GetInterface(r.code)));
      FOR e IN SELECT * FROM api.current_interface()
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/session/set/locale' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'code']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, code text)
    LOOP
      PERFORM api.set_session_locale(coalesce(r.id, GetLocale(r.code)));
      FOR e IN SELECT * FROM api.current_locale()
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/session/set/oper_date' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['oper_date']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(oper_date timestamp)
    LOOP
      PERFORM api.set_session_oper_date(r.oper_date);
      FOR e IN SELECT * FROM api.oper_date()
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  ELSE
    PERFORM RouteNotFound(pPath);
  END CASE;

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;
