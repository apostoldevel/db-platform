--------------------------------------------------------------------------------
-- ReportForm ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ReportForm (Id, Reference, Entity, Class, Type,
  Code, Name, Description, Definition,
  Scope, ScopeCode, ScopeName, ScopeDescription
)
AS
  SELECT f.id, f.reference, r.entity, r.class, r.type,
         r.code, r.name, r.description, f.definition,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM db.report_form f INNER JOIN Reference r ON r.id = f.reference;

GRANT SELECT ON ReportForm TO administrator;

--------------------------------------------------------------------------------
-- AccessReportForm ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessReportForm
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('report_form'), current_userid())
  )
  SELECT r.* FROM ReportForm r INNER JOIN access a ON r.id = a.object;

GRANT SELECT ON AccessReportForm TO administrator;

--------------------------------------------------------------------------------
-- ObjectReportForm ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectReportForm (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Name, Label, Description, Definition,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Scope, ScopeCode, ScopeName, ScopeDescription
) AS
  SELECT t.id, r.object, o.parent,
         o.entity, e.code, e.name,
         o.class, c.code, c.label,
         o.type, y.code, y.name, y.description,
         r.code, rt.name, ot.label, rt.description, t.definition,
         o.state_type, st.code, st.name,
         o.state, s.code, s.label, o.udate,
         o.owner, w.username, w.name, o.pdate,
         o.oper, u.username, w.name, o.ldate,
         o.scope, p.code, p.name, p.description
    FROM ReportForm t INNER JOIN db.reference       r ON t.reference = r.id
                      INNER JOIN db.object          o ON t.reference = o.id
                      INNER JOIN Entity             e ON o.entity = e.id
                      INNER JOIN Class              c ON o.class = c.id
                      INNER JOIN Type               y ON o.type = y.id
                      INNER JOIN StateType         st ON o.state_type = st.id
                      INNER JOIN State              s ON o.state = s.id
                      INNER JOIN db.scope           p ON o.scope = p.id
                      INNER JOIN db.user            w ON o.owner = w.id
                      INNER JOIN db.user            u ON o.oper = u.id
                       LEFT JOIN db.reference_text rt ON rt.reference = o.id AND rt.locale = current_locale()
                       LEFT JOIN db.object_text    ot ON ot.object = o.id AND ot.locale = current_locale();

GRANT SELECT ON ObjectReportForm TO administrator;
