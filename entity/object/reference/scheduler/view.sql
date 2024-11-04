--------------------------------------------------------------------------------
-- Scheduler -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Scheduler
AS
  SELECT t.id, o.parent, t.reference,
         o.class, ct.code AS ClassCode, ctt.label AS ClassLabel,
         o.type, y.code AS TypeCode, ty.name AS TypeName, ty.description AS TypeDescription,
         o.state_type AS StateType, st.code AS StateTypeCode, stt.name AS StateTypeName,
         o.state, s.code AS StateCode, sst.label AS StateLabel,
         o.pdate AS Created, o.udate AS LastUpdate, o.ldate AS OperDate,
         r.code, rt.name, ot.label, rt.description,
         t.period, t.dateStart, t.dateStop,
         r.scope, sc.code AS ScopeCode, sc.name AS ScopeName, sc.description AS ScopeDescription
    FROM db.scheduler t INNER JOIN db.reference         r ON t.reference = r.id AND r.scope = current_scope()
                         LEFT JOIN db.reference_text   rt ON rt.reference = r.id AND rt.locale = current_locale()

                        INNER JOIN db.object            o ON o.id = r.object
                         LEFT JOIN db.object_text      ot ON ot.object = o.id AND ot.locale = current_locale()

                        INNER JOIN db.class_tree       ct ON o.class = ct.id
                         LEFT JOIN db.class_text      ctt ON ctt.class = ct.id AND ctt.locale = current_locale()

                        INNER JOIN db.type              y ON y.id = o.type
                         LEFT JOIN db.type_text        ty ON ty.type = y.id AND ty.locale = current_locale()

                        INNER JOIN db.state_type       st ON o.state_type = st.id
                         LEFT JOIN db.state_type_text stt ON stt.type = st.id AND stt.locale = current_locale()

                        INNER JOIN db.state             s ON o.state = s.id
                         LEFT JOIN db.state_text      sst ON sst.state = s.id AND sst.locale = current_locale()

                        INNER JOIN db.scope            sc ON o.scope = sc.id;

GRANT SELECT ON Scheduler TO administrator;

--------------------------------------------------------------------------------
-- AccessScheduler -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessScheduler
AS
WITH _access AS (
   WITH _membergroup AS (
     SELECT current_userid() AS userid UNION SELECT userid FROM db.member_group WHERE member = current_userid()
   ) SELECT object
       FROM db.aou AS a INNER JOIN db.entity    e ON a.entity = e.id AND e.code = 'scheduler'
                        INNER JOIN _membergroup m ON a.userid = m.userid
      GROUP BY object
      HAVING (bit_or(a.allow) & ~bit_or(a.deny)) & B'100' = B'100'
) SELECT t.* FROM db.scheduler t INNER JOIN _access ac ON t.id = ac.object;

GRANT SELECT ON AccessScheduler TO administrator;

--------------------------------------------------------------------------------
-- ObjectScheduler -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectScheduler (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel,
  Code, Name, Label, Description,
  Period, DateStart, DateStop,
  Created, LastUpdate, OperDate,
  Owner, OwnerCode, OwnerName,
  Oper, OperCode, OperName,
  Scope, ScopeCode, ScopeName, ScopeDescription
)
AS
  SELECT t.id, r.object, o.parent,
         o.entity, e.code, et.name,
         o.class, c.code, ct.label,
         o.type, y.code, ty.name, ty.description,
         o.state_type, st.code, stt.name,
         o.state, s.code, sst.label,
         r.code, rt.name, ot.label, rt.description,
         t.period, t.dateStart, t.dateStop,
         o.pdate, o.udate, o.ldate,
         o.owner, w.username, w.name,
         o.oper, u.username, u.name,
         o.scope, sc.code, sc.name, sc.description
    FROM AccessScheduler t INNER JOIN db.reference         r ON t.reference = r.id AND r.scope = current_scope()
                            LEFT JOIN db.reference_text   rt ON rt.reference = r.id AND rt.locale = current_locale()

                           INNER JOIN db.object            o ON t.reference = o.id
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

GRANT SELECT ON ObjectScheduler TO administrator;
