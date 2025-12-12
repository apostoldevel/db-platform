--------------------------------------------------------------------------------
-- ADDRESS TREE ----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.address_tree ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.address_tree
AS
  SELECT * FROM AddressTree;

GRANT SELECT ON api.address_tree TO administrator;

--------------------------------------------------------------------------------
-- api.get_address_tree --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает адрес из справочника адресов КЛАДР
 * @param {integer} pId - Идентификатор
 * @return {api.address_tree}
 */
CREATE OR REPLACE FUNCTION api.get_address_tree (
  pId       integer
) RETURNS   SETOF api.address_tree
AS $$
  SELECT * FROM api.address_tree WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_address_tree -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает справочник адресов КЛАДР.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.address_tree} - Дерево адресов
 */
CREATE OR REPLACE FUNCTION api.list_address_tree (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.address_tree
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'address_tree', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_address_tree_history ------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает историю из справочника адресов
 * @param {integer} pId - Идентификатор
 * @return {SETOF api.address_tree}
 */
CREATE OR REPLACE FUNCTION api.get_address_tree_history (
  pId       integer
) RETURNS   SETOF api.address_tree
AS $$
  WITH RECURSIVE addr_tree(id, parent, code, name, short, index, level) AS (
    SELECT id, parent, code, name, short, index, level FROM db.address_tree WHERE id = pId
     UNION ALL
    SELECT a.id, a.parent, a.code, a.name, a.short, a.index, a.level
      FROM db.address_tree a, addr_tree t
     WHERE a.id = t.parent
  )
  SELECT * FROM addr_tree
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_address_tree_string -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает адрес из справочника адресов по коду в виде строки
 * @param {varchar} pCode - Код из справочника адресов: ФФ СС РРР ГГГ ППП УУУУ. Где: ФФ - код страны; СС - код субъекта РФ; РРР - код района; ГГГ - код города; ППП - код населенного пункта; УУУУ - код улицы.
 * @param {integer} pShort - Сокращение: 0 - нет; 1 - слева; 2 - справа
 * @param {integer} pLevel - Ограничение уровня вложенности
 * @return {text}
 */
CREATE OR REPLACE FUNCTION api.get_address_tree_string (
  pCode         varchar,
  pShort        integer DEFAULT 0,
  pLevel        integer DEFAULT 0
) RETURNS       text
AS $$
BEGIN
  RETURN GetAddressTreeString(pCode, pShort, pLevel);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
