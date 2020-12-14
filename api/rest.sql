--------------------------------------------------------------------------------
-- REST API --------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запрос данных в формате REST JSON API.
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - Данные
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION rest.api (
  pPath     	text,
  pPayload  	jsonb DEFAULT null
) RETURNS   	SETOF json
AS $$
DECLARE
  nId       	numeric;

  r         	record;
  e         	record;

  nKey      	integer;
  arJson    	json[];

  arKeys    	text[];
  vUserName 	text;
BEGIN
  IF NULLIF(pPath, '') IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  CASE lower(pPath)
  WHEN '/ping' THEN

	RETURN NEXT json_build_object();

  WHEN '/time' THEN

	RETURN NEXT json_build_object('serverTime', trunc(extract(EPOCH FROM Now())));

  WHEN '/sign/in' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('signin', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF pPayload ? 'phone' THEN
      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(phone text, password text, agent text, host inet)
      LOOP
        SELECT username INTO vUserName FROM db.user WHERE type = 'U' AND phone = r.phone;
        RETURN NEXT row_to_json(api.signin(vUserName, NULLIF(r.password, ''), NULLIF(r.agent, ''), r.host));
      END LOOP;
    ELSIF pPayload ? 'email' THEN
      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(email text, password text, agent text, host inet)
      LOOP
        SELECT username INTO vUserName FROM db.user WHERE type = 'U' AND email = r.email;
        RETURN NEXT row_to_json(api.signin(vUserName, NULLIF(r.password, ''), NULLIF(r.agent, ''), r.host));
      END LOOP;
    ELSE
      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(username text, password text, agent text, host inet)
      LOOP
        RETURN NEXT row_to_json(api.signin(NULLIF(r.username, ''), NULLIF(r.password, ''), NULLIF(r.agent, ''), r.host));
      END LOOP;
    END IF;

  WHEN '/sign/up' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('signup', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(type varchar, username text, password text, name jsonb, phone text, email text, info jsonb, description text)
    LOOP
      FOR r IN EXECUTE format('SELECT row_to_json(api.signup(%s)) FROM jsonb_to_record($1) AS x(%s)', array_to_string(GetRoutines('signup', 'api', false, 'x'), ', '), array_to_string(GetRoutines('signup', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;
    END LOOP;

  WHEN '/sign/out' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, GetRoutines('signout', 'api', false));
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    IF current_session() IS NULL THEN
      PERFORM LoginFailed();
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(session text, close_all boolean)
    LOOP
      FOR e IN SELECT * FROM api.signout(coalesce(r.session, current_session()), r.close_all) AS success
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/authenticate' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('authenticate', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(session text, secret text, agent text, host inet)
    LOOP
      RETURN NEXT row_to_json(api.authenticate(r.session, r.secret, r.agent, r.host));
    END LOOP;

  WHEN '/authorize' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('authorize', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(session text, agent text, host inet)
    LOOP
      RETURN NEXT row_to_json(api.authorize(r.session, r.agent, r.host));
    END LOOP;

  WHEN '/su' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    IF current_session() IS NULL THEN
      PERFORM LoginFailed();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('su', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(username text, password text)
    LOOP
      FOR e IN SELECT * FROM api.su(r.username, r.password) AS success
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/whoami' THEN

    IF current_session() IS NULL THEN
      PERFORM LoginFailed();
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.whoami', JsonbToFields(r.fields, GetColumns('whoami', 'api')))
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/run' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    IF current_session() IS NULL THEN
      PERFORM LoginFailed();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('run', 'api', false));
    arKeys := array_cat(arKeys, ARRAY['key']);

    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN
      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(key text, method text, path text, payload jsonb)
      LOOP
        FOR e IN SELECT * FROM api.run(coalesce(r.method, 'POST'), r.path, r.payload)
        LOOP
          arJson := array_append(arJson, (row_to_json(e)->>'run')::json);
        END LOOP;

        RETURN NEXT jsonb_build_object('key', coalesce(r.key, IntToStr(nKey)), 'method', coalesce(r.method, 'POST'), 'path', r.path, 'payload', array_to_json(arJson)::jsonb);

        arJson := null;
        nKey := nKey + 1;
      END LOOP;

    ELSE

      PERFORM IncorrectJsonType(jsonb_typeof(pPayload), 'array');

    END IF;

  WHEN '/locale' THEN

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.locale', JsonbToFields(r.fields, GetColumns('locale', 'api')))
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/entity' THEN

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.entity', JsonbToFields(r.fields, GetColumns('entity', 'api')))
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/type' THEN

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.type', JsonbToFields(r.fields, GetColumns('type', 'api')))
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/class' THEN

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.class', JsonbToFields(r.fields, GetColumns('class', 'api')))
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/state/type' THEN

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.state_type', JsonbToFields(r.fields, GetColumns('state_type', 'api')))
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/state' THEN

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.state', JsonbToFields(r.fields, GetColumns('state', 'api')))
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/state/class' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['fields', 'class', 'code']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(fields jsonb, class numeric, code varchar)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.state($1)', JsonbToFields(r.fields, GetColumns('state', 'api'))) USING coalesce(r.class, GetClass(r.code))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, class numeric, code varchar)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.state($1)', JsonbToFields(r.fields, GetColumns('state', 'api'))) USING coalesce(r.class, GetClass(r.code))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/action' THEN

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.action', JsonbToFields(r.fields, GetColumns('action', 'api')))
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/action/execute' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    IF current_session() IS NULL THEN
      PERFORM LoginFailed();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['object', 'action', 'code', 'params']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(object numeric, action numeric, code text, params jsonb)
      LOOP
        FOR e IN SELECT * FROM api.execute_object_action(r.object, coalesce(r.action, GetAction(r.code)), r.params)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(object numeric, action numeric, code text, params jsonb)
      LOOP
        FOR e IN SELECT * FROM api.execute_object_action(r.object, coalesce(r.action, GetAction(r.code)), r.params)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/method' THEN

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.method', JsonbToFields(r.fields, GetColumns('method', 'api')))
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/method/run' THEN

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

  WHEN '/method/execute' THEN

    IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
    END IF;

    IF current_session() IS NULL THEN
      PERFORM LoginFailed();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['object', 'method', 'code', 'params']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(object numeric, method numeric, code text, params jsonb)
      LOOP
        RETURN NEXT api.execute_method(r.object, coalesce(r.method, GetObjectMethod(r.object, GetAction(r.code))), r.params);
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(object numeric, method numeric, code text, params jsonb)
      LOOP
        RETURN NEXT api.execute_method(r.object, coalesce(r.method, GetObjectMethod(r.object, GetAction(r.code))), r.params);
      END LOOP;

    END IF;

  WHEN '/method/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('get_method', 'api', false));
    arKeys := array_cat(arKeys, ARRAY['classcode', 'statecode', 'actioncode']);

    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(object numeric, class numeric, classcode varchar, state numeric, statecode varchar, action numeric, actioncode varchar)
    LOOP
      nId := coalesce(r.class, GetClass(r.classcode), GetObjectClass(r.object));
      FOR e IN SELECT * FROM api.get_methods(nId, coalesce(r.state, GetState(nId, r.statecode), GetObjectState(r.object)), coalesce(r.action, GetAction(r.actioncode)))
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/method/list' THEN

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

  WHEN '/member/area' THEN

    FOR r IN SELECT * FROM api.member_area(current_userid())
    LOOP
      RETURN NEXT row_to_json(r);
    END LOOP;

  WHEN '/member/interface' THEN

    FOR r IN SELECT * FROM api.member_interface(current_userid())
    LOOP
      RETURN NEXT row_to_json(r);
    END LOOP;

  WHEN '/user/set' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('set_user', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN EXECUTE format('SELECT row_to_json(api.set_user(%s)) FROM jsonb_to_recordset($1) AS x(%s)', array_to_string(GetRoutines('set_user', 'api', false, 'x'), ', '), array_to_string(GetRoutines('set_user', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    ELSE

      FOR r IN EXECUTE format('SELECT row_to_json(api.set_user(%s)) FROM jsonb_to_record($1) AS x(%s)', array_to_string(GetRoutines('set_user', 'api', false, 'x'), ', '), array_to_string(GetRoutines('set_user', 'api', true), ', ')) USING pPayload
      LOOP
        RETURN NEXT r;
      END LOOP;

    END IF;

  WHEN '/user/password' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'username', 'oldpass', 'newpass']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, username varchar, oldpass text, newpass text)
      LOOP
        FOR e IN SELECT true AS success FROM api.change_password(coalesce(r.id, GetUser(r.username)), r.oldpass, r.newpass)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, username varchar, oldpass text, newpass text)
      LOOP
        FOR e IN SELECT true AS success FROM api.change_password(coalesce(r.id, GetUser(r.username)), r.oldpass, r.newpass)
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
