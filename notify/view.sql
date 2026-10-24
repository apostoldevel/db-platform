--------------------------------------------------------------------------------
-- NotifyChannel ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW NotifyChannel
AS
  SELECT * FROM notify.channel;

GRANT SELECT ON NotifyChannel TO administrator;

--------------------------------------------------------------------------------
-- NotifySubscriber ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW NotifySubscriber
AS
  SELECT * FROM notify.subscriber;

GRANT SELECT ON NotifySubscriber TO administrator;

--------------------------------------------------------------------------------
-- NotifyQueue -----------------------------------------------------------------
--------------------------------------------------------------------------------

-- The payload is not shown: it is data of the producer's, and on some channels
-- it carries what the producer's own record protects.

CREATE OR REPLACE VIEW NotifyQueue
AS
  SELECT id, channel, key, expire, max_attempts, dedupe, target, state, owner, token,
         taken, lease_until, seen, attempts, error, created, done, woken
    FROM notify.queue;

GRANT SELECT ON NotifyQueue TO administrator;
