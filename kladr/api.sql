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
 * @brief Fetch a single address tree node by its ID.
 * @param {integer} pId - Address tree node identifier
 * @return {SETOF api.address_tree} - One row matching the given ID
 * @since 1.0.0
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
 * @brief List address tree nodes with optional search, filtering, and pagination.
 * @param {jsonb} pSearch - Search conditions: [{"condition": "AND|OR", "field": "<col>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<val>"}]
 * @param {jsonb} pFilter - Column-level equality filter: {"<col>": "<val>"}
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip before returning results
 * @param {jsonb} pOrderBy - Array of column names to sort by
 * @return {SETOF api.address_tree} - Matching address tree rows
 * @since 1.0.0
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
 * @brief Retrieve the full ancestor chain for an address node (recursive walk to root).
 * @param {integer} pId - Address tree node identifier to start from
 * @return {SETOF api.address_tree} - All ancestor rows from the node up to the root
 * @since 1.0.0
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
 * @brief Format an address as a human-readable string by its KLADR code.
 * @param {varchar} pCode - Composite address code: FF SS RRR GGG PPP UUUU (FF = country, SS = subject, RRR = district, GGG = city, PPP = settlement, UUUU = street)
 * @param {integer} pShort - Abbreviation mode: 0 = none, 1 = prefix, 2 = suffix
 * @param {integer} pLevel - Minimum tree depth to include in the output
 * @return {text} - Formatted address string
 * @see GetAddressTreeString
 * @since 1.0.0
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
