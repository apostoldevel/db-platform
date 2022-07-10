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
  r         	record;
  e         	record;

  nKey      	integer;
  arJson    	json[];

  arKeys    	text[];
BEGIN
  IF NULLIF(pPath, '') IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  CASE lower(pPath)
  WHEN '/ping' THEN

	RETURN NEXT json_build_object('error', json_build_object('code', 200, 'message', 'OK'));

  WHEN '/time' THEN

	RETURN NEXT json_build_object('serverTime', trunc(extract(EPOCH FROM Now())));

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
      FOR e IN SELECT true AS success FROM api.su(r.username, r.password)
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/search' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    IF current_session() IS NULL THEN
      PERFORM LoginFailed();
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(text text, entities jsonb, fields jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.search($1, $2)', JsonbToFields(r.fields, GetColumns('search', 'api'))) USING r.text, r.entities
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

  WHEN '/locale/set' THEN

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

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, parent uuid, parentcode text)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.class($1)', JsonbToFields(r.fields, GetColumns('class', 'api'))) USING coalesce(r.parent, GetClass(r.parentcode))
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/priority' THEN

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.priority', JsonbToFields(r.fields, GetColumns('priority', 'api')))
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

--------------------------------------------------------------------------------
-- REST API (sign) -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запрос данных в формате REST JSON API (sign).
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - Данные
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION rest.sign (
  pPath     	text,
  pPayload  	jsonb DEFAULT null
) RETURNS   	SETOF json
AS $$
DECLARE
  r         	record;
  e         	record;

  arKeys    	text[];
BEGIN
  IF NULLIF(pPath, '') IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  CASE lower(pPath)
  WHEN '/sign/in' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('signin', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(username text, password text, agent text, host inet)
	LOOP
	  RETURN NEXT row_to_json(api.signin(NULLIF(r.username, ''), NULLIF(r.password, ''), NULLIF(r.agent, ''), r.host));
	END LOOP;

  WHEN '/sign/up' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('signup', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	FOR r IN EXECUTE format('SELECT row_to_json(api.signup(%s)) FROM jsonb_to_record($1) AS x(%s)', array_to_string(GetRoutines('signup', 'api', false, 'x'), ', '), array_to_string(GetRoutines('signup', 'api', true), ', ')) USING pPayload
	LOOP
	  RETURN NEXT r;
	END LOOP;

  WHEN '/sign/out' THEN

    IF current_session() IS NULL THEN
      PERFORM LoginFailed();
    END IF;

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, GetRoutines('signout', 'api', false));
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(session text, close_all boolean)
    LOOP
      FOR e IN SELECT *, GetErrorMessage() AS message FROM api.signout(coalesce(r.session, current_session()), r.close_all) AS success
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

--------------------------------------------------------------------------------
-- REST API (user) -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запрос данных в формате REST JSON API (user).
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - Данные
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION rest.user (
  pPath     	text,
  pPayload  	jsonb DEFAULT null
) RETURNS   	SETOF json
AS $$
DECLARE
  r         	record;
  e         	record;

  arKeys    	text[];
BEGIN
  IF NULLIF(pPath, '') IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  IF current_session() IS NULL THEN
	PERFORM LoginFailed();
  END IF;

  CASE lower(pPath)
  WHEN '/user/count' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_user(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
      LOOP
        FOR e IN SELECT count(*) FROM api.list_user(r.search, r.filter, r.reclimit, r.recoffset, r.orderby)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/user/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'fields']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_user($1)', JsonbToFields(r.fields, GetColumns('user', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, fields jsonb)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.get_user($1)', JsonbToFields(r.fields, GetColumns('user', 'api'))) USING r.id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/user/set' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['username', 'password', 'name', 'phone', 'email', 'description']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(username text, password text, name text, phone text, email text, description text)
	  LOOP
		FOR e IN SELECT * FROM api.set_user(current_userid(), r.username, r.password, r.name, r.phone, r.email, r.description)
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

    ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(username text, password text, name text, phone text, email text, description text)
	  LOOP
		FOR e IN SELECT * FROM api.set_user(current_userid(), r.username, r.password, r.name, r.phone, r.email, r.description)
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

    END IF;

  WHEN '/user/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_user($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('user', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/user/profile' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['id', 'code', 'fields']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, code text, fields jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.profile($1)', JsonbToFields(r.fields, GetColumns('user', 'api'))) USING coalesce(r.id, GetClient(r.code), GetClientByUserId(current_userid()))
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/user/profile/set' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['familyname', 'givenname', 'patronymicname', 'locale', 'area', 'interface', 'picture']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

	  FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(familyname text, givenname text, patronymicname text, locale text, area text, interface text, picture text)
	  LOOP
		FOR e IN SELECT * FROM api.set_user_profile(current_userid(), r.familyname, r.givenname, r.patronymicname, r.locale, r.area, r.interface, r.picture)
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

    ELSE

	  FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(familyname text, givenname text, patronymicname text, locale text, area text, interface text, picture text)
	  LOOP
		FOR e IN SELECT * FROM api.set_user_profile(current_userid(), r.familyname, r.givenname, r.patronymicname, r.locale, r.area, r.interface, r.picture)
		LOOP
		  RETURN NEXT row_to_json(e);
		END LOOP;
	  END LOOP;

    END IF;

  WHEN '/user/password' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['oldpass', 'newpass']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(oldpass text, newpass text)
	LOOP
	  FOR e IN SELECT true AS success FROM api.change_password(current_userid(), r.oldpass, r.newpass)
	  LOOP
		RETURN NEXT row_to_json(e);
	  END LOOP;
	END LOOP;

  WHEN '/user/password/recovery' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['identifier']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(identifier text)
	LOOP
	  RETURN NEXT json_build_object('ticket', api.recovery_password(r.identifier));
	END LOOP;

  WHEN '/user/security/answer' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['ticket', 'securityanswer']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(ticket uuid, securityanswer text)
	LOOP
	  FOR e IN SELECT * FROM api.check_recovery_ticket(r.ticket, r.securityanswer)
	  LOOP
		RETURN NEXT row_to_json(e);
	  END LOOP;
	END LOOP;

  WHEN '/user/password/reset' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['ticket', 'securityanswer', 'password']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(ticket uuid, securityanswer text, password text)
	LOOP
	  FOR e IN SELECT * FROM api.reset_password(r.ticket, r.securityanswer, r.password)
	  LOOP
		RETURN NEXT row_to_json(e);
	  END LOOP;
	END LOOP;

  WHEN '/user/registration/code' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['phone']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(phone text)
	LOOP
	  RETURN NEXT json_build_object('ticket', api.registration_code(r.phone));
	END LOOP;

  WHEN '/user/registration/check' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['ticket', 'code']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

	FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(ticket uuid, code text)
	LOOP
	  FOR e IN SELECT * FROM api.check_registration_code(r.ticket, r.code)
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

--------------------------------------------------------------------------------
-- REST API (state) ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запрос данных в формате REST JSON API (state).
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - Данные
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION rest.state (
  pPath     	text,
  pPayload  	jsonb DEFAULT null
) RETURNS   	SETOF json
AS $$
DECLARE
  r         	record;
  e         	record;

  arKeys    	text[];
BEGIN
  IF NULLIF(pPath, '') IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  IF current_session() IS NULL THEN
	PERFORM LoginFailed();
  END IF;

  CASE lower(pPath)
  WHEN '/state' THEN

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.state', JsonbToFields(r.fields, GetColumns('state', 'api')))
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

  WHEN '/state/class' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['fields', 'class', 'code']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(fields jsonb, class uuid, code text)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.state($1)', JsonbToFields(r.fields, GetColumns('state', 'api'))) USING coalesce(r.class, GetClass(r.code))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, class uuid, code text)
      LOOP
        FOR e IN EXECUTE format('SELECT %s FROM api.state($1)', JsonbToFields(r.fields, GetColumns('state', 'api'))) USING coalesce(r.class, GetClass(r.code))
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/state/by/type' THEN

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(type uuid, fields jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.state_by_type($1)', JsonbToFields(r.fields, GetColumns('state_by_type', 'api'))) USING r.type
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

--------------------------------------------------------------------------------
-- REST API (action) -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запрос данных в формате REST JSON API (action).
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - Данные
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION rest.action (
  pPath     	text,
  pPayload  	jsonb DEFAULT null
) RETURNS   	SETOF json
AS $$
DECLARE
  r         	record;
  e         	record;

  arKeys    	text[];
BEGIN
  IF NULLIF(pPath, '') IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  IF current_session() IS NULL THEN
	PERFORM LoginFailed();
  END IF;

  CASE lower(pPath)
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

    arKeys := array_cat(arKeys, ARRAY['object', 'action', 'code', 'params']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(object uuid, action uuid, code text, params jsonb)
      LOOP
        FOR e IN SELECT * FROM api.execute_object_action(r.object, coalesce(r.action, GetAction(r.code)), r.params)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(object uuid, action uuid, code text, params jsonb)
      LOOP
        FOR e IN SELECT * FROM api.execute_object_action(r.object, coalesce(r.action, GetAction(r.code)), r.params)
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

--------------------------------------------------------------------------------
-- REST API (method) -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запрос данных в формате REST JSON API (method).
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - Данные
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION rest.method (
  pPath     	text,
  pPayload  	jsonb DEFAULT null
) RETURNS   	SETOF json
AS $$
DECLARE
  uId       	uuid;

  r         	record;
  e         	record;

  arKeys    	text[];
BEGIN
  IF NULLIF(pPath, '') IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  IF current_session() IS NULL THEN
	PERFORM LoginFailed();
  END IF;

  CASE lower(pPath)
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

    arKeys := array_cat(arKeys, ARRAY['id', 'method', 'code', 'params']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id uuid, method uuid, code text, params jsonb)
      LOOP
        RETURN NEXT api.execute_method(r.id, coalesce(r.method, GetObjectMethod(r.id, GetAction(r.code))), r.params);
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id uuid, method uuid, code text, params jsonb)
      LOOP
        RETURN NEXT api.execute_method(r.id, coalesce(r.method, GetObjectMethod(r.id, GetAction(r.code))), r.params);
      END LOOP;

    END IF;

  WHEN '/method/execute' THEN

    IF pPayload IS NULL THEN
	  PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['object', 'method', 'code', 'params']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(object uuid, method uuid, code text, params jsonb)
      LOOP
        RETURN NEXT api.execute_method(r.object, coalesce(r.method, GetObjectMethod(r.object, GetAction(r.code))), r.params);
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(object uuid, method uuid, code text, params jsonb)
      LOOP
        RETURN NEXT api.execute_method(r.object, coalesce(r.method, GetObjectMethod(r.object, GetAction(r.code))), r.params);
      END LOOP;

    END IF;

  WHEN '/method/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('get_methods', 'api', false));
    arKeys := array_cat(arKeys, ARRAY['classcode', 'statecode', 'actioncode']);

    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(object uuid, class uuid, classcode text, state uuid, statecode text, action uuid, actioncode text)
    LOOP
      uId := coalesce(r.class, GetClass(r.classcode), GetObjectClass(r.object));
      FOR e IN SELECT * FROM api.get_methods(uId, coalesce(r.state, GetState(uId, r.statecode), GetObjectState(r.object)), coalesce(r.action, GetAction(r.actioncode)))
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

  ELSE
    PERFORM RouteNotFound(pPath);
  END CASE;

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- REST API (member) -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запрос данных в формате REST JSON API (member).
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - Данные
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION rest.member (
  pPath     	text,
  pPayload  	jsonb DEFAULT null
) RETURNS   	SETOF json
AS $$
DECLARE
  r         	record;
BEGIN
  IF NULLIF(pPath, '') IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  IF current_session() IS NULL THEN
	PERFORM LoginFailed();
  END IF;

  CASE lower(pPath)
  WHEN '/member/group' THEN -- Группы пользователя

	FOR r IN SELECT * FROM api.member_group(current_userid())
	LOOP
	  RETURN NEXT row_to_json(r);
	END LOOP;

  WHEN '/member/area' THEN -- Зоны пользователя

    FOR r IN SELECT * FROM api.member_area(current_userid())
    LOOP
      RETURN NEXT row_to_json(r);
    END LOOP;

  WHEN '/member/interface' THEN -- Интерфейсы пользователя

    FOR r IN SELECT * FROM api.member_interface(current_userid())
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
