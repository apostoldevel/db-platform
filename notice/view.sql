--------------------------------------------------------------------------------
-- Notice ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Notice
AS
  SELECT n.id, n.userid, n.object,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription, o.label,
         n.text, n.category, n.status,
         CASE
         WHEN n.status = 0 THEN 'created'
         WHEN n.status = 1 THEN 'delivered'
         WHEN n.status = 2 THEN 'read'
         WHEN n.status = 3 THEN 'accepted'
         WHEN n.status = 4 THEN 'refused'
         ELSE 'undefined'
         END AS StatusCode,
         n.created, n.updated
    FROM db.notice n LEFT JOIN Object o ON n.object = o.id;

GRANT SELECT ON Notice TO administrator;
