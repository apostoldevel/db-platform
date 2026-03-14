--------------------------------------------------------------------------------
-- REST CURRENT ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Dispatch REST JSON API requests for reading current session context values.
 * @param {text} pPath - REST route path (e.g. /current/user, /current/locale)
 * @param {jsonb} pPayload - Request payload (unused by most routes)
 * @return {SETOF json} - Current context value as JSON
 * @throws RouteIsEmpty - When pPath is NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION rest.current (
  pPath       text,
  pPayload    jsonb default null
) RETURNS     SETOF json
AS $$
DECLARE
  r           record;
BEGIN
  IF pPath IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  CASE pPath
  WHEN '/current/session' THEN

    FOR r IN SELECT * FROM api.current_session()
    LOOP
      RETURN NEXT row_to_json(r);
    END LOOP;

  WHEN '/current/user' THEN

    FOR r IN SELECT * FROM api.current_user()
    LOOP
      RETURN NEXT row_to_json(r);
    END LOOP;

  WHEN '/current/userid' THEN

    FOR r IN SELECT * FROM api.current_userid() AS userid
    LOOP
      RETURN NEXT row_to_json(r);
    END LOOP;

  WHEN '/current/username' THEN

    FOR r IN SELECT * FROM api.current_username() AS username
    LOOP
      RETURN NEXT row_to_json(r);
    END LOOP;

  WHEN '/current/area' THEN

    FOR r IN SELECT * FROM api.current_area()
    LOOP
      RETURN NEXT row_to_json(r);
    END LOOP;

  WHEN '/current/interface' THEN

    FOR r IN SELECT * FROM api.current_interface()
    LOOP
      RETURN NEXT row_to_json(r);
    END LOOP;

  WHEN '/current/locale' THEN

    FOR r IN SELECT * FROM api.current_locale()
    LOOP
      RETURN NEXT row_to_json(r);
    END LOOP;

  WHEN '/current/oper_date' THEN

    FOR r IN SELECT * FROM api.oper_date()
    LOOP
      RETURN NEXT row_to_json(r);
    END LOOP;

  ELSE
    PERFORM RouteNotFound(pPath);
  END CASE;

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;
