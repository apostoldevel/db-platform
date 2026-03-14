--------------------------------------------------------------------------------
-- AddProvider -----------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Register a new OAuth 2.0 provider.
 * @param {char} pType - Provider kind: "I" (internal) or "E" (external)
 * @param {text} pCode - Unique machine-readable identifier (e.g. "google")
 * @param {text} pName - Human-readable display name
 * @return {integer} - ID of the newly created provider
 * @throws AccessDenied - When the caller is not an administrator
 * @see GetProvider, GetProviderCode, GetProviderType
 * @since 1.0.0
 */
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

/**
 * @brief Look up a provider ID by its code.
 * @param {text} pCode - Unique provider code
 * @return {integer} - Provider ID, or NULL if not found
 * @see AddProvider, GetProviderCode, GetProviderType
 * @since 1.0.0
 */
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

/**
 * @brief Retrieve the code of a provider by its ID.
 * @param {integer} pId - Provider ID
 * @return {text} - Provider code, or NULL if not found
 * @see AddProvider, GetProvider, GetProviderType
 * @since 1.0.0
 */
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

/**
 * @brief Retrieve the type of a provider by its ID.
 * @param {integer} pId - Provider ID
 * @return {char} - Provider type: "I" (internal) or "E" (external), or NULL if not found
 * @see AddProvider, GetProvider, GetProviderCode
 * @since 1.0.0
 */
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

/**
 * @brief Register a new OAuth 2.0 client application.
 * @param {char} pType - Application kind: "S" (service), "W" (web), or "N" (native)
 * @param {text} pCode - Unique machine-readable identifier
 * @param {text} pName - Human-readable display name
 * @return {integer} - ID of the newly created application
 * @throws AccessDenied - When the caller is not an administrator
 * @see GetApplication, GetApplicationCode
 * @since 1.0.0
 */
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

/**
 * @brief Look up an application ID by its code.
 * @param {text} pCode - Unique application code
 * @return {integer} - Application ID, or NULL if not found
 * @see AddApplication, GetApplicationCode
 * @since 1.0.0
 */
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

/**
 * @brief Retrieve the code of an application by its ID.
 * @param {integer} pId - Application ID
 * @return {text} - Application code, or NULL if not found
 * @see AddApplication, GetApplication
 * @since 1.0.0
 */
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

/**
 * @brief Register a new JWT token issuer for a given provider.
 * @param {integer} pProvider - Owning OAuth 2.0 provider ID
 * @param {text} pCode - Unique issuer identifier (typically a URL)
 * @param {text} pName - Human-readable display name
 * @return {integer} - ID of the newly created issuer
 * @throws AccessDenied - When the caller is not an administrator
 * @see GetIssuer, GetIssuerCode
 * @since 1.0.0
 */
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

/**
 * @brief Look up an issuer ID by its code.
 * @param {text} pCode - Unique issuer code
 * @return {integer} - Issuer ID, or NULL if not found
 * @see AddIssuer, GetIssuerCode
 * @since 1.0.0
 */
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

/**
 * @brief Retrieve the code of an issuer by its ID.
 * @param {integer} pId - Issuer ID
 * @return {text} - Issuer code, or NULL if not found
 * @see AddIssuer, GetIssuer
 * @since 1.0.0
 */
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

/**
 * @brief Register a new hashing/signing algorithm.
 * @param {text} pCode - Short algorithm code (e.g. "HS256")
 * @param {text} pName - Algorithm name as recognized by pgcrypto
 * @return {integer} - ID of the newly created algorithm
 * @throws AccessDenied - When the caller is not an administrator
 * @see GetAlgorithm, GetAlgorithmCode, GetAlgorithmName
 * @since 1.0.0
 */
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

/**
 * @brief Look up an algorithm ID by its code.
 * @param {text} pCode - Algorithm code
 * @return {integer} - Algorithm ID, or NULL if not found
 * @see AddAlgorithm, GetAlgorithmCode, GetAlgorithmName
 * @since 1.0.0
 */
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

/**
 * @brief Retrieve the code of an algorithm by its ID.
 * @param {integer} pId - Algorithm ID
 * @return {text} - Algorithm code, or NULL if not found
 * @see AddAlgorithm, GetAlgorithm, GetAlgorithmName
 * @since 1.0.0
 */
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

/**
 * @brief Retrieve the pgcrypto-compatible name of an algorithm by its ID.
 * @param {integer} pId - Algorithm ID
 * @return {text} - Algorithm name, or NULL if not found
 * @see AddAlgorithm, GetAlgorithm, GetAlgorithmCode
 * @since 1.0.0
 */
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

/**
 * @brief Create a new OAuth 2.0 audience (client credentials record).
 * @param {integer} pProvider - Owning OAuth 2.0 provider ID
 * @param {integer} pApplication - Client application ID
 * @param {integer} pAlgorithm - Hashing algorithm ID used for the secret
 * @param {text} pCode - Client identifier (client_id)
 * @param {text} pSecret - Client secret in plain text; a bcrypt hash is stored alongside
 * @param {text} pName - Human-readable display name
 * @return {integer} - ID of the newly created audience
 * @throws AccessDenied - When the caller is not an administrator
 * @see GetAudience, GetAudienceCode
 * @since 1.0.0
 */
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

/**
 * @brief Look up an audience ID by its client code.
 * @param {text} pCode - Client identifier (client_id)
 * @return {integer} - Audience ID, or NULL if not found
 * @see CreateAudience, GetAudienceCode
 * @since 1.0.0
 */
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

/**
 * @brief Retrieve the client code of an audience by its ID.
 * @param {integer} pId - Audience ID
 * @return {text} - Client identifier (client_id), or NULL if not found
 * @see CreateAudience, GetAudience
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetAudienceCode (
  pId		integer
) RETURNS 	text
AS $$
  SELECT code FROM oauth2.audience WHERE id = pId;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
