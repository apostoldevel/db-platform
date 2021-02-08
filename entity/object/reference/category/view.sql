--------------------------------------------------------------------------------
-- Category --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Category (Id, Reference, Code, Name, Description)
AS
  SELECT c.id, c.reference, r.code, r.name, r.description
    FROM db.category c INNER JOIN db.reference r ON r.id = c.reference;

GRANT SELECT ON Category TO administrator;

--------------------------------------------------------------------------------
-- AccessCategory --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessCategory
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('category'), current_userid())
  )
  SELECT c.* FROM Category c INNER JOIN access ac ON c.id = ac.object;

GRANT SELECT ON AccessCategory TO administrator;

--------------------------------------------------------------------------------
-- ObjectCategory --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectCategory (Id, Object, Parent,
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
  SELECT c.id, r.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         r.code, r.name, o.label, r.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate
    FROM AccessCategory c INNER JOIN Reference r ON c.reference = r.id
                          INNER JOIN Object    o ON c.reference = o.id;

GRANT SELECT ON ObjectCategory TO administrator;
