--------------------------------------------------------------------------------
-- ADDRESS ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.address (
    id			numeric(12) PRIMARY KEY,
    document	numeric(12) NOT NULL,
    code		varchar(30) NOT NULL,
    index		varchar( 6),
    country		varchar(50), 
    region		varchar(50),
    district	varchar(50),
    city		varchar(50), 
    settlement	varchar(50),
    street		varchar(50),
    house		varchar(10),
    building	varchar(10),
    structure	varchar(10),
    apartment	varchar(10),
    sortnum		numeric NOT NULL,
    CONSTRAINT fk_address_document FOREIGN KEY (document) REFERENCES db.document(id)
);

COMMENT ON TABLE db.address IS 'Адрес объекта.';

COMMENT ON COLUMN db.address.id IS 'Идентификатор';
COMMENT ON COLUMN db.address.document IS 'Ссылка на документ';
COMMENT ON COLUMN db.address.code IS 'Код из справочника адресов в виде дерева';
COMMENT ON COLUMN db.address.index IS 'Почтовый индекс';
COMMENT ON COLUMN db.address.country IS 'Страна';
COMMENT ON COLUMN db.address.region IS 'Регион';
COMMENT ON COLUMN db.address.district IS 'Район';
COMMENT ON COLUMN db.address.city IS 'Город';
COMMENT ON COLUMN db.address.settlement IS 'Населённый пункт';
COMMENT ON COLUMN db.address.street IS 'Улица';
COMMENT ON COLUMN db.address.house IS 'Дом';
COMMENT ON COLUMN db.address.building IS 'Корпус';
COMMENT ON COLUMN db.address.structure IS 'Строение';
COMMENT ON COLUMN db.address.apartment IS 'Квартира';
COMMENT ON COLUMN db.address.sortnum IS 'Номер для сортировки';

CREATE INDEX ON db.address (document);
CREATE INDEX ON db.address (code);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_address_insert()
RETURNS trigger AS $$
BEGIN
  IF NULLIF(NEW.id, 0) IS NULL THEN
    SELECT NEW.document INTO NEW.id;
  END IF;

  IF NULLIF(NEW.sortnum, 0) IS NULL THEN
    SELECT NEW.id INTO NEW.sortnum;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_address_insert
  BEFORE INSERT ON db.address
  FOR EACH ROW
  EXECUTE PROCEDURE ft_address_insert();

--------------------------------------------------------------------------------
-- CreateAddress ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateAddress (
  pParent       numeric,
  pType         numeric,
  pCode         varchar,
  pIndex        varchar,
  pCountry      varchar,
  pRegion       varchar,
  pDistrict     varchar,
  pCity         varchar,
  pSettlement   varchar,
  pStreet       varchar,
  pHouse        varchar,
  pBuilding     varchar,
  pStructure    varchar,
  pApartment    varchar,
  pAddress      text DEFAULT null
) RETURNS       numeric
AS $$
DECLARE
  r             db.address%rowtype;

  sList         text[];
  sShort        text;
  sAddress      text;

  nAddress      numeric;
  nClass        numeric;
  nDocument     numeric;
  nMethod       numeric;
BEGIN
  SELECT class INTO nClass FROM db.type WHERE id = pType;

  IF GetEntityCode(nClass) <> 'address' THEN
    PERFORM IncorrectClassType();
  END IF;

  IF pParent IS NOT NULL THEN
    SELECT * INTO r FROM db.address a WHERE a.id = pParent;

    pCode := coalesce(pCode, r.code);
    pIndex := CheckNull(coalesce(pIndex, r.index, '<null>'));
    pCountry := CheckNull(coalesce(pCountry, r.country, '<null>'));
    pRegion := CheckNull(coalesce(pRegion, r.region, '<null>'));
    pDistrict := CheckNull(coalesce(pDistrict, r.district, '<null>'));
    pCity := CheckNull(coalesce(pCity, r.city, '<null>'));
    pSettlement := CheckNull(coalesce(pSettlement, r.settlement, '<null>'));
    pStreet := CheckNull(coalesce(pStreet, r.street, '<null>'));
    pHouse := CheckNull(coalesce(pHouse, r.house, '<null>'));
    pBuilding := CheckNull(coalesce(pBuilding, r.building, '<null>'));
    pStructure := CheckNull(coalesce(pStructure, r.structure, '<null>'));
    pApartment := CheckNull(coalesce(pApartment, r.apartment, '<null>'));
  END IF;

  sAddress := pAddress;

  IF sAddress IS NULL THEN

    sList[1] := pCity;
    sList[2] := pSettlement;
    sList[3] := pStreet;
    sList[4] := pHouse;
    sList[5] := pBuilding;
    sList[6] := pStructure;
    sList[7] := pApartment;

    sList[8] := null;
    sList[9] := null;

    IF pCode IS NULL THEN
      FOR nIndex IN 1..3
      LOOP
        IF sList[nIndex] IS NOT NULL THEN
          IF sList[8] IS NULL THEN
            sList[8] := sShort || sList[nIndex];
          ELSE
            sList[8] := sList[8] || ', ' || sShort || sList[nIndex];
          END IF;
        END IF;
      END LOOP;
    ELSE
      sList[8] := GetAddressTreeString(pCode, 1, 1);
    END IF;

    FOR nIndex IN 4..7
    LOOP
      IF sList[nIndex] IS NOT NULL THEN
        CASE nIndex
        WHEN 4 THEN
          sShort := 'дом ';
        WHEN 5 THEN
          sShort := 'к';
        WHEN 6 THEN
          sShort := ', стр. ';
        WHEN 7 THEN
          sShort := ', кв. ';
        END CASE;

        IF sList[9] IS NULL THEN
          sList[9] := sShort || sList[nIndex];
        ELSE
          sList[9] := sList[9] || sShort || sList[nIndex];
        END IF;
      END IF;
    END LOOP;

    IF sList[8] IS NULL THEN
      sAddress := sList[9];
    ELSE
      IF sList[9] IS NULL THEN
        sAddress := sList[8];
      ELSE
        sAddress := sList[8] || ', ' || sList[9];
      END IF;
    END IF;
  END IF;

  nDocument := CreateDocument(pParent, pType, null, sAddress);

  INSERT INTO db.address (id, document, code, index, country, region, district, city, settlement, street, house, building, structure, apartment, sortnum)
  VALUES (nDocument, nDocument, pCode, pIndex, pCountry, pRegion, pDistrict, pCity, pSettlement, pStreet, pHouse, pBuilding, pStructure, pApartment, 0)
  RETURNING id INTO nAddress;

  nMethod := GetMethod(nClass, null, GetAction('create'));
  PERFORM ExecuteMethod(nAddress, nMethod);

  RETURN nAddress;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditAddress -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditAddress (
  pId           numeric,
  pParent       numeric DEFAULT null,
  pType         numeric DEFAULT null,
  pCode         varchar DEFAULT null,
  pIndex        varchar DEFAULT null,
  pCountry      varchar DEFAULT null,
  pRegion       varchar DEFAULT null,
  pDistrict     varchar DEFAULT null,
  pCity         varchar DEFAULT null,
  pSettlement   varchar DEFAULT null,
  pStreet       varchar DEFAULT null,
  pHouse        varchar DEFAULT null,
  pBuilding     varchar DEFAULT null,
  pStructure    varchar DEFAULT null,
  pApartment    varchar DEFAULT null,
  pAddress      text DEFAULT null
) RETURNS       void
AS $$
DECLARE
  r             db.address%rowtype;

  sList		    text[];
  sShort		text;
  sAddress	    text;

  nClass        numeric;
  nMethod       numeric;

  -- current
  cParent	    numeric;
  cType		    numeric;
BEGIN
  SELECT parent, type INTO cParent, cType FROM db.object WHERE id = pId;

  pParent := coalesce(pParent, cParent, 0);
  pType := coalesce(pType, cType);

  IF CheckNull(pParent) IS NOT NULL THEN

    SELECT * INTO r FROM db.address a WHERE a.id = pParent;

    pCode := coalesce(pCode, r.code);
    pIndex := CheckNull(coalesce(pIndex, r.index, '<null>'));
    pCountry := CheckNull(coalesce(pCountry, r.country, '<null>'));
    pRegion := CheckNull(coalesce(pRegion, r.region, '<null>'));
    pDistrict := CheckNull(coalesce(pDistrict, r.district, '<null>'));
    pCity := CheckNull(coalesce(pCity, r.city, '<null>'));
    pSettlement := CheckNull(coalesce(pSettlement, r.settlement, '<null>'));
    pStreet := CheckNull(coalesce(pStreet, r.street, '<null>'));
    pHouse := CheckNull(coalesce(pHouse, r.house, '<null>'));
    pBuilding := CheckNull(coalesce(pBuilding, r.building, '<null>'));
    pStructure := CheckNull(coalesce(pStructure, r.structure, '<null>'));
    pApartment := CheckNull(coalesce(pApartment, r.apartment, '<null>'));

  ELSE

    SELECT * INTO r FROM db.address WHERE id = pId;

    pCode := coalesce(pCode, r.code);
    pIndex := CheckNull(coalesce(pIndex, r.index, '<null>'));
    pCountry := CheckNull(coalesce(pCountry, r.country, '<null>'));
    pRegion := CheckNull(coalesce(pRegion, r.region, '<null>'));
    pDistrict := CheckNull(coalesce(pDistrict, r.district, '<null>'));
    pCity := CheckNull(coalesce(pCity, r.city, '<null>'));
    pSettlement := CheckNull(coalesce(pSettlement, r.settlement, '<null>'));
    pStreet := CheckNull(coalesce(pStreet, r.street, '<null>'));
    pHouse := CheckNull(coalesce(pHouse, r.house, '<null>'));
    pBuilding := CheckNull(coalesce(pBuilding, r.building, '<null>'));
    pStructure := CheckNull(coalesce(pStructure, r.structure, '<null>'));
    pApartment := CheckNull(coalesce(pApartment, r.apartment, '<null>'));

  END IF;

  sAddress := pAddress;

  IF sAddress IS NULL THEN

    sList[1] := pCity;
    sList[2] := pSettlement;
    sList[3] := pStreet;
    sList[4] := pHouse;
    sList[5] := pBuilding;
    sList[6] := pStructure;
    sList[7] := pApartment;

    sList[8] := null;
    sList[9] := null;

    IF pCode IS NULL THEN
      FOR nIndex IN 1..3
      LOOP
        IF sList[nIndex] IS NOT NULL THEN
          IF sList[8] IS NULL THEN
            sList[8] := sShort || sList[nIndex];
          ELSE
            sList[8] := sList[8] || ', ' || sShort || sList[nIndex];
          END IF;
        END IF;
      END LOOP;
    ELSE
      sList[8] := GetAddressTreeString(pCode, 1, 1);
    END IF;

    FOR nIndex IN 4..7
    LOOP
      IF sList[nIndex] IS NOT NULL THEN
        CASE nIndex
        WHEN 4 THEN
          sShort := 'дом ';
        WHEN 5 THEN
          sShort := 'к';
        WHEN 6 THEN
          sShort := ', стр. ';
        WHEN 7 THEN
          sShort := ', кв. ';
        END CASE;

        IF sList[9] IS NULL THEN
          sList[9] := sShort || sList[nIndex];
        ELSE
          sList[9] := sList[9] || sShort || sList[nIndex];
        END IF;
      END IF;
    END LOOP;

    IF sList[8] IS NULL THEN
      sAddress := sList[9];
    ELSE
      IF sList[9] IS NULL THEN
        sAddress := sList[8];
      ELSE
        sAddress := sList[8] || ', ' || sList[9];
      END IF;
    END IF;
  END IF;

  IF pParent <> coalesce(cParent, 0) THEN
    UPDATE db.object SET parent = CheckNull(pParent) WHERE id = pId;
  END IF;

  IF pType <> cType THEN
    UPDATE db.object SET type = pType WHERE id = pId;
  END IF;

  IF sAddress IS NOT NULL THEN
    UPDATE db.document SET description = CheckNull(sAddress) WHERE id = pId;
  END IF;

  UPDATE db.address
     SET code = pCode,
         index = pIndex,
         country = pCountry,
         region = pRegion,
         district = pDistrict,
         city = pCity,
         Settlement = pSettlement,
         Street = pStreet,
         House = pHouse,
         Building = pBuilding,
         Structure = pStructure,
         Apartment = pApartment
   WHERE id = pId;

  nClass := GetObjectClass(pId);
  nMethod := GetMethod(nClass, null, GetAction('edit'));
  PERFORM ExecuteMethod(pId, nMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAddressString ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAddressString (
  pId		numeric
) RETURNS   text
AS $$
DECLARE
  r         db.address%rowtype;
  sList		text[];
  sDelim	text;
  sShort	text;
  sAddress	text; 
BEGIN
  SELECT * INTO r FROM db.address WHERE id = pId;

  sList[ 1] := r.index;
  sList[ 2] := r.country;
  sList[ 3] := r.region;
  sList[ 4] := r.district;
  sList[ 5] := r.city;
  sList[ 6] := r.settlement;
  sList[ 7] := r.street;
  sList[ 8] := r.house;
  sList[ 9] := r.building;
  sList[10] := r.structure;
  sList[11] := r.apartment;

  IF r.code IS NULL THEN
    FOR nIndex IN 1..7
    LOOP
      IF sList[nIndex] IS NOT NULL THEN
        IF sAddress IS NULL THEN
          sAddress := sList[nIndex];
        ELSE
          sAddress := sAddress || ', ' || sList[nIndex];
        END IF;
      END IF;
    END LOOP;
  ELSE
    sAddress := GetAddressTreeString(r.code, 1, 0);
  END IF;

  FOR nIndex IN 8..11
  LOOP
    IF sList[nIndex] IS NOT NULL THEN

      IF sAddress IS NOT NULL THEN
        sDelim := ', ';
      END IF;

      CASE nIndex
      WHEN 8 THEN
        sShort := 'дом ';
      WHEN 9 THEN
        sDelim := '';
        sShort := 'к';
      WHEN 10 THEN
        sShort := 'стр. ';
      WHEN 11 THEN
        sShort := 'кв. ';
      END CASE;

      IF sAddress IS NULL THEN
        sAddress := sList[nIndex];
      ELSE
        sAddress := sAddress || sDelim || sShort || sList[nIndex];
      END IF;
    END IF;
  END LOOP;

  RETURN sAddress;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Address ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Address
AS
  SELECT * FROM db.address;

GRANT SELECT ON Address TO administrator;

--------------------------------------------------------------------------------
-- AccessAddress ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessAddress
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('address'), current_userid())
  )
  SELECT a.* FROM Address a INNER JOIN access ac ON a.id = ac.object;

GRANT SELECT ON AccessAddress TO administrator;

--------------------------------------------------------------------------------
-- ObjectAddress ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectAddress (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Index, Country, Region, District, City, Settlement, Street, House, Building, Structure, Apartment, SortNum,
  Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Area, AreaCode, AreaName, AreaDescription
) AS
  SELECT a.id, d.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         a.code, a.index, a.country, a.region, a.district, a.city, a.settlement, a.street, a.house, a.building, a.structure, a.apartment, a.sortnum,
         o.label, d.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         d.area, d.areacode, d.areaname, d.areadescription
    FROM AccessAddress a INNER JOIN Document d ON a.document = d.id
                         INNER JOIN Object   o ON a.document = o.id;

GRANT SELECT ON ObjectAddress TO administrator;

--------------------------------------------------------------------------------
-- ObjectAddresses -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectAddresses (Id, Object, Address, TypeCode,
    Code, Index, Country, Region, District, City, Settlement, Street, House,
    Building, Structure, Apartment, SortNum,
    ValidFromDate, ValidToDate
)
AS
  SELECT ol.id, ol.object, ol.linked, ol.key,
         a.code, a.index, a.country, a.region, a.district, a.city, a.settlement, a.street, a.house,
         a.building, a.structure, a.apartment, a.sortnum,
         ol.validFromDate, ol.validToDate
    FROM db.object_link ol INNER JOIN db.address a ON ol.linked = a.id;

GRANT SELECT ON ObjectAddresses TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectAddress ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает адрес объекта.
 * @param {numeric} pObject - Идентификатор объекта
 * @param {varchar} pKey - Ключ
 * @param {timestamp} pDate - Дата
 * @return {text}
 */
CREATE OR REPLACE FUNCTION GetObjectAddress (
  pObject	numeric,
  pKey	    varchar,
  pDate		timestamp DEFAULT oper_date()
) RETURNS	text
AS $$
DECLARE
  nAddress		numeric;
BEGIN
  SELECT linked INTO nAddress
    FROM db.object_link
   WHERE object = pObject
     AND key = pKey
     AND validFromDate <= pDate
     AND validToDate > pDate;

  RETURN GetAddressString(nAddress);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectAddresses ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectAddresses (
  pObject	numeric,
  pDate		timestamp DEFAULT oper_date()
) RETURNS	text[]
AS $$
DECLARE
  arResult	text[];
  r		    ObjectAddresses%rowtype;
BEGIN
  FOR r IN
    SELECT address AS id, typecode, code, GetAddressString(address) AS address
      FROM ObjectAddresses
     WHERE object = pObject
       AND validFromDate <= pDate
       AND validToDate > pDate
  LOOP
    arResult := array_cat(arResult, ARRAY[r.id, r.typecode, r.code, r.address]);
  END LOOP;

  RETURN arResult;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectAddressesJson ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectAddressesJson (
  pObject	numeric,
  pDate		timestamp DEFAULT oper_date()
) RETURNS	json
AS $$
DECLARE
  arResult	json[];
  r		    record;
BEGIN
  FOR r IN
    SELECT address AS id, typecode, code, GetAddressString(address) AS address
      FROM ObjectAddresses
     WHERE object = pObject
       AND validFromDate <= pDate
       AND validToDate > pDate
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectAddressesJsonb -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectAddressesJsonb (
  pObject	numeric,
  pDate		timestamp DEFAULT oper_date()
) RETURNS	jsonb
AS $$
BEGIN
  RETURN GetObjectAddressesJson(pObject, pDate);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
