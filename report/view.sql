--------------------------------------------------------------------------------
-- REPORT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Report (Id, Reference, Entity, Class, Type,
  Tree, TreeCode, TreeName, TreeDescription,
  Form, FormCode, FormName, FormDescription,
  Binding, BindingCode, BindingLabel,
  Code, Name, Description, Info,
  Scope, ScopeCode, ScopeName, ScopeDescription
)
AS
  SELECT p.id, p.reference, r.entity, r.class, r.type,
         p.tree, t.code, t.name, t.description,
         p.form, f.code, f.name, f.description,
         p.binding, c.code, c.label,
         r.code, r.name, r.description, p.info,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM db.report p INNER JOIN Reference  r ON p.reference = r.id
                     INNER JOIN ReportTree t ON p.tree = t.id
                      LEFT JOIN ReportForm f ON p.form = f.id
                      LEFT JOIN Class      c ON p.binding = c.id;

GRANT SELECT ON Report TO administrator;

--------------------------------------------------------------------------------
-- AccessReport ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessReport
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('report'), current_userid())
  )
  SELECT r.* FROM Report r INNER JOIN access a ON r.id = a.object;

GRANT SELECT ON AccessReport TO administrator;

--------------------------------------------------------------------------------
-- ObjectReport ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectReport (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Tree, TreeCode, TreeName, TreeDescription,
  Form, FormCode, FormName, FormDescription,
  Binding, BindingCode, BindingLabel,
  Code, Name, Label, Description, Info,
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
         t.tree, t.treecode, t.treename, t.treedescription,
         t.form, t.formcode, t.formname, t.formdescription,
         t.binding, t.bindingcode, t.bindinglabel,
         r.code, rt.name, ot.label, rt.description, t.info,
         o.state_type, st.code, st.name,
         o.state, s.code, s.label, o.udate,
         o.owner, w.username, w.name, o.pdate,
         o.oper, u.username, w.name, o.ldate,
         o.scope, p.code, p.name, p.description
    FROM Report t INNER JOIN db.reference       r ON t.reference = r.id
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

GRANT SELECT ON ObjectReport TO administrator;
