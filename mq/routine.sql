--------------------------------------------------------------------------------
-- MQ --------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- CHANNEL ---------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Create a message channel.
 * @param {text} pCode - Channel code, unique and stable
 * @param {text} pName - Human-readable name
 * @param {text} pDirection - edge-to-hub, hub-to-edge or both
 * @param {integer} pPriority - Lane priority 1..3
 * @param {text} pDelivery - at-most-once or at-least-once
 * @param {interval} pLifetime - How long a message stays worth delivering (NULL never expires)
 * @param {boolean} pCompaction - Keep only the last message per key
 * @param {interval} pRetention - How long delivered messages are kept (NULL forever)
 * @param {text} pDescription - What travels here and why it is a lane of its own
 * @return {integer} - Channel identifier
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.create_channel (
  pCode         text,
  pName         text,
  pDirection    text DEFAULT 'both',
  pPriority     integer DEFAULT 2,
  pDelivery     text DEFAULT 'at-least-once',
  pLifetime     interval DEFAULT null,
  pCompaction   boolean DEFAULT false,
  pRetention    interval DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS       integer
AS $$
DECLARE
  nId           integer;
BEGIN
  INSERT INTO mq.channel (code, name, description, direction, priority, delivery, lifetime, compaction, retention)
  VALUES (pCode, pName, pDescription, coalesce(pDirection, 'both'), coalesce(pPriority, 2),
          coalesce(pDelivery, 'at-least-once'), pLifetime, coalesce(pCompaction, false), pRetention)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Change a channel. NULL leaves the current value in place.
 * @param {integer} pId - Channel identifier
 * @param {text} pName - New name
 * @param {text} pDirection - New direction
 * @param {integer} pPriority - New priority
 * @param {text} pDelivery - New delivery guarantee
 * @param {interval} pLifetime - New lifetime
 * @param {boolean} pCompaction - New compaction setting
 * @param {interval} pRetention - New retention
 * @param {boolean} pEnabled - Whether the channel is in service
 * @param {text} pDescription - New description
 * @return {void}
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.edit_channel (
  pId           integer,
  pName         text DEFAULT null,
  pDirection    text DEFAULT null,
  pPriority     integer DEFAULT null,
  pDelivery     text DEFAULT null,
  pLifetime     interval DEFAULT null,
  pCompaction   boolean DEFAULT null,
  pRetention    interval DEFAULT null,
  pEnabled      boolean DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS       void
AS $$
BEGIN
  -- lifetime and retention are nullable BY MEANING -- NULL is "never expires"
  -- and "keep forever", the values an evidential channel wants. So they cannot
  -- be cleared through this function, and clearing one is a deliberate UPDATE.
  -- Silently reading NULL as "leave alone" for one column and as "clear" for
  -- another is how an evidential channel quietly acquires an expiry.

  UPDATE mq.channel
     SET name = coalesce(pName, name),
         description = coalesce(pDescription, description),
         direction = coalesce(pDirection, direction),
         priority = coalesce(pPriority, priority),
         delivery = coalesce(pDelivery, delivery),
         lifetime = coalesce(pLifetime, lifetime),
         compaction = coalesce(pCompaction, compaction),
         retention = coalesce(pRetention, retention),
         enabled = coalesce(pEnabled, enabled),
         updated = Now()
   WHERE id = pId;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ERR-40000: Channel "%" not found.', pId;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Find a channel by code.
 * @param {text} pCode - Channel code
 * @return {integer} - Channel identifier, NULL when there is no such channel
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.get_channel (
  pCode     text
) RETURNS   integer
AS $$
  SELECT id FROM mq.channel WHERE code = pCode;
$$ LANGUAGE SQL STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PEER ------------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Register a node of the exchange.
 * @param {text} pCode - Node code, unique and stable
 * @param {text} pName - Human-readable name
 * @param {text} pRole - hub or edge
 * @param {boolean} pLocal - Whether this row is the instance the database belongs to
 * @param {uuid} pArea - Area incoming facts from this node are written into
 * @param {text} pKey - Public key verifying this node's packet signature
 * @return {integer} - Node identifier
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.create_peer (
  pCode     text,
  pName     text,
  pRole     text,
  pLocal    boolean DEFAULT false,
  pArea     uuid DEFAULT null,
  pKey      text DEFAULT null
) RETURNS   integer
AS $$
DECLARE
  nId       integer;
BEGIN
  INSERT INTO mq.peer (code, name, role, local, area, key)
  VALUES (pCode, pName, pRole, coalesce(pLocal, false), pArea, pKey)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Change a node. NULL leaves the current value in place.
 * @param {integer} pId - Node identifier
 * @param {text} pName - New name
 * @param {text} pRole - New role
 * @param {uuid} pArea - New area
 * @param {text} pKey - New public key
 * @param {boolean} pEnabled - Whether exchange with the node is in service
 * @return {void}
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.edit_peer (
  pId       integer,
  pName     text DEFAULT null,
  pRole     text DEFAULT null,
  pArea     uuid DEFAULT null,
  pKey      text DEFAULT null,
  pEnabled  boolean DEFAULT null
) RETURNS   void
AS $$
BEGIN
  UPDATE mq.peer
     SET name = coalesce(pName, name),
         role = coalesce(pRole, role),
         area = coalesce(pArea, area),
         key = coalesce(pKey, key),
         enabled = coalesce(pEnabled, enabled),
         updated = Now()
   WHERE id = pId;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ERR-40000: Node "%" not found.', pId;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Find a node by code.
 * @param {text} pCode - Node code
 * @return {integer} - Node identifier, NULL when there is no such node
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.get_peer (
  pCode     text
) RETURNS   integer
AS $$
  SELECT id FROM mq.peer WHERE code = pCode;
$$ LANGUAGE SQL STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief The node this database belongs to.
 * @return {integer} - Identifier of the local node
 * @throws ERR-40000 - When no local node is registered
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.local_peer()
RETURNS     integer
AS $$
DECLARE
  nId       integer;
BEGIN
  SELECT id INTO nId FROM mq.peer WHERE local;

  IF NOT FOUND THEN
    -- Publishing stamps a source into every message, so a database that does
    -- not know which node it is cannot publish at all. Say that, rather than
    -- writing NULL into the log and discovering it at the far end.
    RAISE EXCEPTION 'ERR-40000: The local node is not registered: mq.create_peer(<code>, <name>, <role>, true).';
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- LINK ------------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Register a kind of link.
 * @param {text} pCode - Link code, unique and stable
 * @param {text} pName - Human-readable name
 * @param {boolean} pMetered - Whether traffic is billed by volume
 * @param {integer} pThreshold - Lowest lane priority this link admits (1..3)
 * @param {text} pDescription - What this kind of link is and what it costs
 * @return {integer} - Link identifier
 * @since 1.2.18
 */
CREATE OR REPLACE FUNCTION mq.create_link (
  pCode         text,
  pName         text,
  pMetered      boolean DEFAULT false,
  pThreshold    integer DEFAULT 3,
  pDescription  text DEFAULT null
) RETURNS       integer
AS $$
DECLARE
  nId           integer;
BEGIN
  INSERT INTO mq.link (code, name, description, metered, threshold)
  VALUES (pCode, pName, pDescription, coalesce(pMetered, false), coalesce(pThreshold, 3))
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Change a kind of link. NULL leaves the current value in place.
 * @param {integer} pId - Link identifier
 * @param {text} pName - New name
 * @param {boolean} pMetered - Whether traffic is billed by volume
 * @param {integer} pThreshold - New threshold
 * @param {boolean} pEnabled - Whether the link kind is in service
 * @param {text} pDescription - New description
 * @return {void}
 * @since 1.2.18
 */
CREATE OR REPLACE FUNCTION mq.edit_link (
  pId           integer,
  pName         text DEFAULT null,
  pMetered      boolean DEFAULT null,
  pThreshold    integer DEFAULT null,
  pEnabled      boolean DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS       void
AS $$
BEGIN
  UPDATE mq.link
     SET name = coalesce(pName, name),
         description = coalesce(pDescription, description),
         metered = coalesce(pMetered, metered),
         threshold = coalesce(pThreshold, threshold),
         enabled = coalesce(pEnabled, enabled),
         updated = Now()
   WHERE id = pId;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ERR-40000: Link "%" not found.', pId;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Find a kind of link by code.
 * @param {text} pCode - Link code
 * @return {integer} - Link identifier, NULL when there is no such link
 * @since 1.2.18
 */
CREATE OR REPLACE FUNCTION mq.get_link (
  pCode     text
) RETURNS   integer
AS $$
  SELECT id FROM mq.link WHERE code = pCode;
$$ LANGUAGE SQL STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SCHEDULE --------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Set the session schedule on a pair, creating or replacing the row.
 * @param {integer} pChannel - Channel
 * @param {integer} pLink - Kind of link
 * @param {interval} pPeriod - How often a session opens
 * @param {integer} pBatch - Largest number of messages per session
 * @param {interval} pTimeout - How long a session may stay open
 * @param {interval} pBackoff - First delay after a failed session
 * @param {interval} pCatchup - Interval used while the node is behind
 * @param {integer} pPeer - Node this row applies to; NULL is the default for every node
 * @return {integer} - Schedule identifier
 * @since 1.2.18
 */
CREATE OR REPLACE FUNCTION mq.set_schedule (
  pChannel      integer,
  pLink         integer,
  pPeriod       interval,
  pBatch        integer DEFAULT null,
  pTimeout      interval DEFAULT null,
  pBackoff      interval DEFAULT null,
  pCatchup      interval DEFAULT null,
  pPeer         integer DEFAULT null
) RETURNS       integer
AS $$
DECLARE
  nId           integer;
BEGIN
  -- ON CONFLICT cannot serve here: the uniqueness is carried by two PARTIAL
  -- indexes (one for the default row, one for the per-node row), and an
  -- inference clause matches neither. The read-then-write is safe under the
  -- indexes -- a concurrent insert loses on the index, it does not duplicate.

  UPDATE mq.schedule
     SET period = pPeriod,
         batch = coalesce(pBatch, batch),
         timeout = coalesce(pTimeout, timeout),
         backoff = coalesce(pBackoff, backoff),
         catchup = coalesce(pCatchup, catchup),
         updated = Now()
   WHERE channel = pChannel
     AND link = pLink
     AND peer IS NOT DISTINCT FROM pPeer
  RETURNING id INTO nId;

  IF NOT FOUND THEN
    INSERT INTO mq.schedule (peer, channel, link, period, batch, timeout, backoff, catchup)
    VALUES (pPeer, pChannel, pLink, pPeriod, coalesce(pBatch, 100),
            coalesce(pTimeout, interval '5 minutes'), coalesce(pBackoff, interval '1 minute'),
            coalesce(pCatchup, interval '30 seconds'))
    RETURNING id INTO nId;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Remove a schedule row.
 * @param {integer} pChannel - Channel
 * @param {integer} pLink - Kind of link
 * @param {integer} pPeer - Node the row applies to; NULL is the default row
 * @return {boolean} - Whether a row was removed
 * @since 1.2.18
 */
CREATE OR REPLACE FUNCTION mq.delete_schedule (
  pChannel      integer,
  pLink         integer,
  pPeer         integer DEFAULT null
) RETURNS       boolean
AS $$
BEGIN
  DELETE FROM mq.schedule
   WHERE channel = pChannel
     AND link = pLink
     AND peer IS NOT DISTINCT FROM pPeer;

  RETURN FOUND;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief The schedule in force for a node on a pair: the row naming the node
 *        when there is one, the default row otherwise.
 * @param {integer} pChannel - Channel
 * @param {integer} pLink - Kind of link
 * @param {integer} pPeer - Node asking; NULL considers only the default row
 * @return {record} - id, period, batch, timeout, backoff, catchup, scope
 * @since 1.2.18
 */
CREATE OR REPLACE FUNCTION mq.get_schedule (
  pChannel      integer,
  pLink         integer,
  pPeer         integer DEFAULT null
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
  -- Written in SQL rather than PL/pgSQL deliberately. A RETURNS TABLE in
  -- PL/pgSQL declares OUT variables with these very names, and every unqualified
  -- reference to a column called period or batch inside the body would then
  -- resolve to the variable instead of the column -- ambiguous at best, silently
  -- wrong at worst. A SQL body has no such variables at all.
  SELECT s.id, s.period, s.batch, s.timeout, s.backoff, s.catchup,
         CASE WHEN s.peer IS NULL THEN 'default' ELSE 'peer' END
    FROM mq.schedule s
   WHERE s.channel = pChannel
     AND s.link = pLink
     AND (s.peer IS NULL OR s.peer = pPeer)
   ORDER BY s.peer NULLS LAST
   LIMIT 1;
$$ LANGUAGE SQL STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief How far a node is behind us on a channel: what we have published and
 *        it has not confirmed.
 * @param {integer} pPeer - Node on the other end
 * @param {integer} pChannel - Channel
 * @return {bigint} - Number of messages outstanding, 0 when the node is level
 * @since 1.2.18
 */
CREATE OR REPLACE FUNCTION mq.depth (
  pPeer         integer,
  pChannel      integer
) RETURNS       bigint
AS $$
  SELECT coalesce((SELECT max(m.serial)
                     FROM mq.message m
                    WHERE m.channel = pChannel
                      AND m.source = (SELECT p.id FROM mq.peer p WHERE p.local)), 0)
       - coalesce((SELECT w.sent
                     FROM mq.watermark w
                    WHERE w.peer = pPeer AND w.channel = pChannel), 0);
$$ LANGUAGE SQL STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief When the next sending session on a pair is due.
 * @param {integer} pPeer - Node on the other end
 * @param {integer} pChannel - Channel
 * @param {integer} pLink - Kind of link the process is connected over
 * @return {timestamptz} - When to open the next session; NULL when this lane
 *                         does not travel over this link at all
 * @since 1.2.18
 */
CREATE OR REPLACE FUNCTION mq.next_session (
  pPeer         integer,
  pChannel      integer,
  pLink         integer
) RETURNS       timestamptz
AS $$
DECLARE
  r             record;
  s             record;
  nFailed       integer;
  tLast         timestamptz;
BEGIN
  -- Does this lane travel here at all? Four ways it may not, and they are asked
  -- in this order so the answer to "why is nothing moving" is the first one
  -- true rather than whichever the query happened to notice.

  SELECT c.priority, c.enabled AS channelenabled, l.threshold, l.enabled AS linkenabled,
         p.enabled AS peerenabled, p.local
    INTO r
    FROM mq.channel c, mq.link l, mq.peer p
   WHERE c.id = pChannel AND l.id = pLink AND p.id = pPeer;

  IF NOT FOUND OR r.local OR NOT r.peerenabled OR NOT r.channelenabled OR NOT r.linkenabled THEN
    RETURN null;
  END IF;

  IF r.priority > r.threshold THEN
    RETURN null;
  END IF;

  SELECT * INTO s FROM mq.get_schedule(pChannel, pLink, pPeer);

  IF NOT FOUND THEN
    RETURN null;
  END IF;

  -- An open session holds the lane: nothing new is due until it has either
  -- closed or outlived its timeout.

  SELECT max(x.started) INTO tLast
    FROM mq.session x
   WHERE x.peer = pPeer AND x.channel = pChannel AND x.direction = 'send' AND x.finished IS NULL;

  IF tLast IS NOT NULL THEN
    RETURN tLast + s.timeout;
  END IF;

  SELECT max(x.finished) INTO tLast
    FROM mq.session x
   WHERE x.peer = pPeer AND x.channel = pChannel AND x.direction = 'send';

  IF tLast IS NULL THEN
    RETURN Now();
  END IF;

  -- Consecutive failures since the last session that carried something. A
  -- partial session counts as progress and clears the backoff: something did
  -- get through, and on this link a session broken in the middle is ordinary
  -- weather rather than a fault.

  SELECT count(*) INTO nFailed
    FROM mq.session x
   WHERE x.peer = pPeer AND x.channel = pChannel AND x.direction = 'send'
     AND x.result = 'failed'
     AND x.started > coalesce((SELECT max(y.started)
                                 FROM mq.session y
                                WHERE y.peer = pPeer AND y.channel = pChannel
                                  AND y.direction = 'send' AND y.result IN ('ok', 'partial')), '-infinity');

  IF nFailed > 0 THEN
    -- Doubling, capped by the period: the schedule is already the longest wait
    -- that buys anything. least() also keeps the multiplication away from the
    -- range where an interval overflows.
    RETURN tLast + least(s.backoff * power(2, least(nFailed, 16) - 1), s.period);
  END IF;

  -- Behind: the catch-up interval, not the ordinary one. Breaks in service run
  -- to twelve hours on this link, so catching up is the ordinary path.

  IF mq.depth(pPeer, pChannel) > 0 THEN
    RETURN tLast + s.catchup;
  END IF;

  RETURN tLast + s.period;
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- BINDING ---------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Bind an entity class to a channel.
 * @param {integer} pChannel - Channel the class publishes to
 * @param {uuid} pClass - Entity class
 * @param {uuid} pAction - Action that publishes (NULL binds every action)
 * @param {text} pType - Message type the receiving side looks up in mq.ingest
 * @param {text} pRoute - Routing key
 * @param {jsonb} pProjection - Field names that travel, as a JSON array
 * @return {integer} - Binding identifier
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.create_binding (
  pChannel      integer,
  pClass        uuid,
  pAction       uuid,
  pType         text,
  pRoute        text,
  pProjection   jsonb DEFAULT null
) RETURNS       integer
AS $$
DECLARE
  nId           integer;
BEGIN
  INSERT INTO mq.binding (channel, class, action, type, route, projection)
  VALUES (pChannel, pClass, pAction, pType, pRoute, pProjection)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PUBLISH ---------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Publish a message on a channel.
 * @param {integer} pChannel - Channel
 * @param {text} pType - Message type
 * @param {jsonb} pPayload - Message body
 * @param {text} pKey - Compaction key (NULL keeps the message out of compaction)
 * @param {text} pRoute - Routing key
 * @param {text} pSignature - Signature of this node over the message
 * @return {bigint} - Serial issued within the channel
 * @throws ERR-40000 - When the channel does not exist or is out of service
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.publish (
  pChannel      integer,
  pType         text,
  pPayload      jsonb,
  pKey          text DEFAULT null,
  pRoute        text DEFAULT null,
  pSignature    text DEFAULT null
) RETURNS       bigint
AS $$
DECLARE
  nSerial       bigint;
  iLifetime     interval;
BEGIN
  -- The counter is taken by UPDATE ... RETURNING rather than from a sequence,
  -- and the difference matters at the far end: a sequence hands out a number
  -- that a rollback then abandons, and a gap in the log is exactly how the
  -- receiving side detects a truncated tail. Here a rollback takes the number
  -- back with it. The row lock also serialises publication on the channel,
  -- which is what makes the order well defined.

  UPDATE mq.channel
     SET serial = serial + 1,
         updated = Now()
   WHERE id = pChannel
     AND enabled
  RETURNING serial, lifetime INTO nSerial, iLifetime;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ERR-40000: Channel "%" does not exist or is out of service.', pChannel;
  END IF;

  INSERT INTO mq.message (source, channel, serial, type, route, key, payload, signature, expires)
  VALUES (mq.local_peer(), pChannel, nSerial, pType, pRoute, pKey, pPayload, pSignature,
          CASE WHEN iLifetime IS NULL THEN null ELSE Now() + iLifetime END);

  RETURN nSerial;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Publish an object through whatever bindings its class has.
 * @param {uuid} pObject - Object being published
 * @param {uuid} pAction - Action that fired
 * @param {jsonb} pPayload - Message body; NULL builds one from the object by the binding's projection
 * @return {integer} - Number of messages published
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.publish_object (
  pObject   uuid,
  pAction   uuid DEFAULT null,
  pPayload  jsonb DEFAULT null
) RETURNS   integer
AS $$
DECLARE
  r         record;
  jPayload  jsonb;
  nCount    integer := 0;
BEGIN
  FOR r IN
    SELECT b.channel, b.type, b.route, b.projection
      FROM mq.binding b
     INNER JOIN db.object o ON o.class = b.class
     WHERE o.id = pObject
       AND (b.action IS NULL OR b.action = pAction)
       AND b.enabled
  LOOP
    -- No body and no projection is refused rather than filled with whatever
    -- db.object happens to hold. A quietly impoverished message travels to the
    -- far node and becomes a "fact" there, indistinguishable from a complete
    -- one -- and it is discovered, if ever, while reconstructing an incident.
    -- A loud refusal is fixed once, when the entity is bound.

    IF pPayload IS NULL AND r.projection IS NULL THEN
      RAISE EXCEPTION 'ERR-40000: Binding of message type "%" has no projection and no body was given.', r.type
        USING HINT = 'Pass the body from the entity''s own event, or give the binding a projection.';
    END IF;

    jPayload := coalesce(pPayload, mq.object_payload(pObject, r.projection));

    PERFORM mq.publish(r.channel, r.type, jPayload, pObject::text, r.route);

    nCount := nCount + 1;
  END LOOP;

  RETURN nCount;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Build a message body from an object by a projection.
 * @param {uuid} pObject - Object
 * @param {jsonb} pProjection - Field names that travel, as a JSON array (NULL takes all of them)
 * @return {jsonb} - Message body
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.object_payload (
  pObject       uuid,
  pProjection   jsonb DEFAULT null
) RETURNS       jsonb
AS $$
  -- Only what db.object itself holds. An entity with fields of its own passes
  -- its body in, because the transport has no business knowing its table --
  -- and because those fields, not these, are what a hash preimage may read:
  -- owner, suid and the dates below are assigned by the receiving side's own
  -- trigger and cannot match across two nodes.
  SELECT jsonb_object_agg(e.key, e.value)
    FROM db.object o, jsonb_each(to_jsonb(o)) e
   WHERE o.id = pObject
     AND (pProjection IS NULL OR e.key IN (SELECT jsonb_array_elements_text(pProjection)));
$$ LANGUAGE SQL STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SEND ------------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Messages a node has not confirmed yet, oldest first.
 * @param {integer} pPeer - Node the messages are for
 * @param {integer} pChannel - Channel
 * @param {integer} pLimit - Batch size
 * @return {SETOF mq.message} - Messages to hand over
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.queue (
  pPeer     integer,
  pChannel  integer,
  pLimit    integer DEFAULT 100
) RETURNS   SETOF mq.message
AS $$
  SELECT m.*
    FROM mq.message m
   WHERE m.channel = pChannel
     AND m.source = mq.local_peer()
     AND m.serial > coalesce((SELECT w.sent FROM mq.watermark w WHERE w.peer = pPeer AND w.channel = pChannel), 0)
     AND (m.expires IS NULL OR m.expires > Now())
   ORDER BY m.serial
   LIMIT coalesce(pLimit, 100);
$$ LANGUAGE SQL STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Record that a node confirmed our messages up to a serial.
 * @param {integer} pPeer - Node that confirmed
 * @param {integer} pChannel - Channel
 * @param {bigint} pSerial - Serial the node reports as accepted
 * @param {text} pFloor - What the peer did with our floor: honoured, refused or none
 * @return {void}
 * @throws ERR-40000 - When the peer is stuck and the session declared no floor twice running
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.confirm (
  pPeer     integer,
  pChannel  integer,
  pSerial   bigint,
  pFloor    text DEFAULT null
) RETURNS   void
AS $$
DECLARE
  nStalled  integer;
  bGap      boolean;
  bPending  boolean;
BEGIN
  -- greatest(), so a late or repeated report cannot walk the cursor backwards
  -- and cause the same batch to be sent for a third time.

  INSERT INTO mq.watermark AS w (peer, channel, sent)
  VALUES (pPeer, pChannel, pSerial)
  ON CONFLICT (peer, channel) DO UPDATE
     SET sent = greatest(w.sent, excluded.sent),
         updated = Now();

  UPDATE mq.peer SET seen = Now() WHERE id = pPeer;

  -- A session that never sends the floor cannot be detected from inside
  -- mq.advance -- it is not called. It CAN be detected here, because confirm is
  -- the one step a session cannot skip: without it the sender never learns the
  -- peer's cursor. And the failure has exactly one signature -- the peer
  -- reports a cursor sitting right below a serial IT CANNOT CROSS BY ITSELF
  -- (expired here, or gone from the log altogether) while deliverable messages
  -- wait above it.
  --
  -- Once is a dropped link. Twice in a row on the same pair is a protocol step
  -- that is not being sent, and the exchange would otherwise re-send the same
  -- tail every session, for ever, on a metered link. So the second one is
  -- refused rather than logged -- a failing session gets looked at, a growing
  -- number in a table does not.

  SELECT NOT EXISTS (SELECT FROM mq.message
                      WHERE channel = pChannel AND source = mq.local_peer()
                        AND serial = pSerial + 1
                        AND (expires IS NULL OR expires > Now()))
    INTO bGap;

  SELECT EXISTS (SELECT FROM mq.message
                  WHERE channel = pChannel AND source = mq.local_peer()
                    AND serial > pSerial
                    AND (expires IS NULL OR expires > Now()))
    INTO bPending;

  IF bGap AND bPending AND coalesce(pFloor, 'none') = 'refused' THEN

    -- The peer DID get a floor and refused it, which means the batch behind it
    -- did not arrive in full. On this link that is weather, not a fault: the
    -- session did everything right and the next window will carry the rest.
    -- Counting it as a stalled session would fire the guard below precisely
    -- when the protocol is working as designed, and the message would accuse
    -- the process of skipping a step it had just performed.

    -- stalled is cleared, not merely left alone: a refusal is PROOF that the
    -- session does declare a floor -- the peer had one to refuse. Leaving the
    -- counter standing would let the sequence "stall, broken batch, real
    -- omission" raise on the first real omission instead of the second, which
    -- is the same false accusation this branch exists to prevent.

    UPDATE mq.watermark
       SET refused = refused + 1,
           stalled = 0,
           updated = Now()
     WHERE peer = pPeer AND channel = pChannel;

  ELSIF bGap AND bPending THEN
    UPDATE mq.watermark
       SET stalled = stalled + 1
     WHERE peer = pPeer AND channel = pChannel
    RETURNING stalled INTO nStalled;

    -- coalesce, not a bare comparison: the row is created by the INSERT above,
    -- and this reads its counter back. Should these two ever be reordered, a
    -- missing row would leave nStalled NULL, and NULL <> 1 would raise on the
    -- FIRST confirmation of a pair -- an exception on a healthy session, which
    -- is the failure this whole guard is built to avoid.

    IF coalesce(nStalled, 1) <= 1 THEN
      PERFORM pg_notify('mq_stalled', json_build_object('peer', pPeer, 'channel', pChannel, 'serial', pSerial)::text);
    ELSE
      RAISE EXCEPTION 'ERR-40000: Node "%" is stuck below serial % on channel % and the session is not declaring a floor.', pPeer, pSerial + 1, pChannel
        USING HINT = 'Call mq.floor after the batch and hand the result to mq.advance on the receiving side; if the floor was refused, pass that back to mq.confirm.';
    END IF;
  ELSE
    UPDATE mq.watermark
       SET stalled = 0
     WHERE peer = pPeer AND channel = pChannel AND stalled <> 0;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RECEIVE ---------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Register a reception handler for a message type.
 * @param {text} pType - Message type
 * @param {text} pHandler - Function name, called with the message as jsonb
 * @param {integer} pChannel - Channel the type is expected on (NULL accepts it anywhere)
 * @return {void}
 * @throws ERR-40000 - When no such function exists with the expected signature
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.register_ingest (
  pType     text,
  pHandler  text,
  pChannel  integer DEFAULT null
) RETURNS   void
AS $$
BEGIN
  -- Checked here, so a typo fails at registration rather than at the first
  -- arrival -- when the failure would look like a message being refused for a
  -- reason of its own, and would be filed as one.

  IF to_regprocedure(pHandler || '(jsonb)') IS NULL THEN
    RAISE EXCEPTION 'ERR-40000: Ingest handler "%(jsonb)" does not exist.', pHandler;
  END IF;

  INSERT INTO mq.ingest AS i (type, handler, channel)
  VALUES (pType, pHandler, pChannel)
  ON CONFLICT (type) DO UPDATE
     SET handler = excluded.handler,
         channel = excluded.channel,
         enabled = true,
         updated = Now();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Remove a reception handler.
 * @param {text} pType - Message type
 * @return {void}
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.unregister_ingest (
  pType     text
) RETURNS   void
AS $$
BEGIN
  DELETE FROM mq.ingest WHERE type = pType;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Park a message that was refused, with the reason and the attempt count.
 * @param {integer} pSource - Node that published it
 * @param {integer} pChannel - Channel
 * @param {bigint} pSerial - Serial
 * @param {text} pReason - Why it was refused
 * @return {void}
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.park (
  pSource   integer,
  pChannel  integer,
  pSerial   bigint,
  pReason   text
) RETURNS   void
AS $$
BEGIN
  INSERT INTO mq.dead AS d (source, channel, serial, reason)
  VALUES (pSource, pChannel, pSerial, pReason)
  ON CONFLICT (source, channel, serial) DO UPDATE
     SET reason = excluded.reason,
         attempt = d.attempt + 1,
         state = 'parked',
         updated = Now();

  PERFORM pg_notify('mq_dead', json_build_object('source', pSource, 'channel', pChannel, 'serial', pSerial, 'reason', pReason)::text);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Call the registered handler for a message that is already in the log.
 * @param {integer} pSource - Node that published it
 * @param {integer} pChannel - Channel
 * @param {bigint} pSerial - Serial
 * @return {text} - NULL when the handler accepted it, the reason for refusal otherwise
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.apply (
  pSource   integer,
  pChannel  integer,
  pSerial   bigint
) RETURNS   text
AS $$
DECLARE
  m         mq.message%rowtype;
  h         mq.ingest%rowtype;
  vReason   text;
BEGIN
  SELECT * INTO m FROM mq.message WHERE source = pSource AND channel = pChannel AND serial = pSerial;

  IF NOT FOUND THEN
    RETURN format('message %s/%s/%s is not in the log', pSource, pChannel, pSerial);
  END IF;

  SELECT * INTO h FROM mq.ingest WHERE type = m.type;

  -- A type with no handler is refused, never applied by a general fallback and
  -- never dropped. This is the whole point of the registry: reception is a
  -- path per class of message, and the absence of one is a refusal with a
  -- reason, not silence.

  IF NOT FOUND THEN
    RETURN format('no ingest handler registered for message type "%s"', m.type);
  END IF;

  IF NOT h.enabled THEN
    RETURN format('ingest handler for message type "%s" is out of service', m.type);
  END IF;

  IF h.channel IS NOT NULL AND h.channel <> pChannel THEN
    RETURN format('message type "%s" is not expected on channel %s', m.type, pChannel);
  END IF;

  BEGIN
    EXECUTE format('SELECT %s($1)', h.handler) USING to_jsonb(m);
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS vReason = MESSAGE_TEXT;
    RETURN vReason;
  END;

  RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Accept an incoming message: write it to the log, then apply it.
 * @param {integer} pSource - Node that published it
 * @param {integer} pChannel - Channel
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
CREATE OR REPLACE FUNCTION mq.accept (
  pSource       integer,
  pChannel      integer,
  pSerial       bigint,
  pType         text,
  pPayload      jsonb,
  pKey          text DEFAULT null,
  pRoute        text DEFAULT null,
  pSignature    text DEFAULT null,
  pCreated      timestamptz DEFAULT null
) RETURNS       boolean
AS $$
DECLARE
  vReason       text;
BEGIN
  IF pSource = mq.local_peer() THEN
    RAISE EXCEPTION 'ERR-40000: A node cannot accept its own message as incoming.';
  END IF;

  -- Writing the message first, applying second, is deliberate: the log records
  -- WHAT ARRIVED, and that is true whether or not the handler could make sense
  -- of it. A refusal is recorded next to it, not instead of it -- the absence
  -- of a serial in the log has to keep meaning "did not arrive, ask again".
  --
  -- ON CONFLICT DO NOTHING is the idempotency "at least once" delivery rests
  -- on: the repeat changes nothing and, because the insert reports it, the
  -- handler is not called a second time. Applying somebody else's fact twice
  -- is not a duplicate row, it is a second record in a journal.

  INSERT INTO mq.message (source, channel, serial, type, route, key, payload, signature, created, received)
  VALUES (pSource, pChannel, pSerial, pType, pRoute, pKey, pPayload, pSignature, coalesce(pCreated, Now()), Now())
  ON CONFLICT (source, channel, serial) DO NOTHING;

  IF NOT FOUND THEN
    UPDATE mq.peer SET seen = Now() WHERE id = pSource;

    RETURN NOT EXISTS (SELECT FROM mq.dead
                        WHERE source = pSource AND channel = pChannel AND serial = pSerial
                          AND state = 'parked');
  END IF;

  UPDATE mq.peer SET seen = Now() WHERE id = pSource;

  vReason := mq.apply(pSource, pChannel, pSerial);

  IF vReason IS NOT NULL THEN
    PERFORM mq.park(pSource, pChannel, pSerial, vReason);
  END IF;

  -- The cursor moves in both cases, and only as far as the log is unbroken.
  -- A parked message does not hold it back: its row is in the log, so it is
  -- accounted for and visible. A MISSING serial does hold it back, so the
  -- message that never arrived is asked for again at the next session.

  PERFORM FROM mq.advance(pSource, pChannel);

  RETURN vReason IS NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Try a parked message again.
 * @param {integer} pSource - Node that published it
 * @param {integer} pChannel - Channel
 * @param {bigint} pSerial - Serial
 * @return {boolean} - TRUE when it applied this time
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.retry (
  pSource   integer,
  pChannel  integer,
  pSerial   bigint
) RETURNS   boolean
AS $$
DECLARE
  vReason   text;
BEGIN
  vReason := mq.apply(pSource, pChannel, pSerial);

  IF vReason IS NULL THEN
    UPDATE mq.dead
       SET state = 'resolved',
           attempt = attempt + 1,
           updated = Now()
     WHERE source = pSource AND channel = pChannel AND serial = pSerial;
  ELSE
    PERFORM mq.park(pSource, pChannel, pSerial, vReason);
  END IF;

  PERFORM FROM mq.advance(pSource, pChannel);

  RETURN vReason IS NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- WATERMARK -------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief The serial below which a node will never be sent anything again, and on what grounds.
 * @param {integer} pPeer - Node the messages are for
 * @param {integer} pChannel - Channel
 * @param {bigint} pUpto - Last serial handed over in this session (NULL when nothing was)
 * @return {TABLE} - floor bigint, kind text ('batch' or 'channel')
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.floor (
  pPeer         integer,
  pChannel      integer,
  pUpto         bigint DEFAULT null
) RETURNS TABLE (
  floor         bigint,
  kind          text
)
AS $$
DECLARE
  nSent         bigint;
  nNext         bigint;
  nIssued       bigint;
BEGIN
  -- Only the SENDER can answer this. To the receiver, a serial that never
  -- arrives looks the same whether it was compacted away, expired on the shelf,
  -- or is still sitting in a queue waiting for the next window -- and the three
  -- need opposite responses. Without an answer the receiving cursor stops at
  -- the first gap forever, the sender's cursor never moves either, and every
  -- session hands over the whole tail again. On a per-megabyte link that is not
  -- an inefficiency, it is a bill.
  --
  -- The KIND travels with the number because the two answers below are
  -- different claims and the receiver must weigh them differently. Returning
  -- one bigint for both -- which is what this function did at first -- lets a
  -- claim the receiver can check be honoured as one it cannot.

  IF pUpto IS NOT NULL THEN

    -- Claim "batch": everything at or below pUpto either travelled in the batch
    -- that just went, or will never travel. mq.queue hands over every
    -- deliverable serial in order, so pUpto is by construction the LAST
    -- DELIVERABLE message of that batch -- which gives the receiver a way to
    -- check the claim: on a session that completed it holds pUpto itself.
    --
    -- Computed without a batch the answer is weaker and, taken alone, wrong in
    -- the case that matters: before anything is sent, the first deliverable
    -- serial is still pending, so the floor equals the cursor and moves
    -- nothing. That is the shape this function had when it was written, and
    -- the test for an expired message in the middle caught it.

    RETURN QUERY SELECT pUpto, 'batch'::text;
    RETURN;
  END IF;

  SELECT coalesce(sent, 0) INTO nSent FROM mq.watermark WHERE peer = pPeer AND channel = pChannel;
  nSent := coalesce(nSent, 0);

  SELECT min(serial) INTO nNext
    FROM mq.message
   WHERE channel = pChannel
     AND source = mq.local_peer()
     AND serial > nSent
     AND (expires IS NULL OR expires > Now());

  -- Without a batch to point at, "everything below the first deliverable
  -- serial is gone" is a claim about the CHANNEL, not about anything the
  -- receiver was just handed -- so it is answered as one. Calling it "batch"
  -- would let it past the ownership check that kind is subject to, which is the
  -- one thing keeping a floor from stepping over records that never arrived.
  --
  -- READ THIS BEFORE RELYING ON THIS BRANCH: it is honest only BEFORE a batch
  -- goes out. In the natural order of a session -- queue, floor, advance -- the
  -- deliverable messages above `sent` have just been handed over and are
  -- sitting above the receiver's cursor, so the "channel" claim is refused
  -- there and this answer changes nothing. It is not dead code (a caller that
  -- asks before sending gets a true answer, and the branch below it carries the
  -- stuck channel), but a session must not be built on it.

  IF nNext IS NOT NULL THEN
    RETURN QUERY SELECT nNext - 1, 'channel'::text;
    RETURN;
  END IF;

  -- Claim "channel": below this serial the channel holds nothing at all any
  -- more. Nothing the receiver owns can confirm it -- by definition it owns
  -- nothing there -- so it is honoured only where there is nothing to skip
  -- over. This is the stuck channel, whose remaining serials are all gone, and
  -- the case where a floor matters most.

  SELECT serial INTO nIssued FROM mq.channel WHERE id = pChannel;

  RETURN QUERY SELECT greatest(coalesce(nIssued, 0), nSent), 'channel'::text;
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Move the reception cursor over the unbroken run, and over a floor the receiver can verify.
 * @param {integer} pSource - Node whose messages were received
 * @param {integer} pChannel - Channel
 * @param {bigint} pFloor - Serial the sender declares as never deliverable (NULL trusts nothing)
 * @param {text} pKind - Grounds of the claim: batch or channel
 * @return {TABLE} - received bigint, floor text ('honoured', 'refused' or 'none')
 * @throws ERR-40000 - When a floor is offered on a channel where nothing may disappear
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.advance (
  pSource       integer,
  pChannel      integer,
  pFloor        bigint DEFAULT null,
  pKind         text DEFAULT 'batch'
) RETURNS TABLE (
  received      bigint,
  floor         text
)
AS $$
DECLARE
  nReceived     bigint;
  nFrom         bigint;
  nEnd          bigint;
  nHighest      bigint;
  nSkipped      bigint := 0;
  nClaimed      bigint;
  bPerishable   boolean;
  vFloor        text := 'none';
BEGIN
  -- Every column below is qualified, and it is not style: RETURNS TABLE
  -- declares OUT variables named `received` and `floor`, which are exactly the
  -- names of the columns this function reads. An unqualified reference is
  -- ambiguous and PostgreSQL refuses it at run time -- in a function called
  -- from mq.accept, which is to say on the receiving path of every message.

  SELECT coalesce(w.received, 0) INTO nReceived
    FROM mq.watermark w
   WHERE w.peer = pSource AND w.channel = pChannel;

  nReceived := coalesce(nReceived, 0);
  nFrom := nReceived;

  -- A floor already at or below the cursor has nothing left to do, and saying
  -- "there was no floor" about it would be a lie with consequences: paired with
  -- a gap the receiver cannot cross, mq.confirm would read it as a session that
  -- never declared one and, on the second such report, accuse the process of
  -- skipping the step it had just performed.

  IF pFloor IS NOT NULL AND pFloor <= nReceived THEN
    vFloor := 'honoured';
  END IF;

  nClaimed := pFloor;

  IF pFloor IS NOT NULL AND pFloor > nReceived THEN

    -- A floor is a claim that something no longer exists, and it is not
    -- accepted on a channel where nothing is allowed to. On an evidential lane
    -- -- no compaction, no lifetime, no retention -- a sender declaring a floor
    -- is either broken or reaching for a hole in the middle of the record, and
    -- either way it is refused loudly rather than obeyed. Everything already
    -- accepted stays accepted: this refusal is a separate call from mq.accept.

    SELECT (c.compaction OR c.lifetime IS NOT NULL OR c.retention IS NOT NULL)
      INTO bPerishable
      FROM mq.channel c
     WHERE c.id = pChannel;

    IF NOT coalesce(bPerishable, false) THEN
      RAISE EXCEPTION 'ERR-40000: Channel "%" admits no floor: nothing published on it may disappear.', pChannel;
    END IF;

    -- THE CLAIM IS CHECKED, not taken on trust, and the check is local: no
    -- extra round trip, no signature, nothing on the wire.
    --
    -- "batch" is honoured only if this node actually holds pFloor. The sender
    -- computes it as the last deliverable message of the batch it handed over,
    -- so a session that ran to the end leaves that message here. A session that
    -- broke halfway does not -- and that is exactly the case the honest-looking
    -- claim would destroy: the batch [1,3,4,6..100] with 6..100 lost to a
    -- dropped link would move the cursor to 100 and those records would never
    -- be asked for again. On this channel, records means the ship's log.
    --
    -- "channel" cannot be checked that way -- the receiver owns nothing down
    -- there, that is the whole claim -- so it is honoured only when there is
    -- nothing above the cursor to jump over at all.

    IF pKind = 'batch' THEN
      PERFORM FROM mq.message m
       WHERE m.source = pSource AND m.channel = pChannel AND m.serial = pFloor;

      IF FOUND THEN
        vFloor := 'honoured';
      ELSE
        vFloor := 'refused';
        pFloor := null;
      END IF;
    ELSIF pKind = 'channel' THEN
      SELECT max(m.serial) INTO nHighest
        FROM mq.message m
       WHERE m.source = pSource AND m.channel = pChannel;

      IF coalesce(nHighest, 0) > nReceived THEN
        vFloor := 'refused';
        pFloor := null;
      ELSE
        vFloor := 'honoured';
      END IF;
    ELSE
      RAISE EXCEPTION 'ERR-40000: Unknown floor kind "%": expected batch or channel.', pKind;
    END IF;

    -- A REFUSAL IS THE MOST INFORMATIVE EVENT IN THE PROTOCOL, and it happens
    -- on the receiving side while the decision that depends on it is made on
    -- the sending side -- another database, reachable only over the wire. So it
    -- is counted here AND travels back in the result: without it, the sender
    -- sees a peer whose cursor did not move and cannot tell "your last batch
    -- broke halfway" from "you never sent the floor at all". Those two look
    -- identical and are fixed in opposite places -- one by waiting for the next
    -- window, the other by fixing the session -- so mq.confirm must be told
    -- which it was rather than guessing.

    IF vFloor = 'refused' THEN
      INSERT INTO mq.watermark AS w (peer, channel, refused)
      VALUES (pSource, pChannel, 1)
      ON CONFLICT (peer, channel) DO UPDATE
         SET refused = w.refused + 1,
             updated = Now();

      -- nClaimed, not pFloor: the refusal above sets pFloor to NULL, and it has
      -- to -- further down it works as the flag that no jump happens. But a
      -- refusal reported without the number that was claimed is half a signal:
      -- "we are at 4, they claimed 10" is a batch that broke, "we are at 4,
      -- they claimed 10000" is a sender that is broken, and only the second one
      -- stops being a question about the weather.

      PERFORM pg_notify('mq_refused', json_build_object('source', pSource, 'channel', pChannel, 'floor', nClaimed, 'kind', pKind)::text);
    END IF;
  END IF;

  IF pFloor IS NOT NULL AND pFloor > nReceived THEN

    -- Counted, not merely obeyed. The count separates a floor that skipped a
    -- hundred records from one that skipped nothing but already-delivered
    -- serials, and the two must never look alike in the log.

    SELECT (pFloor - nReceived) - count(*) INTO nSkipped
      FROM mq.message m
     WHERE m.source = pSource AND m.channel = pChannel
       AND m.serial > nReceived AND m.serial <= pFloor;

    nFrom := pFloor;
  END IF;

  -- Beyond the floor the ordinary rule applies again: the cursor moves only
  -- over an unbroken run starting at the very next serial. A gap that is NOT
  -- covered by a floor still holds it back -- so the message that never arrived
  -- is asked for at the next session instead of being stepped over.

  PERFORM FROM mq.message m
   WHERE m.source = pSource AND m.channel = pChannel AND m.serial = nFrom + 1;

  IF FOUND THEN
    SELECT min(m.serial) INTO nEnd
      FROM mq.message m
     WHERE m.source = pSource
       AND m.channel = pChannel
       AND m.serial > nFrom
       AND NOT EXISTS (SELECT FROM mq.message x
                        WHERE x.source = m.source AND x.channel = m.channel AND x.serial = m.serial + 1);
  ELSE
    nEnd := nFrom;
  END IF;

  IF nEnd <= nReceived AND nSkipped = 0 THEN
    RETURN QUERY SELECT nReceived, vFloor;
    RETURN;
  END IF;

  INSERT INTO mq.watermark AS w (peer, channel, received, floor, skipped)
  VALUES (pSource, pChannel, nEnd, coalesce(pFloor, 0), nSkipped)
  ON CONFLICT (peer, channel) DO UPDATE
     SET received = greatest(w.received, excluded.received),
         floor = greatest(w.floor, excluded.floor),
         skipped = w.skipped + excluded.skipped,
         updated = Now();

  IF nSkipped > 0 THEN
    PERFORM pg_notify('mq_floor', json_build_object('source', pSource, 'channel', pChannel, 'floor', pFloor, 'skipped', nSkipped)::text);
  END IF;

  RETURN QUERY SELECT nEnd, vFloor;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SESSION ---------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Open an exchange session.
 * @param {integer} pPeer - Node on the other end
 * @param {integer} pChannel - Channel
 * @param {text} pDirection - send or receive
 * @param {integer} pLink - Kind of link this session runs over
 * @return {bigint} - Session identifier
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.session_open (
  pPeer         integer,
  pChannel      integer,
  pDirection    text,
  pLink         integer DEFAULT null
) RETURNS       bigint
AS $$
DECLARE
  nId           bigint;
BEGIN
  -- A session whose process never came back would otherwise stay open for
  -- good. next_session releases the pair after the timeout, so it becomes due
  -- again and a second session opens beside the first -- and nobody closes the
  -- first, because there is nobody left to. The table then accumulates open
  -- sessions, and both the plan and anyone reading it see more exchanges in
  -- flight than there are processes.
  --
  -- Opening a session on the same triple IS the proof that any earlier open one
  -- is over: two concurrent sessions on one pair in one direction would
  -- double-send. So the earlier one is closed here, mechanically, rather than
  -- left to the discipline of whichever process starts next.
  --
  -- Closed as failed, not as something softer: a session that ended without a
  -- word is a failure, and the backoff that follows is the right answer to a
  -- process that keeps dying.

  UPDATE mq.session
     SET finished = Now(),
         result = 'failed',
         message = 'abandoned: superseded by a new session on the same pair'
   WHERE peer = pPeer
     AND channel = pChannel
     AND direction = pDirection
     AND finished IS NULL;

  INSERT INTO mq.session (peer, channel, direction, link)
  VALUES (pPeer, pChannel, pDirection, pLink)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Close an exchange session with its outcome.
 * @param {bigint} pId - Session identifier
 * @param {text} pResult - ok, partial or failed
 * @param {integer} pMessages - How many messages were carried
 * @param {bigint} pBytes - How many bytes went over the link
 * @param {text} pMessage - Error or explanation
 * @return {void}
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.session_close (
  pId           bigint,
  pResult       text,
  pMessages     integer DEFAULT 0,
  pBytes        bigint DEFAULT 0,
  pMessage      text DEFAULT null
) RETURNS       void
AS $$
BEGIN
  UPDATE mq.session
     SET finished = Now(),
         result = pResult,
         messages = coalesce(pMessages, 0),
         bytes = coalesce(pBytes, 0),
         message = pMessage
   WHERE id = pId;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ERR-40000: Session "%" not found.', pId;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- HOUSEKEEPING ----------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Compact a channel: keep only the last message per key.
 * @param {integer} pChannel - Channel
 * @return {integer} - Number of superseded messages removed
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.compact (
  pChannel      integer
) RETURNS       integer
AS $$
DECLARE
  nCount        integer;
BEGIN
  PERFORM FROM mq.channel WHERE id = pChannel AND compaction;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  -- A compacted channel is a snapshot, and that is what lets a node joining
  -- for the first time reach the current state by reading it from zero instead
  -- of replaying every revision ever published. Messages with no key stay: a
  -- NULL key means "this is not a state, do not fold it".

  WITH superseded AS (
    SELECT m.source, m.channel, m.serial
      FROM mq.message m
     WHERE m.channel = pChannel
       AND m.key IS NOT NULL
       AND m.serial < (SELECT max(x.serial) FROM mq.message x
                        WHERE x.channel = m.channel AND x.source = m.source AND x.key = m.key)
  )
  DELETE FROM mq.message d
   USING superseded s
   WHERE d.source = s.source AND d.channel = s.channel AND d.serial = s.serial;

  GET DIAGNOSTICS nCount = ROW_COUNT;

  RETURN nCount;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Remove messages a channel no longer has to keep.
 * @param {integer} pChannel - Channel
 * @return {integer} - Number of messages removed
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.purge (
  pChannel      integer
) RETURNS       integer
AS $$
DECLARE
  iRetention    interval;
  nCount        integer;
BEGIN
  SELECT retention INTO iRetention FROM mq.channel WHERE id = pChannel;

  IF NOT FOUND OR iRetention IS NULL THEN
    RETURN 0;
  END IF;

  -- Our own messages are kept until every node that exchanges this channel has
  -- confirmed them, retention or no retention. Deleting a message a node has
  -- not confirmed is deleting the only copy it can still be asked for -- and
  -- it would be deleted precisely for the node that has been out of touch
  -- longest, which is the node that needs it.
  --
  -- The join is LEFT and starts from mq.peer on purpose. An INNER JOIN from
  -- mq.watermark drops every node that has never synchronised at all -- it has
  -- no cursor row yet -- so the guard would protect nodes that already reported
  -- and quietly fail to protect the newly registered one, which is the node
  -- that needs the whole log from zero. The local node is excluded: our own
  -- cursor says nothing about what anybody else received.
  --
  -- How long a silent node may hold the log is NOT decided here. It is the
  -- owner's call ("how long may a ship stay quiet before we forget its tail"),
  -- and until it is made, retention alone never deletes an unconfirmed message.

  DELETE FROM mq.message m
   WHERE m.channel = pChannel
     AND m.created < Now() - iRetention
     AND (m.source <> mq.local_peer()
          OR m.serial <= coalesce((SELECT min(coalesce(w.sent, 0))
                                     FROM mq.peer p
                                     LEFT JOIN mq.watermark w ON w.peer = p.id AND w.channel = pChannel
                                    WHERE p.enabled AND NOT p.local), 0));

  GET DIAGNOSTICS nCount = ROW_COUNT;

  RETURN nCount;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
