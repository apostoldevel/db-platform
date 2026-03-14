--------------------------------------------------------------------------------
-- COMMENT ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.comment -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.comment
AS
  WITH RECURSIVE tree AS (
    SELECT *, ARRAY[row_number() OVER (ORDER BY priority DESC)] AS sortlist FROM Comment WHERE parent IS NULL
     UNION ALL
    SELECT c.*, array_append(t.sortlist, row_number() OVER (ORDER BY c.priority DESC))
      FROM Comment c INNER JOIN tree t ON c.parent = t.id
  ) SELECT t.*, array_to_string(sortlist, '.', '0') AS Index FROM tree t;

GRANT SELECT ON api.comment TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION api.comment --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve all comments for a given object, sorted by priority and creation date.
 * @param {uuid} pObject - Target object identifier
 * @return {SETOF api.comment} - Threaded comment rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.comment (
  pObject   uuid
) RETURNS   SETOF api.comment
AS $$
  SELECT * FROM api.comment WHERE object = pObject ORDER BY priority DESC, created DESC
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_comment -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Add a new comment as the current user.
 * @param {uuid} pParent - Parent comment identifier (NULL for top-level)
 * @param {uuid} pObject - Target object identifier
 * @param {integer} pPriority - Sort priority (defaults to 0)
 * @param {text} pText - Comment body text
 * @param {jsonb} pData - Arbitrary JSON payload
 * @return {uuid} - New comment identifier
 * @see CreateComment
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_comment (
  pParent       uuid,
  pObject       uuid,
  pPriority     integer,
  pText         text,
  pData         jsonb default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateComment(pParent, pObject, current_userid(), coalesce(pPriority, 0), pText, pData);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_comment ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update a comment (owner or administrator only).
 * @param {uuid} pId - Comment identifier
 * @param {integer} pPriority - Sort priority
 * @param {text} pText - Comment body text
 * @param {jsonb} pData - Arbitrary JSON payload
 * @return {void}
 * @throws NotFound - When the comment does not exist
 * @throws AccessDenied - When the caller is neither the owner nor an administrator
 * @see EditComment
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_comment (
  pId           uuid,
  pPriority     integer default null,
  pText         text default null,
  pData         jsonb default null
) RETURNS       void
AS $$
DECLARE
  uOwner        uuid;
BEGIN
  SELECT owner INTO uOwner FROM db.comment WHERE id = pId;

  IF NOT FOUND THEN
    PERFORM NotFound();
  END IF;

  IF uOwner <> current_userid() THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  PERFORM EditComment(pId, pPriority, pText, pData);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_comment -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert a comment and return the resulting row.
 * @param {uuid} pId - Comment identifier (NULL to create)
 * @param {uuid} pParent - Parent comment identifier
 * @param {uuid} pObject - Target object identifier
 * @param {integer} pPriority - Sort priority
 * @param {text} pText - Comment body text
 * @param {jsonb} pData - Arbitrary JSON payload
 * @return {SETOF api.comment} - The created or updated comment row
 * @see api.add_comment, api.update_comment
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_comment (
  pId        	uuid,
  pParent		uuid default null,
  pObject		uuid default null,
  pPriority		integer default null,
  pText			text default null,
  pData         jsonb default null
) RETURNS		SETOF api.comment
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_comment(pParent, pObject, coalesce(pPriority, 0), pText, pData);
  ELSE
    PERFORM api.update_comment(pId, coalesce(pPriority, 0), pText, pData);
  END IF;

  RETURN QUERY SELECT * FROM api.comment WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_comment -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single comment by identifier (with access check).
 * @param {uuid} pId - Comment identifier
 * @return {SETOF api.comment} - Matching comment row
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_comment (
  pId		uuid
) RETURNS	SETOF api.comment
AS $$
  SELECT * FROM api.comment WHERE id = pId AND CheckObjectAccess(id, B'100')
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_comment ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete a comment (owner or administrator only).
 * @param {uuid} pId - Comment identifier
 * @return {boolean} - TRUE if deleted
 * @throws NotFound - When the comment does not exist
 * @throws AccessDenied - When the caller is neither the owner nor an administrator
 * @see DeleteComment
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.delete_comment (
  pId			uuid
) RETURNS		boolean
AS $$
DECLARE
  uOwner        uuid;
BEGIN
  SELECT owner INTO uOwner FROM db.comment WHERE id = pId;

  IF NOT FOUND THEN
	PERFORM NotFound();
  END IF;

  IF uOwner <> current_userid() THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
	  PERFORM AccessDenied();
	END IF;
  END IF;

  RETURN DeleteComment(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_comment ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List comments with dynamic search, filter, and pagination.
 * @param {jsonb} pSearch - Search conditions: '[{"condition": "AND|OR", "field": "<col>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<val>"}]'
 * @param {jsonb} pFilter - Simple key-value filter: '{"<col>": "<val>"}'
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Array of column names to sort by
 * @return {SETOF api.comment} - Matching comment rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_comment (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.comment
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'comment', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
