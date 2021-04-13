--------------------------------------------------------------------------------
-- Model -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Model (Id, Reference, Code, Name, Description,
    Vendor, VendorCode, VendorName, VendorDescription,
    Category, CategoryCode, CategoryName, CategoryDescription
)
AS
  SELECT m.id, m.reference, r.code, r.name, r.description,
         m.vendor, v.code, v.name, v.description,
         m.category, c.code, c.name, c.description
    FROM db.model m INNER JOIN Reference r ON m.reference = r.id
                    INNER JOIN Reference v ON m.vendor = v.id
                     LEFT JOIN Reference c ON m.category = c.id;

GRANT SELECT ON Model TO administrator;

--------------------------------------------------------------------------------
-- AccessModel -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessModel
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('model'), current_userid())
  )
  SELECT m.* FROM Model m INNER JOIN access ac ON m.id = ac.object;

GRANT SELECT ON AccessModel TO administrator;

--------------------------------------------------------------------------------
-- ObjectModel -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectModel (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Vendor, VendorCode, VendorName, VendorDescription,
  Category, CategoryCode, CategoryName, CategoryDescription,
  Code, Name, Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Scope, ScopeCode, ScopeName, ScopeDescription
)
AS
  SELECT m.id, r.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         m.vendor, m.vendorcode, m.vendorname, m.vendordescription,
         m.category, m.categorycode, m.categoryname, m.categorydescription,
         r.code, r.name, o.label, r.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM AccessModel m INNER JOIN Reference r ON m.reference = r.id
                       INNER JOIN Object    o ON m.reference = o.id;

GRANT SELECT ON ObjectModel TO administrator;

--------------------------------------------------------------------------------
-- ModelProperty ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ModelProperty (
  Category, CategoryCode, CategoryName, CategoryDescription,
  Model, ModelCode, ModelName, ModelDescription,
  Measure, MeasureCode, MeasureName, MeasureDescription,
  Type, TypeCode, TypeName, TypeDescription,
  Property, PropertyCode, PropertyName, PropertyDescription,
  TypeValue, Value, Format, Sequence
)
AS
  SELECT m.category, m.categorycode, m.categoryname, m.categorydescription,
         mp.model, m.code, m.name, m.description,
         mp.measure, s.code, s.name, s.description,
         p.type, p.typecode, p.typename, p.typedescription,
         mp.property, p.code, p.name, p.description,
         (mp.value).vType,
         CASE
         WHEN (mp.value).vType = 0 THEN to_char((mp.value).vInteger, coalesce(mp.format, 'FM999999999990'))
         WHEN (mp.value).vType = 1 THEN to_char((mp.value).vNumeric, coalesce(mp.format, 'FM999999999990.00'))
         WHEN (mp.value).vType = 2 THEN to_char((mp.value).vDateTime, coalesce(mp.format, 'DD.MM.YYYY HH24:MI:SS'))
         WHEN (mp.value).vType = 3 THEN (mp.value).vString
         WHEN (mp.value).vType = 4 THEN (mp.value).vBoolean::text
         END,
         mp.format, mp.sequence
    FROM db.model_property mp INNER JOIN Model    m ON m.id = mp.model
                              INNER JOIN Property p ON p.id = mp.property
                               LEFT JOIN Measure  s ON s.id = mp.measure;

GRANT SELECT ON ModelProperty TO administrator;

--------------------------------------------------------------------------------
-- ModelPropertyJson -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ModelPropertyJson (ModelId, PropertyId, MeasureId,
  Property, Measure, TypeValue, Value, Format, Sequence
)
AS
  SELECT m.id, p.id, s.id,
         row_to_json(p), row_to_json(s),
         (mp.value).vType,
         CASE
         WHEN (mp.value).vType = 0 THEN to_char((mp.value).vInteger, coalesce(mp.format, 'FM999999999990'))
         WHEN (mp.value).vType = 1 THEN to_char((mp.value).vNumeric, coalesce(mp.format, 'FM999999999990.00'))
         WHEN (mp.value).vType = 2 THEN to_char((mp.value).vDateTime, coalesce(mp.format, 'DD.MM.YYYY HH24:MI:SS'))
         WHEN (mp.value).vType = 3 THEN (mp.value).vString
         WHEN (mp.value).vType = 4 THEN (mp.value).vBoolean::text
         END,
         mp.format, mp.sequence
    FROM db.model_property mp INNER JOIN Model    m ON m.id = mp.model
                              INNER JOIN Property p ON p.id = mp.property
                               LEFT JOIN Measure  s ON s.id = mp.measure;

GRANT SELECT ON ModelPropertyJson TO administrator;
