--------------------------------------------------------------------------------
-- FILE ------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- NormalizeFileName -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NormalizeFileName (
  pName		text,
  pLink     boolean DEFAULT false
) RETURNS	text
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
$$ LANGUAGE plpgsql IMMUTABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NormalizeFilePath -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NormalizeFilePath (
  pPath		text,
  pLink     boolean DEFAULT false
) RETURNS	text
AS $$
DECLARE
  i         int;
  arPath    text[];
BEGIN
  IF SubStr(pPath, 1, 1) = '.' OR StrPos(pPath, '..') != 0 THEN
	RAISE EXCEPTION 'ERR-40000: Invalid file path: %', pPath;
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
$$ LANGUAGE plpgsql IMMUTABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION CollectFilePath ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CollectFilePath (
  pId		uuid
) RETURNS	text
AS $$
DECLARE
  r		    record;
  vPath		text;
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
-- NewFile ---------------------------------------------------------------------
--------------------------------------------------------------------------------

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
  pHash     text DEFAULT null
) RETURNS	uuid
AS $$
DECLARE
  uId       uuid;
  nLevel	integer;
BEGIN
  nLevel := 0;
  pParent := coalesce(pParent, pRoot);

  IF pParent IS NOT NULL THEN
    SELECT level + 1 INTO nLevel FROM db.file WHERE id = pParent;
  END IF;

  INSERT INTO db.file (id, type, mask, owner, root, parent, link, level, path, name, size, date, data, mime, text, hash)
  VALUES (coalesce(pId, gen_kernel_uuid('8')), coalesce(pType, '-'), coalesce(pMask, B'111110100'), coalesce(pOwner, current_userid()), pRoot, pParent, pLink, nLevel, CollectFilePath(pParent), pName, coalesce(pSize, 0), coalesce(pDate, Now()), pData, pMime, pText, pHash)
  RETURNING id INTO uId;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddFile ---------------------------------------------------------------------
--------------------------------------------------------------------------------

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
  pHash     text DEFAULT null
) RETURNS	uuid
AS $$
BEGIN
  RETURN NewFile(null, pRoot, pParent, pName, pType, pOwner, pMask, pLink, pSize, pDate, pData, pMime, pText, pHash);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditFile --------------------------------------------------------------------
--------------------------------------------------------------------------------

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
  pHash     text DEFAULT null
) RETURNS	bool
AS $$
BEGIN
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
        hash = CheckNull(coalesce(pHash, hash, ''))
  WHERE id = pId;

  RETURN FOUND;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetFile ---------------------------------------------------------------------
--------------------------------------------------------------------------------

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
  pHash     text DEFAULT null
) RETURNS	uuid
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := NewFile(pId, pRoot, pParent, pName, pType, pOwner, pMask, pLink, pSize, pDate, pData, pMime, pText, pHash);
  ELSE
    PERFORM EditFile(pId, pRoot, pParent, pName, pOwner, pMask, pLink, pSize, pDate, pData, pMime, pText, pHash);
  END IF;

  RETURN pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteFile ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteFile (
  pId       uuid
) RETURNS	boolean
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

CREATE OR REPLACE FUNCTION DeleteFiles (
  pId		uuid
) RETURNS	void
AS $$
DECLARE
  r		    record;
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

CREATE OR REPLACE FUNCTION GetFile (
  pParent		uuid,
  pName			text
) RETURNS		uuid
AS $$
DECLARE
  uId			uuid;
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

CREATE OR REPLACE FUNCTION GetFile (
  pName     text,
  pPath     text
) RETURNS	uuid
AS $$
  SELECT id FROM db.file WHERE path = pPath AND name = pName;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION NewFilePath --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NewFilePath (
  pPath			text,
  pRoot         uuid DEFAULT null
) RETURNS		uuid
AS $$
DECLARE
  uId			uuid;
  uParent		uuid;

  arPath		text[];
  i				integer;
BEGIN
  IF pPath IS NOT NULL THEN
    arPath := path_to_array(pPath);
    FOR i IN 1..array_length(arPath, 1)
    LOOP
      uParent := coalesce(uId, pRoot);
      uId := GetFile(uParent, arPath[i]);

      IF uId IS NULL THEN
        uId := AddFile(pRoot, uParent, arPath[i], 'd');
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