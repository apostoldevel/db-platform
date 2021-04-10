--------------------------------------------------------------------------------
-- REST NOTIFICATION -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запрос данных в формате REST JSON API (Уведомления).
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - JSON
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION rest.notification (
  pPath		text,
  pPayload	jsonb default null
) RETURNS	SETOF json
AS $$
DECLARE
  r			record;
  e			record;
  o			record;

  search	jsonb;

  arKeys	text[];
BEGIN
  IF pPath IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  IF current_session() IS NULL THEN
	PERFORM LoginFailed();
  END IF;

  CASE pPath
  WHEN '/notification' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['point', 'fields']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(point double precision, fields jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.notification($1)', JsonbToFields(r.fields, GetColumns('notification', 'api'))) USING coalesce(to_timestamp(r.point), Now())
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/notification/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_notification($1)', JsonbToFields(r.fields, GetColumns('notification', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_notification($1)', JsonbToFields(r.fields, GetColumns('notification', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/notification/count' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_notification(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_notification(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/notification/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby', 'groupby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb, groupby jsonb)
    LOOP
      IF r.groupby IS NOT NULL THEN
        FOR e IN EXECUTE format('SELECT %s FROM api.list_notification($1, $2, $3, $4, $5) GROUP BY %s', array_to_string(array_quote_literal_json(JsonbToStrArray(r.fields)), ','), array_to_string(array_quote_literal_json(JsonbToStrArray(r.groupby)), ',')) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
	  ELSE
        FOR e IN EXECUTE format('SELECT %s FROM api.list_notification($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('notification', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END IF;
    END LOOP;

  WHEN '/notification/changed/objects' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['objects', 'fromdate', 'todate']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(objects jsonb, fromdate timestamptz, todate timestamptz)
    LOOP
      search := jsonb_build_array(jsonb_build_object('field', 'object', 'valarr', r.objects, 'compare', 'IN'));

      IF r.fromdate IS NOT NULL THEN
	    search := search || jsonb_build_object('field', 'datetime', 'compare', 'GEQ', 'value', r.fromdate);
	  END IF;

      IF r.todate IS NOT NULL THEN
	    search := search || jsonb_build_object('field', 'datetime', 'compare', 'LSS', 'value', r.todate);
	  END IF;

	  FOR e IN SELECT entity, object FROM api.list_notification(search, null, null, null, null) GROUP BY entity, object
	  LOOP
		FOR o IN EXECUTE format('SELECT * FROM api.get_%s($1)', GetEntityCode(e.entity)) USING e.object
		LOOP
		  IF o.id IS NOT NULL THEN
	        RETURN NEXT row_to_json(o);
	      END IF;
		END LOOP;
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
