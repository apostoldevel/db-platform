--------------------------------------------------------------------------------
-- PROGRAM ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.program -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.program
AS
  SELECT * FROM ObjectProgram;

GRANT SELECT ON api.program TO administrator;

--------------------------------------------------------------------------------
-- api.add_program -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new executable program via the API (defaults to 'plpgsql.program' type).
 * @param {uuid} pParent - Parent object or NULL
 * @param {uuid} pType - Program type (NULL = plpgsql.program)
 * @param {text} pCode - Unique business code
 * @param {text} pName - Display name
 * @param {text} pBody - SQL/PL/pgSQL source code
 * @param {text} pDescription - Optional description
 * @return {uuid} - ID of the created program
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_program (
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pName         text,
  pBody         text,
  pDescription  text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateProgram(pParent, coalesce(pType, GetType('plpgsql.program')), pCode, pName, pBody, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_program ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing program via the API.
 * @param {uuid} pId - Program to update
 * @param {uuid} pParent - New parent (NULL keeps current)
 * @param {uuid} pType - New type (NULL keeps current)
 * @param {text} pCode - New code (NULL keeps current)
 * @param {text} pName - New name (NULL keeps current)
 * @param {text} pBody - New source code (NULL keeps current)
 * @param {text} pDescription - New description (NULL keeps current)
 * @return {void}
 * @throws ObjectNotFound - When program with given ID does not exist
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_program (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pBody         text default null,
  pDescription  text default null
) RETURNS       void
AS $$
DECLARE
  uProgram      uuid;
BEGIN
  SELECT t.id INTO uProgram FROM db.program t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('program', 'id', pId);
  END IF;

  PERFORM EditProgram(uProgram, pParent, pType, pCode, pName, pBody, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_program -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert a program: create when pId is NULL, otherwise update. Return the row.
 * @param {uuid} pId - Program ID (NULL = create new)
 * @param {uuid} pParent - Parent object or NULL
 * @param {uuid} pType - Program type
 * @param {text} pCode - Business code
 * @param {text} pName - Display name
 * @param {text} pBody - Source code
 * @param {text} pDescription - Optional description
 * @return {SETOF api.program} - The created or updated program row
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_program (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pBody         text default null,
  pDescription  text default null
) RETURNS       SETOF api.program
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_program(pParent, pType, pCode, pName, pBody, pDescription);
  ELSE
    PERFORM api.update_program(pId, pParent, pType, pCode, pName, pBody, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.program WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_program -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single program by ID (with access check).
 * @param {uuid} pId - Program ID
 * @return {SETOF api.program} - Matching row or empty set
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_program (
  pId       uuid
) RETURNS   SETOF api.program
AS $$
  SELECT * FROM api.program WHERE id = pId AND CheckObjectAccess(id, B'100')
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_program -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count program records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_program (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'program', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_program ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List programs with optional search, filter, and pagination.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @param {integer} pLimit - Maximum rows to return
 * @param {integer} pOffSet - Rows to skip
 * @param {jsonb} pOrderBy - Sort fields array
 * @return {SETOF api.program} - Matching rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_program (
  pSearch   jsonb default null,
  pFilter   jsonb default null,
  pLimit    integer default null,
  pOffSet   integer default null,
  pOrderBy  jsonb default null
) RETURNS   SETOF api.program
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'program', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_program_id ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve a program ID from a code or UUID string.
 * @param {text} pCode - Program code or UUID
 * @return {uuid} - Program ID
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_program_id (
  pCode     text
) RETURNS   uuid
AS $$
BEGIN
  IF length(pCode) = 36 AND SubStr(pCode, 15, 1) = '4' THEN
    RETURN pCode;
  END IF;

  RETURN GetProgram(pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
