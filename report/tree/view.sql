--------------------------------------------------------------------------------
-- ReportTree ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ReportTree (Id, Reference, Entity, Class, Type,
  Root, Node, Level, Sequence,
  Code, Name, Description,
  Scope, ScopeCode, ScopeName, ScopeDescription
)
AS
  SELECT t.id, t.reference, r.entity, r.class, r.type,
         t.root, t.node, t.level, t.sequence, r.code, r.name, r.description,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM db.report_tree t INNER JOIN Reference r ON t.reference = r.id;

GRANT SELECT ON ReportTree TO administrator;

--------------------------------------------------------------------------------
-- AccessReportTree ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessReportTree
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('report_tree'), current_userid())
  )
  SELECT r.* FROM ReportTree r INNER JOIN access a ON r.id = a.object;

GRANT SELECT ON AccessReportTree TO administrator;

--------------------------------------------------------------------------------
-- VIEW ObjectReportTree -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectReportTree (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Root, Node, Level, Sequence,
  Code, Name, Label, Description,
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
         t.root, t.node, t.level, t.sequence,
         r.code, rt.name, ot.label, rt.description,
         o.state_type, st.code, st.name,
         o.state, s.code, s.label, o.udate,
         o.owner, w.username, w.name, o.pdate,
         o.oper, u.username, w.name, o.ldate,
         o.scope, p.code, p.name, p.description
    FROM ReportTree t INNER JOIN db.reference       r ON t.reference = r.id
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

GRANT SELECT ON ObjectReportTree TO administrator;