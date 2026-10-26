--------------------------------------------------------------------------------
-- P00000041 -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- The channel `http`: `expire` = 10 minutes (apostol-csms T1150, the owner's word 25.10, variant A).
--
-- A request of the channel `http` without an `expire` of its own -- the reads of a status, the binding of a card,
-- the onboarding, a command to a station -- had no limit on how long it may wait for a sender. Under `single` a row
-- that no sender took within 10 minutes of the first look of a subscriber (notify.queue.seen) is now closed
-- `unsent: expired` -> http.abandon -> "not sent", the producer is NOT called (the on_expire of P00000038). A request
-- with an `expire` of its own is not touched: notify.take and notify.sweep_channel read coalesce(q.expire, c.expire),
-- so the payment kinds with a lifetime of their own (create 15 min, capture / cancel / refund 23 h / 50 min) keep it.
--
-- What it does NOT do: the channel is `legacy` on every installation, so none of this is in force until it is switched
-- (`single` is a separate word of the owner, per site); the value protects against a row nobody took only when a
-- subscriber has looked at the row -- a channel with no live subscriber is looked over by the job of the configuration
-- (api.sweep_notify_channel('http'), the configuration's P00000102).
--
-- The guard: only a row whose `expire` is NULL is filled -- a value an operator set stays. An operator who set NULL on
-- purpose ("no limit") cannot be told from a row never set: the value is filled again. The mode is not asked: nothing
-- of the channel changes while it is `legacy`, and a base already `single` meets the value the same way.
--
-- notify/init.sql carries the same statement for a fresh install (and for a base that comes through P00000035, which
-- includes it); this patch is for a base past P00000035, where init.sql is not run again. Single phase, kernel,
-- repeatable, no session.
--------------------------------------------------------------------------------

UPDATE notify.channel SET expire = interval '10 minutes'
 WHERE code = 'http' AND expire IS NULL;
