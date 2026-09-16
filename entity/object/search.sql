--------------------------------------------------------------------------------
-- api.search ------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Shape of search_en / search_ru (T306, 16.09.2026). The first version built
-- the user's whole access set first — aou(current_userid()), 664 k rows for an
-- administrator, 1.4 s — and drove the text search from it: 664 k index probes
-- into object_text, then a hash join over the entire api.object view. 6.7 s for
-- two hits. Now the GIN search runs first (ms), access is checked per hit with
-- aou(user, object) — the same predicate, applied to the hits instead of to the
-- world — and api.object is entered through `id = ANY(array)`, which the planner
-- turns into index probes instead of a full scan of the view's dozen-plus joins.
-- MATERIALIZED keeps the two CTEs from being flattened back into that plan.
-- Measured on the same base: 2 hits 6.7 s → 12 ms, 1 615 hits 6.6 s → 125 ms,
-- identical row sets.
/**
 * @brief Perform full-text search across objects using the English locale index.
 * @param {text} pText - Search query string
 * @return {SETOF api.object} - Matching objects (access-filtered)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.search_en (
  pText      text
) RETURNS    SETOF api.object
AS $$
  WITH search AS MATERIALIZED (
  SELECT o.object
    FROM db.object_text o
   WHERE o.locale = '00000000-0000-4001-a000-000000000001'
     AND o.searchable_en @@ websearch_to_tsquery('english', pText)
   UNION
  SELECT r.object
    FROM db.reference r
   WHERE r.code LIKE pText || '%'
  ), allowed AS MATERIALIZED (
  SELECT s.object
    FROM search s
   WHERE EXISTS (SELECT 1 FROM aou(current_userid(), s.object) a WHERE a.mask & B'100' = B'100')
  ) SELECT o.* FROM api.object o WHERE o.id = ANY (ARRAY(SELECT object FROM allowed));
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
/**
 * @brief Perform full-text search across objects using the Russian locale index.
 * @param {text} pText - Search query string
 * @return {SETOF api.object} - Matching objects (access-filtered)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.search_ru (
  pText      text
) RETURNS    SETOF api.object
AS $$
  WITH search AS MATERIALIZED (
  SELECT o.object
    FROM db.object_text o
   WHERE o.locale = '00000000-0000-4001-a000-000000000002'
     AND o.searchable_ru @@ websearch_to_tsquery('russian', pText)
   UNION
  SELECT r.object
    FROM db.reference r
   WHERE r.code LIKE pText || '%'
  ), allowed AS MATERIALIZED (
  SELECT s.object
    FROM search s
   WHERE EXISTS (SELECT 1 FROM aou(current_userid(), s.object) a WHERE a.mask & B'100' = B'100')
  ) SELECT o.* FROM api.object o WHERE o.id = ANY (ARRAY(SELECT object FROM allowed));
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
/**
 * @brief Perform full-text search with locale auto-detection and entity filtering.
 * @param {text} pText - Search query string
 * @param {jsonb} pEntities - JSON array of entity codes to filter by (NULL = all)
 * @param {text} pLocaleCode - Locale code ('ru' or 'en', defaults to session locale)
 * @return {SETOF api.object} - Matching objects filtered by entity and access
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.search (
  pText         text,
  pEntities     jsonb DEFAULT null,
  pLocaleCode   text DEFAULT locale_code()
) RETURNS       SETOF api.object
AS $$
DECLARE
  arClasses     text[];
BEGIN
  SELECT array_agg(t.code) INTO arClasses
    FROM db.class_tree t INNER JOIN db.entity e on e.id = t.entity
   WHERE e.code = ANY(JsonbToStrArray(pEntities)) AND NOT abstract;

  IF pLocaleCode = 'ru' THEN
    RETURN QUERY SELECT * FROM api.search_ru(pText) WHERE array_position(coalesce(arClasses, ARRAY[classcode]), classcode) IS NOT NULL;
  ELSE
    RETURN QUERY SELECT * FROM api.search_en(pText) WHERE array_position(coalesce(arClasses, ARRAY[classcode]), classcode) IS NOT NULL;
  END IF;

  RETURN;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
