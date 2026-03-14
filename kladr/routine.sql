--------------------------------------------------------------------------------
-- AddAddressTree --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Insert a node into the hierarchical address tree.
 * @param {integer} pParent - Parent node ID (NULL for root)
 * @param {varchar} pCode - Composite KLADR address code (17 chars)
 * @param {varchar} pName - Display name of the address object
 * @param {varchar} pShort - Abbreviated type (e.g. "г", "ул")
 * @param {varchar} pIndex - Postal code
 * @param {integer} pLevel - Depth level in the tree hierarchy
 * @return {integer} - ID of the newly inserted node, or NULL on conflict
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AddAddressTree (
  pParent   integer,
  pCode     varchar,
  pName     varchar,
  pShort    varchar,
  pIndex    varchar,
  pLevel    integer
) RETURNS   integer
AS $$
DECLARE
  nId       integer;
BEGIN
  INSERT INTO db.address_tree (parent, code, name, short, index, level)
  VALUES (pParent, pCode, pName, pShort, pIndex, pLevel)
  ON CONFLICT (code) DO NOTHING
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddKladrToTree --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a KLADR entry by code and add it to the address tree.
 * @param {integer} pParent - Parent node ID in the address tree
 * @param {varchar} pCode - 11-char KLADR code (without actuality suffix)
 * @param {integer} pLevel - Depth level to assign in the tree
 * @return {integer} - ID of the inserted address tree node
 * @see AddAddressTree
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AddKladrToTree (
  pParent   integer,
  pCode     varchar,
  pLevel    integer
) RETURNS   integer
AS $$
DECLARE
  r         db.kladr%rowtype;
  nId       integer;
BEGIN
  SELECT * INTO r FROM db.kladr WHERE code = pCode || '00';
  nId := AddAddressTree(pParent, '01' || pCode || '0000', r.name, r.socr, r.index, pLevel);

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddStreetToTree -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a street entry by code and add it to the address tree.
 * @param {integer} pParent - Parent node ID in the address tree
 * @param {varchar} pCode - 15-char street code (without actuality suffix)
 * @param {integer} pLevel - Depth level to assign in the tree
 * @return {integer} - ID of the inserted address tree node
 * @see AddAddressTree
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AddStreetToTree (
  pParent   integer,
  pCode     varchar,
  pLevel    integer
) RETURNS   integer
AS $$
DECLARE
  r         db.street%rowtype;
  nId       integer;
BEGIN
  SELECT * INTO r FROM db.street WHERE code = pCode || '00';
  nId := AddAddressTree(pParent, '01' || pCode, r.name, r.socr, r.index, pLevel);

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CopyFromKladr ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Copy all KLADR and street entries for one region into the address tree.
 * @param {integer} pParent - Root node ID to attach the region subtree to
 * @param {varchar} pCode - Two-character region code (SS part of the KLADR code)
 * @return {void}
 * @see AddKladrToTree, AddStreetToTree
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CopyFromKladr (
  pParent   integer,
  pCode     varchar
) RETURNS   void
AS $$
DECLARE
  Rec       record;
  nPLev     integer;
  nCLev     integer;
  nIndex    integer;

  IdList    integer[];
  sList     text[];
BEGIN
  IdList[0] := pParent;

  FOR Rec IN (
    SELECT SubStr(code,  1, 2) as SS,
           SubStr(code,  3, 3) as RRR,
           SubStr(code,  6, 3) as GGG,
           SubStr(code,  9, 3) as PPP,
           '0000' as UUUU
      FROM db.kladr
     WHERE SubStr(code, 12, 2) = '00'
       AND SubStr(code, 1, 2) = pCode
     GROUP BY SubStr(code,  1, 2),
              SubStr(code,  3, 3),
              SubStr(code,  6, 3),
              SubStr(code,  9, 3)
     UNION ALL
    SELECT SubStr(code,  1, 2) as SS,
           SubStr(code,  3, 3) as RRR,
           SubStr(code,  6, 3) as GGG,
           SubStr(code,  9, 3) as PPP,
           SubStr(code, 12, 4) as UUUU
      FROM db.street
     WHERE SubStr(code, 16, 2) = '00'
       AND SubStr(code, 1, 2) = pCode
     GROUP BY SubStr(code,  1, 2),
              SubStr(code,  3, 3),
              SubStr(code,  6, 3),
              SubStr(code,  9, 3),
              SubStr(code, 12, 4)
     ORDER BY 1, 2, 3, 4, 5
  )
  LOOP
    nCLev := 0;

    sList[1] := Rec.SS;
    sList[2] := Rec.RRR;
    sList[3] := Rec.GGG;
    sList[4] := Rec.PPP;
    sList[5] := Rec.UUUU;

    FOR nIndex IN 1..5
    LOOP
      IF coalesce(to_number(nullif(sList[nIndex], ''), '9999'), 0) <> 0 THEN
        nPLev := nCLev;
        nCLev := nIndex;
      END IF;
    END LOOP;

    IF Rec.UUUU = '0000' THEN
      IdList[nCLev] := AddKladrToTree(IdList[nPLev], Rec.SS || Rec.RRR || Rec.GGG || Rec.PPP, nCLev);
    ELSE
      IdList[nCLev] := AddStreetToTree(IdList[nPLev], Rec.SS || Rec.RRR || Rec.GGG || Rec.PPP || Rec.UUUU, nCLev);
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- LoadFromKladr ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Build the full address tree from KLADR data for selected or all regions.
 * @param {text[]} pCodes - Array of two-character region codes to load; NULL loads all regions
 * @return {void}
 * @see CopyFromKladr
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION LoadFromKladr (
  pCodes    text[]
) RETURNS   void
AS $$
DECLARE
  Rec       record;
  nId       integer;
  i         integer;
BEGIN
  nId := AddAddressTree(null, '01000000000000000', 'Российская Федерация', null, null, 0);

  IF pCodes IS NOT NULL THEN
    FOR i IN 1..array_length(pCodes, 1)
    LOOP
      PERFORM CopyFromKladr(nId, pCodes[i]);
    END LOOP;
  ELSE
    -- All RF regions
    FOR Rec IN (
      SELECT SubStr(code, 1, 2) as SS
        FROM db.kladr
       WHERE SubStr(code, 11, 2) = '00'
         AND SubStr(code, 1, 2) <> '99'
       GROUP BY SubStr(code, 1, 2)
       ORDER BY 1
    )
    LOOP
      PERFORM CopyFromKladr(nId, Rec.SS);
    END LOOP;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAddressTreeId ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve an address tree node ID by its composite address code.
 * @param {varchar} pCode - Composite KLADR address code (17 chars)
 * @return {integer} - Address tree node ID, or NULL if not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetAddressTreeId (
  pCode     varchar
) RETURNS   integer
AS $$
DECLARE
  nId        integer;
BEGIN
  SELECT id INTO nId FROM db.address_tree WHERE code = pCode;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAddressTree --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the full address hierarchy as a text array by walking up from a given code.
 * @param {varchar} pCode - Composite KLADR address code (17 chars)
 * @return {text[]} - Array of address names indexed by level (0 = country, 1 = region, ...)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetAddressTree (
  pCode     varchar
) RETURNS   text[]
AS $$
DECLARE
  r         record;
  arResult  text[];
BEGIN
  FOR r IN (
    WITH RECURSIVE addr_tree(id, parent, name, level) AS (
      SELECT id, parent, name, level FROM db.address_tree WHERE code = pCode
       UNION ALL
      SELECT a.id, a.parent, a.name, a.level
        FROM db.address_tree a, addr_tree t
       WHERE a.id = t.parent
    )
    SELECT * FROM addr_tree ORDER BY level
  )
  LOOP
    arResult[r.level] := r.name;
  END LOOP;

  RETURN arResult;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAddressTreeString --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Format the full address path as a comma-separated string with optional abbreviations.
 * @param {varchar} pCode - Composite KLADR address code (17 chars)
 * @param {int} pShort - Abbreviation mode: 0 = none, 1 = prefix ("г. Москва"), 2 = suffix ("Москва г.")
 * @param {int} pLevel - Minimum tree level to include; 0 = start from country
 * @return {text} - Formatted address string, optionally prefixed with postal code
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetAddressTreeString (
  pCode     varchar,
  pShort    int DEFAULT 0,
  pLevel    int DEFAULT 0
) RETURNS   text
AS $$
DECLARE
  r         record;
  sIndex    text;
  sStr      text;
  sResult   text;
BEGIN
  FOR r IN (
    WITH RECURSIVE addr_tree(id, parent, index, name, short, level) AS (
      SELECT id, parent, index, name, short, level FROM db.address_tree WHERE code = pCode
       UNION ALL
      SELECT a.id, a.parent, a.index, a.name, a.short, a.level
        FROM db.address_tree a, addr_tree t
       WHERE a.id = t.parent
         AND a.level >= pLevel
    )
    SELECT * FROM addr_tree
  )
  LOOP
    IF pLevel = 0 and r.Level = 5 and r.Index IS NOT NULL THEN
      sIndex := r.Index;
    END IF;

    IF r.Short IS NULL THEN
      sStr := r.Name;
    ELSE
      IF pShort = 0 THEN
        sStr := r.Name;
      elsif pShort = 1 THEN
        sStr := r.Short || '. ' || r.Name;
      ELSE
        sStr := r.Name || ' ' || r.Short || '.';
      END IF;
    END IF;

    IF sResult IS NULL THEN
      sResult := sStr;
    ELSE
      sResult := sStr || ', ' || sResult;
    END IF;
  END LOOP;

  IF sIndex IS NOT NULL THEN
    sResult := sIndex || ', ' || sResult;
  END IF;

  RETURN sResult;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
