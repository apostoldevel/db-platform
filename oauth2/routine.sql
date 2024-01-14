--------------------------------------------------------------------------------
-- AddProvider -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddProvider (
  pType          char,
  pCode          text,
  pName          text DEFAULT null
) RETURNS        integer
AS $$
DECLARE
  nId            integer;
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
  pCode     text
) RETURNS   integer
AS $$
  SELECT id FROM oauth2.provider WHERE code = pCode;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetProviderCode ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetProviderCode (
  pId       integer
) RETURNS   text
AS $$
  SELECT code FROM oauth2.provider WHERE id = pId;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetProviderType ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetProviderType (
  pId       integer
) RETURNS   char
AS $$
  SELECT type FROM oauth2.provider WHERE id = pId;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddApplication --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddApplication (
  pType     char,
  pCode     text,
  pName     text DEFAULT null
) RETURNS   integer
AS $$
DECLARE
  nId       integer;
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
  pCode     text
) RETURNS   integer
AS $$
  SELECT id FROM oauth2.application WHERE code = pCode;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetApplicationCode -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetApplicationCode (
  pId       integer
) RETURNS   text
AS $$
  SELECT code FROM oauth2.application WHERE id = pId;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddIssuer -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddIssuer (
  pProvider     integer,
  pCode         text,
  pName         text
) RETURNS       integer
AS $$
DECLARE
  nId           integer;
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
  pCode     text
) RETURNS   integer
AS $$
  SELECT id FROM oauth2.issuer WHERE code = pCode;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetIssuerCode ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetIssuerCode (
  pId       integer
) RETURNS   text
AS $$
  SELECT code FROM oauth2.issuer WHERE id = pId;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddAlgorithm ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddAlgorithm (
  pCode     text,
  pName     text
) RETURNS   integer
AS $$
DECLARE
  nId		integer;
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
  pCode		text
) RETURNS 	integer
AS $$
  SELECT id FROM oauth2.algorithm WHERE code = pCode;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAlgorithmCode ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAlgorithmCode (
  pId		integer
) RETURNS 	text
AS $$
  SELECT code FROM oauth2.algorithm WHERE id = pId;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAlgorithmName ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAlgorithmName (
  pId		integer
) RETURNS 	text
AS $$
  SELECT name FROM oauth2.algorithm WHERE id = pId;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateAudience --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateAudience (
  pProvider     integer,
  pApplication	integer,
  pAlgorithm    integer,
  pCode         text,
  pSecret       text,
  pName         text DEFAULT null
) RETURNS       integer
AS $$
DECLARE
  nId           integer;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO oauth2.audience (provider, application, algorithm, code, secret, hash, name)
  VALUES (pProvider, pApplication, pAlgorithm, pCode, pSecret, crypt(pSecret, gen_salt('md5')), pName)
  RETURNING Id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAudience --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAudience (
  pCode		text
) RETURNS 	integer
AS $$
  SELECT id FROM oauth2.audience WHERE code = pCode;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAudienceCode ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAudienceCode (
  pId		integer
) RETURNS 	text
AS $$
  SELECT code FROM oauth2.audience WHERE id = pId;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
