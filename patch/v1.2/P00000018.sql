--------------------------------------------------------------------------------
-- P00000018 -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Case-insensitive uniqueness for db.user.username, case-preserving storage.
--
-- Decision of 2026-09-09 (DECISIONS.md, "Логин хранится как введён, а
-- сравнивается без учёта регистра"): the person's own spelling is theirs to
-- choose — "userName" stays "userName" — and it must be impossible to create a
-- second account as "UserName", "Username" or "username".
--
-- The old index enforced the storage rule instead of the identity rule:
-- UNIQUE (type, username) lets all four spellings coexist. Measured on the test
-- contour the same day, through the ordinary registration path and nothing
-- exotic:
--
--   signup('Ivan.Petrov') → created,  signup('ivan.petrov') → CREATED   (two rows)
--   signup('ivan.petrov') → created,  signup('Ivan.Petrov') → refused
--
-- Same two strings, opposite outcomes, decided by the order of registration.
--
-- This patch replaces the index. The comparisons that read it — sixteen of them
-- across the platform and the configuration — are changed in the routine files
-- to lower(username) = lower(<parameter>). The four places that WRITE the name
-- are deliberately left verbatim: that is what "stored as typed" means.
--------------------------------------------------------------------------------

-- ⚠️ Run the pre-flight below on every deployment BEFORE the release, not here.
-- migrate.sh runs under `set -e`, so the RAISE below aborts the deploy AFTER the
-- earlier patches have committed and BEFORE update.psql — a half-migrated
-- database whose only diagnostic is a failed deploy. The patch is the last place
-- you want to learn this:
--
--   SELECT type, string_agg(quote_literal(username), ', ')
--     FROM db.user GROUP BY type, lower(username) HAVING count(*) > 1;
--
-- Empty on all four deployments as of 2026-09-09 (81 of 81 distinct on prod,
-- 922 of 922 on the test contour). The guard stays anyway: "it was empty when we
-- looked" is not the same as "it is empty now".

DO $$
DECLARE
  vCollisions   text;
BEGIN
  -- Fail with a readable message rather than with a bare index error. A
  -- collision here means two live accounts already differ only by case: the
  -- patch cannot decide which one is the person and which is the duplicate,
  -- and guessing would merge two identities.
  SELECT string_agg(format('%s: %s', t, names), '; ') INTO vCollisions
    FROM (
      SELECT u.type AS t, string_agg(quote_literal(u.username), ', ') AS names
        FROM db.user u
       GROUP BY u.type, lower(u.username)
      HAVING count(*) > 1
    ) x;

  IF vCollisions IS NOT NULL THEN
    RAISE EXCEPTION 'P00000018: db.user holds names that differ only by case, so a case-insensitive unique index cannot be built: %. Resolve them by hand first — which of them is the real account is not something a patch can decide.', vCollisions;
  END IF;
END $$;

-- One unit, not two statements. DROP + CREATE in sequence would leave the table
-- with NO uniqueness at all if the CREATE failed between them — and a release
-- that stops there leaves a live base on which the very duplicates this patch
-- exists to prevent can be created.
--
-- What makes it one unit is the explicit BEGIN/COMMIT below and nothing else:
-- psql wraps each statement separately otherwise, and migrate.sh's phase
-- splitting is about \connect lines, not about transactions. The DROP and the
-- CREATE therefore commit together or not at all. The cost is an ACCESS
-- EXCLUSIVE lock on db.user for the length of the index build — measured in
-- milliseconds at these row counts, and this runs during migration anyway.
BEGIN;

DROP INDEX IF EXISTS db.user_type_username_idx;

CREATE UNIQUE INDEX user_type_username_idx ON db.user (type, lower(username));

COMMIT;
