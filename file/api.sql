--------------------------------------------------------------------------------
-- FILE ------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.file --------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Point reads through the view see only what the session may read — the
-- verdict of CheckFileAccess per row, which is right for a lookup by id and
-- wrong for a scan (~85 µs a row). Lists and counts therefore do not go
-- through this view: api.list_file / api.count_file take the set-based pair
-- FileObject / FileAccess through api.sql('kernel', …), as every Object<X>
-- does (1.2.24, ОБ-14).

CREATE OR REPLACE VIEW api.file
AS
  SELECT t.* FROM FileTree t WHERE CheckFileAccess(t.id, B'100');

GRANT SELECT ON api.file TO administrator;

--------------------------------------------------------------------------------
-- api.file_data ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.file_data
AS
  SELECT t.* FROM FileData t WHERE CheckFileAccess(t.id, B'100');

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
 * @throws AccessDenied - When the file exists and the session holds no write bit on it (CheckFileAccess), or the entry lands under /public and the session may not publish (CheckFilePublish)
 * @see SetFile, NewFilePath, CheckFileAccess
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

  -- An existing file is written only with the write bit on it: the mask
  -- decides for a change of content, name or place as it does for reading.
  -- An id nothing carries stays what it was — SetFile's no-op — not a refusal.
  IF pId IS NOT NULL AND EXISTS (SELECT 1 FROM db.file WHERE id = pId) AND NOT CheckFileAccess(pId, B'010') THEN
    PERFORM AccessDenied();
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

  -- Through the gated view: a write the session may not read back (w without
  -- r, or pOwner someone else) succeeds and answers an empty set.
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
 *
 * Read access is checked as for an object (CheckFileAccess: owner, area
 * branch, mask). A file the current session may not read is returned as an
 * empty set, indistinguishable from a file that does not exist — the same
 * answer Object<X> views give, and the one FileServer already maps to 404.
 *
 * @param {uuid} pId - File identifier
 * @return {SETOF api.file_data} - File metadata and content; empty when not found or not readable
 * @see CheckFileAccess
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_file (
  pId       uuid
) RETURNS   SETOF api.file_data
AS $$
  SELECT * FROM api.file_data WHERE id = pId AND CheckFileAccess(pId, B'100');
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.decode_file_access ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Decode the effective access of a user to a file (read, write, execute).
 *
 * The contract for a module that serves a file it already holds — FileServer
 * with a copy in its disk cache: after api.authorize(session) it asks
 * `SELECT r FROM api.decode_file_access(api.get_file_id(name, path))` and
 * serves only on true. Same verdict api.get_file gives, without the bytes.
 *
 * @param {uuid} pId - File identifier
 * @param {uuid} pUserId - User identifier (defaults to current)
 * @return {record} - (r: read, w: write, x: execute) booleans; all false when the file does not exist
 * @see DecodeFileAccess, api.decode_object_access
 * @since 1.2.22
 */
CREATE OR REPLACE FUNCTION api.decode_file_access (
  pId       uuid,
  pUserId   uuid DEFAULT null,
  OUT r     boolean,
  OUT w     boolean,
  OUT x     boolean
) RETURNS   record
AS $$
  SELECT * FROM DecodeFileAccess(pId, coalesce(pUserId, current_userid()));
$$ LANGUAGE SQL STABLE
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
 *
 * A file that does not exist answers false, as before; one that exists is
 * deleted only with the write bit on it (CheckFileAccess) — the same bit
 * api.set_file asks for, since 1.2.24.
 *
 * @param {uuid} pId - File identifier to delete
 * @return {boolean} - TRUE if the file was deleted
 * @throws AccessDenied - When the file exists and the session holds no write bit on it
 * @see DeleteFile, CheckFileAccess
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.delete_file (
  pId       uuid
) RETURNS   boolean
AS $$
BEGIN
  PERFORM FROM db.file WHERE id = pId;
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF NOT CheckFileAccess(pId, B'010') THEN
    PERFORM AccessDenied();
  END IF;

  RETURN DeleteFile(pId);
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_file --------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Count file records matching search/filter criteria — those the session may read.
 *
 * Through the pair FileObject / FileAccess (file/view.sql,
 * entity/object/document/view.sql): api.sql('kernel', …) attaches the access
 * set at run time and skips it for the administrator, the dynamic model of
 * every Object<X>. Until 1.2.24 this counted the whole tree for any session.
 *
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
  RETURN QUERY EXECUTE api.sql('kernel', 'FileObject', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_file ---------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief List files with optional search, filtering, pagination, and sorting — those the session may read (see api.count_file).
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
  RETURN QUERY EXECUTE api.sql('kernel', 'FileObject', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
