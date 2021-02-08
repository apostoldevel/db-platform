--------------------------------------------------------------------------------
-- Document --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Document (Id, Object, Entity, Class, Area, Description,
  AreaCode, AreaName, AreaDescription
) AS
  WITH RECURSIVE area_tree(id, parent) AS (
    SELECT id, parent FROM db.area WHERE id = GetArea('default') AND id != current_area()
     UNION ALL
    SELECT id, parent FROM db.area WHERE id = current_area()
     UNION ALL
    SELECT a.id, a.parent
      FROM db.area a INNER JOIN area_tree t ON a.parent = t.id
     WHERE a.id != GetArea('default')
  )
  SELECT d.id, d.object, d.entity, d.class, d.area, d.description,
         a.code, a.name, a.description
    FROM db.document d INNER JOIN area_tree t ON d.area = t.id
                       INNER JOIN db.area a ON d.area = a.id;

GRANT SELECT ON Document TO administrator;

--------------------------------------------------------------------------------
-- ObjectDocument --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectDocument (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Label, Description, Data,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Area, AreaCode, AreaName, AreaDescription
)
AS
  WITH RECURSIVE area_tree(id, parent) AS (
    SELECT id, parent FROM db.area WHERE id = current_area()
     UNION ALL
    SELECT a.id, a.parent
      FROM db.area a INNER JOIN area_tree t ON a.parent = t.id
  )
  SELECT d.id, d.object, o.parent,
         d.entity, e.code, e.name,
         d.class, ct.code, ct.label,
         o.type, t.code, t.name, t.description,
         o.label, d.description, o.data,
         o.state_type, st.code, st.name,
         o.state, s.code, s.label, o.udate,
         o.owner, w.username, w.name, o.pdate,
         o.oper, u.username, u.name, o.ldate,
         d.area, a.code, a.name, a.description
    FROM db.document d INNER JOIN area_tree     at ON d.area = at.id
                       INNER JOIN db.area        a ON d.area = a.id
                       INNER JOIN db.entity     e ON d.entity = e.id
                       INNER JOIN db.class_tree ct ON d.class = ct.id
                       INNER JOIN db.object      o ON d.object = o.id
                       INNER JOIN db.type        t ON o.type = t.id
                       INNER JOIN db.state_type st ON o.state_type = st.id
                       INNER JOIN db.state       s ON o.state = s.id
                       INNER JOIN db.user        w ON o.owner = w.id
                       INNER JOIN db.user        u ON o.oper = u.id;

GRANT SELECT ON ObjectDocument TO administrator;
