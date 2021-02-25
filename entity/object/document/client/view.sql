--------------------------------------------------------------------------------
-- ClientName ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ClientName (Id, Client, Locale, LocaleCode, LocaleName, LocaleDescription,
  FullName, ShortName, LastName, FirstName, MiddleName, validFromDate, validToDate
)
AS
  SELECT n.id, n.client, n.locale, l.code, l.name, l.description,
         n.name, n.short, n.last, n.first, n.middle, n.validfromdate, n.validToDate
    FROM db.client_name n INNER JOIN db.locale l ON l.id = n.locale;

GRANT SELECT ON ClientName TO administrator;

--------------------------------------------------------------------------------
-- VIEW Balance ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Balance
AS
  SELECT * FROM db.balance;

GRANT SELECT ON Balance TO administrator;

--------------------------------------------------------------------------------
-- Client ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Client (Id, Document, Code, Creation, UserId,
  FullName, ShortName, LastName, FirstName, MiddleName, Balance,
  Phone, Email, Info, EmailVerified, PhoneVerified, Picture,
  Locale, LocaleCode, LocaleName, LocaleDescription
)
AS
  SELECT c.id, c.document, c.code, c.creation, c.userid,
         n.name, n.short, n.last, n.first, n.middle, b.amount AS balance,
         c.phone, c.email, c.info, p.email_verified, p.phone_verified, p.picture,
         n.locale, l.code, l.name, l.description
    FROM db.client c INNER JOIN db.locale      l ON l.id = current_locale()
                      LEFT JOIN db.client_name n ON c.id = n.client AND l.id = n.locale AND n.validFromDate <= oper_date() AND n.validToDate > oper_date()
                      LEFT JOIN db.balance     b ON b.type = 1 AND c.id = b.client AND b.validFromDate <= oper_date() AND b.validToDate > oper_date()
                      LEFT JOIN db.profile     p ON c.userid = p.userid;

GRANT SELECT ON Client TO administrator;

--------------------------------------------------------------------------------
-- AccessClient ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessClient
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('client'), current_userid())
  )
  SELECT c.* FROM Client c INNER JOIN access ac ON c.id = ac.object;

GRANT SELECT ON AccessClient TO administrator;

--------------------------------------------------------------------------------
-- ObjectClient ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectClient (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Creation, UserId,
  FullName, ShortName, LastName, FirstName, MiddleName, Balance,
  Phone, Email, Info, EmailVerified, PhoneVerified, Picture,
  Locale, LocaleCode, LocaleName, LocaleDescription,
  Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Area, AreaCode, AreaName, AreaDescription
)
AS
  SELECT c.id, d.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         c.code, c.creation, c.userid,
         c.fullname, c.shortname, c.lastname, c.firstname, c.middlename, c.balance,
         c.phone, c.email, c.info, emailverified, phoneverified, picture,
         c.locale, c.localecode, c.localename, c.localedescription,
         o.label, d.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         d.area, d.areacode, d.areaname, d.areadescription
    FROM AccessClient c INNER JOIN Document d ON c.document = d.id
                        INNER JOIN Object   o ON c.document = o.id;

GRANT SELECT ON ObjectClient TO administrator;
