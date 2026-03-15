--------------------------------------------------------------------------------
-- FILE ------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.file --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.file
AS
  SELECT * FROM FileTree;

GRANT SELECT ON api.file TO administrator;

--------------------------------------------------------------------------------
-- api.file_data ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.file_data
AS
  SELECT * FROM FileData;

GRANT SELECT ON api.file_data TO administrator;

--------------------------------------------------------------------------------
-- api.set_file ----------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Create or update a file, auto-creating intermediate directories from pPath.
 * @param {uuid} pId - File identifier (NULL to create; looked up by path+name if omitted)
 * @param {char} pType - Entry type: "-" file, "d" directory, "l" link, "s" storage
 * @param {int} pMask - Permission bitmask as integer (cast to bit(9) internally)
 * @param {uuid} pOwner - Owner user identifier
 * @param {uuid} pRoot - Root node identifier
 * @param {uuid} pParent - Parent directory identifier
 * @param {uuid} pLink - Link target identifier
 * @param {text} pName - File or directory name
 * @param {text} pPath - Directory path; missing segments are created automatically
 * @param {integer} pSize - Content size in bytes
 * @param {timestamptz} pDate - Modification timestamp
 * @param {text} pData - Base64-encoded binary content
 * @param {text} pMime - MIME type
 * @param {text} pText - Free-text description
 * @param {text} pHash - Content hash
 * @param {text} pDone - Success callback function name
 * @param {text} pFail - Failure callback function name
 * @return {SETOF api.file} - The created or updated file record
 * @see SetFile, NewFilePath
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_file (
  pId       uuid,
  pType     char,
  pMask     int,
  pOwner    uuid,
  pRoot     uuid,
  pParent   uuid,
  pLink     uuid,
  pName     text,
  pPath     text DEFAULT null,
  pSize     integer DEFAULT null,
  pDate     timestamptz DEFAULT null,
  pData     text DEFAULT null,
  pMime     text DEFAULT null,
  pText     text DEFAULT null,
  pHash     text DEFAULT null,
  pDone     text DEFAULT null,
  pFail     text DEFAULT null
) RETURNS   SETOF api.file
AS $$
DECLARE
  vRoot     text;
BEGIN
  pPath := NULLIF(NULLIF(pPath, '/'), '');

  IF pId IS NULL THEN
    SELECT id INTO pId FROM db.file WHERE path = NormalizeFilePath(pPath) AND name = pName;
  END IF;

  IF pPath IS NULL THEN
    SELECT path INTO pPath FROM db.file WHERE id = pId;
  END IF;

  IF pPath IS NOT NULL THEN
    vRoot := split_part(pPath, '/', 2);
    IF vRoot IS NOT NULL THEN
      pRoot := GetFile(null::uuid, vRoot);
      IF pRoot IS NULL THEN
        pRoot := NewFilePath(concat('/', vRoot));
      END IF;
    END IF;

    pParent := NewFilePath(pPath);
  END IF;

  pId := SetFile(pId, pType, pMask::bit(9), pOwner, pRoot, pParent, pLink, pName, pSize, pDate, decode(pData, 'base64'), pMime, pText, pHash, pDone, pFail);

  RETURN QUERY SELECT * FROM api.file WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_file ----------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Fetch a single file record with its binary data by identifier.
 * @param {uuid} pId - File identifier
 * @return {SETOF api.file_data} - File metadata and content
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_file (
  pId       uuid
) RETURNS   SETOF api.file_data
AS $$
  SELECT * FROM api.file_data WHERE id = pId;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_file_id -------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Resolve a file identifier by name and optional path.
 * @param {text} pName - File name (defaults to "index.html" when NULL)
 * @param {text} pPath - Directory path (normalised internally)
 * @return {uuid} - Matching file identifier, or NULL if not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_file_id (
  pName     text,
  pPath     text DEFAULT null
) RETURNS   uuid
AS $$
BEGIN
  RETURN GetFile(coalesce(NormalizeFileName(pName), 'index.html'), NormalizeFilePath(pPath));
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_file -------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Delete a file by identifier.
 * @param {uuid} pId - File identifier to delete
 * @return {boolean} - TRUE if the file was deleted
 * @see DeleteFile
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.delete_file (
  pId       uuid
) RETURNS   boolean
AS $$
BEGIN
  RETURN DeleteFile(pId);
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_file --------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Count file records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_file (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'file', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_file ---------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief List files with optional search, filtering, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions: [{"condition":"AND|OR","field":"<col>","compare":"EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN","value":"<val>"},...]
 * @param {jsonb} pFilter - Key-value filter: {"<column>":"<value>"}
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Array of column names to sort by
 * @return {SETOF api.file} - Matching file records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_file (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.file
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'file', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
