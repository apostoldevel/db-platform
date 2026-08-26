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
 * @return {bigint} - Session identifier
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION api.mq_session_open (
  pPeer         text,
  pChannel      text,
  pDirection    text
) RETURNS       bigint
AS $$
  SELECT mq.session_open(api.mq_peer_id(pPeer), api.mq_channel_id(pChannel), pDirection);
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
