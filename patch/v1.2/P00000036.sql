--------------------------------------------------------------------------------
-- P00000036 -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- T1014 (apostol-csms): an index by age on the two HTTP tables.
--
-- http.request and http.log were never purged and have no index by datetime; a
-- collector that removes what is older than a retention period would read the
-- whole table to find it, once per call. The indexes are the ones table.sql
-- creates now (`CREATE INDEX ON http.request (datetime)` is named
-- request_datetime_idx, http.log -- log_datetime_idx), so that a base built by
-- this patch and a base installed afresh are the same.
--
-- DDL only: kernel phase, no \connect. Re-runnable. The tables are small next
-- to their responses (http.response is not indexed here: it goes with its
-- request by ON DELETE CASCADE, along the index on http.response (request)).

\set ON_ERROR_STOP on

CREATE INDEX IF NOT EXISTS request_datetime_idx ON http.request (datetime);
CREATE INDEX IF NOT EXISTS log_datetime_idx ON http.log (datetime);
