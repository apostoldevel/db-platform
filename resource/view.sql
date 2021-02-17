--------------------------------------------------------------------------------
-- Resource --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Resource (Id, Root, Node, Type, Level, Sequence,
    Name, Description, Encoding, Data, Updated,
    Locale, LocaleCode, LocaleName, LocaleDescription
)
AS
  SELECT r.id, r.root, r.node, r.type, r.level, r.sequence,
         d.name, d.description, d.encoding, d.data, d.updated,
         d.locale, l.code, l.name, l.description
    FROM db.resource r INNER JOIN db.resource_data d ON d.resource = r.id AND d.locale = current_locale()
                       INNER JOIN db.locale        l ON l.id = d.locale;

GRANT SELECT ON Resource TO administrator;

--------------------------------------------------------------------------------
-- VIEW ResourceTree -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ResourceTree
AS
  WITH _resource_tree AS (
    WITH RECURSIVE tree AS (
      SELECT *, ARRAY[row_number() OVER (ORDER BY level, sequence)] AS sortlist FROM Resource WHERE node IS NULL
       UNION ALL
      SELECT s.*, array_append(t.sortlist, row_number() OVER (ORDER BY s.level, s.node, s.sequence))
        FROM Resource s INNER JOIN tree t ON s.node = t.id
    ) SELECT * FROM tree
  ) SELECT st.*, array_to_string(sortlist, '.', '0') AS Index FROM _resource_tree st;

GRANT SELECT ON ResourceTree TO administrator;
