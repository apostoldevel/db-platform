--------------------------------------------------------------------------------
-- VIEW File -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW File 
AS
  SELECT t.id, t.root, t.parent, t.link,
         t.owner, u.username, u.name AS userlabel,
         t.type,
         CASE
         WHEN t.type = '-' THEN 'File'
         WHEN t.type = 'd' THEN 'Directory'
         WHEN t.type = 'l' THEN 'Link'
         WHEN t.type = 's' THEN 'Storage'
         END AS typelabel,
         t.mask, t.level, t.path, t.name,
         t.size, t.date,
         t.mime, t.text, t.hash, t.url, t.done, t.fail
    FROM db.file t INNER JOIN db.user u ON u.id = t.owner;

GRANT SELECT ON File TO administrator;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW FileData
AS
  SELECT t.id, t.root, t.parent, t.link,
         t.owner, u.username, u.name AS userlabel,
         t.type,
         CASE
         WHEN t.type = '-' THEN 'File'
         WHEN t.type = 'd' THEN 'Directory'
         WHEN t.type = 'l' THEN 'Link'
         WHEN t.type = 's' THEN 'Storage'
         END AS typelabel,
         t.mask, t.level, t.path, t.name,
         t.size, t.date, encode(t.data, 'base64') AS data,
         t.mime, t.text, t.hash, t.url, t.done, t.fail
    FROM db.file t INNER JOIN db.user u ON u.id = t.owner;

GRANT SELECT ON FileData TO administrator;

--------------------------------------------------------------------------------
-- VIEW FileFree ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW FileTree
AS
  WITH RECURSIVE tree AS (
    SELECT *, ARRAY[row_number() OVER (ORDER BY level, name)] AS sortlist FROM File WHERE parent IS NULL
     UNION ALL
    SELECT f.*, array_append(t.sortlist, row_number() OVER (ORDER BY f.level, f.parent, f.name))
      FROM File f INNER JOIN tree t ON f.parent = t.id
  ) SELECT t.*, array_to_string(sortlist, '.', '0') AS Index FROM tree t;

GRANT SELECT ON FileTree TO administrator;

--------------------------------------------------------------------------------
-- FileObject ------------------------------------------------------------------
--------------------------------------------------------------------------------
-- The list side of the read barrier (1.2.24). FileTree under the name shape
-- api.sql() recognises: api.sql('kernel', 'FileObject', …) derives the access
-- view as replace(lower('FileObject'), 'object', 'access') = FileAccess, attaches
-- `WITH aou AS MATERIALIZED (SELECT object FROM kernel.fileaccess)` at run time
-- and skips it for the administrator — the dynamic model every Object<X> /
-- Access<X> pair uses. The usual prefix form is taken: ObjectFile is the
-- attachment view of the entity module, and its derived name AccessFile would
-- have joined on a column FileTree does not have.
--
-- FileAccess itself is defined in entity/object/document/view.sql: the rule it
-- states reads db.object_file and db.document, and the entity module loads
-- after this one (the trap GetFileMask documents). Nothing here resolves the
-- name before run time.

CREATE OR REPLACE VIEW FileObject
AS
  SELECT * FROM FileTree;

GRANT SELECT ON FileObject TO administrator;
