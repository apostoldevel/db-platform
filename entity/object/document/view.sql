--------------------------------------------------------------------------------
-- DocumentAreaTree ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW DocumentAreaTree
AS
  WITH RECURSIVE area_tree(id, parent) AS (
    SELECT id, parent FROM db.area WHERE type = '00000000-0000-4002-a001-000000000000'::uuid AND scope IS NOT DISTINCT FROM current_scope() AND id IS DISTINCT FROM current_area()
     UNION
    SELECT id, parent FROM db.area WHERE id IS NOT DISTINCT FROM current_area()
     UNION
    SELECT a.id, a.parent
      FROM db.area a INNER JOIN area_tree t ON a.parent = t.id
     WHERE a.type IS DISTINCT FROM '00000000-0000-4002-a001-000000000000'::uuid AND a.scope IS NOT DISTINCT FROM current_scope()
  ) SELECT a.* FROM db.area a INNER JOIN area_tree t USING (id);

GRANT SELECT ON DocumentAreaTree TO administrator;

--------------------------------------------------------------------------------
-- DocumentAreaTreeId ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW DocumentAreaTreeId
AS
  WITH RECURSIVE area_tree(id, parent) AS (
    SELECT id, parent FROM db.area WHERE type = '00000000-0000-4002-a001-000000000000'::uuid AND scope IS NOT DISTINCT FROM current_scope() AND id IS DISTINCT FROM current_area()
     UNION
    SELECT id, parent FROM db.area WHERE id IS NOT DISTINCT FROM current_area()
     UNION
    SELECT a.id, a.parent
      FROM db.area a INNER JOIN area_tree t ON a.parent = t.id
     WHERE a.type IS DISTINCT FROM '00000000-0000-4002-a001-000000000000'::uuid AND a.scope IS NOT DISTINCT FROM current_scope()
  ) SELECT id FROM db.area INNER JOIN area_tree USING (id);

GRANT SELECT ON DocumentAreaTreeId TO administrator;

--------------------------------------------------------------------------------
-- Document --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Document (Id, Object,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Description,
  Priority, PriorityCode, PriorityName, PriorityDescription,
  Area, AreaCode, AreaName, AreaDescription,
  Scope, ScopeCode, ScopeName, ScopeDescription
) AS
  SELECT d.id, d.object,
         d.entity, e.code, et.name,
         d.class, c.code, ct.label,
         d.type, y.code, ty.name, ty.description,
         dt.description,
         d.priority, p.code, pt.name, pt.description,
         d.area, a.code, a.name, a.description,
         d.scope, s.code, s.name, s.description
    FROM db.document d INNER JOIN db.entity            e ON d.entity = e.id
                        LEFT JOIN db.entity_text      et ON et.entity = e.id AND et.locale = current_locale()
                       INNER JOIN db.class_tree        c ON d.class = c.id
                        LEFT JOIN db.class_text       ct ON ct.class = c.id AND ct.locale = current_locale()
                       INNER JOIN db.type              y ON d.type = y.id
                        LEFT JOIN db.type_text        ty ON ty.type = y.id AND ty.locale = current_locale()
                       INNER JOIN db.priority          p ON d.priority = p.id
                        LEFT JOIN db.priority_text    pt ON pt.priority = p.id AND pt.locale = current_locale()
                        LEFT JOIN db.document_text    dt ON dt.document = d.id AND dt.locale = current_locale()
                       INNER JOIN DocumentAreaTree     a ON d.area = a.id
                       INNER JOIN db.scope             s ON d.scope = s.id;

GRANT SELECT ON Document TO administrator;

--------------------------------------------------------------------------------
-- CurrentDocument -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW CurrentDocument (Id, Object,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Description,
  Priority, PriorityCode, PriorityName, PriorityDescription,
  Area, AreaCode, AreaName, AreaDescription,
  Scope, ScopeCode, ScopeName, ScopeDescription
) AS
  SELECT d.id, d.object,
         d.entity, e.code, et.name,
         d.class, c.code, ct.label,
         d.type, y.code, ty.name, ty.description,
         dt.description,
         d.priority, p.code, pt.name, pt.description,
         d.area, a.code, a.name, a.description,
         d.scope, sc.code, sc.name, sc.description
    FROM db.document d INNER JOIN DocumentAreaTree     a ON d.area = a.id

                       INNER JOIN db.entity            e ON d.entity = e.id
                        LEFT JOIN db.entity_text      et ON et.entity = e.id AND et.locale = current_locale()

                       INNER JOIN db.class_tree        c ON d.class = c.id
                        LEFT JOIN db.class_text       ct ON ct.class = c.id AND ct.locale = current_locale()

                       INNER JOIN db.type              y ON d.type = y.id
                        LEFT JOIN db.type_text        ty ON ty.type = y.id AND ty.locale = current_locale()

                       INNER JOIN db.priority          p ON d.priority = p.id
                        LEFT JOIN db.priority_text    pt ON pt.priority = p.id AND pt.locale = current_locale()
                        LEFT JOIN db.document_text    dt ON dt.document = d.id AND dt.locale = current_locale()

                       INNER JOIN db.scope            sc ON d.scope = sc.id;

GRANT SELECT ON CurrentDocument TO administrator;

--------------------------------------------------------------------------------
-- AccessDocumentUser ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AccessDocumentUser (
  pUserId    uuid DEFAULT current_userid()
) RETURNS TABLE (
    object   uuid
)
AS $$
  WITH _membergroup AS (
      SELECT pUserId AS userid UNION SELECT userid FROM db.member_group WHERE member = pUserId
  )
  SELECT a.object
	FROM db.document t INNER JOIN db.aou         a ON a.object = t.id
                       INNER JOIN _membergroup   m ON a.userid = m.userid
   WHERE t.scope = current_scope()
     AND a.mask = B'100'
   GROUP BY a.object
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AccessDocument --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessDocument
AS
WITH _access AS (
  WITH _membergroup AS (
      SELECT current_userid() AS userid UNION SELECT userid FROM db.member_group WHERE member = current_userid()
  )
  SELECT a.object
	FROM db.document t INNER JOIN db.aou         a ON a.object = t.id
                       INNER JOIN _membergroup   m ON a.userid = m.userid
   WHERE t.scope = current_scope()
     AND a.mask = B'100'
   GROUP BY a.object
) SELECT d.* FROM db.document d INNER JOIN _access ac ON d.id = ac.object;

GRANT SELECT ON AccessDocument TO administrator;

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
  Priority, PriorityCode, PriorityName, PriorityDescription,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Area, AreaCode, AreaName, AreaDescription,
  Scope, ScopeCode, ScopeName, ScopeDescription
)
AS
  SELECT t.id, t.object, o.parent,
         o.entity, e.code, et.name,
         o.class, c.code, ct.label,
         o.type, y.code, ty.name, ty.description,
         ot.label, dt.description, ot.text,
         o.state_type, st.code, stt.name,
         o.state, s.code, sst.label, o.udate,
         t.priority, p.code, pt.name, pt.description,
         o.owner, w.username, w.name, o.pdate,
         o.oper, u.username, u.name, o.ldate,
         t.area, a.code, a.name, a.description,
         o.scope, sc.code, sc.name, sc.description
    FROM db.Document t INNER JOIN DocumentAreaTree     a ON t.area = a.id
                           LEFT JOIN db.document_text    dt ON dt.document = t.id AND dt.locale = current_locale()

                          INNER JOIN db.entity            e ON t.entity = e.id
                           LEFT JOIN db.entity_text      et ON et.entity = e.id AND et.locale = current_locale()

                          INNER JOIN db.class_tree        c ON t.class = c.id
                           LEFT JOIN db.class_text       ct ON ct.class = c.id AND ct.locale = current_locale()

                          INNER JOIN db.type              y ON t.type = y.id
                           LEFT JOIN db.type_text        ty ON ty.type = y.id AND ty.locale = current_locale()

                          INNER JOIN db.priority          p ON t.priority = p.id
                           LEFT JOIN db.priority_text    pt ON pt.priority = p.id AND pt.locale = current_locale()

                          INNER JOIN db.object            o ON t.object = o.id
                           LEFT JOIN db.object_text      ot ON ot.object = o.id AND ot.locale = current_locale()

                          INNER JOIN db.state_type       st ON o.state_type = st.id
                           LEFT JOIN db.state_type_text stt ON stt.type = st.id AND stt.locale = current_locale()

                          INNER JOIN db.state             s ON o.state = s.id
                           LEFT JOIN db.state_text      sst ON sst.state = s.id AND sst.locale = current_locale()

                          INNER JOIN db.user              w ON o.owner = w.id
                          INNER JOIN db.user              u ON o.oper = u.id

                          INNER JOIN db.scope            sc ON o.scope = sc.id;

GRANT SELECT ON ObjectDocument TO administrator;
