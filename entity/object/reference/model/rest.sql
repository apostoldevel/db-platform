--------------------------------------------------------------------------------
-- REST MODEL ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запрос данных в формате REST JSON API (Модель).
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - JSON
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION rest.model (
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
  WHEN '/model/type' THEN

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.type($1)', JsonbToFields(r.fields, GetColumns('type', 'api'))) USING GetEntity('model')
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/model/method' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid)
      LOOP
        FOR e IN SELECT r.id, api.get_methods(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_model(r.id) ORDER BY id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid)
      LOOP
        FOR e IN SELECT r.id, api.get_methods(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_model(r.id) ORDER BY id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/model/count' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_model(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_model(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/model/set' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('set_model', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN EXECUTE format('SELECT row_to_json(api.set_model(%s)) FROM jsonb_to_recordset($1) AS x(%s)', array_to_string(GetRoutines('set_model', 'api', false, 'x'), ', '), array_to_string(GetRoutines('set_model', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    ELSE

      FOR r IN EXECUTE format('SELECT row_to_json(api.set_model(%s)) FROM jsonb_to_record($1) AS x(%s)', array_to_string(GetRoutines('set_model', 'api', false, 'x'), ', '), array_to_string(GetRoutines('set_model', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    END IF;

  WHEN '/model/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_model($1)', JsonbToFields(r.fields, GetColumns('model', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_model($1)', JsonbToFields(r.fields, GetColumns('model', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/model/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_model($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('model', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/model/property' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'properties']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid, properties json)
	  LOOP
		IF r.properties IS NOT NULL THEN
		  FOR e IN SELECT * FROM api.set_model_property_json(r.id, r.properties)
		  LOOP
			RETURN NEXT row_to_json(e);
		  END LOOP;
		ELSE
		  RETURN NEXT api.get_model_property_json(r.id);
		END IF;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, properties json)
	  LOOP
		IF r.properties IS NOT NULL THEN
		  FOR e IN SELECT * FROM api.set_model_property_json(r.id, r.properties)
		  LOOP
			RETURN NEXT row_to_json(e);
		  END LOOP;
		ELSE
		  RETURN NEXT api.get_model_property_json(r.id);
		END IF;
	  END LOOP;

	END IF;

  WHEN '/model/property/set' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

    arKeys := array_cat(arKeys, GetRoutines('set_model_property', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN EXECUTE format('SELECT row_to_json(api.set_model_property(%s)) FROM jsonb_to_recordset($1) AS x(%s)', array_to_string(GetRoutines('set_model_property', 'api', false, 'x'), ', '), array_to_string(GetRoutines('set_model_property', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    ELSE

      FOR r IN EXECUTE format('SELECT row_to_json(api.set_model_property(%s)) FROM jsonb_to_record($1) AS x(%s)', array_to_string(GetRoutines('set_model_property', 'api', false, 'x'), ', '), array_to_string(GetRoutines('set_model_property', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    END IF;

  WHEN '/model/property/get' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'property', 'fields']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid, property uuid, fields jsonb)
	  LOOP
		FOR e IN EXECUTE format('SELECT %s FROM api.get_model_property($1, $2)', JsonbToFields(r.fields, GetColumns('model_property', 'api'))) USING r.id, r.property
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, property uuid, fields jsonb)
	  LOOP
		FOR e IN EXECUTE format('SELECT %s FROM api.get_model_property($1, $2)', JsonbToFields(r.fields, GetColumns('model_property', 'api'))) USING r.id, r.property
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	END IF;

  WHEN '/model/property/delete' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id', 'property']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid, property uuid)
	  LOOP
		FOR e IN SELECT r.id, r.property, api.delete_model_property(r.id, r.property) AS deleted
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, property uuid)
	  LOOP
		FOR e IN SELECT r.id, r.property, api.delete_model_property(r.id, r.property) AS deleted
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

	END IF;

  WHEN '/model/property/clear' THEN

	IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
	END IF;

	arKeys := array_cat(arKeys, ARRAY['id']);
	PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid)
	  LOOP
		PERFORM api.clear_model_property(r.id);
		RETURN NEXT row_to_json(r);
	  END LOOP;

	ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid)
	  LOOP
		PERFORM api.clear_model_property(r.id);
		RETURN NEXT row_to_json(r);
	  END LOOP;

	END IF;

  WHEN '/model/property/count' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_model_property(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_model_property(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/model/property/list' THEN

	IF pPayload IS NOT NULL THEN
	  arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
	  PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
	ELSE
	  pPayload := '{}';
	END IF;

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
	LOOP
	  FOR e IN EXECUTE format('SELECT %s FROM api.list_model_property($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('model_property', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
	  LOOP
		RETURN NEXT row_to_json(e);
	  END LOOP;
	END LOOP;

  ELSE
    RETURN NEXT ExecuteDynamicMethod(pPath, pPayload);
  END CASE;

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;
