--------------------------------------------------------------------------------
-- ReportRoutine ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ReportRoutine (Id, Reference, Entity, Class, Type,
  Report, ReportCode, ReportName, ReportDescription,
  Code, Name, Description, Definition,
  Scope, ScopeCode, ScopeName, ScopeDescription
)
AS
  SELECT f.id, f.reference, r.entity, r.class, r.type,
         f.report, p.code, p.name, p.description,
         r.code, r.name, r.description, f.definition,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM db.report_routine f INNER JOIN Reference r ON r.id = f.reference
                             INNER JOIN Report    p ON p.id = f.report;

GRANT SELECT ON ReportRoutine TO administrator;

--------------------------------------------------------------------------------
-- AccessReportRoutine ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessReportRoutine
AS
WITH _membergroup AS (
  SELECT current_userid() AS userid UNION SELECT userid FROM db.member_group WHERE member = current_userid()
) SELECT object
	FROM db.report_routine t INNER JOIN db.aou         a ON a.object = t.id
                             INNER JOIN _membergroup   m ON a.userid = m.userid
   WHERE a.mask = B'100'
   GROUP BY object;

GRANT SELECT ON AccessReportRoutine TO administrator;

--------------------------------------------------------------------------------
-- ObjectReportRoutine ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectReportRoutine (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Report, ReportCode, ReportName, ReportDescription,
  Code, Name, Label, Description, Definition,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Scope, ScopeCode, ScopeName, ScopeDescription
) AS
  SELECT t.id, r.object, o.parent,
         o.entity, e.code, et.name,
         o.class, c.code, ct.label,
         o.type, y.code, ty.name, ty.description,
         t.report, rp.code, rpt.name, rpt.description,
         r.code, rt.name, ot.label, rt.description, t.definition,
         o.state_type, st.code, stt.name,
         o.state, s.code, sst.label, o.udate,
         o.owner, w.username, w.name, o.pdate,
         o.oper, u.username, u.name, o.ldate,
         o.scope, sc.code, sc.name, sc.description
    FROM db.report_routine t INNER JOIN db.reference         r ON t.reference = r.id AND r.scope = current_scope()
                              LEFT JOIN db.reference_text   rt ON rt.reference = r.id AND rt.locale = current_locale()

                             INNER JOIN db.object            o ON r.object = o.id
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

                             INNER JOIN db.report            p ON t.report = p.id
                             INNER JOIN db.reference        rp ON p.reference = rp.id
                              LEFT JOIN db.reference_text  rpt ON rpt.reference = rp.id AND rpt.locale = current_locale()

                             INNER JOIN db.user              w ON o.owner = w.id
                             INNER JOIN db.user              u ON o.oper = u.id

                             INNER JOIN db.scope            sc ON o.scope = sc.id;

GRANT SELECT ON ObjectReportRoutine TO administrator;
