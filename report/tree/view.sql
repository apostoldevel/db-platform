--------------------------------------------------------------------------------
-- ReportTree ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ReportTree (Id, Reference, Entity, Class, Type,
  Root, Node, Level, Sequence, Code, Name, Description
)
AS
  SELECT t.id, t.reference, r.entity, r.class, r.type,
         t.root, t.node, t.level, t.sequence, r.code, r.name, r.description
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

CREATE OR REPLACE VIEW ObjectReportTree
AS
  SELECT t.id, r.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         t.root, t.node, t.level, t.sequence,
         r.code, r.name, o.label, r.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM AccessReportTree t INNER JOIN Reference r ON t.reference = r.id
                            INNER JOIN Object    o ON t.reference = o.id;
