--------------------------------------------------------------------------------
-- Comment ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Comment
AS
  SELECT c.id, c.parent, c.object,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription, o.label,
         c.owner, u.username, u.name, u.given_name, u.family_name, u.patronymic_name,
         u.email, u.email_verified, u.phone, u.phone_verified,
         c.priority, c.created, c.updated, c.text, c.data
    FROM db.comment c INNER JOIN Object o ON c.object = o.id
                      INNER JOIN Users  u ON c.owner = u.id AND u.scope = current_scope();

GRANT SELECT ON Comment TO administrator;
