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
-- FileAccess ------------------------------------------------------------------
--------------------------------------------------------------------------------
-- The set of files the current session may READ — the pair of FileObject
-- (file/view.sql), attached by api.sql('kernel', 'FileObject', …) to
-- api.list_file / api.count_file at run time and skipped for the
-- administrator. Column `object` is what the dynamic join expects (t.id =
-- aou.object), here it carries the file id.
--
-- The same verdict CheckFileAccess(id, B'100') gives, restated as one query
-- over db.file instead of a call per row: the call costs ~85 µs of lookups
-- (IsAdmin, IsSystem, the owner's areas, IsMemberArea walking up the tree),
-- which is 0.85 s on 10 000 files — the volume a fleet's attachments reach
-- within a year. Set-based, the walk goes once: `_area` is every area the
-- session (or a group of theirs) is a member of and everything below it —
-- exactly the areas IsMemberArea(area, user) answers true for. A view and a
-- function stating one rule is the platform's shape for objects too
-- (AccessObject / CheckObjectAccess); a probe comparing the two over every
-- file and every session of a stand is the check that they agree.
--
-- It lives here, not in file/view.sql, because the group clause reads
-- db.object_file and db.document — tables of the entity module, which
-- create.psql loads after file (the trap GetFileMask documents: a view is
-- checked when it is created).

CREATE OR REPLACE VIEW FileAccess
AS
  WITH RECURSIVE _me AS (
    SELECT current_userid() AS userid
  ), _member AS (
    SELECT userid FROM _me
     UNION
    SELECT g.userid FROM db.member_group g INNER JOIN _me m ON m.userid = g.member
  ), _area AS (
    SELECT m.area AS id
      FROM db.member_area m INNER JOIN _member u ON u.userid = m.member
     UNION
    SELECT a.id
      FROM db.area a INNER JOIN _area t ON a.parent = t.id
  ), _owner AS (
    -- owners whose areas the session is a member of (root, system, guest left out)
    SELECT m.member
      FROM db.member_area m INNER JOIN db.area a ON a.id = m.area
                            INNER JOIN _area   t ON t.id = m.area
     WHERE a.type NOT IN (GetAreaType('root'), GetAreaType('system'), GetAreaType('guest'))
  ), _attached AS (
    -- files attached to a document of their own owner inside the session's area tree
    SELECT x.file
      FROM db.object_file x INNER JOIN db.document d ON d.id = x.object
                            INNER JOIN _area       t ON t.id = d.area
                            INNER JOIN db.object   o ON o.id = x.object
                            INNER JOIN db.file     f ON f.id = x.file AND f.owner = o.owner
  )
  -- Uncorrelated scalar subqueries on purpose: each becomes an InitPlan the
  -- executor evaluates once, where the bare call would run per row. The
  -- order is CheckFileAccess's: the kernel reads everything; no session reads
  -- nothing; an administrator or the system group reads everything; then the
  -- public root and the mask segment.
  SELECT f.id AS object
    FROM db.file f
   WHERE (SELECT session_user = 'kernel')
      OR (SELECT userid IS NOT NULL FROM _me)
         AND ( (SELECT IsAdmin(userid) OR IsSystem(userid) FROM _me)
            OR f.root IN (SELECT id FROM db.file WHERE parent IS NULL AND name = 'public')
            OR CASE
               WHEN f.owner = (SELECT userid FROM _me)       THEN SubString(f.mask FROM 1 FOR 1)
               WHEN f.owner IN (SELECT member FROM _owner)   THEN SubString(f.mask FROM 4 FOR 1)
               WHEN f.id    IN (SELECT file FROM _attached)  THEN SubString(f.mask FROM 4 FOR 1)
               ELSE SubString(f.mask FROM 7 FOR 1)
               END = B'1' );

GRANT SELECT ON FileAccess TO administrator;

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
    FROM db.document d  LEFT JOIN db.document_text    dt ON dt.document = d.id AND dt.locale = current_locale()

                       INNER JOIN db.entity            e ON d.entity = e.id
                        LEFT JOIN db.entity_text      et ON et.entity = e.id AND et.locale = current_locale()

                       INNER JOIN db.class_tree        c ON d.class = c.id
                        LEFT JOIN db.class_text       ct ON ct.class = c.id AND ct.locale = current_locale()

                       INNER JOIN db.type              y ON d.type = y.id
                        LEFT JOIN db.type_text        ty ON ty.type = y.id AND ty.locale = current_locale()

                       INNER JOIN db.priority          p ON d.priority = p.id
                        LEFT JOIN db.priority_text    pt ON pt.priority = p.id AND pt.locale = current_locale()

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
         d.scope, s.code, s.name, s.description
    FROM db.document d  LEFT JOIN db.document_text    dt ON dt.document = d.id AND dt.locale = current_locale()

                       INNER JOIN db.entity            e ON d.entity = e.id
                        LEFT JOIN db.entity_text      et ON et.entity = e.id AND et.locale = current_locale()

                       INNER JOIN db.class_tree        c ON d.class = c.id
                        LEFT JOIN db.class_text       ct ON ct.class = c.id AND ct.locale = current_locale()

                       INNER JOIN db.type              y ON d.type = y.id
                        LEFT JOIN db.type_text        ty ON ty.type = y.id AND ty.locale = current_locale()

                       INNER JOIN db.priority          p ON d.priority = p.id
                        LEFT JOIN db.priority_text    pt ON pt.priority = p.id AND pt.locale = current_locale()

                       INNER JOIN DocumentAreaTree     a ON d.area = a.id
                       INNER JOIN db.scope             s ON d.scope = s.id;

GRANT SELECT ON CurrentDocument TO administrator;

--------------------------------------------------------------------------------
-- AccessDocumentUser ----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Return document ids the given user has explicit read access to via AOU permissions.
 * @param {uuid} pUserId - User identifier (defaults to current session user)
 * @return {TABLE(object uuid)}
 * @since 1.0.0
 */
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
    FROM db.aou a INNER JOIN _membergroup m ON a.userid = m.userid
                  INNER JOIN db.document  d ON a.object = d.object
   GROUP BY a.object
  HAVING (bit_or(a.allow) & ~bit_or(a.deny)) & B'100' = B'100';
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AccessDocument --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessDocument
AS
WITH _membergroup AS (
  SELECT current_userid() AS userid UNION SELECT userid FROM db.member_group WHERE member = current_userid()
) SELECT a.object
    FROM db.aou a INNER JOIN _membergroup m ON a.userid = m.userid
                  INNER JOIN db.document  d ON a.object = d.object
   WHERE d.scope = current_scope()
   GROUP BY a.object
  HAVING (bit_or(a.allow) & ~bit_or(a.deny)) & B'100' = B'100';

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
    FROM db.document t  LEFT JOIN db.document_text    dt ON dt.document = t.id AND dt.locale = current_locale()

                       INNER JOIN db.object            o ON t.object = o.id
                        LEFT JOIN db.object_text      ot ON ot.object = o.id AND ot.locale = current_locale()

                       INNER JOIN db.entity            e ON t.entity = e.id
                        LEFT JOIN db.entity_text      et ON et.entity = e.id AND et.locale = current_locale()

                       INNER JOIN db.class_tree        c ON t.class = c.id
                        LEFT JOIN db.class_text       ct ON ct.class = c.id AND ct.locale = current_locale()

                       INNER JOIN db.type              y ON t.type = y.id
                        LEFT JOIN db.type_text        ty ON ty.type = y.id AND ty.locale = current_locale()

                       INNER JOIN db.priority          p ON t.priority = p.id
                        LEFT JOIN db.priority_text    pt ON pt.priority = p.id AND pt.locale = current_locale()

                       INNER JOIN db.state_type       st ON o.state_type = st.id
                        LEFT JOIN db.state_type_text stt ON stt.type = st.id AND stt.locale = current_locale()

                       INNER JOIN db.state             s ON o.state = s.id
                        LEFT JOIN db.state_text      sst ON sst.state = s.id AND sst.locale = current_locale()

                       INNER JOIN db.user              w ON o.owner = w.id
                       INNER JOIN db.user              u ON o.oper = u.id

                       INNER JOIN DocumentAreaTree     a ON t.area = a.id
                       INNER JOIN db.scope            sc ON o.scope = sc.id;

GRANT SELECT ON ObjectDocument TO administrator;
