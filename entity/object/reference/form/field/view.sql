--------------------------------------------------------------------------------
-- FormField -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW FormField (Form, FormCode, FormName, FormDescription,
  Key, Type, Label, Format, Value, Data, Mutable, Sequence
)
AS
  SELECT f.id, f.code, f.name, f.description,
         t.key, t.type, t.label, t.format, t.value, t.data, t.mutable, t.sequence
    FROM db.form_field t INNER JOIN Form f ON t.form = f.id;

GRANT SELECT ON FormField TO administrator;
