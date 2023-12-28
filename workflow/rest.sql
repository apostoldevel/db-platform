--------------------------------------------------------------------------------
-- REST WORKFLOW ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запрос данных в формате REST JSON API (Документооборот).
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - JSON
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION rest.workflow (
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

  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  CASE pPath
  WHEN '/workflow/entity/count' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_entity(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_entity(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/workflow/entity/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_entity($1)', JsonbToFields(r.fields, GetColumns('entity', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_entity($1)', JsonbToFields(r.fields, GetColumns('entity', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/workflow/entity/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_entity($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('entity', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/workflow/type/count' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_type(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_type(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/workflow/type/set' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('set_type', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN EXECUTE format('SELECT row_to_json(api.set_type(%s)) FROM jsonb_to_recordset($1) AS x(%s)', array_to_string(GetRoutines('set_type', 'api', false, 'x'), ', '), array_to_string(GetRoutines('set_type', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    ELSE

      FOR r IN EXECUTE format('SELECT row_to_json(api.set_type(%s)) FROM jsonb_to_record($1) AS x(%s)', array_to_string(GetRoutines('set_type', 'api', false, 'x'), ', '), array_to_string(GetRoutines('set_type', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    END IF;

  WHEN '/workflow/type/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_type($1)', JsonbToFields(r.fields, GetColumns('type', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_type($1)', JsonbToFields(r.fields, GetColumns('type', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/workflow/type/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_type($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('type', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/workflow/type/delete' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid)
      LOOP
        PERFORM api.delete_type(r.id);
        RETURN NEXT json_build_object('id', r.id, 'result', true, 'message', 'Success');
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid)
      LOOP
        PERFORM api.delete_type(r.id);
        RETURN NEXT json_build_object('id', r.id, 'result', true, 'message', 'Success');
      END LOOP;

    END IF;

  WHEN '/workflow/class/count' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_class(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_class(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/workflow/class/set' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('set_class', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN EXECUTE format('SELECT row_to_json(api.set_class(%s)) FROM jsonb_to_recordset($1) AS x(%s)', array_to_string(GetRoutines('set_class', 'api', false, 'x'), ', '), array_to_string(GetRoutines('set_class', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    ELSE

      FOR r IN EXECUTE format('SELECT row_to_json(api.set_class(%s)) FROM jsonb_to_record($1) AS x(%s)', array_to_string(GetRoutines('set_class', 'api', false, 'x'), ', '), array_to_string(GetRoutines('set_class', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    END IF;

  WHEN '/workflow/class/copy' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['source', 'destination']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(source uuid, destination uuid)
      LOOP
        PERFORM api.copy_class(r.source, r.destination);
        RETURN NEXT json_build_object('source', r.source, 'destination', r.destination, 'result', true, 'message', 'Success');
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(source uuid, destination uuid)
      LOOP
        PERFORM api.copy_class(r.source, r.destination);
        RETURN NEXT json_build_object('source', r.source, 'destination', r.destination, 'result', true, 'message', 'Success');
      END LOOP;

    END IF;

  WHEN '/workflow/class/clone' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('clone_class', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN EXECUTE format('SELECT row_to_json(api.clone_class(%s)) FROM jsonb_to_recordset($1) AS x(%s)', array_to_string(GetRoutines('clone_class', 'api', false, 'x'), ', '), array_to_string(GetRoutines('clone_class', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    ELSE

      FOR r IN EXECUTE format('SELECT row_to_json(api.clone_class(%s)) FROM jsonb_to_record($1) AS x(%s)', array_to_string(GetRoutines('clone_class', 'api', false, 'x'), ', '), array_to_string(GetRoutines('clone_class', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    END IF;

  WHEN '/workflow/class/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_class($1)', JsonbToFields(r.fields, GetColumns('class', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_class($1)', JsonbToFields(r.fields, GetColumns('class', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/workflow/class/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_class($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('class', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/workflow/class/delete' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid)
      LOOP
        PERFORM api.delete_class(r.id);
        RETURN NEXT json_build_object('id', r.id, 'result', true, 'message', 'Success');
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid)
      LOOP
        PERFORM api.delete_class(r.id);
        RETURN NEXT json_build_object('id', r.id, 'result', true, 'message', 'Success');
      END LOOP;

    END IF;

  WHEN '/workflow/class/access' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'code']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, code text)
    LOOP
      FOR e IN SELECT * FROM api.class_access(coalesce(r.id, GetClass(r.code)))
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/workflow/class/access/set' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'mask', 'userid', 'recursive', 'objectset']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid, mask int, userid uuid, recursive bool, objectset bool)
      LOOP
        PERFORM api.chmodc(r.id, r.mask, r.userid, r.recursive, r.objectset);
        RETURN NEXT row_to_json(r);
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, mask int, userid uuid, recursive bool, objectset bool)
      LOOP
        PERFORM api.chmodc(r.id, r.mask, r.userid, r.recursive, r.objectset);
        RETURN NEXT row_to_json(r);
      END LOOP;

    END IF;

  WHEN '/workflow/class/access/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_class_access($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('class_access', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/workflow/class/access/decode' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'code', 'userid']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid, code text, userid uuid)
      LOOP
        FOR e IN SELECT * FROM api.decode_class_access(coalesce(r.id, GetClass(r.code)), coalesce(r.userid, current_userid()))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, code text, userid uuid)
      LOOP
        FOR e IN SELECT * FROM api.decode_class_access(coalesce(r.id, GetClass(r.code)), coalesce(r.userid, current_userid()))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/workflow/state/type' THEN

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.state_type', JsonbToFields(r.fields, GetColumns('state_type', 'api')))
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/workflow/state/count' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_state(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_state(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/workflow/state/set' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('set_state', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN EXECUTE format('SELECT row_to_json(api.set_state(%s)) FROM jsonb_to_recordset($1) AS x(%s)', array_to_string(GetRoutines('set_state', 'api', false, 'x'), ', '), array_to_string(GetRoutines('set_state', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    ELSE

      FOR r IN EXECUTE format('SELECT row_to_json(api.set_state(%s)) FROM jsonb_to_record($1) AS x(%s)', array_to_string(GetRoutines('set_state', 'api', false, 'x'), ', '), array_to_string(GetRoutines('set_state', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    END IF;

  WHEN '/workflow/state/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_state($1)', JsonbToFields(r.fields, GetColumns('state', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_state($1)', JsonbToFields(r.fields, GetColumns('state', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/workflow/state/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_state($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('state', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/workflow/state/delete' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid)
      LOOP
        PERFORM api.delete_state(r.id);
        RETURN NEXT json_build_object('id', r.id, 'result', true, 'message', 'Success');
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid)
      LOOP
        PERFORM api.delete_state(r.id);
        RETURN NEXT json_build_object('id', r.id, 'result', true, 'message', 'Success');
      END LOOP;

    END IF;

  WHEN '/workflow/action/count' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_action(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_action(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/workflow/action/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_action($1)', JsonbToFields(r.fields, GetColumns('action', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_action($1)', JsonbToFields(r.fields, GetColumns('action', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/workflow/action/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_action($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('action', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/workflow/method/count' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_method(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_method(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/workflow/method/set' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('set_method', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN EXECUTE format('SELECT row_to_json(api.set_method(%s)) FROM jsonb_to_recordset($1) AS x(%s)', array_to_string(GetRoutines('set_method', 'api', false, 'x'), ', '), array_to_string(GetRoutines('set_method', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    ELSE

      FOR r IN EXECUTE format('SELECT row_to_json(api.set_method(%s)) FROM jsonb_to_record($1) AS x(%s)', array_to_string(GetRoutines('set_method', 'api', false, 'x'), ', '), array_to_string(GetRoutines('set_method', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    END IF;

  WHEN '/workflow/method/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_method($1)', JsonbToFields(r.fields, GetColumns('method', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_method($1)', JsonbToFields(r.fields, GetColumns('method', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/workflow/method/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_method($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('method', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/workflow/method/delete' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid)
      LOOP
        PERFORM api.delete_method(r.id);
        RETURN NEXT json_build_object('id', r.id, 'result', true, 'message', 'Success');
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid)
      LOOP
        PERFORM api.delete_method(r.id);
        RETURN NEXT json_build_object('id', r.id, 'result', true, 'message', 'Success');
      END LOOP;

    END IF;

  WHEN '/workflow/method/access' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid)
    LOOP
      FOR e IN SELECT * FROM api.method_access(r.id)
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/workflow/method/access/set' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'mask', 'userid']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid, mask int, userid uuid)
      LOOP
        PERFORM api.chmodm(r.id, r.mask, r.userid);
        RETURN NEXT row_to_json(r);
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, mask int, userid uuid)
      LOOP
        PERFORM api.chmodm(r.id, r.mask, r.userid);
        RETURN NEXT row_to_json(r);
      END LOOP;

    END IF;

  WHEN '/workflow/method/access/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_method_access($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('method_access', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/workflow/method/access/decode' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('decode_method_access', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN EXECUTE format('SELECT row_to_json(api.decode_method_access(%s)) FROM jsonb_to_recordset($1) AS x(%s)', array_to_string(GetRoutines('decode_method_access', 'api', false, 'x'), ', '), array_to_string(GetRoutines('decode_method_access', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    ELSE

      FOR r IN EXECUTE format('SELECT row_to_json(api.decode_method_access(%s)) FROM jsonb_to_record($1) AS x(%s)', array_to_string(GetRoutines('decode_method_access', 'api', false, 'x'), ', '), array_to_string(GetRoutines('decode_method_access', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    END IF;

  WHEN '/workflow/transition/count' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_transition(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_transition(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/workflow/transition/set' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('set_transition', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN EXECUTE format('SELECT row_to_json(api.set_transition(%s)) FROM jsonb_to_recordset($1) AS x(%s)', array_to_string(GetRoutines('set_transition', 'api', false, 'x'), ', '), array_to_string(GetRoutines('set_transition', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    ELSE

      FOR r IN EXECUTE format('SELECT row_to_json(api.set_transition(%s)) FROM jsonb_to_record($1) AS x(%s)', array_to_string(GetRoutines('set_transition', 'api', false, 'x'), ', '), array_to_string(GetRoutines('set_transition', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    END IF;

  WHEN '/workflow/transition/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_transition($1)', JsonbToFields(r.fields, GetColumns('transition', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_transition($1)', JsonbToFields(r.fields, GetColumns('transition', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/workflow/transition/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_transition($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('transition', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/workflow/transition/delete' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid)
      LOOP
        PERFORM api.delete_transition(r.id);
        RETURN NEXT json_build_object('id', r.id, 'result', true, 'message', 'Success');
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid)
      LOOP
        PERFORM api.delete_transition(r.id);
        RETURN NEXT json_build_object('id', r.id, 'result', true, 'message', 'Success');
      END LOOP;

    END IF;

  WHEN '/workflow/event/type' THEN

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.event_type', JsonbToFields(r.fields, GetColumns('event_type', 'api')))
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/workflow/event/count' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_event(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_event(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/workflow/event/set' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('set_event', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN EXECUTE format('SELECT row_to_json(api.set_event(%s)) FROM jsonb_to_recordset($1) AS x(%s)', array_to_string(GetRoutines('set_event', 'api', false, 'x'), ', '), array_to_string(GetRoutines('set_event', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    ELSE

      FOR r IN EXECUTE format('SELECT row_to_json(api.set_event(%s)) FROM jsonb_to_record($1) AS x(%s)', array_to_string(GetRoutines('set_event', 'api', false, 'x'), ', '), array_to_string(GetRoutines('set_event', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    END IF;

  WHEN '/workflow/event/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_event($1)', JsonbToFields(r.fields, GetColumns('event', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_event($1)', JsonbToFields(r.fields, GetColumns('event', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/workflow/event/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_event($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('event', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/workflow/event/delete' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid)
      LOOP
        PERFORM api.delete_event(r.id);
        RETURN NEXT json_build_object('id', r.id, 'result', true, 'message', 'Success');
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid)
      LOOP
        PERFORM api.delete_event(r.id);
        RETURN NEXT json_build_object('id', r.id, 'result', true, 'message', 'Success');
      END LOOP;

    END IF;

  WHEN '/workflow/priority/count' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_priority(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_priority(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/workflow/priority/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_priority($1)', JsonbToFields(r.fields, GetColumns('priority', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_priority($1)', JsonbToFields(r.fields, GetColumns('priority', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/workflow/priority/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_priority($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('priority', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
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
