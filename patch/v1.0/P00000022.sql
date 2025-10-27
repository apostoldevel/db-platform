DROP FUNCTION IF EXISTS GetObjectGroup(text);
DROP INDEX db.object_group_code_idx;
CREATE UNIQUE INDEX ON db.object_group (owner, code);

DROP FUNCTION IF EXISTS GetTypeName(uuid);