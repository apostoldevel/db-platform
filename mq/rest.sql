--------------------------------------------------------------------------------
-- REST MQ ---------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Dispatch REST JSON API requests for the message transport.
 * @param {text} pPath - REST route path (e.g. /mq/queue, /mq/accept, /mq/plan/list)
 * @param {jsonb} pPayload - Request payload
 * @return {SETOF json} - JSON response rows
 * @throws RouteIsEmpty - When pPath is NULL
 * @throws LoginFailed - When no active session exists
 * @throws AccessDenied - When the caller is not a member of the mq group
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION rest.mq (
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

  -- The group is looked up by code rather than written here as a literal uuid.
  -- The platform's own system identifiers and the ones projects assign share
  -- one range with nothing dividing it -- 00000000-0000-4000-a000-000000000006
  -- is already taken by a group of its own in more than one project -- so a new
  -- platform group takes a generated identifier, and code that needs it asks
  -- for it by name.

  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('mq'), current_userid()) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  CASE pPath
  WHEN '/mq/publish' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['channel', 'type', 'payload', 'key', 'route', 'signature']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(channel text, type text, payload jsonb, key text, route text, signature text)
      LOOP
        RETURN NEXT json_build_object('channel', r.channel, 'serial', api.mq_publish(r.channel, r.type, r.payload, r.key, r.route, r.signature));
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(channel text, type text, payload jsonb, key text, route text, signature text)
      LOOP
        RETURN NEXT json_build_object('channel', r.channel, 'serial', api.mq_publish(r.channel, r.type, r.payload, r.key, r.route, r.signature));
      END LOOP;

    END IF;

  WHEN '/mq/queue' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['peer', 'channel', 'reclimit']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(peer text, channel text, reclimit integer)
    LOOP
      FOR e IN SELECT * FROM api.mq_queue(r.peer, r.channel, r.reclimit)
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/mq/accept' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['source', 'channel', 'serial', 'type', 'payload', 'key', 'route', 'signature', 'created']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    -- A batch arrives as an array and is accepted message by message: one
    -- refusal parks its own message and the rest of the batch goes on. A batch
    -- that failed as a whole because of one bad row is exactly the outage this
    -- transport is built to avoid.

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(source text, channel text, serial bigint, type text, payload jsonb, key text, route text, signature text, created timestamp with time zone)
      LOOP
        RETURN NEXT json_build_object('source', r.source, 'channel', r.channel, 'serial', r.serial,
                                      'applied', api.mq_accept(r.source, r.channel, r.serial, r.type, r.payload, r.key, r.route, r.signature, r.created));
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(source text, channel text, serial bigint, type text, payload jsonb, key text, route text, signature text, created timestamp with time zone)
      LOOP
        RETURN NEXT json_build_object('source', r.source, 'channel', r.channel, 'serial', r.serial,
                                      'applied', api.mq_accept(r.source, r.channel, r.serial, r.type, r.payload, r.key, r.route, r.signature, r.created));
      END LOOP;

    END IF;

  WHEN '/mq/floor' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['peer', 'channel', 'upto']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(peer text, channel text, upto bigint)
    LOOP
      FOR e IN SELECT * FROM api.mq_floor(r.peer, r.channel, r.upto)
      LOOP
        -- The kind travels with the number: the receiving side weighs a claim
        -- it can check differently from one it cannot, and dropping it here
        -- would leave it unable to tell them apart.
        RETURN NEXT json_build_object('peer', r.peer, 'channel', r.channel, 'floor', e.floor, 'kind', e.kind);
      END LOOP;
    END LOOP;

  WHEN '/mq/advance' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['source', 'channel', 'floor', 'kind']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(source text, channel text, floor bigint, kind text)
    LOOP
      FOR e IN SELECT * FROM api.mq_advance(r.source, r.channel, r.floor, r.kind)
      LOOP
        -- The fate of the floor goes back with the cursor. The sender decides
        -- what to do next from it, and it happened in a database it cannot read.
        RETURN NEXT json_build_object('source', r.source, 'channel', r.channel, 'received', e.received, 'floor', e.floor);
      END LOOP;
    END LOOP;

  WHEN '/mq/confirm' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['peer', 'channel', 'serial', 'floor']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(peer text, channel text, serial bigint, floor text)
    LOOP
      RETURN NEXT json_build_object('peer', r.peer, 'channel', r.channel, 'sent', api.mq_confirm(r.peer, r.channel, r.serial, r.floor));
    END LOOP;

  WHEN '/mq/retry' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['source', 'channel', 'serial']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(source text, channel text, serial bigint)
    LOOP
      RETURN NEXT json_build_object('source', r.source, 'channel', r.channel, 'serial', r.serial,
                                    'applied', api.mq_retry(r.source, r.channel, r.serial));
    END LOOP;

  WHEN '/mq/session/open' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['peer', 'channel', 'direction', 'link']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(peer text, channel text, direction text, link text)
    LOOP
      RETURN NEXT json_build_object('id', api.mq_session_open(r.peer, r.channel, r.direction, r.link));
    END LOOP;

  WHEN '/mq/session/close' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'result', 'messages', 'bytes', 'message']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id bigint, result text, messages integer, bytes bigint, message text)
    LOOP
      RETURN NEXT json_build_object('id', api.mq_session_close(r.id, r.result, r.messages, r.bytes, r.message));
    END LOOP;

  WHEN '/mq/compact' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['channel']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(channel text)
    LOOP
      RETURN NEXT json_build_object('channel', r.channel, 'removed', api.mq_compact(r.channel));
    END LOOP;

  WHEN '/mq/purge' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['channel']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(channel text)
    LOOP
      RETURN NEXT json_build_object('channel', r.channel, 'removed', api.mq_purge(r.channel));
    END LOOP;

  WHEN '/mq/link/create' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['code', 'name', 'metered', 'threshold', 'description']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(code text, name text, metered boolean, threshold integer, description text)
    LOOP
      FOR e IN SELECT * FROM api.mq_create_link(r.code, r.name, r.metered, r.threshold, r.description)
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/mq/link/edit' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['code', 'name', 'metered', 'threshold', 'enabled', 'description']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(code text, name text, metered boolean, threshold integer, enabled boolean, description text)
    LOOP
      FOR e IN SELECT * FROM api.mq_edit_link(r.code, r.name, r.metered, r.threshold, r.enabled, r.description)
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/mq/link/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    END IF;

    FOR e IN SELECT * FROM api.mq_link ORDER BY threshold, code
    LOOP
      RETURN NEXT row_to_json(e);
    END LOOP;

  WHEN '/mq/schedule/set' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['channel', 'link', 'period', 'batch', 'timeout', 'backoff', 'catchup', 'peer']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(channel text, link text, period interval, batch integer, timeout interval, backoff interval, catchup interval, peer text)
    LOOP
      FOR e IN SELECT * FROM api.mq_set_schedule(r.channel, r.link, r.period, r.batch, r.timeout, r.backoff, r.catchup, r.peer)
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/mq/schedule/delete' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['channel', 'link', 'peer']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(channel text, link text, peer text)
    LOOP
      RETURN NEXT json_build_object('channel', r.channel, 'link', r.link, 'removed', api.mq_delete_schedule(r.channel, r.link, r.peer));
    END LOOP;

  WHEN '/mq/schedule/get' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['channel', 'link', 'peer']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(channel text, link text, peer text)
    LOOP
      FOR e IN SELECT * FROM api.mq_get_schedule(r.channel, r.link, r.peer)
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/mq/schedule/count' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN SELECT * FROM api.count_mq_schedule(r.search, r.filter) AS count
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/mq/schedule/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_mq_schedule($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('mq_schedule', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/mq/plan/count' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN SELECT * FROM api.count_mq_plan(r.search, r.filter) AS count
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/mq/plan/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_mq_plan($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('mq_plan', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/mq/session/next' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['peer', 'channel', 'link']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(peer text, channel text, link text)
    LOOP
      RETURN NEXT json_build_object('peer', r.peer, 'channel', r.channel, 'link', r.link, 'due', api.mq_next_session(r.peer, r.channel, r.link));
    END LOOP;

  WHEN '/mq/channel/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    END IF;

    FOR e IN SELECT * FROM api.mq_channel ORDER BY priority, code
    LOOP
      RETURN NEXT row_to_json(e);
    END LOOP;

  WHEN '/mq/message/count' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN SELECT * FROM api.count_mq_message(r.search, r.filter) AS count
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/mq/message/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_mq_message($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('mq_message', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/mq/dead/count' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN SELECT * FROM api.count_mq_dead(r.search, r.filter) AS count
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/mq/dead/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_mq_dead($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('mq_dead', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/mq/session/count' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN SELECT * FROM api.count_mq_session(r.search, r.filter) AS count
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/mq/session/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_mq_session($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('mq_session', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/mq/watermark/count' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN SELECT * FROM api.count_mq_watermark(r.search, r.filter) AS count
      LOOP
        RETURN NEXT row_to_json(e);
      END LOOP;
    END LOOP;

  WHEN '/mq/watermark/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['fields', 'search', 'filter', 'reclimit', 'recoffset', 'orderby']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(fields jsonb, search jsonb, filter jsonb, reclimit integer, recoffset integer, orderby jsonb)
    LOOP
      FOR e IN EXECUTE format('SELECT %s FROM api.list_mq_watermark($1, $2, $3, $4, $5)', JsonbToFields(r.fields, GetColumns('mq_watermark', 'api'))) USING r.search, r.filter, r.reclimit, r.recoffset, r.orderby
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
