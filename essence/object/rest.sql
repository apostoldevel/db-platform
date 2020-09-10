--------------------------------------------------------------------------------
-- REST OBJECT -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запрос данных в формате REST JSON API (Объект).
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - JSON
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION rest.object (
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
  WHEN '/object/class' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric)
      LOOP
        FOR e IN SELECT * FROM Class WHERE id = GetObjectClass(r.id)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric)
      LOOP
        FOR e IN SELECT * FROM Class WHERE id = GetObjectClass(r.id)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/object/type' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.type WHERE id = GetObjectType($1)', JsonbToFields(r.fields, GetColumns('type', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.type WHERE id = GetObjectType($1)', JsonbToFields(r.fields, GetColumns('type', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/object/state' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.state WHERE id = GetObjectState($1)', JsonbToFields(r.fields, GetColumns('state', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.state WHERE id = GetObjectState($1)', JsonbToFields(r.fields, GetColumns('state', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/object/delete/force' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric)
      LOOP
        FOR e IN SELECT * FROM api.object_force_delete(r.id) AS success
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric)
      LOOP
        FOR e IN SELECT * FROM api.object_force_delete(r.id) AS success
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;
    END IF;

  WHEN '/object/file' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'files']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, files json)
      LOOP
        IF r.files IS NOT NULL THEN
          FOR e IN SELECT * FROM api.set_object_files_json(r.id, r.files)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        ELSE
          RETURN NEXT api.get_object_files_json(r.id);
        END IF;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, files json)
      LOOP
        IF r.files IS NOT NULL THEN
          FOR e IN SELECT * FROM api.set_object_files_json(r.id, r.files)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        ELSE
          RETURN NEXT api.get_object_files_json(r.id);
        END IF;
      END LOOP;

    END IF;

  WHEN '/object/file/set' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'files']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, files json)
      LOOP
        FOR e IN SELECT * FROM api.set_object_files_json(r.id, r.files)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, files json)
      LOOP
        FOR e IN SELECT * FROM api.set_object_files_json(r.id, r.files)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/object/file/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'name', 'fields']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, name text, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_object_file($1, $2)', JsonbToFields(r.fields, GetColumns('object_file', 'api'))) USING r.id, r.name
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, name text, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_object_file($1, $2)', JsonbToFields(r.fields, GetColumns('object_file', 'api'))) USING r.id, r.name
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/object/file/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_object_file($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('object_file', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/object/data' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'data']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, data json)
      LOOP
        IF r.data IS NOT NULL THEN
          FOR e IN SELECT * FROM api.set_object_data_json(r.id, r.data)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        ELSE
          RETURN NEXT api.get_object_data_json(r.id);
        END IF;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, data json)
      LOOP
        IF r.data IS NOT NULL THEN
          FOR e IN SELECT * FROM api.set_object_data_json(r.id, r.data)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        ELSE
          RETURN NEXT api.get_object_data_json(r.id);
        END IF;
      END LOOP;

    END IF;

  WHEN '/object/data/set' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'data']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, data json)
      LOOP
        FOR e IN SELECT * FROM api.set_object_data_json(r.id, r.data)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, data json)
      LOOP
        FOR e IN SELECT * FROM api.set_object_data_json(r.id, r.data)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/object/data/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'type', 'typecode', 'code', 'fields']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(fields jsonb, id numeric, type numeric, typecode varchar, code varchar)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_object_data($1, $2, $3)', JsonbToFields(r.fields, GetColumns('object_data', 'api'))) USING r.id, coalesce(r.type, GetObjectDataType(r.typecode)), r.code
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, id numeric, type numeric, typecode varchar, code varchar)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_object_data($1, $2, $3)', JsonbToFields(r.fields, GetColumns('object_data', 'api'))) USING r.id, coalesce(r.type, GetObjectDataType(r.typecode)), r.code
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/object/data/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_object_data($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('object_data', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/object/address' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'addresses']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, addresses json)
      LOOP
        IF r.addresses IS NOT NULL THEN
          FOR e IN SELECT * FROM api.set_object_addresses_json(r.id, r.addresses)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        ELSE
          RETURN NEXT api.get_object_addresses_json(r.id);
        END IF;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, addresses json)
      LOOP
        IF r.addresses IS NOT NULL THEN
          FOR e IN SELECT * FROM api.set_object_addresses_json(r.id, r.addresses)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        ELSE
          RETURN NEXT api.get_object_addresses_json(r.id);
        END IF;
      END LOOP;

    END IF;

  WHEN '/object/address/set' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'address', 'datefrom']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, address numeric, datefrom timestamp)
      LOOP
        FOR e IN SELECT * FROM api.set_object_address(r.id, r.address, coalesce(r.datefrom, oper_date()))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, address numeric, datefrom timestamp)
      LOOP
        FOR e IN SELECT * FROM api.set_object_address(r.id, r.address, coalesce(r.datefrom, oper_date()))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/object/address/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_object_address($1)', JsonbToFields(r.fields, GetColumns('object_address', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_object_address($1)', JsonbToFields(r.fields, GetColumns('object_address', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/object/address/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_object_address($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('object_address', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/object/geolocation' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'coordinates']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, coordinates json)
      LOOP
        IF r.coordinates IS NOT NULL THEN
          FOR e IN SELECT * FROM api.set_object_coordinates_json(r.id, r.coordinates) AS id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        ELSE
          RETURN NEXT api.get_object_coordinates_json(r.id);
        END IF;
      END LOOP;

      ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, coordinates json)
      LOOP
        IF r.coordinates IS NOT NULL THEN
          FOR e IN SELECT * FROM api.set_object_coordinates_json(r.id, r.coordinates) AS id
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        ELSE
          RETURN NEXT api.get_object_coordinates_json(r.id);
        END IF;
      END LOOP;

    END IF;

  WHEN '/object/geolocation/set' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'coordinates']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, coordinates json)
      LOOP
        FOR e IN SELECT * FROM api.set_object_coordinates_json(r.id, r.coordinates) AS id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, coordinates json)
      LOOP
        FOR e IN SELECT * FROM api.set_object_coordinates_json(r.id, r.coordinates) AS id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/object/geolocation/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'code', 'fields']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, code varchar, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_object_coordinates($1, $2)', JsonbToFields(r.fields, GetColumns('object_coordinates', 'api'))) USING r.id, coalesce(r.code, 'default')
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, code varchar, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_object_coordinates($1, $2)', JsonbToFields(r.fields, GetColumns('object_coordinates', 'api'))) USING r.id, coalesce(r.code, 'default')
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/object/geolocation/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_object_coordinates($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('object_coordinates', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
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
