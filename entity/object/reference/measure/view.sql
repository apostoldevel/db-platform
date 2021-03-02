--------------------------------------------------------------------------------
-- Measure ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Measure (Id, Reference, Code, Name, Description)
AS
  SELECT c.id, c.reference, r.code, r.name, r.description
    FROM db.measure c INNER JOIN Reference r ON r.id = c.reference;

GRANT SELECT ON Measure TO administrator;

--------------------------------------------------------------------------------
-- AccessMeasure ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessMeasure
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('measure'), current_userid())
  )
  SELECT c.* FROM Measure c INNER JOIN access ac ON c.id = ac.object;

GRANT SELECT ON AccessMeasure TO administrator;

--------------------------------------------------------------------------------
-- ObjectMeasure ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectMeasure (Id, Object, Parent,
  Event, EventCode, EventName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Name, Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate
)
AS
  SELECT m.id, r.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         r.code, r.name, o.label, r.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate
    FROM AccessMeasure m INNER JOIN Reference r ON m.reference = r.id
                         INNER JOIN Object    o ON m.reference = o.id;

GRANT SELECT ON ObjectMeasure TO administrator;
