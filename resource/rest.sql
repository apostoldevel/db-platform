
-- REST RESOURCE ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Dispatch REST JSON API requests for the resource endpoint.
 * @param {text} pPath - Route path (e.g. '/resource/get', '/resource/list')
 * @param {jsonb} pPayload - Request payload as JSON object or array
 * @return {SETOF json} - Result rows serialised as JSON
 * @throws RouteIsEmpty - When pPath is NULL
 * @throws RouteNotFound - When pPath does not match any known route
 * @throws JsonIsEmpty - When a required payload is NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION rest.resource (
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
  WHEN '/resource/count' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT * FROM api.count_resource(r.search, r.filter)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT * FROM api.count_resource(r.search, r.filter)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/resource/set' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('set_resource', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN EXECUTE format('SELECT row_to_json(api.set_resource(%s)) FROM jsonb_to_recordset($1) AS x(%s)', array_to_string(GetRoutines('set_resource', 'api', false, 'x'), ', '), array_to_string(GetRoutines('set_resource', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    ELSE

      FOR r IN EXECUTE format('SELECT row_to_json(api.set_resource(%s)) FROM jsonb_to_record($1) AS x(%s)', array_to_string(GetRoutines('set_resource', 'api', false, 'x'), ', '), array_to_string(GetRoutines('set_resource', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    END IF;

  WHEN '/resource/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_resource($1)', JsonbToFields(r.fields, GetColumns('resource', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_resource($1)', JsonbToFields(r.fields, GetColumns('resource', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/resource/delete' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('delete_resource', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN EXECUTE format('SELECT api.delete_resource(%s) FROM jsonb_to_recordset($1) AS x(%s)', array_to_string(GetRoutines('delete_resource', 'api', false, 'x'), ', '), array_to_string(GetRoutines('delete_resource', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT json_build_object('success', true);
      END LOOP;

    ELSE

      FOR r IN EXECUTE format('SELECT api.delete_resource(%s) FROM jsonb_to_record($1) AS x(%s)', array_to_string(GetRoutines('delete_resource', 'api', false, 'x'), ', '), array_to_string(GetRoutines('delete_resource', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT json_build_object('success', true);
      END LOOP;

    END IF;

  WHEN '/resource/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_resource($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('resource', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
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
