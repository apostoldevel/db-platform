--------------------------------------------------------------------------------
-- CreateAddress ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateAddress (
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pIndex        text,
  pCountry      text,
  pRegion       text,
  pDistrict     text,
  pCity         text,
  pSettlement   text,
  pStreet       text,
  pHouse        text,
  pBuilding     text,
  pStructure    text,
  pApartment    text,
  pAddress      text DEFAULT null
) RETURNS       uuid
AS $$
DECLARE
  r             db.address%rowtype;

  sList         text[];
  sShort        text DEFAULT '';
  sAddress      text;

  uAddress      uuid;
  uClass        uuid;
  uDocument     uuid;
  uMethod       uuid;
BEGIN
  SELECT class INTO uClass FROM db.type WHERE id = pType;

  IF GetEntityCode(uClass) <> 'address' THEN
    PERFORM IncorrectClassType();
  END IF;

  IF pParent IS NOT NULL THEN
    SELECT * INTO r FROM db.address a WHERE a.id = pParent;
    IF FOUND THEN
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

    sShort := sList[9];

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

  uDocument := CreateDocument(pParent, pType, sShort, sAddress);

  INSERT INTO db.address (id, document, code, index, country, region, district, city, settlement, street, house, building, structure, apartment, sortnum)
  VALUES (uDocument, uDocument, pCode, pIndex, pCountry, pRegion, pDistrict, pCity, pSettlement, pStreet, pHouse, pBuilding, pStructure, pApartment, 0)
  RETURNING id INTO uAddress;

  uMethod := GetMethod(uClass, GetAction('create'));
  PERFORM ExecuteMethod(uAddress, uMethod);

  RETURN uAddress;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditAddress -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditAddress (
  pId           uuid,
  pParent       uuid DEFAULT null,
  pType         uuid DEFAULT null,
  pCode         text DEFAULT null,
  pIndex        text DEFAULT null,
  pCountry      text DEFAULT null,
  pRegion       text DEFAULT null,
  pDistrict     text DEFAULT null,
  pCity         text DEFAULT null,
  pSettlement   text DEFAULT null,
  pStreet       text DEFAULT null,
  pHouse        text DEFAULT null,
  pBuilding     text DEFAULT null,
  pStructure    text DEFAULT null,
  pApartment    text DEFAULT null,
  pAddress      text DEFAULT null
) RETURNS       void
AS $$
DECLARE
  r             db.address%rowtype;

  sList		    text[];
  sShort		text DEFAULT '';
  sAddress	    text;

  uClass        uuid;
  uMethod       uuid;

  -- current
  cParent	    uuid;
BEGIN
  SELECT parent INTO cParent FROM db.object WHERE id = pId;

  pParent := coalesce(pParent, cParent, null_uuid());

  IF CheckNull(pParent) IS NOT NULL THEN

    SELECT * INTO r FROM db.address a WHERE a.id = pParent;
    IF FOUND THEN
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

    sShort := sList[9];

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

  PERFORM EditDocument(pId, pParent, pType, sShort, sAddress);

  UPDATE db.address
     SET code = pCode,
         index = pIndex,
         country = pCountry,
         region = pRegion,
         district = pDistrict,
         city = pCity,
         settlement = pSettlement,
         street = pStreet,
         house = pHouse,
         building = pBuilding,
         structure = pStructure,
         apartment = pApartment
   WHERE id = pId;

  uClass := GetObjectClass(pId);
  uMethod := GetMethod(uClass, GetAction('edit'));
  PERFORM ExecuteMethod(pId, uMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAddressString ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAddressString (
  pId		uuid
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
-- FUNCTION GetObjectAddress ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает адрес объекта.
 * @param {uuid} pObject - Идентификатор объекта
 * @param {text} pKey - Ключ
 * @param {timestamp} pDate - Дата
 * @return {text}
 */
CREATE OR REPLACE FUNCTION GetObjectAddress (
  pObject	uuid,
  pKey	    text,
  pDate		timestamp DEFAULT oper_date()
) RETURNS	text
AS $$
DECLARE
  uAddress		uuid;
BEGIN
  SELECT linked INTO uAddress
    FROM db.object_link
   WHERE object = pObject
     AND key = pKey
     AND validFromDate <= pDate
     AND validToDate > pDate;

  RETURN GetAddressString(uAddress);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectAddresses ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectAddresses (
  pObject	uuid,
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
  pObject	uuid,
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
  pObject	uuid,
  pDate		timestamp DEFAULT oper_date()
) RETURNS	jsonb
AS $$
BEGIN
  RETURN GetObjectAddressesJson(pObject, pDate);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
