--------------------------------------------------------------------------------
-- FILE ------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- NormalizeFileName -----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Validate and optionally URL-encode a file name.
 * @param {text} pName - File name to normalise (must not contain "/")
 * @param {boolean} pLink - When true, return the URL-encoded form
 * @return {text} - Normalised (or URL-encoded) file name
 * @throws ERR-40000 - When the name contains a slash character
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION NormalizeFileName (
  pName     text,
  pLink     boolean DEFAULT false
) RETURNS   text
AS $$
BEGIN
  IF StrPos(pName, '/') != 0 THEN
    RAISE EXCEPTION 'ERR-40000: Invalid file name: %', pName;
  END IF;

  IF pLink THEN
    RETURN URLEncode(pName);
  END IF;

  RETURN pName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NormalizeFilePath -----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Validate and optionally URL-encode a file path.
 * @param {text} pPath - File path to normalise (must not start with "." or contain "..")
 * @param {boolean} pLink - When true, URL-encode each path segment
 * @return {text} - Normalised absolute path ending with "/"
 * @throws ERR-40000 - When the path is relative or contains ".."
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION NormalizeFilePath (
  pPath     text,
  pLink     boolean DEFAULT false
) RETURNS   text
AS $$
DECLARE
  i         int;
  arPath    text[];
BEGIN
  IF SubStr(pPath, 1, 1) = '.' OR StrPos(pPath, '..') != 0 THEN
    RAISE EXCEPTION 'ERR-40000: Invalid file path: %', pPath;
  END IF;

  IF pPath = '~/' THEN
    RETURN '/';
  END IF;

  arPath := path_to_array(pPath);
  IF arPath IS NULL THEN
    RETURN '/';
  END IF;

  pPath := '/';

  FOR i IN 1..array_length(arPath, 1)
  LOOP
    IF pLink THEN
      pPath := concat(pPath, URLEncode(arPath[i]), '/');
    ELSE
      pPath := concat(pPath, arPath[i], '/');
    END IF;
  END LOOP;

  RETURN pPath;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION CollectFilePath ----------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Build the full path for a node by walking the parent chain recursively.
 * @param {uuid} pId - File or directory identifier to start from
 * @return {text} - Absolute path assembled from ancestor names (e.g. "/root/sub/")
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CollectFilePath (
  pId        uuid
) RETURNS    text
AS $$
DECLARE
  r          record;
  vPath      text;
BEGIN
  FOR r IN
    WITH RECURSIVE tree(id, parent, name) AS (
      SELECT id, parent, name FROM db.file WHERE id = pId
    UNION ALL
      SELECT p.id, p.parent, p.name
        FROM db.file p INNER JOIN tree t ON p.id = t.parent
    )
    SELECT name FROM tree
  LOOP
    IF vPath IS NULL THEN
      vPath := r.name;
    ELSE
     vPath := r.name || '/' || vPath;
    END IF;
  END LOOP;

  RETURN coalesce('/' || vPath, '/');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckFilePublish ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Check whether the current session may write an entry under the "public" root.
 *
 * Everything under /public is served without a session — by the path, not by
 * the mask (CheckFileAccess grants the read bit under that root, PutFileToS3
 * uploads it with a public-read ACL). Writing there is therefore publishing to
 * the world, and until 1.2.24 any session could: api.set_file with a path
 * under /public created the directories and the file, and a missing /public
 * root was created under the caller, who then owned it. One call, and a tenant
 * publishes what it likes.
 *
 * The right to publish is the platform's own notion, not a special case: the
 * w bit of the DIRECTORY the entry lands in, as CheckFileAccess reads it —
 * the kernel, an administrator and the system group pass by its bypasses,
 * everyone else by the directory's mask. Delegation goes by directories: an
 * administrator creates /public/<tenant>/ and hands it over (owner, or the
 * group bit for the tenant's branch), and that tenant publishes there and
 * nowhere else; opening the root itself (other:w) would hand publishing to
 * every valid session, which is what this gate stops. The root — an entry
 * named "public" with no parent — is created and changed by the bypasses
 * alone, so that it is never owned by whoever asked first. Anything outside
 * that root passes: this is a gate on one name, the rest of the tree is
 * governed by the masks as before.
 *
 * @param {uuid} pRoot - Root of the entry being written (NULL when the entry is a root)
 * @param {uuid} pParent - Parent directory (NULL for a root)
 * @param {text} pName - Name of the entry
 * @return {boolean} - TRUE if the write is allowed
 * @see CheckFileAccess, NewFile, EditFile
 * @since 1.2.24
 */
CREATE OR REPLACE FUNCTION CheckFilePublish (
  pRoot     uuid,
  pParent   uuid,
  pName     text
) RETURNS   boolean
AS $$
DECLARE
  uRoot     uuid;
BEGIN
  IF pParent IS NULL THEN
    IF pName IS DISTINCT FROM 'public' THEN
      RETURN true;
    END IF;

    RETURN session_user = 'kernel' OR IsAdmin() OR IsSystem();
  END IF;

  uRoot := pRoot;
  IF uRoot IS NULL THEN
    SELECT root INTO uRoot FROM db.file WHERE id = pParent;
  END IF;

  PERFORM FROM db.file WHERE id = uRoot AND parent IS NULL AND name = 'public';
  IF NOT FOUND THEN
    RETURN true;
  END IF;

  RETURN CheckFileAccess(pParent, B'010');
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewFile ---------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Insert a new file record into the virtual file system.
 * @param {uuid} pId - Explicit identifier (NULL to auto-generate)
 * @param {uuid} pRoot - Root node of the file tree
 * @param {uuid} pParent - Parent directory identifier
 * @param {text} pName - File or directory name
 * @param {char} pType - Entry type: "-" file, "d" directory, "l" link, "s" storage
 * @param {uuid} pOwner - Owner user identifier (defaults to current user)
 * @param {bit(9)} pMask - UNIX-style permission bitmask
 * @param {uuid} pLink - Target file identifier for link entries
 * @param {integer} pSize - Content size in bytes
 * @param {timestamptz} pDate - Modification timestamp
 * @param {bytea} pData - Binary content
 * @param {text} pMime - MIME type
 * @param {text} pText - Free-text description
 * @param {text} pHash - Content hash (SHA-256)
 * @param {text} pDone - Success callback function name (schema.func)
 * @param {text} pFail - Failure callback function name (schema.func)
 * @return {uuid} - Identifier of the newly created file record
 * @throws AccessDenied - When the entry lands under the "public" root and the session may not publish (CheckFilePublish)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION NewFile (
  pId       uuid,
  pRoot     uuid,
  pParent   uuid,
  pName     text,
  pType     char DEFAULT null,
  pOwner    uuid DEFAULT null,
  pMask     bit(9) DEFAULT null,
  pLink     uuid DEFAULT null,
  pSize     integer DEFAULT null,
  pDate     timestamptz DEFAULT null,
  pData     bytea DEFAULT null,
  pMime     text DEFAULT null,
  pText     text DEFAULT null,
  pHash     text DEFAULT null,
  pDone     text DEFAULT null,
  pFail     text DEFAULT null
) RETURNS   uuid
AS $$
DECLARE
  uId       uuid;
  nLevel    integer;
BEGIN
  nLevel := 0;
  pParent := coalesce(pParent, pRoot);

  IF pParent IS NOT NULL THEN
    SELECT level + 1 INTO nLevel FROM db.file WHERE id = pParent;
  END IF;

  IF NOT CheckFilePublish(pRoot, pParent, pName) THEN
    PERFORM AccessDenied();
  END IF;

  INSERT INTO db.file (id, type, mask, owner, root, parent, link, level, path, name, size, date, data, mime, text, hash, done, fail)
  VALUES (coalesce(pId, gen_kernel_uuid('8')), coalesce(pType, '-'), coalesce(pMask, B'111110000'), coalesce(pOwner, current_userid()), pRoot, pParent, pLink, nLevel, CollectFilePath(pParent), pName, coalesce(pSize, 0), coalesce(pDate, Now()), pData, pMime, pText, pHash, pDone, pFail)
  RETURNING id INTO uId;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddFile ---------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Add a file after validating callback function references.
 * @param {uuid} pRoot - Root node of the file tree
 * @param {uuid} pParent - Parent directory identifier
 * @param {text} pName - File or directory name
 * @param {char} pType - Entry type: "-" file, "d" directory, "l" link, "s" storage
 * @param {uuid} pOwner - Owner user identifier
 * @param {bit(9)} pMask - UNIX-style permission bitmask
 * @param {uuid} pLink - Target file identifier for link entries
 * @param {integer} pSize - Content size in bytes
 * @param {timestamptz} pDate - Modification timestamp
 * @param {bytea} pData - Binary content
 * @param {text} pMime - MIME type
 * @param {text} pText - Free-text description
 * @param {text} pHash - Content hash (SHA-256)
 * @param {text} pDone - Success callback function name (schema.func)
 * @param {text} pFail - Failure callback function name (schema.func)
 * @return {uuid} - Identifier of the newly created file record
 * @throws EXCEPTION - When a specified callback function does not exist
 * @see NewFile
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AddFile (
  pRoot     uuid,
  pParent   uuid,
  pName     text,
  pType     char DEFAULT null,
  pOwner    uuid DEFAULT null,
  pMask     bit(9) DEFAULT null,
  pLink     uuid DEFAULT null,
  pSize     integer DEFAULT null,
  pDate     timestamptz DEFAULT null,
  pData     bytea DEFAULT null,
  pMime     text DEFAULT null,
  pText     text DEFAULT null,
  pHash     text DEFAULT null,
  pDone     text DEFAULT null,
  pFail     text DEFAULT null
) RETURNS   uuid
AS $$
BEGIN
  IF pDone IS NOT NULL THEN
    PERFORM FROM pg_namespace n INNER JOIN pg_proc p ON n.oid = p.pronamespace WHERE n.nspname = split_part(pDone, '.', 1) AND p.proname = split_part(pDone, '.', 2);
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Not found function: %', pDone;
    END IF;
  END IF;

  IF pFail IS NOT NULL THEN
    PERFORM FROM pg_namespace n INNER JOIN pg_proc p ON n.oid = p.pronamespace WHERE n.nspname = split_part(pFail, '.', 1) AND p.proname = split_part(pFail, '.', 2);
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Not found function: %', pFail;
    END IF;
  END IF;

  RETURN NewFile(null, pRoot, pParent, pName, pType, pOwner, pMask, pLink, pSize, pDate, pData, pMime, pText, pHash, pDone, pFail);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditFile --------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Update an existing file record (NULL parameters keep current values).
 * @param {uuid} pId - File identifier to update
 * @param {uuid} pRoot - New root node
 * @param {uuid} pParent - New parent directory
 * @param {text} pName - New file name
 * @param {uuid} pOwner - New owner
 * @param {bit(9)} pMask - New permission bitmask
 * @param {uuid} pLink - New link target
 * @param {integer} pSize - New content size
 * @param {timestamptz} pDate - New modification timestamp
 * @param {bytea} pData - New binary content
 * @param {text} pMime - New MIME type
 * @param {text} pText - New description
 * @param {text} pHash - New content hash
 * @param {text} pDone - New success callback
 * @param {text} pFail - New failure callback
 * @return {bool} - TRUE if a row was updated
 * @throws AccessDenied - When the entry would land under the "public" root and the session may not publish (CheckFilePublish)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditFile (
  pId       uuid,
  pRoot     uuid,
  pParent   uuid,
  pName     text,
  pOwner    uuid DEFAULT null,
  pMask     bit(9) DEFAULT null,
  pLink     uuid DEFAULT null,
  pSize     integer DEFAULT null,
  pDate     timestamptz DEFAULT null,
  pData     bytea DEFAULT null,
  pMime     text DEFAULT null,
  pText     text DEFAULT null,
  pHash     text DEFAULT null,
  pDone     text DEFAULT null,
  pFail     text DEFAULT null
) RETURNS   bool
AS $$
DECLARE
  r         record;
BEGIN
  -- An update is a write at the destination: the entry's root, parent and
  -- name after it decide whether the content lands under /public — a move
  -- into the root as much as new bytes for a file already there.
  SELECT root, parent, name INTO r FROM db.file WHERE id = pId;
  IF FOUND AND NOT CheckFilePublish(coalesce(pRoot, r.root), coalesce(pParent, r.parent), coalesce(pName, r.name)) THEN
    PERFORM AccessDenied();
  END IF;

  UPDATE db.file
    SET root = coalesce(pRoot, root),
        parent = coalesce(pParent, parent),
        name = coalesce(pName, name),
        owner = coalesce(pOwner, owner),
        mask = coalesce(pMask, mask),
        link = coalesce(pLink, link),
        size = coalesce(pSize, size),
        date = coalesce(pDate, date),
        data = coalesce(pData, data),
        mime = CheckNull(coalesce(pMime, mime, '')),
        text = CheckNull(coalesce(pText, text, '')),
        hash = CheckNull(coalesce(pHash, hash, '')),
        done = CheckNull(coalesce(pDone, done, '')),
        fail = CheckNull(coalesce(pFail, fail, ''))
  WHERE id = pId;

  RETURN FOUND;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetFile ---------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Create or update a file record (upsert by identifier).
 * @param {uuid} pId - File identifier (NULL to create, non-NULL to update)
 * @param {char} pType - Entry type
 * @param {bit(9)} pMask - Permission bitmask
 * @param {uuid} pOwner - Owner user identifier
 * @param {uuid} pRoot - Root node
 * @param {uuid} pParent - Parent directory
 * @param {uuid} pLink - Link target
 * @param {text} pName - File name
 * @param {integer} pSize - Content size in bytes
 * @param {timestamptz} pDate - Modification timestamp
 * @param {bytea} pData - Binary content
 * @param {text} pMime - MIME type
 * @param {text} pText - Free-text description
 * @param {text} pHash - Content hash
 * @param {text} pDone - Success callback
 * @param {text} pFail - Failure callback
 * @return {uuid} - File identifier (newly created or existing)
 * @see AddFile, EditFile
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetFile (
  pId       uuid,
  pType     char,
  pMask     bit(9),
  pOwner    uuid,
  pRoot     uuid,
  pParent   uuid,
  pLink     uuid,
  pName     text,
  pSize     integer DEFAULT null,
  pDate     timestamptz DEFAULT null,
  pData     bytea DEFAULT null,
  pMime     text DEFAULT null,
  pText     text DEFAULT null,
  pHash     text DEFAULT null,
  pDone     text DEFAULT null,
  pFail     text DEFAULT null
) RETURNS   uuid
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := AddFile(pRoot, pParent, pName, pType, pOwner, pMask, pLink, pSize, pDate, pData, pMime, pText, pHash, pDone, pFail);
  ELSE
    PERFORM EditFile(pId, pRoot, pParent, pName, pOwner, pMask, pLink, pSize, pDate, pData, pMime, pText, pHash, pDone, pFail);
  END IF;

  RETURN pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteFile ------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Delete a single file record by identifier.
 * @param {uuid} pId - File identifier to delete
 * @return {boolean} - TRUE if a row was deleted
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteFile (
  pId       uuid
) RETURNS   boolean
AS $$
BEGIN
  DELETE FROM db.file WHERE id = pId;
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteFiles --------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Recursively delete a directory and all its descendants.
 * @param {uuid} pId - Root directory identifier to remove
 * @return {void}
 * @see DeleteFile
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteFiles (
  pId        uuid
) RETURNS    void
AS $$
DECLARE
  r          record;
BEGIN
  FOR r IN SELECT id FROM db.file WHERE parent = pId
  LOOP
    PERFORM DeleteFiles(r.id);
  END LOOP;

  PERFORM DeleteFile(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetFile ------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Look up a file identifier by parent directory and name.
 * @param {uuid} pParent - Parent directory identifier (NULL for root-level lookup)
 * @param {text} pName - File or directory name
 * @return {uuid} - Matching file identifier, or NULL if not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetFile (
  pParent        uuid,
  pName          text
) RETURNS        uuid
AS $$
DECLARE
  uId            uuid;
BEGIN
  IF pParent IS NULL THEN
    SELECT id INTO uId FROM db.file WHERE parent IS NULL AND name = pName;
  ELSE
    SELECT id INTO uId FROM db.file WHERE parent = pParent AND name = pName;
  END IF;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetFile ---------------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Look up a file identifier by name and absolute path.
 * @param {text} pName - File name
 * @param {text} pPath - Absolute directory path
 * @return {uuid} - Matching file identifier, or NULL if not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetFile (
  pName     text,
  pPath     text
) RETURNS   uuid
AS $$
  SELECT id FROM db.file WHERE path = pPath AND name = pName;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetFileMask -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch the 3-bit segment of a file's POSIX-style mask that applies to a user.
 *
 * The mirror of GetObjectMask for db.file: {owner:rwx}{group:rwx}{other:rwx}.
 * The owner takes the first segment. The "group" of a file is the subtree of
 * the area tree under the owner: the user takes the second segment when the
 * user is a member of an area the owner belongs to, or of one above it
 * (IsMemberArea walks up from the owner's area), or when the user sees the
 * area of a document the file is attached to (db.object_file →
 * db.document.area) and that document's owner is the file's owner — the
 * relation the platform itself creates in NewObjectFile. Everyone else takes
 * the third segment.
 *
 * Area membership is the platform's own notion of a tenant: users of one
 * tenant sit under one area, and tenants never share a branch below the
 * areas every account passes through. Those shared areas — root, system,
 * guest — are left out of the owner's memberships on purpose: the service
 * accounts live in root, and a project may park a self-registered user in
 * guest before it assigns a tenant; neither makes two tenants one group.
 * The walk goes one way for the same reason: "the owner is above the user"
 * would make a file re-owned to the platform administrator (DeleteUser does
 * that) readable by every tenant, and an attachment made by a stranger
 * (api.set_object_file with a foreign pFile) is not the owner's document. So
 * a valid session of another tenant lands on the "other" segment, which
 * NewFile leaves empty.
 *
 * @param {uuid} pId - File identifier
 * @param {uuid} pUserId - User identifier (defaults to current)
 * @return {bit} - 3-bit mask segment, NULL when the file does not exist
 * @see GetObjectMask, IsMemberArea
 * @since 1.2.22
 */
CREATE OR REPLACE FUNCTION GetFileMask (
  pId        uuid,
  pUserId    uuid DEFAULT current_userid()
) RETURNS    bit
AS $$
BEGIN
  -- plpgsql, not SQL, and not for style: a SQL function's body is checked when
  -- it is created, and db.object_file / db.document belong to the entity
  -- module, which create.psql loads AFTER this one. As a SQL function this
  -- installed on every existing base (the tables were there) and failed on
  -- every fresh one (1.2.22, found by the first --init after it).
  RETURN (
    SELECT CASE
           WHEN pUserId = f.owner THEN SubString(f.mask FROM 1 FOR 3)
           WHEN EXISTS (
                  SELECT 1
                    FROM db.member_area m INNER JOIN db.area a ON a.id = m.area
                   WHERE m.member = f.owner
                     AND a.type NOT IN (GetAreaType('root'), GetAreaType('system'), GetAreaType('guest'))
                     AND IsMemberArea(m.area, pUserId)
                   UNION ALL
                  SELECT 1
                    FROM db.object_file t INNER JOIN db.object   o ON o.id = t.object AND o.owner = f.owner
                                          INNER JOIN db.document d ON d.id = t.object
                   WHERE t.file = f.id
                     AND IsMemberArea(d.area, pUserId)
                ) THEN SubString(f.mask FROM 4 FOR 3)
           ELSE SubString(f.mask FROM 7 FOR 3)
           END
      FROM db.file f
     WHERE f.id = pId
  );
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckFileAccess -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Check whether a user has a specific access permission on a file.
 *
 * The mirror of CheckObjectAccess for db.file. Answers false — never NULL —
 * when there is no user or no such file: a permission check must refuse when
 * it cannot tell who is asking (see IsAdmin).
 *
 * Bypasses, each with a precedent in the platform: the kernel connection
 * (installation and DDL, as in chmodo); administrators and the system group
 * (the OAuth2 service accounts — the bot sessions of FileServer and PGFile
 * read files on behalf of the platform, not of a user); and read access to
 * anything under the "public" root, which PutFileToS3 already publishes with
 * a public-read ACL.
 *
 * @param {uuid} pId - File identifier
 * @param {bit} pMask - Required permission bits (B'100' for read)
 * @param {uuid} pUserId - User identifier (defaults to current)
 * @return {boolean} - TRUE if the user has the required permission
 * @see CheckObjectAccess, GetFileMask
 * @since 1.2.22
 */
CREATE OR REPLACE FUNCTION CheckFileAccess (
  pId        uuid,
  pMask      bit,
  pUserId    uuid DEFAULT current_userid()
) RETURNS    boolean
AS $$
DECLARE
  bMask      bit(3);
BEGIN
  IF pId IS NULL OR pMask IS NULL THEN
    RETURN false;
  END IF;

  IF session_user = 'kernel' THEN
    RETURN true;
  END IF;

  IF pUserId IS NULL THEN
    RETURN false;
  END IF;

  IF IsAdmin(pUserId) OR IsSystem(pUserId) THEN
    RETURN true;
  END IF;

  bMask := GetFileMask(pId, pUserId);

  IF bMask IS NULL THEN
    RETURN false;
  END IF;

  IF EXISTS (SELECT 1 FROM db.file f INNER JOIN db.file r ON r.id = f.root WHERE f.id = pId AND r.parent IS NULL AND r.name = 'public') THEN
    bMask := bMask | B'100';
  END IF;

  RETURN coalesce(bMask & pMask = pMask, false);
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DecodeFileAccess ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Decode the effective access of a user to a file into boolean flags.
 *
 * Unlike DecodeObjectAccess this is the effective answer, not the raw mask
 * segment: each flag is CheckFileAccess for that bit, bypasses and the
 * "public" root included. It exists for a caller that already holds the
 * bytes and only needs the verdict — FileServer serving a cached copy from
 * disk must ask exactly this, or the cache becomes a way around the barrier.
 *
 * @param {uuid} pId - File identifier
 * @param {uuid} pUserId - User identifier (defaults to current)
 * @return {record} - (r: read, w: write, x: execute) booleans
 * @see CheckFileAccess
 * @since 1.2.22
 */
CREATE OR REPLACE FUNCTION DecodeFileAccess (
  pId        uuid,
  pUserId    uuid DEFAULT current_userid(),
  OUT r      boolean,
  OUT w      boolean,
  OUT x      boolean
) RETURNS    record
AS $$
BEGIN
  r := CheckFileAccess(pId, B'100', pUserId);
  w := CheckFileAccess(pId, B'010', pUserId);
  x := CheckFileAccess(pId, B'001', pUserId);
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION NewFilePath --------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Ensure all directories along a path exist, creating missing ones.
 * @param {text} pPath - Desired directory path (e.g. "/images/avatars/")
 * @param {uuid} pRoot - Root node to start from (auto-detected if NULL)
 * @param {uuid} pOwner - Owner for newly created directories
 * @return {uuid} - Identifier of the deepest (leaf) directory
 * @see AddFile
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION NewFilePath (
  pPath         text,
  pRoot         uuid DEFAULT null,
  pOwner        uuid DEFAULT null
) RETURNS       uuid
AS $$
DECLARE
  uId			uuid;
  uParent		uuid;

  arPath		text[];
  i				integer;
BEGIN
  IF pPath IS NOT NULL THEN
    arPath := path_to_array(pPath);

    IF arPath IS NULL THEN
      RETURN uId;
    END IF;

    FOR i IN 1..array_length(arPath, 1)
    LOOP
      uParent := coalesce(uId, pRoot);
      uId := GetFile(uParent, arPath[i]);

      IF uId IS NULL THEN
        uId := AddFile(pRoot, uParent, arPath[i], 'd', coalesce(pOwner, current_userid()));
      END IF;

      IF pRoot IS NULL THEN
        pRoot := uId;
      END IF;
    END LOOP;
  END IF;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION FindFile -----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Resolve a full file path to its identifier by traversing each segment.
 * @param {text} pName - Full path including file name (e.g. "/docs/readme.txt")
 * @return {uuid} - File identifier, or NULL if any segment is missing
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION FindFile (
  pName			text
) RETURNS		uuid
AS $$
DECLARE
  uId			uuid;
  arPath		text[];
  i				integer;
BEGIN
  IF pName IS NOT NULL THEN
    arPath := path_to_array(pName);
    FOR i IN 1..array_length(arPath, 1)
    LOOP
      uId := GetFile(uId, arPath[i]);
    END LOOP;
  END IF;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION QueryFile ----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Resolve a path as far as possible, returning the deepest existing node.
 * @param {text} pFile - Full path to query (e.g. "/docs/missing/file.txt")
 * @return {uuid} - Identifier of the deepest node found along the path
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION QueryFile (
  pFile			text
) RETURNS		uuid
AS $$
DECLARE
  uId			uuid;
  uParent		uuid;
  arPath		text[];
  Index			integer;
BEGIN
  IF pFile IS NOT NULL THEN
    arPath := path_to_array(pFile);
    IF array_length(arPath, 1) > 0 THEN
      Index := 1;
      uId := GetFile(uParent, arPath[Index]);
	  WHILE uId IS NOT NULL
	  LOOP
	    uParent := uId;
        Index := Index + 1;
        uId := GetFile(uParent, arPath[Index]);
	  END LOOP;
	END IF;
  END IF;

  RETURN coalesce(uId, uParent);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PutFileToS3 -----------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Upload a file to an S3-compatible storage bucket using AWS Signature V4.
 * @param {uuid} pId - File identifier to upload
 * @param {text} pRegion - AWS region override (defaults to registry value)
 * @param {text} pDone - HTTP callback on successful upload
 * @param {text} pFail - HTTP callback on failed upload
 * @param {text} pType - Request type label for the HTTP fetch subsystem
 * @param {text} pMessage - Optional message payload for the HTTP fetch subsystem
 * @return {uuid} - HTTP request identifier returned by http.fetch
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION PutFileToS3 (
  pId               uuid,
  pRegion           text DEFAULT null,
  pDone             text DEFAULT null,
  pFail             text DEFAULT null,
  pType             text DEFAULT null,
  pMessage          text DEFAULT null
) RETURNS           uuid
AS $$
DECLARE
  r                 record;
  f                 record;

  currentDate       timestamp;

  vEndpoint         text;
  vAccessKey        text;
  vSecretKey        text;

  vURI              text;
  vRoot             text;
  vDate             text;
  vHost             text;
  vHash             text;
  vMethod           text;
  vAuthorization    text;
  vCanonicalHeaders text;
  vSignedHeaders    text;
  vSignature        text;

  content           bytea;
  headers           jsonb;
BEGIN
  SELECT type, root, path, name, data, mime, hash INTO f FROM db.file WHERE id = pId;

  IF NOT FOUND THEN
	RETURN null;
  END IF;

  IF f.type = 'd' OR f.type = 's' THEN
	RETURN null;
  END IF;

  SELECT name INTO vRoot FROM db.file WHERE id = f.root;

  currentDate := current_timestamp AT TIME ZONE 'UTC';

  pRegion := coalesce(pRegion, RegGetValueString('CURRENT_CONFIG', 'CONFIG\S3', 'Region', current_userid()));

  vEndpoint := RegGetValueString('CURRENT_CONFIG', 'CONFIG\S3', 'Endpoint', current_userid());
  vAccessKey := RegGetValueString('CURRENT_CONFIG', 'CONFIG\S3', 'AccessKey', current_userid());
  vSecretKey := RegGetValueString('CURRENT_CONFIG', 'CONFIG\S3', 'SecretKey', current_userid());

  vMethod := 'PUT';
  vURI := f.path || f.name;
  vDate := to_char(currentDate, 'YYYYMMDD"T"HH24MISS"Z"');
  vHost := get_hostname_from_uri(vEndpoint);
  vHash := f.hash;

  IF f.type = '-' THEN
    content := f.data;
    vHash := coalesce(vHash, encode(digest(f.data, 'sha256'), 'hex'));
  END IF;

  headers := jsonb_build_object('Content-Type', coalesce(f.mime, 'image/png'), 'host', vHost, 'x-amz-content-sha256', vHash, 'x-amz-date', vDate, 'x-amz-storage-class', 'STANDARD');

  IF vRoot = 'public' THEN
    headers := headers || jsonb_build_object('x-amz-acl', 'public-read');
  END IF;

  FOR r IN SELECT * FROM jsonb_each_text(headers) ORDER BY key
  LOOP
    vCanonicalHeaders := coalesce(vCanonicalHeaders, '') || lower(r.key) || ':' || Trim(r.value) || E'\n';
  END LOOP;

  FOR r IN SELECT * FROM jsonb_each_text(headers) ORDER BY key
  LOOP
    IF vSignedHeaders IS NULL THEN
      vSignedHeaders := lower(r.key);
	ELSE
      vSignedHeaders := vSignedHeaders || ';' || lower(r.key);
	END IF;
  END LOOP;

  IF f.type = 'l' THEN
    headers := headers || jsonb_build_object('x-attache-file', convert_from(f.data, 'utf8'));
  END IF;

  headers := headers - 'host';

  vSignature := generate_aws_signature(vMethod, vURI, null, vCanonicalHeaders, vSignedHeaders, vHash, vSecretKey, pRegion, currentDate);

  vAuthorization := format('AWS4-HMAC-SHA256 Credential=%s/%s/%s/s3/aws4_request, SignedHeaders=%s, Signature=%s', vAccessKey, to_char(currentDate, 'YYYYMMDD'), pRegion, vSignedHeaders, vSignature);

  headers := headers || jsonb_build_object('Authorization', vAuthorization);

  RETURN http.fetch(vEndpoint || vURI, vMethod, headers, content, pDone, pFail, vHost, pRegion, 'put', pMessage, pType, jsonb_build_object('id', pId, 'endpoint', vEndpoint, 'region', pRegion));
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
