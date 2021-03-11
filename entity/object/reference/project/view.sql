--------------------------------------------------------------------------------
-- Project ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Project (Id, Reference, Code, Name, Description)
AS
  SELECT p.id, p.reference, d.code, d.name, d.description
    FROM db.project p INNER JOIN Reference d ON p.reference = d.id;

GRANT SELECT ON Project TO administrator;

--------------------------------------------------------------------------------
-- AccessProject ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessProject
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('project'), current_userid())
  )
  SELECT p.* FROM Project p INNER JOIN access ac ON p.id = ac.object;

GRANT SELECT ON AccessProject TO administrator;

--------------------------------------------------------------------------------
-- ObjectProject ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectProject (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Name, Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate
)
AS
  SELECT p.id, r.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         r.code, r.name, o.label, r.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate
    FROM AccessProject p INNER JOIN Reference r ON p.reference = r.id
                         INNER JOIN Object    o ON p.reference = o.id;

GRANT SELECT ON ObjectProject TO administrator;
