--------------------------------------------------------------------------------
-- NOTIFY ----------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Conventions of this file.
--
--  * Every function is SECURITY DEFINER with search_path = kernel, pg_temp and is
--    reached through the USAGE of schema notify (schema.sql). They are NOT in
--    schema kernel on purpose: the guarantee (the token check in notify.ack)
--    must not sit where a project redefines platform functions.
--  * Time is clock_timestamp(), not now(): a subscriber's call may be made from
--    a long transaction, and "has the grace passed" is a question about the wall
--    clock.
--  * notify.send raises nothing of its own (an unknown channel, a failing target_fn, a failed
--    self-registration; what pg_notify itself refuses -- an empty or over-long channel, a
--    payload over 8000 bytes -- it refuses as before): a producer's transaction is not rolled back because
--    the delivery policy could not be decided. It degrades to a plain
--    pg_notify, which is what the producer did before this module existed.
--  * SQLSTATE 'NT409' is the one error a subscriber must tell from the rest: the
--    token is not current, the result written beside the confirmation is rolled
--    back with it.
--  * The mode of a channel is decided by notify.send ALONE. take, ack, nack and
--    the sweep bring the rows that exist to their end whatever the mode is now:
--    a channel returned to legacy under load must be able to drain, not strand
--    its waiting rows.
--  * A wake-up goes ONLY to the personal channel "<channel>:<number>" of a
--    subscriber. The channel "<channel>" itself belongs to the producers of
--    legacy data: during a switch both kinds of traffic exist, and a bare row
--    number on the common channel could not be told from the data of a
--    producer (which for some channels is a number too).
--  * A wake-up goes to ONE named subscriber, never to "everybody", and a row that has been
--    woken is not woken again by the sweep for 3/4 of sweep_every (notify.queue.woken --
--    the subscriber's own timer is spread +-25 %, so a stricter gate would hold back half
--    of its ticks), whoever sweeps. A row whose addressee stays silent is offered to the
--    next live subscriber in the ring, one at a time: the cost of an overloaded executor
--    is one wake-up per waiting row per tick, not subscribers x subscribers x rows.

--------------------------------------------------------------------------------
-- INTERNAL --------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Wake one subscriber for a row. Only personal channels are written to, never
 *        the channel itself. There is no "wake everybody": a storm of wake-ups answers
 *        an overloaded executor with more load.
 * @param {text} pChannel - Channel
 * @param {bigint} pId - Row identifier, the payload of the wake-up
 * @param {integer} pTarget - Subscriber number; NULL wakes nobody
 * @return {void}
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION notify.wake (
  pChannel      text,
  pId           bigint,
  pTarget       integer DEFAULT null
) RETURNS       void
AS $$
BEGIN
  IF pTarget IS NOT NULL THEN
    PERFORM pg_notify(pChannel || ':' || pTarget, pId::text);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Is the subscriber registered, active and recently heard from.
 * @param {integer} pSubscriber - Subscriber number
 * @param {interval} pAlive - The channel's threshold
 * @return {boolean}
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION notify.is_alive (
  pSubscriber   integer,
  pAlive        interval
) RETURNS       boolean
AS $$
  SELECT EXISTS (
    SELECT 1
      FROM notify.subscriber
     WHERE id = pSubscriber
       AND state = 'active'
       AND seen > clock_timestamp() - pAlive
  );
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Ask a channel's target_fn which subscriber holds a key -- the answer as it is.
 *        The name was checked when it was written (notify.ft_channel_check), so a
 *        failure here is the function's own: it is read as "no holder".
 * @param {text} pFn - Function (text) RETURNS integer
 * @param {text} pKey - Key
 * @return {integer} - Subscriber number; NULL when there is no holder or the function failed
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION notify.route_holder (
  pFn           text,
  pKey          text
) RETURNS       integer
AS $$
DECLARE
  nTarget       integer;
BEGIN
  IF pFn IS NULL THEN
    RETURN NULL;
  END IF;

  EXECUTE format('SELECT %s($1)', pFn) INTO nTarget USING pKey;
  RETURN nTarget;
EXCEPTION
WHEN OTHERS THEN
  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief The addressee of a route row: the holder target_fn names, if it is alive.
 *        One check for every target_fn: a route to a worker that was killed is
 *        "no holder" (the row is closed unrouted after the grace) and not a
 *        holder that never answers until the row expires.
 * @param {text} pFn - Function (text) RETURNS integer
 * @param {text} pKey - Key
 * @param {interval} pAlive - alive of the channel
 * @return {integer} - Subscriber number; NULL when there is no holder, it is not active or silent
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION notify.route_target (
  pFn           text,
  pKey          text,
  pAlive        interval
) RETURNS       integer
AS $$
DECLARE
  nTarget       integer;
BEGIN
  nTarget := notify.route_holder(pFn, pKey);

  IF nTarget IS NOT NULL AND NOT notify.is_alive(nTarget, pAlive) THEN
    RETURN NULL;
  END IF;

  RETURN nTarget;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Choose the addressee of a row among the live subscribers.
 * @param {text} pChannel - Channel
 * @param {text} pAffinity - any, key or route
 * @param {text} pKey - Key of the row
 * @param {text} pTargetFn - target_fn of the channel (route)
 * @param {interval} pAlive - alive of the channel
 * @return {integer} - Subscriber number; NULL when there is nobody
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION notify.pick_target (
  pChannel      text,
  pAffinity     text,
  pKey          text,
  pTargetFn     text,
  pAlive        interval
) RETURNS       integer
AS $$
DECLARE
  nTarget       integer;
BEGIN
  IF pAffinity = 'route' THEN
    RETURN notify.route_target(pTargetFn, pKey, pAlive);
  END IF;

  IF pAffinity = 'key' AND pKey IS NOT NULL THEN
    -- rendezvous hashing: the key stays with one subscriber, and when that one
    -- leaves only ITS keys move.
    SELECT s.id INTO nTarget
      FROM notify.subscriber s
     WHERE s.channel = pChannel
       AND s.state = 'active'
       AND s.seen > clock_timestamp() - pAlive
     ORDER BY hashtextextended(pKey || ':' || s.id, 0) DESC, s.id
     LIMIT 1;

    RETURN nTarget;
  END IF;

  -- any: the least loaded (rows addressed to it and not taken, plus rows it holds), ties at random.
  SELECT s.id INTO nTarget
    FROM notify.subscriber s
   WHERE s.channel = pChannel
     AND s.state = 'active'
     AND s.seen > clock_timestamp() - pAlive
   ORDER BY (SELECT count(*) FROM notify.queue q WHERE q.state = 0 AND q.target = s.id)
          + (SELECT count(*) FROM notify.queue q WHERE q.state = 1 AND q.owner = s.id),
            random()
   LIMIT 1;

  RETURN nTarget;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief The next live subscriber of a channel after one, in the order of their numbers, wrapping
 *        round: the one a row is offered to when its addressee stays silent about it. A ring,
 *        not "the least loaded": the least loaded of the others would be the same one or two
 *        subscribers every tick, and a responsive subscriber with rows of its own would never
 *        be offered the row. Walking the ring reaches every live subscriber in turn.
 * @param {text} pChannel - Channel
 * @param {integer} pAfter - Subscriber number the walk starts after (the current addressee)
 * @param {interval} pAlive - alive of the channel
 * @return {integer} - Subscriber number; pAfter itself when it is the only one alive; NULL when nobody is
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION notify.pick_next (
  pChannel      text,
  pAfter        integer,
  pAlive        interval
) RETURNS       integer
AS $$
  SELECT s.id
    FROM notify.subscriber s
   WHERE s.channel = pChannel
     AND s.state = 'active'
     AND s.seen > clock_timestamp() - pAlive
   ORDER BY (s.id > pAfter) DESC NULLS LAST, s.id
   LIMIT 1;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief May a row that was sent be handed out once more.
 * @param {notify.queue} q - The row (attempts counts the deliveries so far)
 * @param {notify.channel} c - Its channel
 * @return {boolean}
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION notify.can_repeat (
  q             notify.queue,
  c             notify.channel
) RETURNS       boolean
AS $$
  SELECT c.resend_enabled
     AND q.attempts <= coalesce(q.max_attempts, c.max_attempts, 0)
     AND (coalesce(q.expire, c.expire) IS NULL
          OR coalesce(q.seen, clock_timestamp()) + coalesce(q.expire, c.expire) > clock_timestamp());
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Has the row never left: nothing was handed out, or the only delivery was refused as `unsent:` and the
 *        row is waiting again. The difference decides how an expired or unrouted row ends: "never sent"
 *        (quiet) or "outcome unknown" (the producer is told). A row sent back by notify.nack after its first
 *        delivery has attempts = 1 and an error that starts with `unsent:`, and nothing else gives a waiting
 *        row that pair (T1102).
 * @param {notify.queue} q - The row
 * @return {boolean}
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION notify.never_sent (
  q             notify.queue
) RETURNS       boolean
AS $$
  SELECT q.attempts = 0
      OR (q.attempts = 1 AND q.state = 0 AND left(coalesce(q.error, ''), 7) = 'unsent:');
$$ LANGUAGE sql IMMUTABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Wake the addressee of the next waiting row of the same key after one of them
 *        was settled. The addressee is worked out again: for a route it may have
 *        changed since the row was written.
 * @param {text} pChannel - Channel
 * @param {text} pKey - Key of the row that was settled
 * @return {void}
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION notify.wake_next (
  pChannel      text,
  pKey          text
) RETURNS       void
AS $$
DECLARE
  r             record;
  nTarget       integer;
BEGIN
  IF pKey IS NULL THEN
    RETURN;
  END IF;

  -- only an ordered channel (key, route) holds a row back behind another one.
  -- A row somebody is already working on (locked) is theirs: skipped.
  SELECT q.id, q.target, c.affinity, c.target_fn, c.alive INTO r
    FROM notify.queue q
         INNER JOIN notify.channel c ON c.code = q.channel AND c.affinity <> 'any'
   WHERE q.channel = pChannel
     AND q.key = pKey
     AND q.state = 0
   ORDER BY q.id
   LIMIT 1
     FOR UPDATE OF q SKIP LOCKED;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  nTarget := notify.pick_target(pChannel, r.affinity, pKey, r.target_fn, r.alive);

  -- nobody to name: the sweep readdresses it (or closes it unrouted).
  IF nTarget IS NULL THEN
    RETURN;
  END IF;

  UPDATE notify.queue SET target = nTarget, woken = clock_timestamp() WHERE id = r.id;

  PERFORM notify.wake(pChannel, r.id, nTarget);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief The payload of a row that is over: without the credential it carried while it was open.
 * @param {text} pChannel - Channel of the row
 * @param {text} pPayload - Payload of the row
 * @return {text} - The payload to keep. The channels `report` and `file` carry the session code of whoever asked
 *         (db.ft_notification_after_insert, db.ft_file_notify): a full credential, which the executor needs to act
 *         in that session and nobody needs afterwards. A row of the channel is kept for retain_done (confirmed) or
 *         retain_closed (closed), up to 90 days; the key `session` is taken out of it when the row ends, so the
 *         code lives in notify.queue as long as the delivery does. Only the key of the top level is taken: both
 *         triggers write it there, and a payload of another shape would keep what it holds deeper. A payload that
 *         is not JSON cannot be cleaned key by key and is dropped (NULL): nothing reads the payload of a row that
 *         is over. Any other channel: unchanged.
 * @since 1.2.39
 *
 * One place for the policy: notify.ack and notify.close call it, and a project that has another channel with a
 * credential in its payload overrides this function (the way it overrides the rest of the platform), not them.
 * The row is cleaned BEFORE on_abandon is called, so the callback does not see the code either.
 */
CREATE OR REPLACE FUNCTION notify.scrub (
  pChannel      text,
  pPayload      text
) RETURNS       text
AS $$
BEGIN
  IF pPayload IS NULL OR pChannel IS NULL OR pChannel NOT IN ('report', 'file') THEN
    RETURN pPayload;
  END IF;

  BEGIN
    RETURN (pPayload::jsonb - 'session')::text;
  EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
  END;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Close a row without a confirmation and call the channel's on_abandon.
 * @param {bigint} pId - Row
 * @param {text} pReason - Why; the prefix says which of the three closings it is
 *        (unsent:, unrouted:, orphaned:, nack:)
 * @param {boolean} pSent - The row was handed out at least once, its outcome is unknown.
 *        false: it never left; on_abandon is called only if the channel says on_expire
 * @return {void}
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION notify.close (
  pId           bigint,
  pReason       text,
  pSent         boolean
) RETURNS       void
AS $$
DECLARE
  q             notify.queue%ROWTYPE;
  c             notify.channel%ROWTYPE;
BEGIN
  UPDATE notify.queue
     SET state = 3, error = pReason, done = clock_timestamp(), lease_until = NULL,
         payload = notify.scrub(channel, payload)
   WHERE id = pId AND state < 2
  RETURNING * INTO q;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  SELECT * INTO c FROM notify.channel WHERE code = q.channel;

  IF c.on_abandon IS NOT NULL AND (pSent OR c.on_expire) THEN
    BEGIN
      EXECUTE format('SELECT %s($1, $2, $3, $4)', c.on_abandon) USING q.id, q.key, q.payload, pReason;
    EXCEPTION
    WHEN OTHERS THEN
      -- the row stays closed; a failing callback is a thing to read, not a
      -- reason to leave a row open and be handed out again.
      UPDATE notify.queue SET error = left(pReason || ' | on_abandon failed: ' || SQLERRM, 4000) WHERE id = q.id;
    END;
  END IF;

  PERFORM notify.wake_next(q.channel, q.key);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SEND ------------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Deliver a notification: the replacement of pg_notify at every producer.
 * @param {text} pChannel - Channel
 * @param {text} pPayload - Data; for a single channel it is kept in the row
 * @param {text} pKey - Key: the order and, per channel, the addressee and the uniqueness
 * @param {interval} pExpire - How long after the first look the row may still be handed out;
 *        NULL takes the channel's
 * @param {integer} pMaxAttempts - Repeats allowed after the first delivery; NULL takes the channel's
 * @return {bigint} - The row for a single channel (an existing one for a duplicate of a dedupe
 *         channel); NULL when the channel is a plain broadcast
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION notify.send (
  pChannel      text,
  pPayload      text,
  pKey          text DEFAULT null,
  pExpire       interval DEFAULT null,
  pMaxAttempts  integer DEFAULT null
) RETURNS       bigint
AS $$
DECLARE
  c             record;
  nId           bigint;
  nTarget       integer;
BEGIN
  SELECT mode, affinity, target_fn, alive INTO c FROM notify.channel WHERE code = pChannel;

  IF NOT FOUND THEN
    -- A channel nobody classified is a broadcast, as it always was; it is
    -- written down so that someone looks at it. The exception never leaves
    -- this block: the producer is not rolled back for want of a policy.
    BEGIN
      INSERT INTO notify.channel (code, mode, classified, description)
      VALUES (pChannel, 'broadcast', false, 'recorded by notify.send on first sight')
      ON CONFLICT DO NOTHING;
    EXCEPTION
    WHEN OTHERS THEN
      NULL;
    END;

    PERFORM pg_notify(pChannel, pPayload);
    RETURN NULL;
  END IF;

  IF c.mode <> 'single' THEN
    PERFORM pg_notify(pChannel, pPayload);
    RETURN NULL;
  END IF;

  nTarget := notify.pick_target(pChannel, c.affinity, pKey, c.target_fn, c.alive);

  -- a negative number of repeats is "none": the CHECK of the queue would refuse it, and the
  -- producer would be rolled back for a number it passes through (http.request has no CHECK).
  INSERT INTO notify.queue (channel, payload, key, expire, max_attempts, dedupe, target)
  SELECT pChannel, pPayload, pKey, pExpire,
         CASE WHEN pMaxAttempts < 0 THEN 0 ELSE pMaxAttempts END,
         (d.dedupe AND pKey IS NOT NULL), nTarget
    FROM notify.channel d
   WHERE d.code = pChannel
  ON CONFLICT (channel, key) WHERE dedupe DO NOTHING
  RETURNING id INTO nId;

  IF nId IS NULL THEN
    -- a duplicate of a dedupe channel: the row that is already there is the answer.
    SELECT id INTO nId FROM notify.queue WHERE channel = pChannel AND key = pKey AND dedupe;
    RETURN nId;
  END IF;

  -- nobody to name (a route without a live holder, a channel without a live
  -- subscriber): the row waits, the sweep of whoever comes first readdresses it or
  -- closes it unrouted. A wake-up has nobody to go to.
  IF nTarget IS NOT NULL THEN
    PERFORM notify.wake(pChannel, nId, nTarget);
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SUBSCRIBERS -----------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Register a listener of a channel; the number returned names its personal channel.
 * @param {text} pNode - Signature of the instance for people
 * @param {text} pChannel - Channel
 * @param {text} pApplication - Application
 * @param {text} pRole - Role of the process in the application
 * @param {integer} pPid - Backend pid of the LISTEN connection; the caller's by default
 * @return {integer} - Subscriber number. Listen on "<channel>" and "<channel>:<number>"
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION notify.subscribe (
  pNode         text,
  pChannel      text,
  pApplication  text DEFAULT null,
  pRole         text DEFAULT null,
  pPid          integer DEFAULT null
) RETURNS       integer
AS $$
DECLARE
  nId           integer;
BEGIN
  BEGIN
    INSERT INTO notify.channel (code, mode, classified, description)
    VALUES (pChannel, 'broadcast', false, 'recorded by notify.subscribe on first sight')
    ON CONFLICT DO NOTHING;
  EXCEPTION
  WHEN OTHERS THEN
    NULL;
  END;

  INSERT INTO notify.subscriber (node, application, role, channel, backend_pid)
  VALUES (pNode, pApplication, pRole, pChannel, coalesce(pPid, pg_backend_pid()))
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief The listener is alive.
 * @param {integer} pId - Subscriber number
 * @param {integer} pPid - Backend pid of the LISTEN connection if it changed (a reconnect)
 * @return {text} - active, draining, or NULL when the number is not registered any more
 *         (purged): subscribe again
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION notify.heartbeat (
  pId           integer,
  pPid          integer DEFAULT null
) RETURNS       text
AS $$
DECLARE
  vState        text;
BEGIN
  UPDATE notify.subscriber
     SET seen = clock_timestamp(), backend_pid = coalesce(pPid, backend_pid)
   WHERE id = pId
  RETURNING state INTO vState;

  RETURN vState;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief The listener is stopping: it is not chosen as an addressee, takes nothing new,
 *        and finishes and confirms what it started.
 * @param {integer} pId - Subscriber number
 * @return {void}
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION notify.drain (
  pId           integer
) RETURNS       void
AS $$
BEGIN
  UPDATE notify.subscriber SET state = 'draining', seen = clock_timestamp() WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Deregister a listener that has finished. A number that rows still refer to
 *        stays (draining) until notify.sweep removes it.
 * @param {integer} pId - Subscriber number
 * @return {void}
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION notify.unsubscribe (
  pId           integer
) RETURNS       void
AS $$
BEGIN
  DELETE FROM notify.subscriber s
   WHERE s.id = pId
     AND NOT EXISTS (
       SELECT 1 FROM notify.queue q
        WHERE (q.state = 0 AND q.target = s.id) OR (q.state = 1 AND q.owner = s.id)
     );

  IF FOUND THEN
    RETURN;
  END IF;

  UPDATE notify.subscriber SET state = 'draining' WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief The policy of a channel, as a subscriber needs it: the mode to check its own
 *        configuration against (a listener of a legacy channel must not wait for
 *        rows), and the timers it runs (alive, sweep_every, lease). A listener's
 *        role has USAGE on schema notify and no right on the table notify.channel.
 * @param {text} pChannel - Channel
 * @return {SETOF record} - (mode, classified, affinity, alive, sweep_every, lease); no row when
 *         the channel is unknown
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION notify.channel_policy (
  pChannel      text
) RETURNS       TABLE (
  mode          text,
  classified    boolean,
  affinity      text,
  alive         interval,
  sweep_every   interval,
  lease         interval
)
AS $$
  SELECT c.mode, c.classified, c.affinity, c.alive, c.sweep_every, c.lease
    FROM notify.channel c
   WHERE c.code = pChannel;
$$ LANGUAGE sql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- TAKE / ACK / NACK -----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Take a row: the subscriber's reaction to a wake-up or to a sweep.
 * @param {bigint} pId - Row (the payload of the wake-up)
 * @param {integer} pSubscriber - Subscriber number
 * @return {SETOF record} - (payload, key, token, attempts) when the row is the subscriber's to
 *         work on; NO ROWS when it is not (somebody else's, taken, waiting for an earlier row
 *         of its key, or closed here as expired) -- nothing to do
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION notify.take (
  pId           bigint,
  pSubscriber   integer
) RETURNS       TABLE (
  payload       text,
  key           text,
  token         bigint,
  attempts      integer
)
AS $$
#variable_conflict use_column
DECLARE
  q             notify.queue%ROWTYPE;
  c             notify.channel%ROWTYPE;
  s             notify.subscriber%ROWTYPE;
  dNow          timestamptz := clock_timestamp();
  iExpire       interval;
  nToken        bigint;
BEGIN
  SELECT * INTO q FROM notify.queue WHERE id = pId AND state = 0 FOR UPDATE SKIP LOCKED;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  SELECT * INTO s FROM notify.subscriber WHERE id = pSubscriber;

  IF NOT FOUND OR s.channel <> q.channel OR s.state <> 'active' THEN
    RETURN;
  END IF;

  SELECT * INTO c FROM notify.channel WHERE code = q.channel;

  -- no test of c.mode: a row that exists is brought to its end in any mode.
  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- the first look: grace and expire count from here
  IF q.seen IS NULL THEN
    q.seen := dNow;
    UPDATE notify.queue SET seen = dNow WHERE id = q.id;
  END IF;

  iExpire := coalesce(q.expire, c.expire);

  IF iExpire IS NOT NULL AND q.seen + iExpire < dNow THEN
    IF notify.never_sent(q) THEN
      PERFORM notify.close(q.id, 'unsent: expired', false);
    ELSE
      PERFORM notify.close(q.id, 'orphaned: expired before a repeat, outcome unknown', true);
    END IF;

    RETURN;
  END IF;

  -- order: a row waits for an earlier unconfirmed row of its key
  IF c.affinity <> 'any' AND q.key IS NOT NULL AND EXISTS (
       SELECT 1 FROM notify.queue p
        WHERE p.channel = q.channel AND p.key = q.key AND p.id < q.id AND p.state < 2
     )
  THEN
    RETURN;
  END IF;

  -- the addressee
  IF c.affinity = 'route' THEN
    -- the holder at THIS moment; there is no "anybody" after the grace. The caller
    -- is the one asking, so it is alive by definition: only the name is compared.
    IF notify.route_holder(c.target_fn, q.key) IS DISTINCT FROM pSubscriber THEN
      RETURN;
    END IF;
  ELSIF q.target IS NOT NULL AND q.target <> pSubscriber
        AND q.seen + c.grace > dNow
        AND notify.is_alive(q.target, c.alive)
  THEN
    RETURN;
  END IF;

  nToken := nextval('notify.token');

  UPDATE notify.queue
     SET state = 1, owner = pSubscriber, token = nToken, taken = dNow,
         lease_until = dNow + c.lease, attempts = notify.queue.attempts + 1
   WHERE id = q.id;

  RETURN QUERY SELECT q.payload, q.key, nToken, q.attempts + 1;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Confirm a row. Call it in the SAME transaction that writes the result.
 * @param {bigint} pId - Row
 * @param {bigint} pToken - The token notify.take returned
 * @return {void}
 * @throws NT409 - The token is not current (the row was given out again, closed, or never
 *         taken under this token). The exception rolls back the result written beside it.
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION notify.ack (
  pId           bigint,
  pToken        bigint
) RETURNS       void
AS $$
DECLARE
  r             record;
BEGIN
  UPDATE notify.queue
     SET state = 2, done = clock_timestamp(), error = NULL, lease_until = NULL,
         payload = notify.scrub(channel, payload)
   WHERE id = pId AND token = pToken AND state = 1
  RETURNING channel, key INTO r;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ERR-40901: notify.ack: row % is not taken under token %', pId, pToken
      USING ERRCODE = 'NT409';
  END IF;

  PERFORM notify.wake_next(r.channel, r.key);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Take the lock on a row the subscriber holds, and change nothing. Call it FIRST in the batch that writes the
 *        result, ahead of the action on the object; notify.ack stays last, as the transport appends it.
 * @param {bigint} pId - Row
 * @param {bigint} pToken - The token notify.take returned
 * @return {void}
 * @throws NT409 - The token is not current (the row was given out again, closed, or never taken under this token):
 *         the result written beside it is rolled back, and nothing was written yet
 * @since 1.2.39
 *
 * Why it exists. notify.close locks the row of the queue and its on_abandon then locks the object (OutboxAbandon,
 * ReportReadyAbandon, JobAbandon). A sender that writes its result first (the action locks the object) and calls
 * notify.ack last (the row) takes the two locks in the opposite order: measured, the sweep at the end of a lease and
 * a settle deadlock, and when the settle is the quicker the callback of the SWEEP is the victim -- the row stays
 * closed, the message stays `sending` for good. The transport appends notify.ack to the end of the batch itself, so the
 * sender cannot put the ack first; this function takes the same lock at the head of the batch. The sweep takes
 * the rows it works on with FOR UPDATE SKIP LOCKED, so a row held here is skipped, never waited for -- also while a
 * report is being built under it. A sweep that was first has closed the row already: the hold finds it so and
 * raises NT409 before any result is written.
 */
CREATE OR REPLACE FUNCTION notify.hold (
  pId           bigint,
  pToken        bigint
) RETURNS       void
AS $$
BEGIN
  PERFORM FROM notify.queue WHERE id = pId AND token = pToken AND state = 1 FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ERR-40901: notify.hold: row % is not taken under token %', pId, pToken
      USING ERRCODE = 'NT409';
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief Refuse a row the subscriber took: give it out again if a repeat is allowed,
 *        otherwise close it and call on_abandon. A reason that starts with `unsent:` on the
 *        first delivery says the row never left: it goes back whatever the repeats say.
 * @param {bigint} pId - Row
 * @param {bigint} pToken - The token notify.take returned
 * @param {text} pError - Why
 * @return {void}
 * @throws NT409 - The token is not current
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION notify.nack (
  pId           bigint,
  pToken        bigint,
  pError        text DEFAULT null
) RETURNS       void
AS $$
DECLARE
  q             notify.queue%ROWTYPE;
  c             notify.channel%ROWTYPE;
  nTarget       integer;
BEGIN
  SELECT * INTO q FROM notify.queue WHERE id = pId AND token = pToken AND state = 1 FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ERR-40901: notify.nack: row % is not taken under token %', pId, pToken
      USING ERRCODE = 'NT409';
  END IF;

  SELECT * INTO c FROM notify.channel WHERE code = q.channel;

  -- A refusal that says the row was NOT sent ("unsent: ...") on its first delivery is no repeat: a row
  -- that never left may go back to the queue whatever max_attempts and resend_enabled say -- both
  -- are about sending again what was sent. Without this a channel with no repeats (max_attempts 0, the
  -- HTTP request without an expiry) lost the request when its worker stopped before it was sent
  -- (T1102). The second delivery is judged by the usual rule: a worker that keeps saying "not sent"
  -- cannot keep the row going round.
  IF notify.can_repeat(q, c)
     OR (q.attempts = 1 AND left(coalesce(pError, ''), 7) = 'unsent:')
  THEN
    nTarget := notify.pick_target(q.channel, c.affinity, q.key, c.target_fn, c.alive);

    -- the repeat is woken here: woken keeps the sweep from offering it elsewhere at once
    UPDATE notify.queue
       SET state = 0, owner = NULL, token = NULL, taken = NULL, lease_until = NULL,
           target = nTarget, error = pError,
           woken = CASE WHEN nTarget IS NOT NULL THEN clock_timestamp() ELSE woken END
     WHERE id = q.id;

    IF nTarget IS NOT NULL THEN
      PERFORM notify.wake(q.channel, q.id, nTarget);
    END IF;
  ELSE
    PERFORM notify.close(q.id, 'nack: ' || coalesce(pError, ''), true);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SWEEP -----------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief The look-over of a channel, with or without a subscriber: the one place the
 *        rest of this section is done. A channel nobody listens on is looked over by
 *        a job (api.sweep_notify_channel), or its rows would wait for ever and a
 *        row that carries a hold or a command would never be closed.
 *        Waiting rows: mark as seen, readdress where the addressee is gone, offer a row
 *        whose addressee stayed silent past the grace to the next live subscriber in the ring
 *        (one wake-up per row per 3/4 sweep_every, whoever sweeps: notify.queue.woken), close
 *        the expired and the unrouted. Taken rows whose lease ran out: give out again or close as
 *        outcome unknown. Once a minute per channel: delete what is past its
 *        retention. The mode of the channel is not asked (see the top of the file).
 *        on_abandon runs as the owner of this function, whoever calls.
 * @param {text} pChannel - Channel
 * @param {integer} pLimit - Rows per kind per call
 * @return {integer} - Rows it acted on
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION notify.sweep_channel (
  pChannel      text,
  pLimit        integer DEFAULT 100
) RETURNS       integer
AS $$
DECLARE
  c             notify.channel%ROWTYPE;
  q             notify.queue%ROWTYPE;
  dNow          timestamptz := clock_timestamp();
  iExpire       interval;
  nTarget       integer;
  nCount        integer := 0;
  nRows         integer;
BEGIN
  SELECT * INTO c FROM notify.channel WHERE code = pChannel;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  -- waiting rows
  FOR q IN
    SELECT * FROM notify.queue
     WHERE channel = c.code AND state = 0
     ORDER BY id
     LIMIT pLimit
       FOR UPDATE SKIP LOCKED
  LOOP
    IF q.seen IS NULL THEN
      q.seen := dNow;
      UPDATE notify.queue SET seen = dNow WHERE id = q.id;
    END IF;

    iExpire := coalesce(q.expire, c.expire);

    IF iExpire IS NOT NULL AND q.seen + iExpire < dNow THEN
      IF notify.never_sent(q) THEN
        PERFORM notify.close(q.id, 'unsent: expired', false);
      ELSE
        PERFORM notify.close(q.id, 'orphaned: expired before a repeat, outcome unknown', true);
      END IF;

      nCount := nCount + 1;
      CONTINUE;
    END IF;

    IF c.affinity = 'route' THEN
      nTarget := notify.route_target(c.target_fn, q.key, c.alive);

      IF nTarget IS NULL THEN
        IF q.seen + c.grace < dNow THEN
          IF notify.never_sent(q) THEN
            PERFORM notify.close(q.id, 'unrouted: no holder', false);
          ELSE
            PERFORM notify.close(q.id, 'orphaned: no holder after a delivery, outcome unknown', true);
          END IF;

          nCount := nCount + 1;
        END IF;
      ELSIF nTarget IS DISTINCT FROM q.target THEN
        UPDATE notify.queue SET target = nTarget, woken = dNow WHERE id = q.id;
        PERFORM notify.wake(c.code, q.id, nTarget);
        nCount := nCount + 1;
      ELSIF q.seen + c.grace < dNow AND (q.woken IS NULL OR q.woken + c.sweep_every * 3 / 4 <= dNow) THEN
        -- the holder did not take it: say it again (a lost NOTIFY, a row held back by an earlier one),
        -- once per tick however many subscribers sweep
        UPDATE notify.queue SET woken = dNow WHERE id = q.id;
        PERFORM notify.wake(c.code, q.id, nTarget);
      END IF;
    ELSIF q.target IS NULL OR NOT notify.is_alive(q.target, c.alive) THEN
      nTarget := notify.pick_target(c.code, c.affinity, q.key, c.target_fn, c.alive);

      IF nTarget IS NOT NULL THEN
        UPDATE notify.queue SET target = nTarget, woken = dNow WHERE id = q.id;
        PERFORM notify.wake(c.code, q.id, nTarget);
        nCount := nCount + 1;
      END IF;
    ELSIF q.seen + c.grace < dNow AND (q.woken IS NULL OR q.woken + c.sweep_every * 3 / 4 <= dNow) THEN
      -- the addressee is alive but silent about this row: now anybody may take it. Offer it to
      -- the next live subscriber in the ring (notify.pick_next; the addressee itself when it is
      -- the only one), ONE wake-up, once per tick whoever sweeps; the next tick offers it to the
      -- one after, so every live subscriber is reached in turn.
      nTarget := notify.pick_next(c.code, q.target, c.alive);
      UPDATE notify.queue SET target = nTarget, woken = dNow WHERE id = q.id;
      PERFORM notify.wake(c.code, q.id, nTarget);
    END IF;
  END LOOP;

  -- taken rows whose lease ran out
  FOR q IN
    SELECT * FROM notify.queue
     WHERE channel = c.code AND state = 1 AND lease_until < dNow
     ORDER BY lease_until
     LIMIT pLimit
       FOR UPDATE SKIP LOCKED
  LOOP
    IF notify.can_repeat(q, c) THEN
      nTarget := notify.pick_target(c.code, c.affinity, q.key, c.target_fn, c.alive);

      UPDATE notify.queue
         SET state = 0, owner = NULL, token = NULL, taken = NULL, lease_until = NULL,
             target = nTarget, error = 'lease expired',
             woken = CASE WHEN nTarget IS NOT NULL THEN dNow ELSE woken END
       WHERE id = q.id;

      IF nTarget IS NOT NULL THEN
        PERFORM notify.wake(c.code, q.id, nTarget);
      END IF;
    ELSE
      PERFORM notify.close(q.id, 'orphaned: lease expired, outcome unknown', true);
    END IF;

    nCount := nCount + 1;
  END LOOP;

  -- retention: not more than once a minute per channel, a small batch. Rows that are
  -- not finished are never deleted.
  UPDATE notify.channel SET purged = dNow
   WHERE code = c.code AND (purged IS NULL OR purged < dNow - interval '1 minute');

  GET DIAGNOSTICS nRows = ROW_COUNT;

  IF nRows > 0 THEN
    DELETE FROM notify.queue
     WHERE id IN (
       SELECT id FROM notify.queue
        WHERE channel = c.code
          AND ((state = 2 AND done < dNow - c.retain_done) OR (state = 3 AND done < dNow - c.retain_closed))
        ORDER BY id
        LIMIT 1000
          FOR UPDATE SKIP LOCKED
     );

    DELETE FROM notify.subscriber x
     WHERE x.channel = c.code
       AND x.seen < dNow - greatest(c.retain_done, c.retain_closed)
       AND NOT EXISTS (
         SELECT 1 FROM notify.queue r
          WHERE (r.state = 0 AND r.target = x.id) OR (r.state = 1 AND r.owner = x.id)
       );

    -- the safety net (T1158): objects that stand in the delivery and hold no open row -- a callback that failed
    -- (the row stays closed, the object stays `sending`), what the old path had when the channel was switched.
    -- With the retention, once a minute per channel, and only while the channel is single: in legacy the poll of the
    -- old path is the owner of such objects, and a row put in beside it would be a second sender. A failure of the
    -- module's function is not the sweep's: what was closed above stays closed, the failure is a line in the log of
    -- the server; the module's function writes its own failures to the event log, object by object.
    -- (the field is read inside the protected block, and only for a single channel: a base that got update.psql but not
    -- P00000040 has no such column, and the sweep of every other channel must not stop for it)
    IF c.mode = 'single' THEN
      BEGIN
        IF c.on_release IS NOT NULL THEN
          nCount := nCount + notify.release(c.code, false, pLimit);
        END IF;
      EXCEPTION
      WHEN OTHERS THEN
        RAISE WARNING 'notify.sweep_channel: on_release of "%" failed: %', c.code, SQLERRM;
      END;
    END IF;
  END IF;

  RETURN nCount;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

/**
 * @brief The look-over every subscriber makes on a timer and after a reconnect:
 *        notify.sweep_channel of the channel the subscriber listens on.
 * @param {integer} pSubscriber - Subscriber number; its channel is looked over
 * @param {integer} pLimit - Rows per kind per call
 * @return {integer} - Rows it acted on; 0 for a number that is not registered
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION notify.sweep (
  pSubscriber   integer,
  pLimit        integer DEFAULT 100
) RETURNS       integer
AS $$
DECLARE
  vChannel      text;
BEGIN
  SELECT channel INTO vChannel FROM notify.subscriber WHERE id = pSubscriber;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  RETURN notify.sweep_channel(vChannel, pLimit);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RELEASE ---------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Call the function the channel names in on_release: the owning module's look at the objects that stand in
 *        the delivery of the channel and hold no open row of the queue (T1158, T1165). A channel with no such
 *        function: nothing to do.
 * @param {text} pChannel - Channel
 * @param {boolean} pSwitch - The channel has just been switched to single (the trigger): the function may refuse
 *        the switch with an exception. false: the sweep of a single channel
 * @param {integer} pLimit - Objects per call; NULL for all (the switch hands every object over at once)
 * @return {integer} - Objects the function acted on
 * @since 1.2.39
 *
 * The name is text that runs under EXECUTE, as on_abandon does: it is checked where it is written
 * (notify.ft_channel_check) and the function is closed to PUBLIC like the rest of the module.
 */
CREATE OR REPLACE FUNCTION notify.release (
  pChannel      text,
  pSwitch       boolean DEFAULT false,
  pLimit        integer DEFAULT 100
) RETURNS       integer
AS $$
DECLARE
  vFn           text;
  nCount        integer;
BEGIN
  SELECT on_release INTO vFn FROM notify.channel WHERE code = pChannel;

  IF vFn IS NULL THEN
    RETURN 0;
  END IF;

  EXECUTE format('SELECT %s($1, $2)', vFn) INTO nCount USING pSwitch, pLimit;

  RETURN coalesce(nCount, 0);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RETARGET --------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Work out again the addressee of the waiting rows of a key and wake the new one.
 *        A configuration calls it when the answer of target_fn for the key changed (a
 *        route was written, a holder moved): the rows do not wait for the next tick
 *        of the sweep. Only the first waiting row is woken: the others of the key
 *        follow it in order (notify.take).
 * @param {text} pChannel - Channel
 * @param {text} pKey - Key
 * @return {integer} - Waiting rows whose addressee changed
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION notify.retarget (
  pChannel      text,
  pKey          text
) RETURNS       integer
AS $$
DECLARE
  c             notify.channel%ROWTYPE;
  q             record;
  nTarget       integer;
  nFirst        bigint;
  nCount        integer := 0;
BEGIN
  IF pKey IS NULL THEN
    RETURN 0;
  END IF;

  SELECT * INTO c FROM notify.channel WHERE code = pChannel;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  nTarget := notify.pick_target(c.code, c.affinity, pKey, c.target_fn, c.alive);

  -- A row somebody is working on at this moment (locked) is theirs: skipped.
  FOR q IN
    SELECT id, target FROM notify.queue
     WHERE channel = c.code AND key = pKey AND state = 0
     ORDER BY id
       FOR UPDATE SKIP LOCKED
  LOOP
    nFirst := coalesce(nFirst, q.id);

    IF q.target IS DISTINCT FROM nTarget THEN
      UPDATE notify.queue SET target = nTarget WHERE id = q.id;
      nCount := nCount + 1;
    END IF;
  END LOOP;

  IF nFirst IS NOT NULL AND nTarget IS NOT NULL THEN
    UPDATE notify.queue SET woken = clock_timestamp() WHERE id = nFirst;
    PERFORM notify.wake(c.code, nFirst, nTarget);
  END IF;

  RETURN nCount;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PRIVILEGES ------------------------------------------------------------------
--------------------------------------------------------------------------------

-- A function of this schema is SECURITY DEFINER (kernel). The internals take a
-- function NAME as text and run it under EXECUTE (route_holder, route_target,
-- pick_target, close): callable by a role, they are "run any SQL as kernel". So
-- nothing is left to PUBLIC, and the interface alone is granted, to the pools that
-- run subscribers: daemon (the workers) and apibot (the helpers). A role of a
-- configuration (the CSMS: ocpp) gets its own grant from the configuration. The
-- producers need none: they run as kernel inside SECURITY DEFINER chains.
DO $$
DECLARE
  r             record;
BEGIN
  FOR r IN SELECT p.oid::regprocedure AS fn FROM pg_proc p WHERE p.pronamespace = 'notify'::regnamespace
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', r.fn);
  END LOOP;
END $$;

GRANT EXECUTE ON FUNCTION
  notify.send(text, text, text, interval, integer),
  notify.subscribe(text, text, text, text, integer),
  notify.heartbeat(integer, integer),
  notify.drain(integer),
  notify.unsubscribe(integer),
  notify.take(bigint, integer),
  notify.ack(bigint, bigint),
  notify.hold(bigint, bigint),
  notify.nack(bigint, bigint, text),
  notify.sweep(integer, integer),
  notify.sweep_channel(text, integer),
  notify.retarget(text, text),
  notify.channel_policy(text)
TO daemon, apibot;
