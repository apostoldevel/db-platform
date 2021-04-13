--------------------------------------------------------------------------------
-- Account ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Account (Id, Document, Code,
    Currency, CurrencyCode, CurrencyDigital, CurrencyName, CurrencyDescription,
    Category, CategoryCode, CategoryName, CategoryDescription,
    Balance, Client, ClientName
)
AS
  SELECT a.id, a.document, a.code,
         a.currency, r.code, r.name, r.description, r.digital,
         a.category, g.code, g.name, g.description,
         b.amount AS balance, a.client, c.fullname
    FROM db.account a INNER JOIN Currency   r ON a.currency = r.id
                       LEFT JOIN Category   g ON a.category = g.id
                       LEFT JOIN Client     c ON a.client = c.id
                       LEFT JOIN db.balance b ON b.type = 1 AND a.id = b.account AND b.validFromDate <= oper_date() AND b.validToDate > oper_date();

GRANT SELECT ON Account TO administrator;

--------------------------------------------------------------------------------
-- VIEW Balance ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Balance
AS
  SELECT * FROM db.balance;

GRANT SELECT ON Balance TO administrator;

--------------------------------------------------------------------------------
-- VIEW Turnover ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Turnover
AS
  SELECT * FROM db.turnover;

GRANT SELECT ON Turnover TO administrator;

--------------------------------------------------------------------------------
-- AccessAccount ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessAccount
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('account'), current_userid())
  )
  SELECT a.* FROM Account a INNER JOIN access ac ON a.id = ac.object;

GRANT SELECT ON AccessAccount TO administrator;

--------------------------------------------------------------------------------
-- ObjectAccount ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectAccount (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Currency, CurrencyCode, CurrencyDigital, CurrencyName, CurrencyDescription,
  Category, CategoryCode, CategoryName, CategoryDescription,
  Balance, Client, ClientName,
  Code, Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Area, AreaCode, AreaName, AreaDescription,
  Scope, ScopeCode, ScopeName, ScopeDescription
)
AS
  SELECT a.id, d.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         a.currency, a.currencycode, a.currencydigital, a.currencyname, a.currencydescription,
         a.category, a.categorycode, a.categoryname, a.categorydescription,
         a.balance, a.client, a.clientname,
         a.code, o.label, d.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         d.area, d.areacode, d.areaname, d.areadescription,
         d.scope, d.scopecode, d.scopename, d.scopedescription
    FROM AccessAccount a INNER JOIN Document d ON a.document = d.id
                         INNER JOIN Object   o ON a.document = o.id;

GRANT SELECT ON ObjectAccount TO administrator;
