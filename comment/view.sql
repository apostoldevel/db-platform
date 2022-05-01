--------------------------------------------------------------------------------
-- Comment ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Comment (id, parent, object,
  entity, entitycode, entityname,
  class, classcode, classlabel,
  type, typecode, typename, typedescription, label,
  owner, username, name, given_name, family_name, patronymic_name,
  email, email_verified, phone, phone_verified,
  priority, created, updated, text, data, picture
) AS
  SELECT t.id, t.parent, t.object,
         o.entity, e.code, et.name,
         o.class, c.code, ct.label,
         o.type, y.code, ty.name, ty.description, ot.label,
         t.owner, u.username, u.name, p.given_name, p.family_name, p.patronymic_name,
         u.email, p.email_verified, u.phone, p.phone_verified,
         t.priority, t.created, t.updated, t.text, t.data, p.picture
    FROM db.comment t INNER JOIN db.object            o ON t.object = o.id
                       LEFT JOIN db.object_text      ot ON ot.object = o.id AND ot.locale = current_locale()
                      INNER JOIN db.entity            e ON o.entity = e.id
                       LEFT JOIN db.entity_text      et ON et.entity = e.id AND et.locale = current_locale()
                      INNER JOIN db.class_tree        c ON o.class = c.id
                       LEFT JOIN db.class_text       ct ON ct.class = c.id AND ct.locale = current_locale()
                      INNER JOIN db.type              y ON o.type = y.id
                       LEFT JOIN db.type_text        ty ON ty.type = y.id AND ty.locale = current_locale()
                      INNER JOIN db.user              u ON t.owner = u.id
                      INNER JOIN db.profile           p ON p.userid = u.id AND p.scope = current_scope();

GRANT SELECT ON Comment TO administrator;
