--------------------------------------------------------------------------------
-- NOTICE ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.notice ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.notice
AS
  SELECT * FROM Notice;

GRANT SELECT ON api.notice TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION api.notice ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve all notices for the current user.
 * @return {SETOF api.notice} - All notice rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.notice (
) RETURNS        SETOF api.notice
AS $$
  SELECT * FROM api.notice
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.notice ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve notices filtered by category for the current user.
 * @param {text} pCategory - Category tag to filter on
 * @return {SETOF api.notice} - Matching notice rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.notice (
  pCategory      text
) RETURNS        SETOF api.notice
AS $$
  SELECT * FROM api.notice WHERE category = pCategory;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_notice --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new notice via the API layer.
 * @param {uuid} pUserId - Recipient user identifier
 * @param {uuid} pObject - Related object identifier
 * @param {text} pText - Notice message text
 * @param {text} pCategory - Category tag (defaults to 'notice')
 * @param {integer} pStatus - Delivery status: 0=created, 1=delivered, 2=read, 3=accepted, 4=refused
 * @param {jsonb} pData - Arbitrary JSON payload
 * @return {uuid} - New notice identifier
 * @see CreateNotice
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_notice (
  pUserId        uuid,
  pObject        uuid,
  pText          text,
  pCategory      text default null,
  pStatus        integer default null,
  pData          jsonb default null
) RETURNS        uuid
AS $$
BEGIN
  RETURN CreateNotice(pUserId, pObject, pText, pCategory, pStatus, pData);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_notice -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing notice via the API layer.
 * @param {uuid} pId - Notice identifier
 * @param {uuid} pUserId - Owner user identifier
 * @param {uuid} pObject - Related object identifier
 * @param {text} pText - Notice message text
 * @param {text} pCategory - Category tag
 * @param {integer} pStatus - Delivery status: 0=created, 1=delivered, 2=read, 3=accepted, 4=refused
 * @param {jsonb} pData - Arbitrary JSON payload
 * @return {void}
 * @see EditNotice
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_notice (
  pId            uuid,
  pUserId        uuid default null,
  pObject        uuid default null,
  pText          text default null,
  pCategory      text default null,
  pStatus        integer default null,
  pData          jsonb default null
) RETURNS        void
AS $$
BEGIN
  PERFORM EditNotice(pId, pUserId, pObject, pText, pCategory, pStatus, pData);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_notice --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert a notice and return the resulting row.
 * @param {uuid} pId - Notice identifier (NULL to create)
 * @param {uuid} pUserId - Recipient user identifier
 * @param {uuid} pObject - Related object identifier
 * @param {text} pText - Notice message text
 * @param {text} pCategory - Category tag
 * @param {integer} pStatus - Delivery status
 * @param {jsonb} pData - Arbitrary JSON payload
 * @return {SETOF api.notice} - The created or updated notice row
 * @see SetNotice
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_notice (
  pId            uuid,
  pUserId        uuid default null,
  pObject        uuid default null,
  pText          text default null,
  pCategory      text default null,
  pStatus        integer default null,
  pData          jsonb default null
) RETURNS        SETOF api.notice
AS $$
BEGIN
  pId := SetNotice(pId, pUserId, pObject, pText, pCategory, pStatus, pData);
  RETURN QUERY SELECT * FROM api.notice WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_notice --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single notice by identifier.
 * @param {uuid} pId - Notice identifier
 * @return {SETOF api.notice} - Matching notice row
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_notice (
  pId       uuid
) RETURNS   SETOF api.notice
AS $$
  SELECT * FROM api.notice WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_notice -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete a notice owned by the current user.
 * @param {uuid} pId - Notice identifier
 * @return {boolean} - TRUE if a row was deleted
 * @see DeleteNotice
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.delete_notice (
  pId        	uuid
) RETURNS		boolean
AS $$
BEGIN
  RETURN DeleteNotice(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_notice ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count notice records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_notice (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'notice', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_notice -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List notices with dynamic search, filter, and pagination.
 * @param {jsonb} pSearch - Search conditions: '[{"condition": "AND|OR", "field": "<col>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<val>"}]'
 * @param {jsonb} pFilter - Simple key-value filter: '{"<col>": "<val>"}'
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Array of column names to sort by
 * @return {SETOF api.notice} - Matching notice rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_notice (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.notice
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'notice', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.mark_notice -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Mark one or all notices as read for the current user.
 * @param {uuid} pId - Notice identifier; NULL marks all unread notices
 * @return {boolean} - TRUE if any rows were updated
 * @see MarkNotice
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.mark_notice (
  pId			uuid
) RETURNS		boolean
AS $$
BEGIN
  RETURN MarkNotice(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

