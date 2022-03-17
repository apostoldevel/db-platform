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

CREATE OR REPLACE VIEW ObjectReport
AS
  SELECT t.id, r.object, r.parent,
         r.entity, r.entitycode, r.entityname,
         r.class, r.classcode, r.classlabel,
         r.type, r.typecode, r.typename, r.typedescription,
         t.tree, t.treecode, t.treename, t.treedescription,
         t.form, t.formcode, t.formname, t.formdescription,
         t.binding, t.bindingcode, t.bindinglabel,
         r.code, r.name, r.label, r.description, t.info,
         r.statetype, r.statetypecode, r.statetypename,
         r.state, r.statecode, r.statelabel, r.lastupdate,
         r.owner, r.ownercode, r.ownername, r.created,
         r.oper, r.opercode, r.opername, r.operdate,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM AccessReport t INNER JOIN ObjectReference r ON t.reference = r.id;

GRANT SELECT ON ObjectReport TO administrator;
