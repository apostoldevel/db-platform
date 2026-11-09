--------------------------------------------------------------------------------
-- P00000043 -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- /api/v2/locales is read by any open session, not by administrators only.
--
-- The list of locales is a platform reference a client reads to show its
-- language switch. API v2 declared it administrator-only twice: the route guard
-- (GuardAdministrator) and the allow-list level of api.list_locale. The route
-- now takes GuardRead, as the other platform references (errors, resources,
-- addresses): GET is GuardSession, any other method an administrator's. The
-- allow-list level of api.list_locale becomes 'session'.
--
-- GuardSession admits an open session whose user is not a member of group
-- system; an administrator who is a member of system read the list before and
-- is refused after.
--
-- A fresh base takes this from InitGateway (gateway/init.sql). An existing base
-- keeps the routes and the allow list it was installed with: update.psql has
-- not re-run InitGateway since P00000031, so the two rows are rewritten here —
-- only where they still hold the platform's earlier declaration:
--   * the route, when /api/v2/locales serves GET alone and its endpoint is
--     exactly `SELECT GuardAdministrator($1, $2, $3);`. A route removed or
--     re-declared with another guard or other methods is left as it is;
--   * the level, when api.list_locale is registered at 'administrator'.
-- Each row says by a NOTICE whether it was rewritten or left. A base that had
-- the earlier declaration on purpose cannot be told from one that had the
-- default: a configuration that keeps the administrator gate re-declares it
-- after this patch — in its own update, or in a patch of its own when it
-- registers its gateway at install only:
--   SELECT RegisterRouteGuard('locales', 'GuardAdministrator', ARRAY['GET']);
--   SELECT RegisterGatewayFunction('list_locale(jsonb, jsonb, integer, integer, jsonb)', 'administrator');
-- On a base older than 1.2.31, P00000031 has already registered the current
-- data and both conditions are false: this patch then changes nothing.
--
-- The comment of gateway.function stated that the table is re-filled on every
-- update; it is restated here, as in table.sql.
--
-- One DO block (all or nothing), kernel phase, no \connect, no session,
-- repeatable.
--------------------------------------------------------------------------------

\set ON_ERROR_STOP on

DO $$
DECLARE
  uPath         uuid;
  bOld          boolean := false;
BEGIN
  uPath := FindPath('/api/v2/locales');

  -- Nested, not one AND chain: the endpoint is read only once GET is known to
  -- be the one route of the node.
  IF uPath IS NOT NULL
     AND (SELECT array_agg(r.method ORDER BY r.method) FROM db.route r WHERE r.path = uPath) = ARRAY['GET'] THEN
    bOld := GetEndpointDefinition(GetEndpoint(uPath, 'GET')) IS NOT DISTINCT FROM 'SELECT GuardAdministrator($1, $2, $3);';
  END IF;

  IF bOld THEN
    PERFORM RegisterRouteGuard('locales', 'GuardRead', ARRAY['GET']);
    RAISE NOTICE 'P00000043: /api/v2/locales GET now takes GuardRead';
  ELSE
    RAISE NOTICE 'P00000043: /api/v2/locales left as it is (not the earlier platform declaration)';
  END IF;

  IF EXISTS (SELECT FROM gateway.function WHERE signature = 'list_locale(jsonb,jsonb,integer,integer,jsonb)' AND level = 'administrator') THEN
    PERFORM RegisterGatewayFunction('list_locale(jsonb, jsonb, integer, integer, jsonb)', 'session');
    RAISE NOTICE 'P00000043: api.list_locale now at level session';
  ELSE
    RAISE NOTICE 'P00000043: api.list_locale left as it is (not at level administrator)';
  END IF;

  EXECUTE $c$COMMENT ON TABLE gateway.function IS 'The functions of schema api that daemon.call may reach — closed by default. Filled by RegisterGatewayFunction from InitGateway at install; an existing base takes a change through a patch.'$c$;
END;
$$;
