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
  SELECT s.id, s.peer, p.code AS peercode, s.channel, c.code AS channelcode,
         s.direction, s.started, s.finished, s.messages, s.bytes, s.result, s.message
    FROM mq.session s
   INNER JOIN mq.peer p ON p.id = s.peer
   INNER JOIN mq.channel c ON c.id = s.channel;

GRANT SELECT ON MQSession TO administrator;

--------------------------------------------------------------------------------
-- MQIngest --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW MQIngest
AS
  SELECT i.type, i.handler, i.channel, c.code AS channelcode, i.enabled, i.created, i.updated
    FROM mq.ingest i LEFT JOIN mq.channel c ON c.id = i.channel;

GRANT SELECT ON MQIngest TO administrator;
