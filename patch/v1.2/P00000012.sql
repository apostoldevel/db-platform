--------------------------------------------------------------------------------
-- daemon.authorization_code ---------------------------------------------------
--------------------------------------------------------------------------------

-- max_age arrives as a new trailing parameter, so CREATE OR REPLACE would not
-- replace anything: a different argument count makes an *overload*, and the
-- nine-argument function — the one that cannot be asked for a fresh sign-in —
-- would stay callable beside the new one. Drop it explicitly.
--
-- P00000011 dropped the eight-argument version for the same reason. After this
-- patch, \df daemon.authorization_code must show exactly one row.

DROP FUNCTION IF EXISTS daemon.authorization_code(varchar, text, text, text, text, text, text, inet, boolean);

--------------------------------------------------------------------------------
