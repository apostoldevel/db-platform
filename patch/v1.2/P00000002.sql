-- P00000002.sql — Fix CreateExceptionResource: bootstrap root node before use
--
-- Bug: CreateExceptionResource passes pRoot as both root and node to SetResource,
-- but the root node (GetExceptionUUID(0,0) = '00000000-0000-4000-9400-000000000000')
-- may not exist in db.resource yet. This causes:
--   1) NULL level (fixed by P00000001)
--   2) FK violation (root REFERENCES db.resource)
--
-- Fix: Create the root exception resource node if it doesn't exist yet.

\set ON_ERROR_STOP on

CREATE OR REPLACE FUNCTION CreateExceptionResource (
  pId            uuid,
  pLocaleCode    text,
  pName          text,
  pDescription   text,
  pRoot          uuid DEFAULT null
) RETURNS        uuid
AS $$
DECLARE
  uLocale        uuid;
  uResource      uuid;

  vCharSet       text;
BEGIN
  uLocale := GetLocale(pLocaleCode);

  IF uLocale IS NOT NULL THEN
    pRoot := NULLIF(coalesce(pRoot, GetExceptionUUID(0, 0)), null_uuid());

    -- Bootstrap: create root node if it doesn't exist yet
    IF pRoot IS NOT NULL AND NOT EXISTS (SELECT 1 FROM db.resource WHERE id = pRoot) THEN
      INSERT INTO db.resource (id, root, node, type, level, sequence)
      VALUES (pRoot, pRoot, null, 'text/plain', 0, 1);
    END IF;

    vCharSet := coalesce(nullif(pg_client_encoding(), 'UTF8'), 'UTF-8');
    uResource := SetResource(pId, pRoot, pRoot, 'text/plain', pName, pDescription, vCharSet, pDescription, null, uLocale);
  END IF;

  RETURN uResource;
END;
$$ LANGUAGE plpgsql;
