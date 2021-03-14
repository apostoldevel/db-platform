--------------------------------------------------------------------------------
-- Currency --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Currency (Id, Reference,
  Code, Digital, Name, Description, Decimal
) AS
  SELECT c.id, c.reference, r.code, c.digital, r.name, r.description, c.decimal
    FROM db.currency c INNER JOIN Reference r ON r.id = c.reference;

GRANT SELECT ON Currency TO administrator;

--------------------------------------------------------------------------------
-- AccessCurrency ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessCurrency
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('currency'), current_userid())
  )
  SELECT c.* FROM Currency c INNER JOIN access ac ON c.id = ac.object;

GRANT SELECT ON AccessCurrency TO administrator;

--------------------------------------------------------------------------------
-- ObjectCurrency ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectCurrency (Id, Object, Parent,
  Event, EventCode, EventName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Digital, Name, Label, Description, Decimal,
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
         r.code, c.digital, r.name, o.label, r.description, c.decimal,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate
    FROM AccessCurrency c INNER JOIN Reference r ON c.reference = r.id
                          INNER JOIN Object    o ON c.reference = o.id;

GRANT SELECT ON ObjectCurrency TO administrator;
