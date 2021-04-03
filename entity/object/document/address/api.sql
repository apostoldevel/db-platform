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
 * @param {uuid} pParent - Идентификатор родителя | null
 * @param {text} pType - Код типа адреса
 * @param {text} pCode - Код: ФФ СС РРР ГГГ ППП УУУУ. Где: ФФ - код страны; СС - код субъекта РФ; РРР - код района; ГГГ - код города; ППП - код населенного пункта; УУУУ - код улицы.
 * @param {text} pIndex - Почтовый индекс
 * @param {text} pCountry - Страна
 * @param {text} pRegion - Регион
 * @param {text} pDistrict - Район
 * @param {text} pCity - Город
 * @param {text} pSettlement - Населённый пункт
 * @param {text} pStreet - Улица
 * @param {text} pHouse - Дом
 * @param {text} pBuilding - Корпус
 * @param {text} pStructure - Строение
 * @param {text} pApartment - Квартира
 * @param {text} pAddress - Полный адрес
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_address (
  pParent       uuid,
  pType         text,
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
 * @param {uuid} pId - Идентификатор адреса
 * @param {uuid} pParent - Идентификатор родителя | null
 * @param {text} pType - Код типа адреса
 * @param {text} pCode - Код: ФФ СС РРР ГГГ ППП УУУУ. Где: ФФ - код страны; СС - код субъекта РФ; РРР - код района; ГГГ - код города; ППП - код населенного пункта; УУУУ - код улицы.
 * @param {text} pIndex - Почтовый индекс
 * @param {text} pCountry - Страна
 * @param {text} pRegion - Регион
 * @param {text} pDistrict - Район
 * @param {text} pCity - Город
 * @param {text} pSettlement - Населённый пункт
 * @param {text} pStreet - Улица
 * @param {text} pHouse - Дом
 * @param {text} pBuilding - Корпус
 * @param {text} pStructure - Строение
 * @param {text} pApartment - Квартира
 * @param {text} pAddress - Полный адрес
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_address (
  pId           uuid,
  pParent       uuid DEFAULT null,
  pType         text DEFAULT null,
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
  uAddress      uuid;
  uType         uuid;
BEGIN
  SELECT a.id INTO uAddress FROM db.address a WHERE a.id = pId;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('адрес', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    uType := CodeToType(lower(pType), 'address');
  ELSE
    SELECT o.type INTO uType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditAddress(uAddress, pParent, uType, pCode, pIndex, pCountry, pRegion, pDistrict, pCity, pSettlement, pStreet, pHouse, pBuilding, pStructure, pApartment, pAddress);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_address -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_address (
  pId           uuid,
  pParent       uuid,
  pType         text,
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
 * @param {uuid} pId - Идентификатор адреса
 * @return {api.address} - Адрес
 */
CREATE OR REPLACE FUNCTION api.get_address (
  pId		uuid
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
 * @param {text} pId - Идентификатор адреса
 * @out param {text} address - Адрес в виде строки
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.get_address_string (
  pId           uuid
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
  pObject       uuid,
  pAddress      uuid,
  pParent       uuid,
  pType         text,
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
  pObject       uuid,
  pAddresses    json
) RETURNS       SETOF api.object_address
AS $$
DECLARE
  r             record;
  uId           uuid;
  arKeys        text[];
BEGIN
  SELECT o.id INTO uId FROM db.object o WHERE o.id = pObject;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('объект', 'id', pObject);
  END IF;

  IF pAddresses IS NOT NULL THEN
    arKeys := array_cat(arKeys, ARRAY['id', 'parent', 'type', 'code', 'index', 'country', 'region', 'district', 'city', 'settlement', 'street', 'house', 'building', 'structure', 'apartment', 'address']);
    PERFORM CheckJsonKeys('/object/address/addresses', arKeys, pAddresses);

    FOR r IN SELECT * FROM json_to_recordset(pAddresses) AS addresses(id uuid, parent uuid, type text, code text, index text, country text, region text, district text, city text, settlement text, street text, house text, building text, structure text, apartment text, address text)
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
  pObject       uuid,
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
  pObject	uuid
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
  pObject	uuid
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
 * @param {uuid} pObject - Идентификатор объекта
 * @param {uuid} pAddress - Идентификатор адреса
 * @param {timestamp} pDateFrom - Дата операции
 * @out param {uuid} id - Идентификатор
 * @out param {boolean} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {SETOF api.object_address}
 */
CREATE OR REPLACE FUNCTION api.set_object_address (
  pObject     uuid,
  pAddress    uuid,
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
 * @param {uuid} pObject - Идентификатор объекта
 * @param {uuid} pAddress - Идентификатор адреса
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.delete_object_address (
  pObject     uuid,
  pAddress    uuid
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
 * @param {uuid} pId - Идентификатор адреса
 * @return {api.object_address}
 */
CREATE OR REPLACE FUNCTION api.get_object_address (
  pObject       uuid,
  pAddress      uuid
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
