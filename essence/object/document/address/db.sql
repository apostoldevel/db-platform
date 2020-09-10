--------------------------------------------------------------------------------
-- ADDRESS ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.address_tree (
    id          numeric(12) PRIMARY KEY,
    parent      numeric(12),
    code        varchar(17) NOT NULL,
    name        varchar(50) NOT NULL,
    short       varchar(30),
    index       varchar(6),
    level		numeric NOT NULL,
    CONSTRAINT fk_address_tree_parent FOREIGN KEY (parent) REFERENCES db.address_tree(id)
);

COMMENT ON TABLE db.address_tree IS 'Справочник адресов в виде дерева.';

COMMENT ON COLUMN db.address_tree.id IS 'Идентификатор';
COMMENT ON COLUMN db.address_tree.parent IS 'Родительский узел';
COMMENT ON COLUMN db.address_tree.code IS 'Код: ФФ СС РРР ГГГ ППП УУУУ. Где: ФФ - код страны; СС - код субъекта РФ; РРР - код района; ГГГ - код города; ППП - код населенного пункта; УУУУ - код улицы.';
COMMENT ON COLUMN db.address_tree.name IS 'Наименование';
COMMENT ON COLUMN db.address_tree.short IS 'Сокращение';
COMMENT ON COLUMN db.address_tree.index IS 'Почтовый индекс';
COMMENT ON COLUMN db.address_tree.level IS 'Уровень';

CREATE INDEX ON db.address_tree (parent);
CREATE UNIQUE INDEX ON db.address_tree (code);

--------------------------------------------------------------------------------
-- AddAddressTree --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddAddressTree (
  pParent   numeric,
  pCode     varchar,
  pName     varchar,
  pShort    varchar,
  pIndex    varchar,
  pLevel    integer
) RETURNS   numeric
AS $$
DECLARE
  nId       numeric;
BEGIN
  INSERT INTO db.address_tree (id, parent, code, name, short, index, level)
  VALUES (nextval('SEQUENCE_ADDRESS'), pParent, pCode, pName, pShort, pIndex, pLevel)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddKladrToTree --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddKladrToTree (
  pParent   numeric,
  pCode     varchar,
  pLevel    integer
) RETURNS   numeric
AS $$
DECLARE
  r         db.kladr%rowtype;
  nId       numeric;
BEGIN
  SELECT * INTO r FROM db.kladr WHERE code = pCode || '00';
  nId := AddAddressTree(pParent, '01' || pCode || '0000', r.name, r.socr, r.index, pLevel);

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddStreetToTree -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddStreetToTree (
  pParent   numeric,
  pCode     varchar,
  pLevel    integer
) RETURNS   numeric
AS $$
DECLARE
  r         db.street%rowtype;
  nId       numeric;
BEGIN
  SELECT * INTO r FROM db.street WHERE code = pCode || '00';
  nId := AddAddressTree(pParent, '01' || pCode, r.name, r.socr, r.index, pLevel);

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CopyFromKladr ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CopyFromKladr (
  pParent   numeric,
  pCode     varchar
) RETURNS   void
AS $$
DECLARE
  Rec       record;
  nPLev     integer;
  nCLev     integer;
  nIndex    integer;

  IdList    numeric[];
  sList     text[];
BEGIN
  IdList[0] := pParent;

  FOR Rec IN (
    SELECT SubStr(code,  1, 2) as SS,
           SubStr(code,  3, 3) as RRR,
           SubStr(code,  6, 3) as GGG,
           SubStr(code,  9, 3) as PPP,
           '0000' as UUUU
      FROM db.kladr 
     WHERE SubStr(code, 12, 2) = '00'
       AND SubStr(code, 1, 2) = pCode
     GROUP BY SubStr(code,  1, 2),
              SubStr(code,  3, 3),
              SubStr(code,  6, 3),
              SubStr(code,  9, 3)
     UNION ALL
    SELECT SubStr(code,  1, 2) as SS,
           SubStr(code,  3, 3) as RRR,
           SubStr(code,  6, 3) as GGG,
           SubStr(code,  9, 3) as PPP,
           SubStr(code, 12, 4) as UUUU
      FROM db.street
     WHERE SubStr(code, 16, 2) = '00'
       AND SubStr(code, 1, 2) = pCode
     GROUP BY SubStr(code,  1, 2),
              SubStr(code,  3, 3),
              SubStr(code,  6, 3),
              SubStr(code,  9, 3),
              SubStr(code, 12, 4)
     ORDER BY 1, 2, 3, 4, 5
  )
  LOOP
    nCLev := 0;
      
    sList[1] := Rec.SS;
    sList[2] := Rec.RRR;
    sList[3] := Rec.GGG;
    sList[4] := Rec.PPP;
    sList[5] := Rec.UUUU;

    FOR nIndex IN 1..5
    LOOP
      IF coalesce(to_number(nullif(sList[nIndex], ''), '9999'), 0) <> 0 THEN
        nPLev := nCLev;
        nCLev := nIndex;
      END IF;
    END LOOP;

    IF Rec.UUUU = '0000' THEN
      IdList[nCLev] := AddKladrToTree(IdList[nPLev], Rec.SS || Rec.RRR || Rec.GGG || Rec.PPP, nCLev);
    ELSE
      IdList[nCLev] := AddStreetToTree(IdList[nPLev], Rec.SS || Rec.RRR || Rec.GGG || Rec.PPP || Rec.UUUU, nCLev);
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- LoadFromKladr ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION LoadFromKladr (
  pCodes    text[]
) RETURNS   void
AS $$
DECLARE
  Rec       record;
  nId       numeric;
  i         integer;
BEGIN
  nId := AddAddressTree(null, '01000000000000000', 'Российская Федерация', null, null, 0);

  IF pCodes IS NOT NULL THEN
    FOR i IN 1..array_length(pCodes, 1)
    LOOP
      PERFORM CopyFromKladr(nId, pCodes[i]);
    END LOOP;
  ELSE
    -- Для всех регионов РФ
    FOR Rec IN (
      SELECT SubStr(code, 1, 2) as SS
        FROM db.kladr
       WHERE SubStr(code, 11, 2) = '00'
         AND SubStr(code, 1, 2) <> '99'
       GROUP BY SubStr(code, 1, 2)
       ORDER BY 1
    )
    LOOP
      PERFORM CopyFromKladr(nId, Rec.SS);
    END LOOP;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAddressTreeId ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAddressTreeId (
  pCode		varchar
) RETURNS   numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.address_tree WHERE code = pCode;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAddressTree --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAddressTree (
  pCode		varchar
) RETURNS   text[]
AS $$
DECLARE
  r         record;
  arResult	text[];
BEGIN
  FOR r IN (
    WITH RECURSIVE addr_tree(id, parent, name, level) AS (
      SELECT id, parent, name, level FROM db.address_tree WHERE code = pCode
       UNION ALL
      SELECT a.id, a.parent, a.name, a.level
        FROM db.address_tree a, addr_tree t
       WHERE a.id = t.parent
    )
    SELECT * FROM addr_tree ORDER BY level
  )
  LOOP
    arResult[r.level] := r.name;
  END LOOP;

  RETURN arResult;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAddressTreeString --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAddressTreeString (
  pCode		varchar,       -- Код из справочника адресов
  pShort	int DEFAULT 0, -- Сокращение: 0 - нет; 1 - слева; 2 - справа
  pLevel	int DEFAULT 0  -- Ограничение уровня вложенности
) RETURNS   text
AS $$
DECLARE
  r         record;
  sIndex	text;
  sStr		text;
  sResult	text;
BEGIN
  FOR r IN (
    WITH RECURSIVE addr_tree(id, parent, index, name, short, level) AS (
      SELECT id, parent, index, name, short, level FROM db.address_tree WHERE code = pCode
       UNION ALL
      SELECT a.id, a.parent, a.index, a.name, a.short, a.level
        FROM db.address_tree a, addr_tree t
       WHERE a.id = t.parent
         AND a.level >= pLevel
    )
    SELECT * FROM addr_tree
  )
  LOOP
    IF pLevel = 0 and r.Level = 5 and r.Index IS NOT NULL THEN
      sIndex := r.Index;
    END IF;

    IF r.Short IS NULL THEN
      sStr := r.Name;
    ELSE
      IF pShort = 0 THEN
        sStr := r.Name;
      elsif pShort = 1 THEN
        sStr := r.Short || '. ' || r.Name;
      ELSE
        sStr := r.Name || ' ' || r.Short || '.';
      END IF;
    END IF;

    IF sResult IS NULL THEN
      sResult := sStr;
    ELSE
      sResult := sStr || ', ' || sResult;
    END IF;
  END LOOP;

  IF sIndex IS NOT NULL THEN
    sResult := sIndex || ', ' || sResult;
  END IF;

  RETURN sResult;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddressTree -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AddressTree (Id, Parent, Code, Name, Short, Index, Level)
AS
  SELECT id, parent, code, name, short, index, level
    FROM db.address_tree;

GRANT ALL ON AddressTree TO administrator;

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
  IF NEW.ID IS NULL OR NEW.ID = 0 THEN
    SELECT NEW.DOCUMENT INTO NEW.ID;
  END IF;

  IF NEW.SORTNUM IS NULL OR NEW.SORTNUM = 0 THEN
    SELECT NEW.ID INTO NEW.SORTNUM;
  END IF;

  RAISE DEBUG '[%] Добавлен адрес: %', NEW.Id, NEW.Code;

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

  nClass := GetObjectClass(nAddress);
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
-- ObjectAddress ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectAddress (Id, Object, Parent,
  Essence, EssenceCode, EssenceName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Index, Country, Region, District, City, Settlement, Street, House, Building, Structure, Apartment, SortNum,
  Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Area, AreaCode, AreaName
) AS
  SELECT a.id, d.object, d.parent,
         d.essence, d.essencecode, d.essencename,
         d.class, d.classcode, d.classlabel,
         d.type, d.typecode, d.typename, d.typedescription,
         a.code, a.index, a.country, a.region, a.district, a.city, a.settlement, a.street, a.house, a.building, a.structure, a.apartment, a.sortnum,
         d.label, d.description,
         d.statetype, d.statetypecode, d.statetypename,
         d.state, d.statecode, d.statelabel, d.lastupdate,
         d.owner, d.ownercode, d.ownername, d.created,
         d.oper, d.opercode, d.opername, d.operdate,
         d.area, d.areacode, d.areaname
    FROM Address a INNER JOIN ObjectDocument d ON d.id = a.document;

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
    FROM db.object_link ol INNER JOIN db.address a ON a.id = ol.linked;

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
