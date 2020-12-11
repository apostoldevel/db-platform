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

  IF current_session() IS NULL THEN
	PERFORM LoginFailed();
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

  WHEN '/object/method' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric)
      LOOP
        FOR e IN SELECT r.id, api.get_methods(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_object(r.id)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric)
      LOOP
        FOR e IN SELECT r.id, api.get_methods(GetObjectClass(r.id), GetObjectState(r.id)) as method FROM api.get_object(r.id)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/object/method/execute' THEN

    IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
    END IF;

    IF current_session() IS NULL THEN
      PERFORM LoginFailed();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'method', 'code', 'params']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, method numeric, code text, params jsonb)
      LOOP
        RETURN NEXT api.execute_method(r.id, coalesce(r.method, GetObjectMethod(r.id, GetAction(r.code))), r.params);
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, method numeric, code text, params jsonb)
      LOOP
        RETURN NEXT api.execute_method(r.id, coalesce(r.method, GetObjectMethod(r.id, GetAction(r.code))), r.params);
      END LOOP;

    END IF;

  WHEN '/object/action/execute' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    IF current_session() IS NULL THEN
      PERFORM LoginFailed();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'action', 'code', 'params']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, action numeric, code text, params jsonb)
      LOOP
        FOR e IN SELECT * FROM api.execute_object_action(r.id, coalesce(r.action, GetAction(r.code)), r.params)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, action numeric, code text, params jsonb)
      LOOP
        FOR e IN SELECT * FROM api.execute_object_action(r.id, coalesce(r.action, GetAction(r.code)), r.params)
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

  WHEN '/object/access' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric)
    LOOP
      FOR e IN SELECT * FROM api.object_access(r.id)
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/object/access/set' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'mask', 'userid']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, mask int, userid numeric)
      LOOP
        PERFORM api.chmodo(r.id, r.mask, r.userid);
        RETURN NEXT row_to_json(r);
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, mask int, userid numeric)
      LOOP
        PERFORM api.chmodo(r.id, r.mask, r.userid);
        RETURN NEXT row_to_json(r);
      END LOOP;

    END IF;

  WHEN '/object/access/decode' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('decode_object_access', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN EXECUTE format('SELECT row_to_json(api.decode_object_access(%s)) FROM jsonb_to_recordset($1) AS x(%s)', array_to_string(GetRoutines('decode_object_access', 'api', false, 'x'), ', '), array_to_string(GetRoutines('decode_object_access', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    ELSE

      FOR r IN EXECUTE format('SELECT row_to_json(api.decode_object_access(%s)) FROM jsonb_to_record($1) AS x(%s)', array_to_string(GetRoutines('decode_object_access', 'api', false, 'x'), ', '), array_to_string(GetRoutines('decode_object_access', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    END IF;

  WHEN '/object/group/count' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_object_group(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_object_group(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/object/group/set' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('set_object_group', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN EXECUTE format('SELECT row_to_json(api.set_object_group(%s)) FROM jsonb_to_recordset($1) AS x(%s)', array_to_string(GetRoutines('set_object_group', 'api', false, 'x'), ', '), array_to_string(GetRoutines('set_object_group', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    ELSE

      FOR r IN EXECUTE format('SELECT row_to_json(api.set_object_group(%s)) FROM jsonb_to_record($1) AS x(%s)', array_to_string(GetRoutines('set_object_group', 'api', false, 'x'), ', '), array_to_string(GetRoutines('set_object_group', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    END IF;

  WHEN '/object/group/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'code', 'fields']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, code varchar, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_object_group($1)', JsonbToFields(r.fields, GetColumns('object_group', 'api'))) USING coalesce(r.id, GetObjectGroup(r.code))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, code varchar, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_object_group($1)', JsonbToFields(r.fields, GetColumns('object_group', 'api'))) USING coalesce(r.id, GetObjectGroup(r.code))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/object/group/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_object_group($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('object_group', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/object/group/member' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'code']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, code varchar)
    LOOP
      FOR e IN SELECT * FROM api.object_group_member(coalesce(r.id, GetObjectGroup(r.code)))
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/object/group/member/add' THEN -- Добавляет объект в группу

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'code', 'object']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, code varchar, object numeric)
      LOOP
        PERFORM api.add_object_to_group(coalesce(r.id, GetObjectGroup(r.code)), r.object);
        RETURN NEXT row_to_json(r);
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, code varchar, object numeric)
      LOOP
        PERFORM api.add_object_to_group(coalesce(r.id, GetObjectGroup(r.code)), r.object);
        RETURN NEXT row_to_json(r);
      END LOOP;

    END IF;

  WHEN '/object/group/member/delete' THEN -- Удалить объект из группы

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'code', 'object']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, code varchar, object numeric)
      LOOP
        PERFORM api.delete_object_from_group(coalesce(r.id, GetObjectGroup(r.code)), r.object);
        RETURN NEXT row_to_json(r);
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, code varchar, object numeric)
      LOOP
        PERFORM api.delete_object_from_group(coalesce(r.id, GetObjectGroup(r.code)), r.object);
        RETURN NEXT row_to_json(r);
      END LOOP;

    END IF;

  WHEN '/object/file' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'clear', 'files']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, clear boolean, files json)
      LOOP
		IF coalesce(r.clear, false) THEN
	  	  PERFORM api.clear_object_files(r.id);
		END IF;

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

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, clear boolean, files json)
      LOOP
		IF coalesce(r.clear, false) THEN
	  	  PERFORM api.clear_object_files(r.id);
		END IF;

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

    arKeys := array_cat(arKeys, ARRAY['id', 'clear', 'files']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, clear boolean, files json)
      LOOP
		IF coalesce(r.clear, false) THEN
	  	  PERFORM api.clear_object_files(r.id);
		END IF;

        FOR e IN SELECT * FROM api.set_object_files_json(r.id, r.files)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, clear boolean, files json)
      LOOP
		IF coalesce(r.clear, false) THEN
	  	  PERFORM api.clear_object_files(r.id);
		END IF;

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

  WHEN '/object/file/clear' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric)
      LOOP
        PERFORM api.clear_object_files(r.id);
        RETURN NEXT row_to_json(r);
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric)
      LOOP
        PERFORM api.clear_object_files(r.id);
        RETURN NEXT row_to_json(r);
      END LOOP;

    END IF;

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
