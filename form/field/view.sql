--------------------------------------------------------------------------------
-- FormField -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW FormField (Form, FormCode, FormName, FormDescription,
  Key, Type, Label, Format, Value, Data, Mutable, Sequence,
  Locale, LocaleCode, LocaleName, LocaleDescription
)
AS
  SELECT t.form, f.code, ft.name, ft.description,
         t.key, t.type, t.label, t.format, t.value, t.data, t.mutable, t.sequence,
         t.locale, l.code, l.name, l.description
    FROM db.form_field t INNER JOIN db.form       f ON t.form = f.id
                          LEFT JOIN db.form_text ft ON t.form = ft.form AND t.locale = ft.locale
                         INNER JOIN db.locale     l ON t.locale = l.id
   WHERE t.locale = current_locale();

GRANT SELECT ON FormField TO administrator;
