--------------------------------------------------------------------------------
-- MQ --------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- The API speaks CODES, not identifiers. A process reads the channel and node
-- it works with from its configuration, and the numeric identifiers are local
-- to each database -- the same channel is 3 here and 7 there. Anything that
-- crossed the boundary as a number would silently mean a different lane on the
-- far side.

CREATE OR REPLACE VIEW api.mq_channel
AS
  SELECT * FROM MQChannel;

GRANT SELECT ON api.mq_channel TO administrator;
GRANT SELECT ON api.mq_channel TO apibot;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.mq_peer
AS
  SELECT id, code, name, role, local, area, enabled, created, updated, seen FROM MQPeer;

GRANT SELECT ON api.mq_peer TO administrator;
GRANT SELECT ON api.mq_peer TO apibot;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.mq_message
AS
  SELECT * FROM MQMessage;

GRANT SELECT ON api.mq_message TO administrator;
GRANT SELECT ON api.mq_message TO apibot;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.mq_watermark
AS
  SELECT * FROM MQWatermark;

GRANT SELECT ON api.mq_watermark TO administrator;
GRANT SELECT ON api.mq_watermark TO apibot;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.mq_dead
AS
  SELECT * FROM MQDead;

GRANT SELECT ON api.mq_dead TO administrator;
GRANT SELECT ON api.mq_dead TO apibot;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.mq_session
AS
  SELECT * FROM MQSession;

GRANT SELECT ON api.mq_session TO administrator;
GRANT SELECT ON api.mq_session TO apibot;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.mq_link
AS
  SELECT * FROM MQLink;

GRANT SELECT ON api.mq_link TO administrator;
GRANT SELECT ON api.mq_link TO apibot;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.mq_schedule
AS
  SELECT * FROM MQSchedule;

GRANT SELECT ON api.mq_schedule TO administrator;
GRANT SELECT ON api.mq_schedule TO apibot;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.mq_plan
AS
  SELECT * FROM MQPlan;

GRANT SELECT ON api.mq_plan TO administrator;
GRANT SELECT ON api.mq_plan TO apibot;

--------------------------------------------------------------------------------
-- api.mq_channel_id -----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Resolve a channel code, refusing an unknown one.
 * @param {text} pCode - Channel code
 * @return {integer} - Channel identifier
 * @throws ERR-40000 - When there is no such channel
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION api.mq_channel_id (
  pCode     text
) RETURNS   integer
AS $$
DECLARE
  nId       integer;
BEGIN
  nId := mq.get_channel(pCode);

  IF nId IS NULL THEN
    RAISE EXCEPTION 'ERR-40000: Channel "%" not found.', pCode;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.mq_peer_id --------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Resolve a node code, refusing an unknown one.
 * @param {text} pCode - Node code
 * @return {integer} - Node identifier
 * @throws ERR-40000 - When there is no such node
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION api.mq_peer_id (
  pCode     text
) RETURNS   integer
AS $$
DECLARE
  nId       integer;
BEGIN
  nId := mq.get_peer(pCode);

  IF nId IS NULL THEN
    -- Refused rather than created on the fly: a node that turns up unknown is
    -- either a mistake in configuration or somebody else's traffic, and
    -- registering it silently would file that traffic as legitimate.
    RAISE EXCEPTION 'ERR-40000: Node "%" not found.', pCode;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.mq_link_id --------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Resolve a link code, refusing an unknown one.
 * @param {text} pCode - Link code
 * @return {integer} - Link identifier
 * @throws ERR-40000 - When there is no such link
 * @since 1.2.18
 */
CREATE OR REPLACE FUNCTION api.mq_link_id (
  pCode     text
) RETURNS   integer
AS $$
DECLARE
  nId       integer;
BEGIN
  nId := mq.get_link(pCode);

  IF nId IS NULL THEN
    RAISE EXCEPTION 'ERR-40000: Link "%" not found.', pCode;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.mq_publish --------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Publish a message on a channel.
 * @param {text} pChannel - Channel code
 * @param {text} pType - Message type
 * @param {jsonb} pPayload - Message body
 * @param {text} pKey - Compaction key
 * @param {text} pRoute - Routing key
 * @param {text} pSignature - Signature of this node over the message
 * @return {bigint} - Serial issued within the channel
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION api.mq_publish (
  pChannel      text,
  pType         text,
  pPayload      jsonb,
  pKey          text DEFAULT null,
  pRoute        text DEFAULT null,
  pSignature    text DEFAULT null
) RETURNS       bigint
AS $$
  SELECT mq.publish(api.mq_channel_id(pChannel), pType, pPayload, pKey, pRoute, pSignature);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.mq_floor ----------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief The serial below which a node will never be sent anything again.
 * @param {text} pPeer - Node code
 * @param {text} pChannel - Channel code
 * @param {bigint} pUpto - Last serial handed over in this session
 * @return {bigint} - Floor of the channel for that node
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION api.mq_floor (
  pPeer     text,
  pChannel  text,
  pUpto     bigint DEFAULT null
) RETURNS TABLE (
  floor     bigint,
  kind      text
)
AS $$
  SELECT * FROM mq.floor(api.mq_peer_id(pPeer), api.mq_channel_id(pChannel), pUpto);
$$ LANGUAGE SQL STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.mq_advance --------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Move the reception cursor, optionally over a floor the sender declared.
 * @param {text} pSource - Code of the node whose messages were received
 * @param {text} pChannel - Channel code
 * @param {bigint} pFloor - Serial the sender declares as never deliverable
 * @param {text} pKind - Grounds of the claim, as mq.floor returned them: batch or channel
 * @return {TABLE} - received bigint, floor text (honoured, refused or none)
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION api.mq_advance (
  pSource   text,
  pChannel  text,
  pFloor    bigint DEFAULT null,
  pKind     text DEFAULT 'batch'
) RETURNS TABLE (
  received  bigint,
  floor     text
)
AS $$
  SELECT * FROM mq.advance(api.mq_peer_id(pSource), api.mq_channel_id(pChannel), pFloor, coalesce(pKind, 'batch'));
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.mq_queue ----------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Messages a node has not confirmed yet.
 * @param {text} pPeer - Node code
 * @param {text} pChannel - Channel code
 * @param {integer} pLimit - Batch size
 * @return {SETOF api.mq_message} - Messages to hand over
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION api.mq_queue (
  pPeer     text,
  pChannel  text,
  pLimit    integer DEFAULT 100
) RETURNS   SETOF api.mq_message
AS $$
  SELECT v.*
    FROM mq.queue(api.mq_peer_id(pPeer), api.mq_channel_id(pChannel), pLimit) q
   INNER JOIN api.mq_message v
      ON v.source = q.source AND v.channel = q.channel AND v.serial = q.serial
   ORDER BY v.serial;
$$ LANGUAGE SQL STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.mq_accept ---------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Accept an incoming message.
 * @param {text} pSource - Code of the node that published it
 * @param {text} pChannel - Channel code
 * @param {bigint} pSerial - Serial within (source, channel)
 * @param {text} pType - Message type
 * @param {jsonb} pPayload - Message body
 * @param {text} pKey - Compaction key
 * @param {text} pRoute - Routing key
 * @param {text} pSignature - Signature of the sending node
 * @param {timestamptz} pCreated - When the sender published it
 * @return {boolean} - TRUE when applied, FALSE when parked in mq.dead
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION api.mq_accept (
  pSource       text,
  pChannel      text,
  pSerial       bigint,
  pType         text,
  pPayload      jsonb,
  pKey          text DEFAULT null,
  pRoute        text DEFAULT null,
  pSignature    text DEFAULT null,
  pCreated      timestamptz DEFAULT null
) RETURNS       boolean
AS $$
  SELECT mq.accept(api.mq_peer_id(pSource), api.mq_channel_id(pChannel), pSerial,
                   pType, pPayload, pKey, pRoute, pSignature, pCreated);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.mq_confirm --------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Record a node's confirmation of our messages.
 * @param {text} pPeer - Node code
 * @param {text} pChannel - Channel code
 * @param {bigint} pSerial - Serial the node reports as accepted
 * @param {text} pFloor - What the peer did with our floor: honoured, refused or none
 * @return {bigint} - The serial recorded
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION api.mq_confirm (
  pPeer     text,
  pChannel  text,
  pSerial   bigint,
  pFloor    text DEFAULT null
) RETURNS   bigint
AS $$
DECLARE
  nPeer     integer;
  nChannel  integer;
  nSent     bigint;
BEGIN
  nPeer := api.mq_peer_id(pPeer);
  nChannel := api.mq_channel_id(pChannel);

  PERFORM mq.confirm(nPeer, nChannel, pSerial, pFloor);

  SELECT sent INTO nSent FROM mq.watermark WHERE peer = nPeer AND channel = nChannel;

  RETURN nSent;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.mq_retry ----------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Try a parked message again.
 * @param {text} pSource - Code of the node that published it
 * @param {text} pChannel - Channel code
 * @param {bigint} pSerial - Serial
 * @return {boolean} - TRUE when it applied this time
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION api.mq_retry (
  pSource   text,
  pChannel  text,
  pSerial   bigint
) RETURNS   boolean
AS $$
  SELECT mq.retry(api.mq_peer_id(pSource), api.mq_channel_id(pChannel), pSerial);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.mq_session_open ---------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Open an exchange session.
 * @param {text} pPeer - Node code
 * @param {text} pChannel - Channel code
 * @param {text} pDirection - send or receive
 * @param {text} pLink - Code of the link this session runs over
 * @return {bigint} - Session identifier
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION api.mq_session_open (
  pPeer         text,
  pChannel      text,
  pDirection    text,
  pLink         text DEFAULT null
) RETURNS       bigint
AS $$
  SELECT mq.session_open(api.mq_peer_id(pPeer), api.mq_channel_id(pChannel), pDirection,
                         CASE WHEN pLink IS NULL THEN null ELSE api.mq_link_id(pLink) END);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.mq_session_close --------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Close an exchange session with its outcome.
 * @param {bigint} pId - Session identifier
 * @param {text} pResult - ok, partial or failed
 * @param {integer} pMessages - How many messages were carried
 * @param {bigint} pBytes - How many bytes went over the link
 * @param {text} pMessage - Error or explanation
 * @return {bigint} - The session identifier
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION api.mq_session_close (
  pId           bigint,
  pResult       text,
  pMessages     integer DEFAULT 0,
  pBytes        bigint DEFAULT 0,
  pMessage      text DEFAULT null
) RETURNS       bigint
AS $$
BEGIN
  PERFORM mq.session_close(pId, pResult, pMessages, pBytes, pMessage);

  RETURN pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.mq_compact --------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Compact a channel, keeping the last message per key.
 * @param {text} pChannel - Channel code
 * @return {integer} - Number of superseded messages removed
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION api.mq_compact (
  pChannel  text
) RETURNS   integer
AS $$
  SELECT mq.compact(api.mq_channel_id(pChannel));
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.mq_purge ----------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Remove messages a channel no longer has to keep.
 * @param {text} pChannel - Channel code
 * @return {integer} - Number of messages removed
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION api.mq_purge (
  pChannel  text
) RETURNS   integer
AS $$
  SELECT mq.purge(api.mq_channel_id(pChannel));
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_mq_message --------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Count messages matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION api.count_mq_message (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'mq_message', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(serial)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_mq_message ---------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief List messages with optional search, filter and pagination.
 * @param {jsonb} pSearch - Full-text search criteria
 * @param {jsonb} pFilter - Column-level filter conditions
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Sort specification
 * @return {SETOF api.mq_message} - Matching messages
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION api.list_mq_message (
  pSearch       jsonb default null,
  pFilter       jsonb default null,
  pLimit        integer default null,
  pOffSet       integer default null,
  pOrderBy      jsonb default null
) RETURNS       SETOF api.mq_message
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'mq_message', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_mq_dead -----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Count dead letters matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION api.count_mq_dead (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'mq_dead', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(serial)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_mq_dead ------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief List dead letters with optional search, filter and pagination.
 * @param {jsonb} pSearch - Full-text search criteria
 * @param {jsonb} pFilter - Column-level filter conditions
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Sort specification
 * @return {SETOF api.mq_dead} - Matching dead letters
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION api.list_mq_dead (
  pSearch       jsonb default null,
  pFilter       jsonb default null,
  pLimit        integer default null,
  pOffSet       integer default null,
  pOrderBy      jsonb default null
) RETURNS       SETOF api.mq_dead
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'mq_dead', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_mq_session --------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Count exchange sessions matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION api.count_mq_session (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'mq_session', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_mq_session ---------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief List exchange sessions with optional search, filter and pagination.
 * @param {jsonb} pSearch - Full-text search criteria
 * @param {jsonb} pFilter - Column-level filter conditions
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Sort specification
 * @return {SETOF api.mq_session} - Matching sessions
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION api.list_mq_session (
  pSearch       jsonb default null,
  pFilter       jsonb default null,
  pLimit        integer default null,
  pOffSet       integer default null,
  pOrderBy      jsonb default null
) RETURNS       SETOF api.mq_session
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'mq_session', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_mq_watermark ------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Count exchange cursors matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION api.count_mq_watermark (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'mq_watermark', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(peer)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_mq_watermark -------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief List exchange cursors with queue depth.
 * @param {jsonb} pSearch - Full-text search criteria
 * @param {jsonb} pFilter - Column-level filter conditions
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Sort specification
 * @return {SETOF api.mq_watermark} - Matching cursors
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION api.list_mq_watermark (
  pSearch       jsonb default null,
  pFilter       jsonb default null,
  pLimit        integer default null,
  pOffSet       integer default null,
  pOrderBy      jsonb default null
) RETURNS       SETOF api.mq_watermark
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'mq_watermark', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.mq_create_link ----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Register a kind of link.
 * @param {text} pCode - Link code, unique and stable
 * @param {text} pName - Human-readable name
 * @param {boolean} pMetered - Whether traffic is billed by volume
 * @param {integer} pThreshold - Lowest lane priority this link admits (1..3)
 * @param {text} pDescription - What this kind of link is and what it costs
 * @return {SETOF api.mq_link} - The registered link
 * @since 1.2.18
 */
CREATE OR REPLACE FUNCTION api.mq_create_link (
  pCode         text,
  pName         text,
  pMetered      boolean DEFAULT false,
  pThreshold    integer DEFAULT 3,
  pDescription  text DEFAULT null
) RETURNS       SETOF api.mq_link
AS $$
BEGIN
  RETURN QUERY SELECT * FROM api.mq_link WHERE id = mq.create_link(pCode, pName, pMetered, pThreshold, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.mq_edit_link ------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Change a kind of link. NULL leaves the current value in place.
 * @param {text} pCode - Link code
 * @param {text} pName - New name
 * @param {boolean} pMetered - Whether traffic is billed by volume
 * @param {integer} pThreshold - New threshold
 * @param {boolean} pEnabled - Whether the link kind is in service
 * @param {text} pDescription - New description
 * @return {SETOF api.mq_link} - The changed link
 * @since 1.2.18
 */
CREATE OR REPLACE FUNCTION api.mq_edit_link (
  pCode         text,
  pName         text DEFAULT null,
  pMetered      boolean DEFAULT null,
  pThreshold    integer DEFAULT null,
  pEnabled      boolean DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS       SETOF api.mq_link
AS $$
DECLARE
  nId           integer;
BEGIN
  nId := api.mq_link_id(pCode);

  PERFORM mq.edit_link(nId, pName, pMetered, pThreshold, pEnabled, pDescription);

  RETURN QUERY SELECT * FROM api.mq_link WHERE id = nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.mq_set_schedule ---------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Set the session schedule on a pair, creating or replacing the row.
 * @param {text} pChannel - Channel code
 * @param {text} pLink - Link code
 * @param {interval} pPeriod - How often a session opens. On an evidential lane
 *        this also sets the window in which a truncated tail of the log stays
 *        undetectable -- see the comment on mq.schedule.period and the
 *        evidential column of api.mq_plan.
 * @param {integer} pBatch - Largest number of messages per session
 * @param {interval} pTimeout - How long a session may stay open
 * @param {interval} pBackoff - First delay after a failed session
 * @param {interval} pCatchup - Interval used while the node is behind
 * @param {text} pPeer - Node code; NULL sets the default for every node
 * @return {SETOF api.mq_schedule} - The schedule row now in force
 * @since 1.2.18
 */
CREATE OR REPLACE FUNCTION api.mq_set_schedule (
  pChannel      text,
  pLink         text,
  pPeriod       interval,
  pBatch        integer DEFAULT null,
  pTimeout      interval DEFAULT null,
  pBackoff      interval DEFAULT null,
  pCatchup      interval DEFAULT null,
  pPeer         text DEFAULT null
) RETURNS       SETOF api.mq_schedule
AS $$
DECLARE
  nId           integer;
BEGIN
  nId := mq.set_schedule(api.mq_channel_id(pChannel), api.mq_link_id(pLink), pPeriod,
                         pBatch, pTimeout, pBackoff, pCatchup,
                         CASE WHEN pPeer IS NULL THEN null ELSE api.mq_peer_id(pPeer) END);

  RETURN QUERY SELECT * FROM api.mq_schedule WHERE id = nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.mq_delete_schedule ------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Remove a schedule row.
 * @param {text} pChannel - Channel code
 * @param {text} pLink - Link code
 * @param {text} pPeer - Node code; NULL removes the default row
 * @return {boolean} - Whether a row was removed
 * @since 1.2.18
 */
CREATE OR REPLACE FUNCTION api.mq_delete_schedule (
  pChannel      text,
  pLink         text,
  pPeer         text DEFAULT null
) RETURNS       boolean
AS $$
  SELECT mq.delete_schedule(api.mq_channel_id(pChannel), api.mq_link_id(pLink),
                            CASE WHEN pPeer IS NULL THEN null ELSE api.mq_peer_id(pPeer) END);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.mq_get_schedule ---------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief The schedule in force for a node on a pair.
 * @param {text} pChannel - Channel code
 * @param {text} pLink - Link code
 * @param {text} pPeer - Node code; NULL considers only the default row
 * @return {record} - id, period, batch, timeout, backoff, catchup, scope
 * @since 1.2.18
 */
CREATE OR REPLACE FUNCTION api.mq_get_schedule (
  pChannel      text,
  pLink         text,
  pPeer         text DEFAULT null
) RETURNS TABLE (
  id            integer,
  period        interval,
  batch         integer,
  timeout       interval,
  backoff       interval,
  catchup       interval,
  scope         text
)
AS $$
  SELECT * FROM mq.get_schedule(api.mq_channel_id(pChannel), api.mq_link_id(pLink),
                                CASE WHEN pPeer IS NULL THEN null ELSE api.mq_peer_id(pPeer) END);
$$ LANGUAGE SQL STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.mq_next_session ---------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief When the next sending session on a pair is due.
 * @param {text} pPeer - Node code
 * @param {text} pChannel - Channel code
 * @param {text} pLink - Code of the link the process is connected over
 * @return {timestamptz} - When to open the next session; NULL when this lane
 *                         does not travel over this link at all
 * @since 1.2.18
 */
CREATE OR REPLACE FUNCTION api.mq_next_session (
  pPeer         text,
  pChannel      text,
  pLink         text
) RETURNS       timestamptz
AS $$
  SELECT mq.next_session(api.mq_peer_id(pPeer), api.mq_channel_id(pChannel), api.mq_link_id(pLink));
$$ LANGUAGE SQL STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_mq_schedule -------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Count schedule rows matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.18
 */
CREATE OR REPLACE FUNCTION api.count_mq_schedule (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'mq_schedule', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_mq_schedule --------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief List schedule rows with optional search, filter and pagination.
 * @param {jsonb} pSearch - Full-text search criteria
 * @param {jsonb} pFilter - Column-level filter conditions
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Sort specification
 * @return {SETOF api.mq_schedule} - Matching schedule rows
 * @since 1.2.18
 */
CREATE OR REPLACE FUNCTION api.list_mq_schedule (
  pSearch       jsonb default null,
  pFilter       jsonb default null,
  pLimit        integer default null,
  pOffSet       integer default null,
  pOrderBy      jsonb default null
) RETURNS       SETOF api.mq_schedule
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'mq_schedule', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_mq_plan -----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Count plan rows matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.18
 */
CREATE OR REPLACE FUNCTION api.count_mq_plan (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'mq_plan', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(peer)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_mq_plan ------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief What happens on every (node, channel, link): whether the lane travels
 *        there, which schedule governs it, when the next session is due and how
 *        far behind the node is.
 * @param {jsonb} pSearch - Full-text search criteria
 * @param {jsonb} pFilter - Column-level filter conditions
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Sort specification
 * @return {SETOF api.mq_plan} - Matching plan rows
 * @since 1.2.18
 */
CREATE OR REPLACE FUNCTION api.list_mq_plan (
  pSearch       jsonb default null,
  pFilter       jsonb default null,
  pLimit        integer default null,
  pOffSet       integer default null,
  pOrderBy      jsonb default null
) RETURNS       SETOF api.mq_plan
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'mq_plan', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
