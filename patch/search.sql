ALTER TABLE db.object
    ADD COLUMN searchable tsvector
    GENERATED ALWAYS AS (to_tsvector('russian', coalesce(label, '') || ' ' || coalesce(data, ''))) STORED;

COMMENT ON COLUMN db.object.searchable IS 'Полнотекстовый поиск';

CREATE INDEX ON db.object USING GIN (searchable);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.search (
  pText		text
) RETURNS	SETOF api.object
AS $$
  WITH access AS (
    SELECT object FROM aou(current_userid())
  ), search AS (
  SELECT o.id
    FROM db.object o INNER JOIN access a ON o.id = a.object
   WHERE o.label ILIKE '%' || pText || '%'
      OR o.data ILIKE '%' || pText || '%'
      OR o.searchable @@ websearch_to_tsquery('russian', pText)
  ) SELECT o.* FROM api.object o INNER JOIN search s ON o.id = s.id;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
