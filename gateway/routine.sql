--------------------------------------------------------------------------------
-- GATEWAY ROUTINES ------------------------------------------------------------
--------------------------------------------------------------------------------
-- The database side of the /api/v2 road (ship-safety T260 + T288): route
-- guards, the allow list of daemon.call, and the session context a request
-- carries between its calls. The entry points for the Go modules are
-- daemon.begin / daemon.call / daemon.end (daemon/daemon.sql).
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- GatewayContext --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief The current.* session context as one object — what SessionIn and the
 *        set_session_* setters write, the same nine names api.authorize_local
 *        moves to the transaction level.
 * @return {jsonb} - name → value; unset names are left out
 * @since 1.2.31
 */
CREATE OR REPLACE FUNCTION GatewayContext (
) RETURNS       jsonb
AS $$
DECLARE
  vName         text;
  jContext      jsonb := '{}';
BEGIN
  FOREACH vName IN ARRAY ARRAY['session', 'user', 'client_id', 'access', 'notification', 'area', 'oper_date', 'debug', 'log']
  LOOP
    jContext := jContext || jsonb_strip_nulls(jsonb_build_object(vName, nullif(current_setting('current.' || vName, true), '')));
  END LOOP;

  RETURN jContext;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetGatewayContext -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Puts a context taken by GatewayContext back, at the transaction level
 *        only: every name is cleared at the session level ('' reads as NULL)
 *        and set with is_local = true, so nothing of it outlives the
 *        transaction — the next request on a pooled connection inherits no
 *        identity. A name absent from the object is cleared.
 * @param {jsonb} pContext - Context object
 * @return {void}
 * @since 1.2.31
 */
CREATE OR REPLACE FUNCTION SetGatewayContext (
  pContext      jsonb
) RETURNS       void
AS $$
DECLARE
  vName         text;
BEGIN
  FOREACH vName IN ARRAY ARRAY['session', 'user', 'client_id', 'access', 'notification', 'area', 'oper_date', 'debug', 'log']
  LOOP
    PERFORM set_config('current.' || vName, '', false);
    PERFORM set_config('current.' || vName, coalesce(pContext->>vName, ''), true);
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ResetGatewayVars ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Clears every GUC the platform takes identity or intent from, at the
 *        session level and the transaction level: the nine current.* names,
 *        object.id (CreateObject takes the id of a new object from it) and the
 *        workflow context.* names. Not current.key: a deployment may set it
 *        for the role or the database (ALTER … SET), TokenValidation hashes
 *        with it, and forging it gains nothing — the token is verified with
 *        the audience's secret first. daemon.begin runs it first
 *        — a value the connection set before the request, or one a pooled
 *        connection kept from another client, must not become part of a
 *        verified context — and daemon.call / daemon.end run it before they
 *        put the context of the request back.
 * @return {void}
 * @since 1.2.31
 */
CREATE OR REPLACE FUNCTION ResetGatewayVars (
) RETURNS       void
AS $$
DECLARE
  vName         text;
BEGIN
  FOREACH vName IN ARRAY ARRAY['current.session', 'current.user', 'current.client_id', 'current.access', 'current.notification',
                               'current.area', 'current.oper_date', 'current.debug', 'current.log', 'object.id',
                               'context.method', 'context.params', 'context.object', 'context.class', 'context.action']
  LOOP
    PERFORM set_config(vName, '', false);
    PERFORM set_config(vName, '', true);
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GuardSession ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Route guard: any open session, except a member of system. Rows are
 *        decided further down, by Access<X> in the functions the route reaches.
 *
 *        system is kept out by default: the service audience is obtainable
 *        without a secret (ship-safety T289), and a system session reads what
 *        an administrator reads in several places (files, registry). A route a
 *        system session needs gets a guard of its own, by name.
 * @param {text} pPath - Path after /api/v2
 * @param {jsonb} pPayload - Request body
 * @param {text} pMethod - HTTP method
 * @return {boolean}
 * @since 1.2.31
 */
CREATE OR REPLACE FUNCTION GuardSession (
  pPath         text,
  pPayload      jsonb,
  pMethod       text
) RETURNS       boolean
AS $$
BEGIN
  RETURN current_session() IS NOT NULL AND NOT coalesce(IsSystem(), false);
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GuardAdministrator ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Route guard: members of administrator only — the /api/v2 twin of the
 *        IsUserRole(administrator) check at the top of rest.admin,
 *        rest.workflow and rest.registry.
 * @param {text} pPath - Path after /api/v2
 * @param {jsonb} pPayload - Request body
 * @param {text} pMethod - HTTP method
 * @return {boolean}
 * @since 1.2.31
 */
CREATE OR REPLACE FUNCTION GuardAdministrator (
  pPath         text,
  pPayload      jsonb,
  pMethod       text
) RETURNS       boolean
AS $$
BEGIN
  RETURN current_session() IS NOT NULL AND coalesce(IsAdmin(), false);
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GuardRead -------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Route guard for a reference the platform keeps (errors, resources,
 *        addresses): any session reads it (GuardSession), only an
 *        administrator writes it (GuardAdministrator).
 * @param {text} pPath - Path after /api/v2
 * @param {jsonb} pPayload - Request body
 * @param {text} pMethod - HTTP method
 * @return {boolean}
 * @since 1.2.31
 */
CREATE OR REPLACE FUNCTION GuardRead (
  pPath         text,
  pPayload      jsonb,
  pMethod       text
) RETURNS       boolean
AS $$
BEGIN
  IF pMethod = 'GET' THEN
    RETURN GuardSession(pPath, pPayload, pMethod);
  END IF;

  RETURN GuardAdministrator(pPath, pPayload, pMethod);
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- InitGatewayRoutes -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief The /api/v2 routes of the go-platform modules and their guards — one
 *        call per prefix, methods as the modules serve them (the route list of
 *        the Go binary, ship-safety docs/wiki/go/v2-routes.md, 26.09). A
 *        prefix of a configuration's own module is registered by the
 *        configuration. Every guard mirrors the check of the module's /api/v1
 *        dispatcher, and is stricter where that dispatcher had none: the whole
 *        event log, the API log and writes to the references are an
 *        administrator's. Re-runnable: called by init.sql and at the end of
 *        update.psql.
 * @return {void}
 * @since 1.2.31
 */
CREATE OR REPLACE FUNCTION InitGatewayRoutes (
) RETURNS       void
AS $$
BEGIN
  PERFORM RegisterRouteGuard('actions', 'GuardAdministrator', ARRAY['GET']);
  PERFORM RegisterRouteGuard('api-log', 'GuardAdministrator', ARRAY['GET']);
  PERFORM RegisterRouteGuard('area-types', 'GuardAdministrator', ARRAY['GET']);
  PERFORM RegisterRouteGuard('areas', 'GuardAdministrator', ARRAY['DELETE', 'GET', 'PATCH', 'POST']);
  PERFORM RegisterRouteGuard('classes', 'GuardAdministrator', ARRAY['DELETE', 'GET', 'PATCH', 'POST', 'PUT']);
  PERFORM RegisterRouteGuard('entities', 'GuardAdministrator', ARRAY['GET']);
  PERFORM RegisterRouteGuard('errors', 'GuardRead', ARRAY['GET', 'PATCH', 'POST']);
  PERFORM RegisterRouteGuard('event-log', 'GuardAdministrator', ARRAY['GET', 'POST']);
  PERFORM RegisterRouteGuard('event-types', 'GuardAdministrator', ARRAY['GET']);
  PERFORM RegisterRouteGuard('events', 'GuardAdministrator', ARRAY['DELETE', 'GET', 'PATCH', 'POST']);
  PERFORM RegisterRouteGuard('groups', 'GuardAdministrator', ARRAY['DELETE', 'GET', 'PATCH', 'POST']);
  PERFORM RegisterRouteGuard('interfaces', 'GuardAdministrator', ARRAY['DELETE', 'GET', 'PATCH', 'POST']);
  PERFORM RegisterRouteGuard('kladr', 'GuardRead', ARRAY['GET']);
  PERFORM RegisterRouteGuard('locales', 'GuardAdministrator', ARRAY['GET']);
  PERFORM RegisterRouteGuard('me', 'GuardSession', ARRAY['GET', 'PATCH']);
  PERFORM RegisterRouteGuard('me/event-log', 'GuardSession', ARRAY['GET']);
  PERFORM RegisterRouteGuard('methods', 'GuardAdministrator', ARRAY['DELETE', 'GET', 'PATCH', 'POST', 'PUT']);
  PERFORM RegisterRouteGuard('notifications', 'GuardSession', ARRAY['GET']);
  PERFORM RegisterRouteGuard('objects', 'GuardSession', ARRAY['DELETE', 'GET', 'POST', 'PUT']);
  PERFORM RegisterRouteGuard('observer', 'GuardSession', ARRAY['GET']);
  PERFORM RegisterRouteGuard('priorities', 'GuardAdministrator', ARRAY['GET']);
  PERFORM RegisterRouteGuard('registry', 'GuardAdministrator', ARRAY['DELETE', 'GET', 'PUT']);
  PERFORM RegisterRouteGuard('resources', 'GuardRead', ARRAY['DELETE', 'GET', 'PATCH', 'POST']);
  PERFORM RegisterRouteGuard('search', 'GuardSession', ARRAY['GET']);
  PERFORM RegisterRouteGuard('sessions', 'GuardAdministrator', ARRAY['GET']);
  PERFORM RegisterRouteGuard('state-types', 'GuardAdministrator', ARRAY['GET']);
  PERFORM RegisterRouteGuard('states', 'GuardAdministrator', ARRAY['DELETE', 'GET', 'PATCH', 'POST']);
  PERFORM RegisterRouteGuard('transitions', 'GuardAdministrator', ARRAY['DELETE', 'GET', 'PATCH', 'POST']);
  PERFORM RegisterRouteGuard('types', 'GuardAdministrator', ARRAY['DELETE', 'GET', 'PATCH', 'POST']);
  PERFORM RegisterRouteGuard('users', 'GuardAdministrator', ARRAY['DELETE', 'GET', 'PATCH', 'POST', 'PUT']);
  PERFORM RegisterRouteGuard('verification', 'GuardAdministrator', ARRAY['GET', 'POST']);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegisterRouteGuard ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Declares the guard of one /api/<version>/<prefix> route, for exactly
 *        the methods given. Re-runnable and declarative: each (path, method)
 *        keeps one endpoint whose definition calls the guard, a repeat replaces
 *        the definition, and a method left out of pMethods loses its route.
 *        (RegisterRoute adds a second row for a pair on a repeat, and
 *        GetEndpoint then takes either — not usable from an update.)
 *
 *        daemon.begin executes the endpoint as
 *        `EXECUTE definition USING path_after_version, payload, method` and
 *        expects one boolean. The definition passes the guard form of
 *        AddEndPoint: `SELECT <guard>($1, $2, $3);`.
 * @param {text} pPrefix - Prefix under the version, without slashes at the ends: 'users', 'me/event-log'
 * @param {text} pGuard - Guard function name; it must take (text, jsonb, text) and return boolean
 * @param {text[]} pMethods - Methods the prefix serves: GET, POST, PUT, PATCH, DELETE
 * @param {text} pVersion - API version segment
 * @return {void}
 * @since 1.2.31
 */
CREATE OR REPLACE FUNCTION RegisterRouteGuard (
  pPrefix       text,
  pGuard        text,
  pMethods      text[],
  pVersion      text DEFAULT 'v2'
) RETURNS       void
AS $$
DECLARE
  uPath         uuid;
  uEndpoint     uuid;
  vPath         text;
  vDefinition   text;
  vMethod       text;
  arMethods     text[];
BEGIN
  IF to_regprocedure(pGuard || '(text, jsonb, text)') IS NULL
     OR (SELECT prorettype FROM pg_proc WHERE oid = to_regprocedure(pGuard || '(text, jsonb, text)')) <> 'boolean'::regtype THEN
    RAISE EXCEPTION 'RegisterRouteGuard: % is not a guard: (text, jsonb, text) -> boolean', pGuard;
  END IF;

  IF NOT regexp_like(pPrefix, '^[a-z0-9_-]+(/[a-z0-9_-]+)*$') THEN
    RAISE EXCEPTION 'RegisterRouteGuard: prefix % must be plain path segments (a-z, 0-9, _ and -): a guard decides for its whole subtree', pPrefix;
  END IF;

  SELECT array_agg(DISTINCT upper(m)) INTO arMethods FROM unnest(pMethods) AS m;

  vPath := '/api/' || pVersion || '/' || trim(both '/' from pPrefix);
  vDefinition := format('SELECT %s($1, $2, $3);', pGuard);

  uPath := FindPath(vPath);
  IF uPath IS NULL THEN
    uPath := RegisterPath(vPath);
  END IF;

  DELETE FROM db.route WHERE path = uPath AND NOT method = ANY (arMethods);

  FOREACH vMethod IN ARRAY arMethods
  LOOP
    SELECT endpoint INTO uEndpoint FROM db.route WHERE method = vMethod AND path = uPath LIMIT 1;

    IF uEndpoint IS NULL THEN
      INSERT INTO db.route (method, path, endpoint) VALUES (vMethod, uPath, AddEndPoint(vDefinition));
    ELSE
      UPDATE db.endpoint SET definition = vDefinition WHERE id = uEndpoint AND definition IS DISTINCT FROM vDefinition;
      DELETE FROM db.route WHERE method = vMethod AND path = uPath AND endpoint <> uEndpoint;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GatewayFunctionArgs ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief The IN parameters of a function as daemon.call sees them: position,
 *        real name, key (the name without its leading p — the convention of
 *        get_routines) and type.
 * @param {oid} pOid - Function
 * @return {SETOF record} - ord, name, key, type
 * @since 1.2.31
 */
CREATE OR REPLACE FUNCTION GatewayFunctionArgs (
  pOid          oid,
  OUT ord       integer,
  OUT name      text,
  OUT key       text,
  OUT type      oid
) RETURNS       SETOF record
AS $$
BEGIN
  RETURN QUERY
    SELECT (row_number() OVER (ORDER BY a.pos))::integer, a.name, substr(a.name, 2), a.type
      FROM (SELECT x.pos, x.name, x.mode, t.type
              FROM pg_proc p,
                   unnest(p.proargnames,
                          coalesce(p.proargmodes, array_fill('i'::"char", ARRAY[coalesce(cardinality(p.proargnames), 0)])))
                     WITH ORDINALITY AS x(name, mode, pos),
                   LATERAL (SELECT coalesce(p.proallargtypes[x.pos], p.proargtypes[x.pos - 1]) AS type) t
             WHERE p.oid = pOid) a
     WHERE a.mode IN ('i', 'b', 'v')
     ORDER BY a.pos;
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GatewayFunctionKeys ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief The keys daemon.call accepts for a function, in parameter order.
 * @param {oid} pOid - Function
 * @return {text[]}
 * @since 1.2.31
 */
CREATE OR REPLACE FUNCTION GatewayFunctionKeys (
  pOid          oid
) RETURNS       text[]
AS $$
BEGIN
  RETURN coalesce((SELECT array_agg(a.key ORDER BY a.ord) FROM GatewayFunctionArgs(pOid) a), '{}');
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegisterGatewayFunction -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Opens a function of schema api to daemon.call. Re-runnable (a repeat
 *        updates the level). The list is closed by default: what is not
 *        registered is refused with ERR-403-012.
 *
 *        Refused: a function outside schema api; one of those that open or
 *        switch a session, relay a message as the system, or run a query or a
 *        route by text (su, login, signin, signup, authorize, authorize_local,
 *        run, sql, log_request, parse_message, send_mail/sms/push,
 *        recovery and registration by code, replication_apply*); any
 *        function whose body (comments stripped) calls one of the session
 *        switches (SubstituteUser, SignIn, Login, SessionIn, Authorize,
 *        EnterSystemContext, SetCurrentUserId, …); a second
 *        form of the same name whose keys are the same set as a registered
 *        one — daemon.call chooses a form by its keys and could not tell them
 *        apart.
 * @param {text} pSignature - name(type, …), with or without the api. prefix
 * @param {text} pLevel - session | administrator
 * @return {void}
 * @since 1.2.31
 */
CREATE OR REPLACE FUNCTION RegisterGatewayFunction (
  pSignature    text,
  pLevel        text DEFAULT 'session'
) RETURNS       void
AS $$
DECLARE
  uOid          oid;
  vName         text;
  vSignature    text;
  arKeys        text[];
  r             record;
BEGIN
  uOid := to_regprocedure(CASE WHEN pSignature LIKE 'api.%' THEN pSignature ELSE 'api.' || pSignature END);

  IF uOid IS NULL THEN
    RAISE EXCEPTION 'RegisterGatewayFunction: no function api.%', pSignature;
  END IF;

  SELECT p.proname INTO vName FROM pg_proc p WHERE p.oid = uOid AND p.pronamespace = 'api'::regnamespace;

  IF vName IS NULL THEN
    RAISE EXCEPTION 'RegisterGatewayFunction: % is not in schema api', pSignature;
  END IF;

  IF vName = ANY (ARRAY['su', 'login', 'signin', 'signup', 'authorize', 'authorize_local', 'run', 'sql', 'log_request', 'parse_message',
                        'send_mail', 'send_sms', 'send_push', 'send_push_data', 'recovery_password', 'reset_password',
                        'check_recovery_ticket', 'registration_code_by_email', 'registration_code_by_phone',
                        'replication_apply', 'replication_apply_relay']) THEN
    RAISE EXCEPTION 'RegisterGatewayFunction: api.% is never open to the gateway', vName;
  END IF;

  -- a function that opens or switches a session is never open either,
  -- whatever its name: the session of a /api/v2 request is daemon.begin's
  IF regexp_like(regexp_replace(regexp_replace((SELECT prosrc FROM pg_proc WHERE oid = uOid), '--[^\n]*', '', 'g'), '/\*.*?\*/', '', 'g'),
                 '\m(SubstituteUser|SignIn|Login|SessionIn|SetCurrentUserId|SetSessionUserId|SetCurrentSession|SetAccessMode|EnterSystemContext|LeaveSystemContext|Authenticate|Authorize|CheckSession|GetAccessToken|GetSession|SessionOut|SignOut)"?\s*\(', 'i') THEN
    RAISE EXCEPTION 'RegisterGatewayFunction: api.% opens or switches a session and is never open to the gateway', vName;
  END IF;

  vSignature := regexp_replace(uOid::regprocedure::text, '^api\.', '');
  arKeys := GatewayFunctionKeys(uOid);

  FOR r IN SELECT signature FROM gateway.function WHERE name = vName AND signature <> vSignature
  LOOP
    IF (SELECT array_agg(k ORDER BY k) FROM unnest(GatewayFunctionKeys(to_regprocedure('api.' || r.signature))) AS k)
       IS NOT DISTINCT FROM (SELECT array_agg(k ORDER BY k) FROM unnest(arKeys) AS k) THEN
      RAISE EXCEPTION 'RegisterGatewayFunction: api.% has the same keys as the registered api.%', vSignature, r.signature;
    END IF;
  END LOOP;

  INSERT INTO gateway.function (signature, name, level) VALUES (vSignature, vName, pLevel)
    ON CONFLICT (signature) DO UPDATE SET level = EXCLUDED.level;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UnregisterGatewayFunction ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Closes a function to daemon.call again.
 * @param {text} pSignature - name(type, …), with or without the api. prefix
 * @return {void}
 * @since 1.2.31
 */
CREATE OR REPLACE FUNCTION UnregisterGatewayFunction (
  pSignature    text
) RETURNS       void
AS $$
BEGIN
  DELETE FROM gateway.function
   WHERE signature = regexp_replace(coalesce(to_regprocedure(CASE WHEN pSignature LIKE 'api.%' THEN pSignature ELSE 'api.' || pSignature END)::regprocedure::text, pSignature), '^api\.', '');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- InitGatewayFunctions --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief The functions of schema api the go-platform modules call, opened to
 *        daemon.call, with the level the Go code needs (ship-safety
 *        docs/wiki/go/gateway-levels.md, 26.09: which routes call each
 *        function). Level session when a route under GuardSession or a GET
 *        under GuardRead calls it, or a configuration's module does;
 *        administrator when only routes under GuardAdministrator do. Of two
 *        forms with the same keys the one Go calls is open (is_user_role by
 *        uuid, set_session_oper_date by timestamptz, set_session_area by uuid —
 *        by code through set_session_area_by_code). list_listener and
 *        get_listener show every session's subscriptions with their codes and
 *        are an administrator's; a user reads list_my_listener. A
 *        configuration opens its own functions itself.
 *        Re-runnable: called by init.sql and at the end of update.psql.
 * @return {void}
 * @since 1.2.31
 */
CREATE OR REPLACE FUNCTION InitGatewayFunctions (
) RETURNS       void
AS $$
BEGIN
  PERFORM RegisterGatewayFunction(f.signature, f.level)
     FROM (VALUES
      ('add_error(text,integer,character,text,text,text,text)', 'administrator'),
      ('add_user(text,text,text,text,text,text,boolean,boolean)', 'administrator'),
      ('area_member(uuid)', 'administrator'),
      ('area_member_add(uuid,uuid)', 'administrator'),
      ('area_member_delete(uuid,uuid)', 'administrator'),
      ('change_password(uuid,text,text)', 'administrator'),
      ('chmodc(uuid,integer,uuid,boolean,boolean)', 'administrator'),
      ('chmodm(uuid,integer,uuid)', 'administrator'),
      ('chmodo(uuid,integer,uuid)', 'administrator'),
      ('class_access(uuid)', 'administrator'),
      ('clear_area()', 'administrator'),
      ('clone_class(uuid,uuid,text,text,boolean)', 'administrator'),
      ('copy_class(uuid,uuid)', 'administrator'),
      ('count_action(jsonb,jsonb)', 'administrator'),
      ('count_area(jsonb,jsonb)', 'administrator'),
      ('count_class(jsonb,jsonb)', 'administrator'),
      ('count_entity(jsonb,jsonb)', 'administrator'),
      ('count_event(jsonb,jsonb)', 'administrator'),
      ('count_event_log(jsonb,jsonb)', 'administrator'),
      ('count_group(jsonb,jsonb)', 'administrator'),
      ('count_interface(jsonb,jsonb)', 'administrator'),
      ('count_log(jsonb,jsonb)', 'administrator'),
      ('count_method(jsonb,jsonb)', 'administrator'),
      ('count_priority(jsonb,jsonb)', 'administrator'),
      ('count_session(jsonb,jsonb)', 'administrator'),
      ('count_state(jsonb,jsonb)', 'administrator'),
      ('count_transition(jsonb,jsonb)', 'administrator'),
      ('count_type(jsonb,jsonb)', 'administrator'),
      ('count_user(jsonb,jsonb)', 'administrator'),
      ('count_verification_code(jsonb,jsonb)', 'administrator'),
      ('decode_class_access(uuid,uuid)', 'administrator'),
      ('decode_method_access(uuid,uuid)', 'administrator'),
      ('delete_area(uuid)', 'administrator'),
      ('delete_class(uuid)', 'administrator'),
      ('delete_event(uuid)', 'administrator'),
      ('delete_group(uuid)', 'administrator'),
      ('delete_interface(uuid)', 'administrator'),
      ('delete_method(uuid)', 'administrator'),
      ('delete_resource(uuid)', 'administrator'),
      ('delete_state(uuid)', 'administrator'),
      ('delete_transition(uuid)', 'administrator'),
      ('delete_type(uuid)', 'administrator'),
      ('delete_user(uuid)', 'administrator'),
      ('get_action(uuid)', 'administrator'),
      ('get_area(uuid)', 'administrator'),
      ('get_class(uuid)', 'administrator'),
      ('get_entity(uuid)', 'administrator'),
      ('get_event(uuid)', 'administrator'),
      ('get_event_log(bigint)', 'administrator'),
      ('get_event_type(uuid)', 'administrator'),
      ('get_group(uuid)', 'administrator'),
      ('get_interface(uuid)', 'administrator'),
      ('get_listener(text,character varying,text)', 'administrator'),
      ('get_log(bigint)', 'administrator'),
      ('get_method(uuid)', 'administrator'),
      ('get_priority(uuid)', 'administrator'),
      ('get_state(uuid)', 'administrator'),
      ('get_state_type(uuid)', 'administrator'),
      ('get_transition(uuid)', 'administrator'),
      ('get_type(uuid)', 'administrator'),
      ('get_user(uuid)', 'administrator'),
      ('get_user_iptable(uuid,character)', 'administrator'),
      ('get_verification_code(uuid)', 'administrator'),
      ('group_member(uuid)', 'administrator'),
      ('group_member_add(uuid,uuid)', 'administrator'),
      ('group_member_delete(uuid,uuid)', 'administrator'),
      ('interface_member(uuid)', 'administrator'),
      ('interface_member_add(uuid,uuid)', 'administrator'),
      ('interface_member_delete(uuid,uuid)', 'administrator'),
      ('list_action(jsonb,jsonb,integer,integer,jsonb)', 'administrator'),
      ('list_area(jsonb,jsonb,integer,integer,jsonb)', 'administrator'),
      ('list_area_type(jsonb, jsonb, integer, integer, jsonb)', 'administrator'),
      ('list_class(jsonb,jsonb,integer,integer,jsonb)', 'administrator'),
      ('list_entity(jsonb,jsonb,integer,integer,jsonb)', 'administrator'),
      ('list_event(jsonb,jsonb,integer,integer,jsonb)', 'administrator'),
      ('list_event_log(jsonb,jsonb,integer,integer,jsonb)', 'administrator'),
      ('list_group(jsonb,jsonb,integer,integer,jsonb)', 'administrator'),
      ('list_interface(jsonb,jsonb,integer,integer,jsonb)', 'administrator'),
      ('list_locale(jsonb, jsonb, integer, integer, jsonb)', 'administrator'),
      ('list_log(jsonb,jsonb,integer,integer,jsonb)', 'administrator'),
      ('list_method(jsonb,jsonb,integer,integer,jsonb)', 'administrator'),
      ('list_priority(jsonb,jsonb,integer,integer,jsonb)', 'administrator'),
      ('list_session(jsonb,jsonb,integer,integer,jsonb)', 'administrator'),
      ('list_state(jsonb,jsonb,integer,integer,jsonb)', 'administrator'),
      ('list_state_type(jsonb, jsonb, integer, integer, jsonb)', 'administrator'),
      ('list_transition(jsonb,jsonb,integer,integer,jsonb)', 'administrator'),
      ('list_type(jsonb,jsonb,integer,integer,jsonb)', 'administrator'),
      ('list_user(jsonb,jsonb,integer,integer,jsonb)', 'administrator'),
      ('list_verification_code(jsonb,jsonb,integer,integer,jsonb)', 'administrator'),
      ('listener(text,character varying,text)', 'administrator'),
      ('member_area(uuid)', 'administrator'),
      ('member_area_add(uuid,uuid)', 'administrator'),
      ('member_area_delete(uuid,uuid)', 'administrator'),
      ('member_group(uuid)', 'administrator'),
      ('member_group_add(uuid,uuid)', 'administrator'),
      ('member_group_delete(uuid,uuid)', 'administrator'),
      ('member_interface(uuid)', 'administrator'),
      ('member_interface_add(uuid,uuid)', 'administrator'),
      ('member_interface_delete(uuid,uuid)', 'administrator'),
      ('method_access(uuid)', 'administrator'),
      ('new_verification_code(character,text,uuid)', 'administrator'),
      ('registry(uuid,uuid,uuid)', 'administrator'),
      ('registry_delete_key(text,text)', 'administrator'),
      ('registry_delete_tree(text,text)', 'administrator'),
      ('registry_delete_value(uuid,text,text,text)', 'administrator'),
      ('registry_enum_key(text,text)', 'administrator'),
      ('registry_enum_value(text,text)', 'administrator'),
      ('registry_enum_value_ex(text,text)', 'administrator'),
      ('registry_ex(uuid,uuid,uuid)', 'administrator'),
      ('registry_get_reg_key(uuid)', 'administrator'),
      ('registry_key(uuid,uuid,uuid,text)', 'administrator'),
      ('registry_read(text,text,text)', 'administrator'),
      ('registry_write(uuid,text,text,text,integer,anynonarray)', 'administrator'),
      ('safely_delete_area(uuid)', 'administrator'),
      ('set_area(uuid,uuid,uuid,uuid,text,text,text,integer,timestamp with time zone,timestamp with time zone)', 'administrator'),
      ('set_class(uuid,uuid,uuid,text,text,boolean)', 'administrator'),
      ('set_error(uuid,text,integer,character,text,text,text,text)', 'administrator'),
      ('set_event(uuid,uuid,uuid,uuid,text,text,integer,boolean)', 'administrator'),
      ('set_group(uuid,text,text,text)', 'administrator'),
      ('set_interface(uuid,text,text,text)', 'administrator'),
      ('set_method(uuid,uuid,uuid,uuid,uuid,text,text,integer,boolean)', 'administrator'),
      ('set_resource(uuid,uuid,uuid,text,text,text,text,text,integer,text)', 'administrator'),
      ('set_state(uuid,uuid,uuid,text,text,integer)', 'administrator'),
      ('set_transition(uuid,uuid,uuid,uuid)', 'administrator'),
      ('set_type(uuid,uuid,text,text,text)', 'administrator'),
      ('set_user(uuid,text,text,text,text,text,text,boolean,boolean)', 'administrator'),
      ('set_user_iptable(uuid,character,text)', 'administrator'),
      ('set_user_profile(uuid,text,text,text,text,text,text,text)', 'administrator'),
      ('user_lock(uuid)', 'administrator'),
      ('user_member(uuid)', 'administrator'),
      ('user_unlock(uuid)', 'administrator'),
      ('write_to_log(text,integer,text,text)', 'administrator'),
      ('"current_user"()', 'session'),
      ('clear_object_files(uuid)', 'session'),
      ('count_address_tree(jsonb,jsonb)', 'session'),
      ('count_error(jsonb,jsonb)', 'session'),
      ('count_notification(jsonb,jsonb)', 'administrator'),
      ('count_object(jsonb,jsonb)', 'session'),
      ('count_object_file(jsonb,jsonb)', 'session'),
      ('count_resource(jsonb,jsonb)', 'session'),
      ('count_user_log(jsonb,jsonb)', 'session'),
      ('current_area()', 'session'),
      ('current_interface()', 'session'),
      ('current_locale()', 'session'),
      ('decode_object_access(uuid,uuid)', 'administrator'),
      ('delete_object_file(uuid,uuid,text,text)', 'session'),
      ('execute_method(uuid,text,jsonb)', 'session'),
      ('execute_method(uuid,uuid,jsonb)', 'session'),
      ('execute_object_action(uuid,text,jsonb)', 'session'),
      ('execute_object_action(uuid,uuid,jsonb)', 'session'),
      ('get_address_tree(integer)', 'session'),
      ('get_address_tree_history(integer)', 'session'),
      ('get_address_tree_string(character varying,integer,integer)', 'session'),
      ('get_error(uuid)', 'session'),
      ('get_error_by_code(text)', 'session'),
      ('get_my_listener(text, text)', 'session'),
      ('get_notification(uuid)', 'administrator'),
      ('get_object(uuid)', 'session'),
      ('get_object_file(uuid,uuid,text,text)', 'session'),
      ('get_object_methods(uuid)', 'session'),
      ('get_publisher(text)', 'session'),
      ('get_resource(uuid)', 'session'),
      ('get_user_log(bigint)', 'session'),
      ('is_administrator()', 'session'),
      ('is_user_role(uuid, uuid)', 'administrator'),
      ('list_address_tree(jsonb,jsonb,integer,integer,jsonb)', 'session'),
      ('list_error(jsonb,jsonb,integer,integer,jsonb)', 'session'),
      ('list_my_listener()', 'session'),
      ('my_notification(timestamp with time zone)', 'session'),
      ('get_my_notification(uuid)', 'session'),
      ('count_my_notification(jsonb, jsonb)', 'session'),
      ('list_my_notification(jsonb, jsonb, integer, integer, jsonb)', 'session'),
      ('list_notification(jsonb,jsonb,integer,integer,jsonb)', 'administrator'),
      ('list_object(jsonb,jsonb,integer,integer,jsonb)', 'session'),
      ('list_object_file(jsonb,jsonb,integer,integer,jsonb)', 'session'),
      ('list_resource(jsonb,jsonb,integer,integer,jsonb)', 'session'),
      ('list_user_log(jsonb,jsonb,integer,integer,jsonb)', 'session'),
      ('notification(timestamp with time zone,uuid)', 'administrator'),
      ('object_access(uuid)', 'session'),
      ('oper_date()', 'session'),
      ('publisher(text)', 'session'),
      ('search(text,jsonb,text)', 'session'),
      ('set_object_files_json(uuid,json)', 'session'),
      ('set_session_area(uuid)', 'session'),
      ('set_session_area_by_code(text)', 'session'),
      ('set_session_interface(uuid)', 'session'),
      ('set_session_locale(text)', 'session'),
      ('set_session_locale(uuid)', 'session'),
      ('set_session_oper_date(timestamp with time zone)', 'session')
     ) AS f(signature, level);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- InitGateway -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Routes, guards and the allow list of /api/v2 for the platform's own
 *        modules. Re-runnable.
 * @return {void}
 * @since 1.2.31
 */
CREATE OR REPLACE FUNCTION InitGateway (
) RETURNS       void
AS $$
BEGIN
  PERFORM InitGatewayRoutes();
  PERFORM InitGatewayFunctions();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
