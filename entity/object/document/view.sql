--------------------------------------------------------------------------------
-- Document --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Document (Id, Object, Entity, Class, Type, Area, Description,
  AreaCode, AreaName, AreaDescription
) AS
  WITH RECURSIVE _area_tree(id, parent) AS (
    SELECT id, parent FROM db.area WHERE id = GetArea('default') AND id IS DISTINCT FROM current_area()
     UNION ALL
    SELECT id, parent FROM db.area WHERE id = current_area()
     UNION ALL
    SELECT a.id, a.parent
      FROM db.area a INNER JOIN _area_tree t ON a.parent = t.id
     WHERE a.id IS DISTINCT FROM GetArea('default')
  )
  SELECT d.id, d.object, d.entity, d.class, d.type, d.area, dt.description,
         a.code, a.name, a.description
    FROM db.document d  LEFT JOIN db.document_text dt ON d.id = dt.document AND dt.locale = current_locale()
                       INNER JOIN _area_tree t ON d.area = t.id
                       INNER JOIN db.area a ON d.area = a.id;

GRANT SELECT ON Document TO administrator;

--------------------------------------------------------------------------------
-- ObjectDocument --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectDocument (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Label, Description, Text,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Area, AreaCode, AreaName, AreaDescription
)
AS
  SELECT d.id, d.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         o.label, d.description, o.text,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         d.area, d.areacode, d.areaname, d.areadescription
    FROM Document d INNER JOIN Object o ON d.object = o.id;

GRANT SELECT ON ObjectDocument TO administrator;
