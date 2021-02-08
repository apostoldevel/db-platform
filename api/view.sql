--------------------------------------------------------------------------------
-- VIEW Routs ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Routs
AS
  SELECT r.method, CollectPath(r.path) AS path, e.definition
    FROM db.route r INNER JOIN db.endpoint e ON r.endpoint = e.id;

GRANT SELECT ON Routs TO administrator;
