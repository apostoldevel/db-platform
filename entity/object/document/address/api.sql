--------------------------------------------------------------------------------
-- ADDRESS ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.address -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.address
AS
  SELECT * FROM ObjectAddress;

GRANT SELECT ON api.address TO administrator;

--------------------------------------------------------------------------------
-- api.add_address -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет новый адрес.
 * @param {numeric} pParent - Идентификатор родителя | null
 * @param {varchar} pType - Код типа адреса
 * @param {varchar} pCode - Код: ФФ СС РРР ГГГ ППП УУУУ. Где: ФФ - код страны; СС - код субъекта РФ; РРР - код района; ГГГ - код города; ППП - код населенного пункта; УУУУ - код улицы.
 * @param {varchar} pIndex - Почтовый индекс
 * @param {varchar} pCountry - Страна
 * @param {varchar} pRegion - Регион
 * @param {varchar} pDistrict - Район
 * @param {varchar} pCity - Город
 * @param {varchar} pSettlement - Населённый пункт
 * @param {varchar} pStreet - Улица
 * @param {varchar} pHouse - Дом
 * @param {varchar} pBuilding - Корпус
 * @param {varchar} pStructure - Строение
 * @param {varchar} pApartment - Квартира
 * @param {text} pAddress - Полный адрес
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION api.add_address (
  pParent       numeric,
  pType         varchar,
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
BEGIN
  RETURN CreateAddress(pParent, CodeToType(lower(coalesce(pType, 'post')), 'address'), pCode, pIndex, pCountry, pRegion, pDistrict, pCity, pSettlement, pStreet, pHouse, pBuilding, pStructure, pApartment, pAddress);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_address ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет данные адреса.
 * @param {numeric} pId - Идентификатор адреса
 * @param {numeric} pParent - Идентификатор родителя | null
 * @param {varchar} pType - Код типа адреса
 * @param {varchar} pCode - Код: ФФ СС РРР ГГГ ППП УУУУ. Где: ФФ - код страны; СС - код субъекта РФ; РРР - код района; ГГГ - код города; ППП - код населенного пункта; УУУУ - код улицы.
 * @param {varchar} pIndex - Почтовый индекс
 * @param {varchar} pCountry - Страна
 * @param {varchar} pRegion - Регион
 * @param {varchar} pDistrict - Район
 * @param {varchar} pCity - Город
 * @param {varchar} pSettlement - Населённый пункт
 * @param {varchar} pStreet - Улица
 * @param {varchar} pHouse - Дом
 * @param {varchar} pBuilding - Корпус
 * @param {varchar} pStructure - Строение
 * @param {varchar} pApartment - Квартира
 * @param {text} pAddress - Полный адрес
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_address (
  pId           numeric,
  pParent       numeric DEFAULT null,
  pType         varchar DEFAULT null,
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
  nAddress      numeric;
  nType         numeric;
BEGIN
  SELECT a.id INTO nAddress FROM db.address a WHERE a.id = pId;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('адрес', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    nType := CodeToType(lower(pType), 'address');
  ELSE
    SELECT o.type INTO nType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditAddress(nAddress, pParent, nType, pCode, pIndex, pCountry, pRegion, pDistrict, pCity, pSettlement, pStreet, pHouse, pBuilding, pStructure, pApartment, pAddress);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_address -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_address (
  pId           numeric,
  pParent       numeric,
  pType         varchar,
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
) RETURNS       SETOF api.address
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_address(pParent, pType, pCode, pIndex, pCountry, pRegion, pDistrict, pCity, pSettlement, pStreet, pHouse, pBuilding, pStructure, pApartment, pAddress);
  ELSE
    PERFORM api.update_address(pId, pParent, pType, pCode, pIndex, pCountry, pRegion, pDistrict, pCity, pSettlement, pStreet, pHouse, pBuilding, pStructure, pApartment, pAddress);
  END IF;

  RETURN QUERY SELECT * FROM api.address WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_address -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает клиента
 * @param {numeric} pId - Идентификатор адреса
 * @return {api.address} - Адрес
 */
CREATE OR REPLACE FUNCTION api.get_address (
  pId		numeric
) RETURNS	SETOF api.address
AS $$
  SELECT * FROM api.address WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_address ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список клиентов.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.address} - Адреса
 */
CREATE OR REPLACE FUNCTION api.list_address (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.address
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'address', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_address_string ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает адрес в виде строки
 * @param {varchar} pId - Идентификатор адреса
 * @out param {text} address - Адрес в виде строки
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.get_address_string (
  pId           numeric
) RETURNS       text
AS $$
BEGIN
  RETURN GetAddressString(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- OBJECT ADDRESS --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.object_address ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.object_address
AS
  SELECT * FROM ObjectAddresses;

GRANT SELECT ON api.object_address TO administrator;

--------------------------------------------------------------------------------
-- api.set_object_addresses ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_object_addresses (
  pObject       numeric,
  pAddress      numeric,
  pParent       numeric,
  pType         varchar,
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
  pText         text DEFAULT null
) RETURNS       SETOF api.object_address
AS $$
BEGIN
  SELECT id INTO pAddress FROM api.set_address(pAddress, pParent, pType, pCode, pIndex, pCountry, pRegion, pDistrict, pCity, pSettlement, pStreet, pHouse, pBuilding, pStructure, pApartment, pText);
  RETURN QUERY SELECT * FROM api.set_object_address(pObject, pAddress);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_addresses_json -----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_object_addresses_json (
  pObject       numeric,
  pAddresses    json
) RETURNS       SETOF api.object_address
AS $$
DECLARE
  r             record;
  nId           numeric;
  arKeys        text[];
BEGIN
  SELECT o.id INTO nId FROM db.object o WHERE o.id = pObject;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('объект', 'id', pObject);
  END IF;

  IF pAddresses IS NOT NULL THEN
    arKeys := array_cat(arKeys, ARRAY['id', 'parent', 'type', 'code', 'index', 'country', 'region', 'district', 'city', 'settlement', 'street', 'house', 'building', 'structure', 'apartment', 'address']);
    PERFORM CheckJsonKeys('/object/address/addresses', arKeys, pAddresses);

    FOR r IN SELECT * FROM json_to_recordset(pAddresses) AS addresses(id numeric, parent numeric, type varchar, code varchar, index varchar, country varchar, region varchar, district varchar, city varchar, settlement varchar, street varchar, house varchar, building varchar, structure varchar, apartment varchar, address text)
    LOOP
      RETURN NEXT api.set_object_addresses(pObject, r.Id, r.Parent, r.Type, r.Code, r.Index, r.Country, r.Region, r.District, r.City, r.Settlement, r.Street, r.House, r.Building, r.Structure, r.Apartment, r.Address);
    END LOOP;
  ELSE
    PERFORM JsonIsEmpty();
  END IF;

  RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_addresses_jsonb ----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_object_addresses_jsonb (
  pObject       numeric,
  pAddresses	jsonb
) RETURNS       SETOF api.object_address
AS $$
BEGIN
  RETURN QUERY SELECT * FROM api.set_object_addresses_json(pObject, pAddresses::json);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_addresses_json -----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_addresses_json (
  pObject	numeric
) RETURNS	json
AS $$
BEGIN
  RETURN GetObjectAddressesJson(pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_addresses_jsonb ----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.get_object_addresses_jsonb (
  pObject	numeric
) RETURNS	jsonb
AS $$
BEGIN
  RETURN GetObjectAddressesJsonb(pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_object_address ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает адрес объекта
 * @param {numeric} pObject - Идентификатор объекта
 * @param {numeric} pAddress - Идентификатор адреса
 * @param {timestamp} pDateFrom - Дата операции
 * @out param {numeric} id - Идентификатор
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {SETOF api.object_address}
 */
CREATE OR REPLACE FUNCTION api.set_object_address (
  pObject     numeric,
  pAddress    numeric,
  pDateFrom   timestamp DEFAULT oper_date()
) RETURNS     SETOF api.object_address
AS $$
BEGIN
  PERFORM SetObjectLink(pObject, pAddress, GetObjectTypeCode(pAddress), pDateFrom);
  RETURN QUERY SELECT * FROM api.get_object_address(pObject, pAddress);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_object_address ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет адрес объекта
 * @param {numeric} pObject - Идентификатор объекта
 * @param {numeric} pAddress - Идентификатор адреса
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.delete_object_address (
  pObject     numeric,
  pAddress    numeric
) RETURNS     void
AS $$
BEGIN
  PERFORM SetObjectLink(pObject, null, GetObjectTypeCode(pAddress));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_object_address ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает адрес объекта
 * @param {numeric} pId - Идентификатор адреса
 * @return {api.object_address}
 */
CREATE OR REPLACE FUNCTION api.get_object_address (
  pObject       numeric,
  pAddress      numeric
) RETURNS       SETOF api.object_address
AS $$
  SELECT * FROM api.object_address WHERE object = pObject AND address = pAddress;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_object_address -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список адресов объекта.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.object_address}
 */
CREATE OR REPLACE FUNCTION api.list_object_address (
  pSearch	jsonb DEFAULT null,
  pFilter	jsonb DEFAULT null,
  pLimit	integer DEFAULT null,
  pOffSet	integer DEFAULT null,
  pOrderBy	jsonb DEFAULT null
) RETURNS	SETOF api.object_address
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'object_address', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
