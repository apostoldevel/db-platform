--------------------------------------------------------------------------------
-- api.search ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.search_en (
  pText      text
) RETURNS    SETOF api.object
AS $$
  WITH access AS (
    SELECT object FROM aou(current_userid())
  ), search AS (
  SELECT o.object
    FROM db.object_text o INNER JOIN access a ON o.object = a.object
   WHERE o.locale = '00000000-0000-4001-a000-000000000001'
     AND o.searchable_en @@ websearch_to_tsquery('english', pText)
   UNION
  SELECT r.object
    FROM db.reference r INNER JOIN access a ON r.object = a.object
   WHERE r.code LIKE pText || '%'
  ) SELECT o.* FROM api.object o INNER JOIN search s ON o.id = s.object;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.search_ru (
  pText      text
) RETURNS    SETOF api.object
AS $$
  WITH access AS (
    SELECT object FROM aou(current_userid())
  ), search AS (
  SELECT o.object
    FROM db.object_text o INNER JOIN access a ON o.object = a.object
   WHERE o.locale = '00000000-0000-4001-a000-000000000002'
     AND o.searchable_ru @@ websearch_to_tsquery('russian', pText)
   UNION
  SELECT r.object
    FROM db.reference r INNER JOIN access a ON r.object = a.object
   WHERE r.code LIKE pText || '%'
  ) SELECT o.* FROM api.object o INNER JOIN search s ON o.id = s.object;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.search (
  pText         text,
  pEntities     jsonb DEFAULT null,
  pLocaleCode   text DEFAULT locale_code()
) RETURNS       SETOF api.object
AS $$
BEGIN
  IF pLocaleCode = 'ru' THEN
    RETURN QUERY SELECT * FROM api.search_ru(pText) WHERE array_position(coalesce(JsonbToStrArray(pEntities), ARRAY[classcode]), classcode) IS NOT NULL;
  ELSE
    RETURN QUERY SELECT * FROM api.search_en(pText) WHERE array_position(coalesce(JsonbToStrArray(pEntities), ARRAY[classcode]), classcode) IS NOT NULL;
  END IF;

  RETURN;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
