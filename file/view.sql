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
         END AS typelabel,
         t.mask, t.level, t.path, t.name,
         t.size, t.date,
         t.mime, t.text, t.hash, t.url
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
         END AS typelabel,
         t.mask, t.level, t.path, t.name,
         t.size, t.date, encode(t.data, 'base64') AS data,
         t.mime, t.text, t.hash, t.url
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
