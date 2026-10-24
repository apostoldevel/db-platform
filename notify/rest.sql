--------------------------------------------------------------------------------
-- REST NOTIFY -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Dispatch REST JSON API requests for the notification delivery module.
 * @param {text} pPath - REST route path (e.g. /notify/channel/list, /notify/queue/count)
 * @param {jsonb} pPayload - Request payload
 * @return {SETOF json} - JSON response rows
 * @throws RouteIsEmpty - When pPath is NULL
 * @throws LoginFailed - When no active session exists
 * @throws AccessDenied - When the caller is not an administrator
 * @since 1.2.36
 */
CREATE OR REPLACE FUNCTION rest.notify (
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
  WHEN '/notify/channel/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    END IF;

    FOR e IN SELECT * FROM api.notify_channel ORDER BY code
    LOOP
      RETURN NEXT row_to_json(e);
    END LOOP;

  WHEN '/notify/channel/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['code']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(code text)
    LOOP
      FOR e IN SELECT * FROM api.get_notify_channel(r.code)
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/notify/channel/set' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['code', 'mode', 'affinity', 'grace', 'lease', 'expire', 'max_attempts', 'resend_enabled', 'on_expire', 'dedupe', 'retain_done', 'retain_closed', 'alive', 'sweep_every']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(code text, mode text, affinity text, grace interval, lease interval, expire interval, max_attempts integer, resend_enabled boolean, on_expire boolean, dedupe boolean, retain_done interval, retain_closed interval, alive interval, sweep_every interval)
    LOOP
      FOR e IN SELECT * FROM api.set_notify_channel(r.code, r.mode, r.affinity, r.grace, r.lease, r.expire, r.max_attempts, r.resend_enabled, r.on_expire, r.dedupe, r.retain_done, r.retain_closed, r.alive, r.sweep_every)
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/notify/subscriber/count' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN SELECT * FROM api.count_notify_subscriber(r.search, r.filter) AS count
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/notify/subscriber/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_notify_subscriber($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('notify_subscriber', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/notify/queue/count' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN SELECT * FROM api.count_notify_queue(r.search, r.filter) AS count
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/notify/queue/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_notify_queue($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('notify_queue', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
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
