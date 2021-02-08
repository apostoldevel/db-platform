--------------------------------------------------------------------------------
-- AddProvider -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddProvider (
  pType		    char,
  pCode		    varchar,
  pName		    varchar DEFAULT null
) RETURNS 	    numeric
AS $$
DECLARE
  nId		    numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO oauth2.provider (type, code, name) VALUES (pType, pCode, pName)
  RETURNING Id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetProvider --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetProvider (
  pCode		varchar
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM oauth2.provider WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetProviderCode ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetProviderCode (
  pId		numeric
) RETURNS 	text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM oauth2.provider WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetProviderType ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetProviderType (
  pId		numeric
) RETURNS 	char
AS $$
DECLARE
  vType		char;
BEGIN
  SELECT type INTO vType FROM oauth2.provider WHERE id = pId;
  RETURN vType;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddApplication --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddApplication (
  pType		    char,
  pCode		    varchar,
  pName		    varchar DEFAULT null
) RETURNS 	    numeric
AS $$
DECLARE
  nId		    numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO oauth2.application (type, code, name) VALUES (pType, pCode, pName)
  RETURNING Id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetApplication -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetApplication (
  pCode		varchar
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM oauth2.application WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetApplicationCode -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetApplicationCode (
  pId		numeric
) RETURNS 	text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM oauth2.application WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddIssuer -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddIssuer (
  pProvider     numeric,
  pCode		    varchar,
  pName		    varchar
) RETURNS 	    numeric
AS $$
DECLARE
  nId		    numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO oauth2.issuer (provider, code, name) VALUES (pProvider, pCode, pName)
  RETURNING Id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetIssuer ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetIssuer (
  pCode		varchar
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM oauth2.issuer WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetIssuerCode ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetIssuerCode (
  pId		numeric
) RETURNS 	text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM oauth2.issuer WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddAlgorithm ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddAlgorithm (
  pCode		    varchar,
  pName		    varchar
) RETURNS 	    numeric
AS $$
DECLARE
  nId		    numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO oauth2.algorithm (code, name) VALUES (pCode, pName)
  RETURNING Id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAlgorithm -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAlgorithm (
  pCode		varchar
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM oauth2.algorithm WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAlgorithmCode ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAlgorithmCode (
  pId		numeric
) RETURNS 	text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM oauth2.algorithm WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAlgorithmName ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAlgorithmName (
  pId		numeric
) RETURNS 	text
AS $$
DECLARE
  vName		text;
BEGIN
  SELECT name INTO vName FROM oauth2.algorithm WHERE id = pId;
  RETURN vName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateAudience --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateAudience (
  pProvider     numeric,
  pApplicaton   numeric,
  pAlgorithm    numeric,
  pCode         text,
  pSecret       text,
  pName         text DEFAULT null
) RETURNS       numeric
AS $$
DECLARE
  nId           numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO oauth2.audience (provider, application, algorithm, code, secret, hash, name)
  VALUES (pProvider, pApplicaton, pAlgorithm, pCode, pSecret, crypt(pSecret, gen_salt('md5')), pName)
  RETURNING Id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAudience --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAudience (
  pCode		varchar
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM oauth2.audience WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAudienceCode ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAudienceCode (
  pId		numeric
) RETURNS 	text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM oauth2.audience WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
