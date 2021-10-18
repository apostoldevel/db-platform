--------------------------------------------------------------------------------
-- Document --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Document (Id, Object, Entity, Class, Type, Area, Description,
  AreaCode, AreaName, AreaDescription,
  Scope, ScopeCode, ScopeName, ScopeDescription
) AS
  SELECT d.id, d.object, d.entity, d.class, d.type, d.area, dt.description,
         a.code, a.name, a.description,
         a.scope, s.code, s.name, s.description
    FROM db.document d INNER JOIN db.area           a ON d.area = a.id
                       INNER JOIN db.scope          s ON s.id = a.scope
                        LEFT JOIN db.document_text dt ON d.id = dt.document AND dt.locale = current_locale();

GRANT SELECT ON Document TO administrator;

--------------------------------------------------------------------------------
-- CurrentDocument -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW CurrentDocument (Id, Object, Entity, Class, Type, Area, Description,
  AreaCode, AreaName, AreaDescription,
  Scope, ScopeCode, ScopeName, ScopeDescription
) AS
  WITH RECURSIVE _area_tree(id, parent) AS (
    SELECT id, parent FROM db.area WHERE type = '00000000-0000-4002-a001-000000000000' AND scope IS NOT DISTINCT FROM current_scope() AND id IS DISTINCT FROM current_area()
     UNION
    SELECT id, parent FROM db.area WHERE id IS NOT DISTINCT FROM current_area()
     UNION
    SELECT a.id, a.parent
      FROM db.area a INNER JOIN _area_tree t ON a.parent = t.id
     WHERE a.type IS DISTINCT FROM '00000000-0000-4002-a001-000000000000' AND scope IS NOT DISTINCT FROM current_scope()
  )
  SELECT d.id, d.object, d.entity, d.class, d.type, d.area, dt.description,
         a.code, a.name, a.description,
         a.scope, s.code, s.name, s.description
    FROM db.document d INNER JOIN _area_tree        t ON d.area = t.id
                       INNER JOIN db.area           a ON d.area = a.id
                       INNER JOIN db.scope          s ON s.id = a.scope
                        LEFT JOIN db.document_text dt ON d.id = dt.document AND dt.locale = current_locale();

GRANT SELECT ON CurrentDocument TO administrator;

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
  Area, AreaCode, AreaName, AreaDescription,
  Scope, ScopeCode, ScopeName, ScopeDescription
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
         d.area, d.areacode, d.areaname, d.areadescription,
         d.scope, d.scopecode, d.scopename, d.scopedescription
    FROM CurrentDocument d INNER JOIN Object o ON o.id = d.object;

GRANT SELECT ON ObjectDocument TO administrator;

--------------------------------------------------------------------------------
-- VIEW SafeDocument -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW SafeDocument
AS
  WITH Access AS (
	WITH _membergroup AS (
	  SELECT current_userid() AS userid UNION SELECT userid FROM db.member_group WHERE member = current_userid()
	)
	SELECT a.object
      FROM db.document d INNER JOIN db.aou       a ON d.object = a.object
                         INNER JOIN _membergroup m ON a.userid = m.userid
     GROUP BY a.object
	HAVING (bit_or(a.allow) & ~bit_or(a.deny)) & B'100' = B'100'
  )
  SELECT d.* FROM ObjectDocument d INNER JOIN Access a ON d.object = a.object;

GRANT SELECT ON SafeDocument TO administrator;
