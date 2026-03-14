--------------------------------------------------------------------------------
-- VERIFICATION ----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.verification_code -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.verification_code
AS
  SELECT * FROM VerificationCode;

GRANT SELECT ON api.verification_code TO administrator;

--------------------------------------------------------------------------------
-- api.new_verification_code ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Generate a new verification code and return the record.
 * @param {char} pType - Channel type: M = email, P = phone
 * @param {text} pCode - Explicit code value (NULL to auto-generate)
 * @param {uuid} pUserId - User account identifier; defaults to current session user
 * @return {SETOF api.verification_code} - The newly created verification code row
 * @see NewVerificationCode
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.new_verification_code (
  pType         char,
  pCode         text DEFAULT null,
  pUserId       uuid DEFAULT current_userid()
) RETURNS       SETOF api.verification_code
AS $$
DECLARE
  uId           uuid;
BEGIN
  uId := NewVerificationCode(pUserId, pType, pCode);
  RETURN QUERY SELECT * FROM api.verification_code WHERE id = uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.confirm_verification_code -----------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Confirm a verification code and mark email/phone as verified.
 * @param {char} pType - Channel type: M = email, P = phone
 * @param {text} pCode - Code value to confirm
 * @param {bool} result - (OUT) TRUE on successful confirmation
 * @param {text} message - (OUT) Human-readable result message
 * @return {record} - {result, message}
 * @see ConfirmVerificationCode
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.confirm_verification_code (
  pType         char,
  pCode         text,
  OUT result    bool,
  OUT message   text
) RETURNS       record
AS $$
DECLARE
  uUserId       uuid;
  vOAuthSecret  text;
BEGIN
  uUserId := ConfirmVerificationCode(pType, pCode);

  result := uUserId IS NOT NULL;
  message := GetErrorMessage();

  IF result AND IsUserRole(GetGroup('system'), session_userid()) THEN
    SELECT a.secret INTO vOAuthSecret FROM oauth2.audience a WHERE a.code = session_username();
    IF FOUND THEN
      PERFORM SubstituteUser(GetUser('apibot'), vOAuthSecret);
      IF pType = 'M' THEN
        PERFORM DoConfirmEmail(uUserId);
      ELSIF pType = 'P' THEN
        PERFORM DoConfirmPhone(uUserId);
      END IF;
      PERFORM SubstituteUser(session_userid(), vOAuthSecret);
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_verification_code ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single verification code by identifier.
 * @param {uuid} pId - Verification code identifier
 * @return {SETOF api.verification_code} - Matching verification code row
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_verification_code (
  pId       uuid
) RETURNS   SETOF api.verification_code
AS $$
  SELECT * FROM api.verification_code WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_verification_code --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List verification codes with dynamic search, filter, and pagination.
 * @param {jsonb} pSearch - Search conditions: '[{"condition": "AND|OR", "field": "<col>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<val>"}]'
 * @param {jsonb} pFilter - Simple key-value filter: '{"<col>": "<val>"}'
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Array of column names to sort by
 * @return {SETOF api.verification_code} - Matching verification code rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_verification_code (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.verification_code
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'verification_code', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

