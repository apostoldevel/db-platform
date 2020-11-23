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
  pPath     text,
  pPayload  jsonb DEFAULT null
) RETURNS   SETOF json
AS $$
DECLARE
  nId       numeric;

  r         record;
  e         record;

  nKey      integer;
  arJson    json[];

  arKeys    text[];
  vUserName text;
BEGIN
  IF NULLIF(pPath, '') IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  IF SubStr(pPath, 1, 7) = '/admin/' THEN

    FOR r IN SELECT * FROM rest.admin(pPath, pPayload)
    LOOP
      RETURN NEXT r.admin;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 10) = '/workflow/' THEN

    FOR r IN SELECT * FROM rest.workflow(pPath, pPayload)
    LOOP
      RETURN NEXT r.workflow;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 8) = '/notify/' THEN

    FOR r IN SELECT * FROM rest.notify(pPath, pPayload)
    LOOP
      RETURN NEXT r.notify;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 9) = '/current/' THEN

    FOR r IN SELECT * FROM rest.current(pPath)
    LOOP
      RETURN NEXT r.current;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 9) = '/session/' THEN

    FOR r IN SELECT * FROM rest.session(pPath, pPayload)
    LOOP
      RETURN NEXT r.session;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 7) = '/event/' THEN

    FOR r IN SELECT * FROM rest.event(pPath, pPayload)
    LOOP
      RETURN NEXT r.event;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 10) = '/registry/' THEN

    FOR r IN SELECT * FROM rest.registry(pPath, pPayload)
    LOOP
      RETURN NEXT r.registry;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 14) = '/verification/' THEN

    FOR r IN SELECT * FROM rest.verification(pPath, pPayload)
    LOOP
      RETURN NEXT r.verification;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 8) = '/object/' THEN

    FOR r IN SELECT * FROM rest.object(pPath, pPayload)
    LOOP
      RETURN NEXT r.object;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 9) = '/address/' THEN

    FOR r IN SELECT * FROM rest.address(pPath, pPayload)
    LOOP
      RETURN NEXT r.address;
    END LOOP;
    RETURN;
  END IF;

  IF SubStr(pPath, 1, 8) = '/client/' THEN

    FOR r IN SELECT * FROM rest.client(pPath, pPayload)
    LOOP
      RETURN NEXT r.client;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 9) = '/message/' THEN

    FOR r IN SELECT * FROM rest.message(pPath, pPayload)
    LOOP
      RETURN NEXT r.message;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 6) = '/task/' THEN

    FOR r IN SELECT * FROM rest.task(pPath, pPayload)
    LOOP
      RETURN NEXT r.task;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 7) = '/agent/' THEN

    FOR r IN SELECT * FROM rest.agent(pPath, pPayload)
    LOOP
      RETURN NEXT r.agent;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 10) = '/calendar/' THEN

    FOR r IN SELECT * FROM rest.calendar(pPath, pPayload)
    LOOP
      RETURN NEXT r.calendar;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 9) = '/program/' THEN

    FOR r IN SELECT * FROM rest.program(pPath, pPayload)
    LOOP
      RETURN NEXT r.program;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 11) = '/scheduler/' THEN

    FOR r IN SELECT * FROM rest.scheduler(pPath, pPayload)
    LOOP
      RETURN NEXT r.scheduler;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 8) = '/vendor/' THEN

    FOR r IN SELECT * FROM rest.vendor(pPath, pPayload)
    LOOP
      RETURN NEXT r.vendor;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 9) = '/version/' THEN

    FOR r IN SELECT * FROM rest.version(pPath, pPayload)
    LOOP
      RETURN NEXT r.version;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 5) = '/car/' THEN

    FOR r IN SELECT * FROM rest.car(pPath, pPayload)
    LOOP
      RETURN NEXT r.car;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 6) = '/card/' THEN

    FOR r IN SELECT * FROM rest.card(pPath, pPayload)
    LOOP
      RETURN NEXT r.card;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 14) = '/charge_point/' THEN

    FOR r IN SELECT * FROM rest.charge_point(pPath, pPayload)
    LOOP
      RETURN NEXT r.charge_point;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 11) = '/connector/' THEN

    FOR r IN SELECT * FROM rest.connector(pPath, pPayload)
    LOOP
      RETURN NEXT r.connector;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 10) = '/contract/' THEN

    FOR r IN SELECT * FROM rest.contract(pPath, pPayload)
    LOOP
      RETURN NEXT r.contract;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 9) = '/invoice/' THEN

    FOR r IN SELECT * FROM rest.invoice(pPath, pPayload)
    LOOP
      RETURN NEXT r.invoice;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 7) = '/order/' THEN

    FOR r IN SELECT * FROM rest.order(pPath, pPayload)
    LOOP
      RETURN NEXT r.order;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 5) = '/sla/' THEN

    FOR r IN SELECT * FROM rest.sla(pPath, pPayload)
    LOOP
      RETURN NEXT r.sla;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 13) = '/transaction/' THEN

    FOR r IN SELECT * FROM rest.transaction(pPath, pPayload)
    LOOP
      RETURN NEXT r.transaction;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 10) = '/category/' THEN

    FOR r IN SELECT * FROM rest.category(pPath, pPayload)
    LOOP
      RETURN NEXT r.category;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 9) = '/charger/' THEN

    FOR r IN SELECT * FROM rest.charger(pPath, pPayload)
    LOOP
      RETURN NEXT r.charger;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 9) = '/measure/' THEN

    FOR r IN SELECT * FROM rest.measure(pPath, pPayload)
    LOOP
      RETURN NEXT r.measure;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 6) = '/mode/' THEN

    FOR r IN SELECT * FROM rest.mode(pPath, pPayload)
    LOOP
      RETURN NEXT r.mode;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 7) = '/model/' THEN

    FOR r IN SELECT * FROM rest.model(pPath, pPayload)
    LOOP
      RETURN NEXT r.model;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 9) = '/network/' THEN

    FOR r IN SELECT * FROM rest.network(pPath, pPayload)
    LOOP
      RETURN NEXT r.network;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 9) = '/service/' THEN

    FOR r IN SELECT * FROM rest.service(pPath, pPayload)
    LOOP
      RETURN NEXT r.service;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 8) = '/tariff/' THEN

    FOR r IN SELECT * FROM rest.tariff(pPath, pPayload)
    LOOP
      RETURN NEXT r.tariff;
    END LOOP;

    RETURN;
  END IF;

  IF SubStr(pPath, 1, 6) = '/ocpp/' THEN

    FOR r IN SELECT * FROM rest.ocpp(pPath, pPayload)
    LOOP
      RETURN NEXT r.ocpp;
    END LOOP;

    RETURN;
  END IF;

  CASE lower(pPath)
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
      FOR e IN SELECT * FROM api.authenticate(r.session, r.secret, r.agent, r.host) AS code
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/authorize' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('authorize', 'api', false));
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(session text)
    LOOP
      RETURN NEXT row_to_json(api.authorize(r.session));
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

  WHEN '/api' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    IF current_session() IS NULL THEN
      PERFORM LoginFailed();
    END IF;

    arKeys := array_cat(arKeys, GetRoutines('api', 'rest', false));
    arKeys := array_cat(arKeys, ARRAY['key']);

    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN
      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(key text, path text, payload jsonb)
      LOOP
        FOR e IN SELECT * FROM rest.api(r.path, r.payload)
        LOOP
          arJson := array_append(arJson, (row_to_json(e)->>'api')::json);
        END LOOP;

        RETURN NEXT jsonb_build_object('key', coalesce(r.key, IntToStr(nKey)), 'path', r.path, 'payload', array_to_json(arJson)::jsonb);

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

  WHEN '/action/run' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    IF current_session() IS NULL THEN
      PERFORM LoginFailed();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'action', 'form']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, action numeric, form jsonb)
      LOOP
        FOR e IN SELECT * FROM api.run_action(r.id, r.action, r.form)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, action numeric, form jsonb)
      LOOP
        FOR e IN SELECT * FROM api.run_action(r.id, r.action, r.form)
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

    arKeys := array_cat(arKeys, ARRAY['id', 'method', 'code', 'form']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, method numeric, code text, form jsonb)
      LOOP
        RETURN NEXT api.run_method(r.id, coalesce(r.method, GetObjectMethod(r.id, GetAction(r.code))), r.form);
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, method numeric, code text, form jsonb)
      LOOP
        RETURN NEXT api.run_method(r.id, coalesce(r.method, GetObjectMethod(r.id, GetAction(r.code))), r.form);
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
