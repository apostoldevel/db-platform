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
         o.entity, e.code, et.name,
         o.class, c.code, ct.label,
         o.type, y.code, ty.name, ty.description,
         t.tree, rtr.code, rtrt.name, rtrt.description,
         t.form, rf.code, rft.name, rft.description,
         t.binding, b.code, bt.label,
         r.code, rt.name, ot.label, rt.description, t.info,
         o.state_type, st.code, stt.name,
         o.state, s.code, sst.label, o.udate,
         o.owner, w.username, w.name, o.pdate,
         o.oper, u.username, w.name, o.ldate,
         o.scope, sc.code, sc.name, sc.description
    FROM db.report t INNER JOIN db.reference         r ON t.reference = r.id
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
                     INNER JOIN db.scope            sc ON o.scope = sc.id
                     INNER JOIN db.reference       rtr ON t.tree = rtr.id
                      LEFT JOIN db.reference_text rtrt ON rtrt.reference = rtr.id AND rtrt.locale = current_locale()
                     INNER JOIN db.reference        rf ON t.form = rf.id
                      LEFT JOIN db.reference_text  rft ON rft.reference = rf.id AND rft.locale = current_locale()
                     INNER JOIN db.class_tree        b ON o.class = b.id
                      LEFT JOIN db.class_text       bt ON bt.class = b.id AND bt.locale = current_locale();

GRANT SELECT ON ObjectReport TO administrator;
