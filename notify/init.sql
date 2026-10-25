--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

-- No application group here, on purpose. mq has one because its REST routes ask
-- IsUserRole(GetGroup('mq'), ...); no function of this module asks about a group
-- (the REST routes are the administrator's), so a group `notify` would decide
-- nothing and suggest that membership grants access. Who may call the functions is
-- the USAGE on the schema (schema.sql): the roles daemon and apibot, the group
-- administrator, and whatever role a configuration grants it to (the CSMS: ocpp, by its
-- own grant -- T590 step 2, not made yet). EXECUTE on the functions is granted in routine.sql.

--------------------------------------------------------------------------------
-- Channels of the platform ----------------------------------------------------
--------------------------------------------------------------------------------

-- EVERY channel is legacy: notify.send is a plain pg_notify, so a binary that
-- does not know this module and a binary that does can share a database. The
-- description says what the channel is meant to become; the switch to single is
-- made per installation, by the owner's word, when every instance listening on
-- the channel is new (notify.channel is edited through /notify/channel/set).
--
-- The values besides mode are the policy the channel will have when it is
-- switched: they are not in force while the mode is legacy, except for rows
-- already in notify.queue (take, ack, nack and the sweep bring those to their
-- end whatever the mode is). The other exception belongs to the executor, not
-- to this module: a TaskScheduler that has T1104 (an earlier one sets no limit)
-- reads the lease of the channel `job` on every poll (1 s by default), in every
-- mode, and sets statement_timeout for each statement of a job body at 8/10 of
-- the lease and, where the server has transaction_timeout (PostgreSQL 17 and
-- later), for the whole body at 9/10. With that binary the lease of `job` --
-- 10 minutes as seeded below -- limits a body even while the channel is legacy.
--
-- Channels of a configuration are registered by the configuration (its own
-- notify/init.sql); notify.send records a channel nobody registered as
-- unclassified.

INSERT INTO notify.channel (code, description, mode, affinity, grace, lease, max_attempts, dedupe, retain_done, on_expire)
VALUES
  ('http',         'Outbound HTTP request (http.request). Meant: single/any -- one PGFetch does the call; a repeat is the producer''s decision, not the channel''s.', 'legacy', 'any', interval '3 seconds', interval '5 minutes', 0, false, interval '7 days', false),
  ('outbox',       'Outgoing message (db.notification). Meant: single/any -- one MessageServer sends the mail; an unknown outcome is not repeated.', 'legacy', 'any', interval '3 seconds', interval '5 minutes', 0, false, interval '7 days', false),
  ('report',       'Report to build (db.notification). Meant: single/any -- one ReportServer builds it.', 'legacy', 'any', interval '3 seconds', interval '10 minutes', 0, false, interval '7 days', false),
  ('job',          'Job that is due (job_due()). Meant: single/any with dedupe on (job id, planned time) -- one TaskScheduler runs it; one repeat after the executor died.', 'legacy', 'any', interval '3 seconds', interval '10 minutes', 1, true, interval '1 day', false),
  ('file',         'File changed (db.file). Meant: per installation -- single when the volume is shared, broadcast when each PGFile has its own disk.', 'legacy', 'any', interval '3 seconds', interval '5 minutes', 0, false, interval '7 days', false),
  ('replication',  'Replication log entry. Meant: single/any; the owner decides per project.', 'legacy', 'any', interval '3 seconds', interval '5 minutes', 0, false, interval '7 days', false),
  ('mq',           'Message transport: a message was written. Meant: single/any; the owner decides per project.', 'legacy', 'any', interval '3 seconds', interval '5 minutes', 0, false, interval '7 days', false),
  ('log',          'A log row (db.log). Broadcast: every WebSocket server forwards it to its own sockets.', 'legacy', 'any', interval '3 seconds', interval '1 minute', null, false, interval '7 days', false),
  ('geo',          'Geo position of an object. Broadcast: every WebSocket server forwards it to its own sockets.', 'legacy', 'any', interval '3 seconds', interval '1 minute', null, false, interval '7 days', false),
  ('notify',       'Notification row (db.notification). Broadcast to WebSocket servers.', 'legacy', 'any', interval '3 seconds', interval '1 minute', null, false, interval '7 days', false),
  ('inbox',        'Incoming message notification. Broadcast to WebSocket servers.', 'legacy', 'any', interval '3 seconds', interval '1 minute', null, false, interval '7 days', false),
  ('notice',       'User notice (db.notice). Broadcast to WebSocket servers.', 'legacy', 'any', interval '3 seconds', interval '1 minute', null, false, interval '7 days', false),
  ('message',      'Message row (db.message). Broadcast.', 'legacy', 'any', interval '3 seconds', interval '1 minute', null, false, interval '7 days', false),
  ('gateway',      'A route of /api/v2 changed (schema gateway). Broadcast: every GatewayAPI refreshes its own cache.', 'legacy', 'any', interval '3 seconds', interval '1 minute', null, false, interval '7 days', false),
  ('gateway_cmd',  'Signed command / answer between GatewayAPI workers; written by C++ (pg_notify directly), every receiver filters by id. Broadcast by design.', 'legacy', 'any', interval '3 seconds', interval '1 minute', null, false, interval '7 days', false),
  ('mq_cmd',       'Message transport: command to a peer. To be inventoried (not used by the CSMS).', 'legacy', 'any', interval '3 seconds', interval '1 minute', null, false, interval '7 days', false),
  ('mq_stalled',   'Message transport: a stream stalled. To be inventoried.', 'legacy', 'any', interval '3 seconds', interval '1 minute', null, false, interval '7 days', false),
  ('mq_dead',      'Message transport: a message went to the dead letters. To be inventoried.', 'legacy', 'any', interval '3 seconds', interval '1 minute', null, false, interval '7 days', false),
  ('mq_refused',   'Message transport: a confirmation was refused. To be inventoried.', 'legacy', 'any', interval '3 seconds', interval '1 minute', null, false, interval '7 days', false),
  ('mq_floor',     'Message transport: the floor of a stream moved. To be inventoried.', 'legacy', 'any', interval '3 seconds', interval '1 minute', null, false, interval '7 days', false)
ON CONFLICT DO NOTHING;

-- API
SELECT RegisterRoute('notify', AddEndpoint('SELECT * FROM rest.notify($1, $2);'));
