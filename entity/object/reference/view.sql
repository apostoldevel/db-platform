--------------------------------------------------------------------------------
-- REFERENCE -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Reference
AS
  SELECT r.id, r.object, r.entity, r.class, r.type, r.code, rt.name, rt.description,
         r.scope, s.code AS scopecode, s.name AS scopename, s.description AS scopedescription
    FROM db.reference r INNER JOIN db.scope s ON s.id = r.scope
                         LEFT JOIN db.reference_text rt ON r.id = rt.reference AND rt.locale = current_locale();

GRANT SELECT ON Reference TO administrator;

--------------------------------------------------------------------------------
-- CurrentReference ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW CurrentReference
AS
  SELECT * FROM Reference WHERE scope = current_scope();

GRANT SELECT ON CurrentReference TO administrator;

--------------------------------------------------------------------------------
-- ObjectReference -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectReference (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Name, Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Scope, ScopeCode, ScopeName, ScopeDescription
)
AS
  SELECT r.id, r.object, o.parent,
         o.entity, e.code, et.name,
         o.class, c.code, ct.label,
         o.type, y.code, ty.name, ty.description,
         r.code, r.name, ot.label, r.description,
         o.state_type, st.code, stt.name,
         o.state, s.code, sst.label, o.udate,
         o.owner, w.username, w.name, o.pdate,
         o.oper, u.username, u.name, o.ldate,
         o.scope, sc.code, sc.name, sc.description
    FROM CurrentReference r INNER JOIN db.object            o ON r.object = o.id
                             LEFT JOIN db.object_text      ot ON ot.object = o.id AND ot.locale = current_locale()
                            INNER JOIN db.entity            e ON o.entity = e.id
                             LEFT JOIN db.entity_text      et ON et.entity = e.id AND et.locale = current_locale()
                            INNER JOIN db.class_tree        c ON o.class = c.id
                             LEFT JOIN db.class_text       ct ON ct.class = c.id AND ct.locale = current_locale()
                            INNER JOIN db.type              y ON o.type = y.id
                             LEFT JOIN db.type_text        ty ON ty.type = y.id AND ty.locale = current_locale()
                            INNER JOIN db.state_type       st ON o.state_type = st.id
                             LEFT JOIN db.state_type_text stt ON stt.type = st.id AND stt.locale = current_locale()
                            INNER JOIN db.state             s ON o.state = s.id
                             LEFT JOIN db.state_text      sst ON sst.state = s.id AND sst.locale = current_locale()
                            INNER JOIN db.user              w ON o.owner = w.id
                            INNER JOIN db.user              u ON o.oper = u.id
                            INNER JOIN db.scope            sc ON o.scope = sc.id;

GRANT SELECT ON ObjectReference TO administrator;

--------------------------------------------------------------------------------
-- SafeReference ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW SafeReference
AS
WITH _access AS (
  WITH _membergroup AS (
	SELECT current_userid() AS userid UNION SELECT userid FROM db.member_group WHERE member = current_userid()
  )
  SELECT a.object
	FROM db.reference r INNER JOIN db.aou       a ON r.object = a.object
						INNER JOIN _membergroup m ON a.userid = m.userid
   GROUP BY a.object
  HAVING (bit_or(a.allow) & ~bit_or(a.deny)) & B'100' = B'100'
) SELECT t.* FROM ObjectReference t INNER JOIN _access a ON t.object = a.object;

GRANT SELECT ON SafeReference TO administrator;

