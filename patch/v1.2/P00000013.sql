--------------------------------------------------------------------------------
-- ERR-403-001 -> ERR-401-008 ---------------------------------------------------
--------------------------------------------------------------------------------

-- An expired or unknown bearer token answered 403. RFC 6750 §3.1 puts it at 401
-- with invalid_token: the request was not authenticated, which the caller can fix
-- by presenting a valid token. 403 says the token was understood and the answer is
-- still no — a different thing, and the one a client must not retry.
--
-- The status travels inside the identifier (ERR-<http>-<n>), so correcting the
-- status means a new identifier. TokenExpired() now raises GetExceptionStr(401, 8).
--
-- RegisterError only fills in what is missing: it creates the catalog row when the
-- code is absent and then sets the text, and it never revises http_code or category
-- on a row that already exists. So the new code is registered here in full rather
-- than left to init.sql, which a database in service does not re-run.

-- Registered from the catalogue itself rather than copied here: a copy of six
-- translations drifts from the original at the first correction to a wording.
-- RegisterError creates what is missing and rewrites the texts of what is not, so
-- re-registering every code is what makes this safe to repeat.
\ir '../../error/init.sql'

-- RegisterError fills in what is missing; it never revises http_code or category on
-- a row that already exists. A database where ERR-401-008 was created by hand, or
-- by an earlier draft of this patch, would keep the wrong status while its texts
-- were rewritten — and error_code_to_status would answer from that wrong status.
DO $$
DECLARE
  uId     uuid;
BEGIN
  uId := GetErrorCatalog('ERR-401-008');

  IF uId IS NOT NULL THEN
    PERFORM EditErrorCatalog(uId, null, 401, 'E', 'auth');
  END IF;
END $$;

-- The old row goes, and its texts with it (error_catalog_text cascades on the
-- catalog id). Left in place it would answer nothing — no code raises it any more —
-- while still claiming the group 403 is about token expiry.
DELETE FROM db.error_catalog WHERE code = 'ERR-403-001';
