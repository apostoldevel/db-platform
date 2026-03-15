-- P00000001.sql — Fix NULL level in CreateResource when parent node does not exist
--
-- Bug: SELECT level + 1 INTO nLevel FROM db.resource WHERE id = pNode;
-- When pNode is NOT NULL but doesn't exist in db.resource, SELECT INTO
-- sets nLevel to NULL, violating the NOT NULL constraint on db.resource.level.
--
-- Fix: Add NOT FOUND check after the SELECT to fall back to level 0.

\set ON_ERROR_STOP on

CREATE OR REPLACE FUNCTION CreateResource (
  pId           uuid,
  pRoot         uuid,
  pNode         uuid,
  pType         text,
  pName         text,
  pDescription  text DEFAULT null,
  pEncoding     text DEFAULT null,
  pData         text DEFAULT null,
  pSequence     integer DEFAULT null,
  pLocale       uuid DEFAULT current_locale()
) RETURNS       uuid
AS $$
DECLARE
  uResource     uuid;
  nLevel        integer;
BEGIN
  nLevel := 0;

  IF pNode IS NOT NULL THEN
    SELECT level + 1 INTO nLevel FROM db.resource WHERE id = pNode;
    IF NOT FOUND THEN
      nLevel := 0;
    END IF;
  END IF;

  IF NULLIF(pSequence, 0) IS NULL THEN
    SELECT max(sequence) + 1 INTO pSequence FROM db.resource WHERE node IS NOT DISTINCT FROM pNode;
  ELSE
    PERFORM SetResourceSequence(pNode, pSequence, 1);
  END IF;

  uResource := coalesce(pId, gen_random_uuid());

  INSERT INTO db.resource (id, root, node, type, level, sequence)
  VALUES (uResource, pRoot, pNode, pType, nLevel, pSequence);

  PERFORM SetResourceData(uResource, pLocale, pName, pDescription, pEncoding, pData);

  RETURN uResource;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;
