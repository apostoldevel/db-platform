--------------------------------------------------------------------------------
-- Form ------------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Form (Id, Entity, EntityCode, EntityName,
  Code, Name, Description
)
AS
  SELECT f.id, f.entity, e.code, et.name,
         f.code, ft.name, ft.description
    FROM db.form f INNER JOIN db.entity       e ON f.entity = e.id
                    LEFT JOIN db.entity_text et ON et.entity = e.id AND et.locale = current_locale()
                    LEFT JOIN db.form_text   ft ON ft.form = f.id AND ft.locale = current_locale();

GRANT SELECT ON Form TO administrator;
