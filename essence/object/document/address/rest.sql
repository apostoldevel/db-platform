--------------------------------------------------------------------------------
-- REST ADDRESS ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запрос данных в формате REST JSON API (адрес).
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - JSON
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION rest.address (
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
  WHEN '/address/tree/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_address_tree($1)', JsonbToFields(r.fields, GetColumns('address_tree', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_address_tree($1)', JsonbToFields(r.fields, GetColumns('address_tree', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/address/tree/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_address_tree($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('address_tree', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/address/tree/history' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['id', 'code']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, code varchar)
    LOOP
      FOR e IN SELECT api.get_address_tree_history(coalesce(r.id, GetAddressTreeId(r.code))) AS history
      LOOP
        RETURN NEXT row_to_json(e)->>'history';
      END LOOP;
    END LOOP;

  WHEN '/address/tree/string' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['code', 'short', 'level']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(code varchar, short integer, level integer)
      LOOP
        FOR e IN SELECT * FROM api.get_address_tree_string(r.code, coalesce(r.short, 0), coalesce(r.level, 0)) AS address
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(code varchar, short integer, level integer)
      LOOP
        FOR e IN SELECT * FROM api.get_address_tree_string(r.code, coalesce(r.short, 0), coalesce(r.level, 0)) AS address
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/address/type' THEN

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.type($1)', JsonbToFields(r.fields, GetColumns('type', 'api'))) USING GetEssence('address')
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/address/method' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric)
      LOOP
        FOR e IN SELECT r.id, api.get_methods(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_address(r.id) ORDER BY id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric)
      LOOP
        FOR e IN SELECT r.id, api.get_methods(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_address(r.id) ORDER BY id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/address/count' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_address(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_address(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/address/set' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('set_address', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN EXECUTE format('SELECT row_to_json(api.set_address(%s)) FROM jsonb_to_recordset($1) AS x(%s)', array_to_string(GetRoutines('set_address', 'api', false, 'x'), ', '), array_to_string(GetRoutines('set_address', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    ELSE

      FOR r IN EXECUTE format('SELECT row_to_json(api.set_address(%s)) FROM jsonb_to_record($1) AS x(%s)', array_to_string(GetRoutines('set_address', 'api', false, 'x'), ', '), array_to_string(GetRoutines('set_address', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    END IF;

  WHEN '/address/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_address($1)', JsonbToFields(r.fields, GetColumns('address', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_address($1)', JsonbToFields(r.fields, GetColumns('address', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/address/get/string' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric)
      LOOP
        FOR e IN SELECT * FROM api.get_address_string(r.id) AS address
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric)
      LOOP
        FOR e IN SELECT * FROM api.get_address_string(r.id) AS address
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/address/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_address($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('address', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
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
