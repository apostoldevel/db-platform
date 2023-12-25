--------------------------------------------------------------------------------
-- AddAddressTree --------------------------------------------------------------
--------------------------------------------------------------------------------

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
    -- Для всех регионов РФ
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

CREATE OR REPLACE FUNCTION GetAddressTreeId (
  pCode    	varchar
) RETURNS   integer
AS $$
DECLARE
  nId		integer;
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

CREATE OR REPLACE FUNCTION GetAddressTree (
  pCode		varchar
) RETURNS   text[]
AS $$
DECLARE
  r         record;
  arResult	text[];
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

CREATE OR REPLACE FUNCTION GetAddressTreeString (
  pCode		varchar,       -- Код из справочника адресов
  pShort	int DEFAULT 0, -- Сокращение: 0 - нет; 1 - слева; 2 - справа
  pLevel	int DEFAULT 0  -- Ограничение уровня вложенности
) RETURNS   text
AS $$
DECLARE
  r         record;
  sIndex	text;
  sStr		text;
  sResult	text;
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
