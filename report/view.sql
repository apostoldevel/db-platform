--------------------------------------------------------------------------------
-- REPORT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Report (Id, Reference, Entity, Class, Type,
  Tree, TreeCode, TreeName, TreeDescription,
  Form, FormCode, FormName, FormDescription,
  Code, Name, Description, Info
)
AS
  SELECT p.id, p.reference, r.entity, r.class, r.type,
         p.tree, t.code, t.name, t.description,
         p.form, f.code, f.name, f.description,
         r.code, r.name, r.description, p.info
    FROM db.report p INNER JOIN Reference  r ON p.reference = r.id
                     INNER JOIN ReportTree t ON p.tree = t.id
                      LEFT JOIN ReportForm f ON p.form = f.id;

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
  SELECT p.id, r.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         p.tree, p.treecode, p.treename, p.treedescription,
         p.form, p.formcode, p.formname, p.formdescription,
         r.code, r.name, o.label, r.description, p.info,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM AccessReport p INNER JOIN Reference r ON p.reference = r.id
                        INNER JOIN Object    o ON p.reference = o.id;

GRANT SELECT ON ObjectReport TO administrator;
