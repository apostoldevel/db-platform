--------------------------------------------------------------------------------
-- ReportReady -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ReportReady (Id, Document, Form,
  Report, ReportCode, ReportName, ReportDescription
)
AS
  SELECT r.id, r.document, r.form,
         r.report, t.code, t.name, t.description
    FROM db.report_ready r INNER JOIN Report t ON r.report = t.id;

GRANT SELECT ON ReportReady TO administrator;

--------------------------------------------------------------------------------
-- AccessReportReady -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessReportReady
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('report_ready'), current_userid())
  )
  SELECT r.* FROM ReportReady r INNER JOIN access a ON r.id = a.object;

GRANT SELECT ON AccessReportReady TO administrator;

--------------------------------------------------------------------------------
-- ObjectReportReady -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectReportReady (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Report, ReportCode, ReportName, ReportDescription,
  Form, Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Area, AreaCode, AreaName, AreaDescription,
  Scope, ScopeCode, ScopeName, ScopeDescription
) AS
  SELECT t.id, d.object, o.parent,
         o.entity, e.code, et.name,
         o.class, c.code, ct.label,
         o.type, y.code, ty.name, ty.description,
         t.report, r.code, rt.name, rt.description,
         t.form, ot.label, dt.description,
         o.state_type, st.code, stt.name,
         o.state, s.code, sst.label, o.udate,
         o.owner, w.username, w.name, o.pdate,
         o.oper, u.username, u.name, o.ldate,
         d.area, a.code, a.name, a.description,
         o.scope, sc.code, sc.name, sc.description
    FROM db.report_ready t INNER JOIN db.document          d ON t.document = d.id
                           INNER JOIN DocumentAreaTree     a ON d.area = a.id
                            LEFT JOIN db.document_text    dt ON dt.document = d.id AND dt.locale = current_locale()
                           INNER JOIN db.object            o ON d.object = o.id
                            LEFT JOIN db.object_text      ot ON ot.object = o.id AND ot.locale = current_locale()
                           INNER JOIN db.reference         r ON t.report = r.id
                            LEFT JOIN db.reference_text   rt ON rt.reference = r.id AND rt.locale = current_locale()
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

GRANT SELECT ON ObjectReportReady TO administrator;
