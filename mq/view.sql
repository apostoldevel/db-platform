--------------------------------------------------------------------------------
-- MQChannel -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW MQChannel
AS
  SELECT * FROM mq.channel;

GRANT SELECT ON MQChannel TO administrator;

--------------------------------------------------------------------------------
-- MQPeer ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW MQPeer
AS
  SELECT * FROM mq.peer;

GRANT SELECT ON MQPeer TO administrator;

--------------------------------------------------------------------------------
-- MQBinding -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW MQBinding
AS
  SELECT b.id, b.channel, c.code AS channelcode, b.class, b.action, b.type, b.route,
         b.projection, b.enabled, b.created, b.updated
    FROM mq.binding b INNER JOIN mq.channel c ON c.id = b.channel;

GRANT SELECT ON MQBinding TO administrator;

--------------------------------------------------------------------------------
-- MQMessage -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW MQMessage
AS
  SELECT m.source, p.code AS sourcecode, m.channel, c.code AS channelcode, m.serial,
         m.type, m.route, m.key, m.payload, m.signature, m.created, m.received, m.expires,
         d.reason AS deadreason, d.attempt AS deadattempt, d.state AS deadstate
    FROM mq.message m
   INNER JOIN mq.peer p ON p.id = m.source
   INNER JOIN mq.channel c ON c.id = m.channel
    LEFT JOIN mq.dead d ON d.source = m.source AND d.channel = m.channel AND d.serial = m.serial;

GRANT SELECT ON MQMessage TO administrator;

--------------------------------------------------------------------------------
-- MQWatermark -----------------------------------------------------------------
--------------------------------------------------------------------------------

-- The queue depth on the pair is the difference between what this node has
-- published and what the other one has confirmed. It is the honest answer to
-- "is the exchange healthy", and it does not need a process running to be read.

CREATE OR REPLACE VIEW MQWatermark
AS
  SELECT w.peer, p.code AS peercode, w.channel, c.code AS channelcode,
         w.sent, w.received, w.floor, w.skipped, w.updated,
         coalesce((SELECT max(m.serial) FROM mq.message m
                    WHERE m.channel = w.channel AND m.source = (SELECT id FROM mq.peer WHERE local)), 0) - w.sent AS depth
    FROM mq.watermark w
   INNER JOIN mq.peer p ON p.id = w.peer
   INNER JOIN mq.channel c ON c.id = w.channel;

GRANT SELECT ON MQWatermark TO administrator;

--------------------------------------------------------------------------------
-- MQDead ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW MQDead
AS
  SELECT d.source, p.code AS sourcecode, d.channel, c.code AS channelcode, d.serial,
         m.type, m.route, m.payload, d.reason, d.attempt, d.state, d.created, d.updated
    FROM mq.dead d
   INNER JOIN mq.peer p ON p.id = d.source
   INNER JOIN mq.channel c ON c.id = d.channel
   INNER JOIN mq.message m ON m.source = d.source AND m.channel = d.channel AND m.serial = d.serial;

GRANT SELECT ON MQDead TO administrator;

--------------------------------------------------------------------------------
-- MQSession -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW MQSession
AS
  -- link and linkcode are LAST, not next to the channel they belong with.
  -- CREATE OR REPLACE VIEW may append columns and may not insert one in the
  -- middle: it refuses with "cannot change name of view column", and the tidy
  -- reading order would cost every installation a dropped view and everything
  -- that depends on it.
  SELECT s.id, s.peer, p.code AS peercode, s.channel, c.code AS channelcode,
         s.direction, s.started, s.finished, s.messages, s.bytes, s.result, s.message,
         s.link, l.code AS linkcode
    FROM mq.session s
   INNER JOIN mq.peer p ON p.id = s.peer
   INNER JOIN mq.channel c ON c.id = s.channel
    LEFT JOIN mq.link l ON l.id = s.link;

GRANT SELECT ON MQSession TO administrator;

--------------------------------------------------------------------------------
-- MQIngest --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW MQIngest
AS
  SELECT i.type, i.handler, i.channel, c.code AS channelcode, i.enabled, i.created, i.updated
    FROM mq.ingest i LEFT JOIN mq.channel c ON c.id = i.channel;

GRANT SELECT ON MQIngest TO administrator;

--------------------------------------------------------------------------------
-- MQLink ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW MQLink
AS
  SELECT * FROM mq.link;

GRANT SELECT ON MQLink TO administrator;

--------------------------------------------------------------------------------
-- MQSchedule ------------------------------------------------------------------
--------------------------------------------------------------------------------

-- The rows as they are stored: the default rows (peercode NULL) and the rows
-- that narrow them to one node. What is in force for a given node is a
-- different question, and MQPlan answers it.

CREATE OR REPLACE VIEW MQSchedule
AS
  SELECT s.id, s.peer, p.code AS peercode, s.channel, c.code AS channelcode,
         s.link, l.code AS linkcode, s.period, s.batch, s.timeout, s.backoff,
         s.catchup, s.created, s.updated
    FROM mq.schedule s
   INNER JOIN mq.channel c ON c.id = s.channel
   INNER JOIN mq.link l ON l.id = s.link
    LEFT JOIN mq.peer p ON p.id = s.peer;

GRANT SELECT ON MQSchedule TO administrator;

--------------------------------------------------------------------------------
-- MQPlan ----------------------------------------------------------------------
--------------------------------------------------------------------------------

-- What actually happens on every (node, channel, link): whether the lane
-- travels there, which schedule row governs it, when the next session is due
-- and how far behind the node is. It is the answer to "why is nothing moving",
-- and it needs no process running to be read.
--
-- The state is a CODE, not a sentence. A view that returned a translated
-- explanation would be a user-facing string in a function body, which the
-- i18n rule exists to prevent; a code is translated once by whoever displays
-- it, in every language the installation speaks.
--
-- evidential is the flag the period comment refers to: a lane that never
-- expires and is kept forever is a lane whose interval also sets the window in
-- which a truncated tail of the log stays undetectable. It is derived, not
-- declared -- a second column saying so could disagree with the first.

CREATE OR REPLACE VIEW MQPlan
AS
  SELECT p.id AS peer, p.code AS peercode, c.id AS channel, c.code AS channelcode,
         l.id AS link, l.code AS linkcode,
         c.priority, l.threshold, l.metered,
         c.lifetime IS NULL AND c.retention IS NULL AS evidential,
         CASE WHEN NOT p.enabled THEN 'peer-disabled'
              WHEN NOT c.enabled THEN 'channel-disabled'
              WHEN NOT l.enabled THEN 'link-disabled'
              WHEN c.priority > l.threshold THEN 'below-threshold'
              WHEN s.id IS NULL THEN 'no-schedule'
              ELSE 'scheduled'
         END AS state,
         s.id AS schedule, s.scope, s.period, s.batch, s.timeout, s.backoff, s.catchup,
         mq.next_session(p.id, c.id, l.id) AS due,
         mq.depth(p.id, c.id) AS depth
    FROM mq.peer p
   CROSS JOIN mq.channel c
   CROSS JOIN mq.link l
    LEFT JOIN LATERAL mq.get_schedule(c.id, l.id, p.id) s ON true
   WHERE NOT p.local;

GRANT SELECT ON MQPlan TO administrator;
