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
         o.entity, e.code, e.name,
         o.class, c.code, c.label,
         o.type, y.code, y.name, y.description,
         t.report, t.reportcode, t.reportname, t.reportdescription,
         t.form, ot.label, dt.description,
         o.state_type, st.code, st.name,
         o.state, s.code, s.label, o.udate,
         o.owner, w.username, w.name, o.pdate,
         o.oper, u.username, w.name, o.ldate,
         d.area, a.code, a.name, a.description,
         o.scope, p.code, p.name, p.description
    FROM ReportReady t INNER JOIN db.document       d ON t.document = d.id
                       INNER JOIN DocumentAreaTree da ON d.area = da.id
                       INNER JOIN db.object         o ON t.document = o.id
                       INNER JOIN Entity            e ON o.entity = e.id
                       INNER JOIN Class             c ON o.class = c.id
                       INNER JOIN Type              y ON o.type = y.id
                       INNER JOIN StateType        st ON o.state_type = st.id
                       INNER JOIN State             s ON o.state = s.id
                       INNER JOIN db.user           w ON o.owner = w.id
                       INNER JOIN db.user           u ON o.oper = u.id
                       INNER JOIN db.area           a ON d.area = a.id
                       INNER JOIN db.scope          p ON o.scope = p.id
                        LEFT JOIN db.document_text dt ON dt.document = d.id AND dt.locale = current_locale()
                        LEFT JOIN db.object_text   ot ON ot.object = o.id AND ot.locale = current_locale();

GRANT SELECT ON ObjectReportReady TO administrator;
