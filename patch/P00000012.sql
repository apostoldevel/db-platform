DROP VIEW Area CASCADE;

DROP FUNCTION api.add_area (uuid, uuid, uuid, text, text, text);
DROP FUNCTION api.update_area (uuid, uuid, uuid, uuid, text, text, text, timestamp, timestamp);

DROP FUNCTION CreateArea (uuid, uuid, uuid, text, text, text, uuid);
DROP FUNCTION EditArea (uuid, uuid, uuid, uuid, text, text, text, timestamp, timestamp);

ALTER TABLE db.area
  ADD COLUMN level integer,
  ADD COLUMN sequence integer;

WITH RECURSIVE area_tree(id, parent) AS (
  SELECT id, parent, 0 AS level FROM db.area WHERE parent IS NULL
  UNION
  SELECT a.id, a.parent, t.level + 1
	FROM db.area a, area_tree t
   WHERE t.id = a.parent
  ) UPDATE db.area r SET level = at.level FROM area_tree at WHERE r.id = at.id;

\ir '../admin/routine.sql'

SELECT SignIn(CreateSystemOAuth2(), 'admin', 'admin');

SELECT GetErrorMessage();

SELECT SortArea(parent) FROM Area WHERE parent IS NOT NULL GROUP BY parent, level ORDER BY level;

SELECT SignOut();

UPDATE db.area SET sequence = 1 WHERE parent IS NULL;

ALTER TABLE db.area
	ALTER COLUMN level SET NOT NULL,
	ALTER COLUMN sequence SET NOT NULL;

COMMENT ON COLUMN db.area.level IS 'Уровень вложенности.';
COMMENT ON COLUMN db.area.sequence IS 'Очерёдность';
