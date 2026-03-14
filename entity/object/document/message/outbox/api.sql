--------------------------------------------------------------------------------
-- api.outbox ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.outbox
AS
  SELECT * FROM ServiceMessage WHERE class = GetClass('outbox') AND scope = current_scope();

GRANT SELECT ON api.outbox TO administrator;
GRANT SELECT ON api.outbox TO apibot;

--------------------------------------------------------------------------------
-- FUNCTION api.outbox ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve outbox messages filtered by state (UUID overload).
 * @param {uuid} pState - State identifier
 * @return {SETOF api.outbox} - Matching outbox message records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.outbox (
  pState    uuid
) RETURNS   SETOF api.outbox
AS $$
  SELECT * FROM api.outbox WHERE state = pState;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.outbox ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve outbox messages filtered by state (text code overload).
 * @param {text} pState - State code (e.g., 'enabled', 'sending')
 * @return {SETOF api.outbox} - Matching outbox message records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.outbox (
  pState    text
) RETURNS   SETOF api.outbox
AS $$
  SELECT * FROM api.outbox(GetState(GetClass('outbox'), pState));
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_outbox --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new outgoing message (outbox) via the API layer.
 * @param {uuid} pParent - Parent object reference
 * @param {uuid} pAgent - Delivery agent
 * @param {text} pCode - Unique message code (MsgId)
 * @param {text} pProfile - Sender profile
 * @param {text} pAddress - Recipient address
 * @param {text} pSubject - Subject line
 * @param {text} pContent - Message body
 * @param {text} pLabel - Display label
 * @param {text} pDescription - Description
 * @return {uuid} - Identifier of the created outbox message
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_outbox (
  pParent       uuid,
  pAgent        uuid,
  pCode         text,
  pProfile      text,
  pAddress      text,
  pSubject      text,
  pContent        text,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateMessage(pParent, GetType('message.outbox'), pAgent, pCode, pProfile, pAddress, pSubject, pContent, pLabel, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_outbox --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single outbox message by identifier with access check.
 * @param {uuid} pId - Message identifier
 * @return {SETOF api.outbox} - Matching outbox message record
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_outbox (
  pId       uuid
) RETURNS   SETOF api.outbox
AS $$
  SELECT * FROM api.outbox WHERE id = pId AND CheckObjectAccess(id, B'100')
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_outbox -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List outbox messages matching search, filter, and sort criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Field-level equality filter
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Array of fields to sort by
 * @return {SETOF api.outbox} - Matching outbox message records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_outbox (
  pSearch    jsonb DEFAULT null,
  pFilter    jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet    integer DEFAULT null,
  pOrderBy    jsonb DEFAULT null
) RETURNS    SETOF api.outbox
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'outbox', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
