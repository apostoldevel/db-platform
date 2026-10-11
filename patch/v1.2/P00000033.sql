--------------------------------------------------------------------------------
-- P00000033 -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- T783 (apostol-csms): api.send_push_all leaves the platform.
--
-- The wrapper was the only platform function calling a CSMS-configuration
-- function (SendPushAll, broadcast campaigns): on a base without that
-- configuration the guarded call died with 42883, and even on a CSMS base the
-- wrapper mis-declared the result — SendPushAll returns the campaign uuid
-- while the wrapper promised integer, so an admin call crashed on the RETURN.
--
-- The function now lives in the CSMS configuration layer
-- (configuration/csms/broadcast/api.sql), created by update.psql after this
-- patch. update.psql cannot replace it by itself: CREATE OR REPLACE refuses
-- to change the return type of an existing function, so the old integer shape
-- is dropped here, conditionally — a base that already lost the old shape
-- (re-run of this patch, or a base where the drop was done by hand) keeps
-- whatever it has.
--
-- DDL only: kernel phase, no \connect. Re-runnable.

\set ON_ERROR_STOP on

DO $$
BEGIN
  IF EXISTS (
    SELECT FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'api'
       AND p.oid = to_regprocedure('api.send_push_all(text, text)')
       AND p.prorettype <> 'uuid'::regtype
  ) THEN
    DROP FUNCTION api.send_push_all(text, text);
  END IF;
END $$;
