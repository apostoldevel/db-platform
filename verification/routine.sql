--------------------------------------------------------------------------------
-- AddVerificationCode ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Add or replace a verification code within the current validity window.
 * @param {uuid} pUserId - User account identifier
 * @param {char} pType - Channel type: M = email, P = phone
 * @param {text} pCode - Verification code value
 * @param {timestamptz} pDateFrom - Validity start; defaults to now
 * @param {timestamptz} pDateTo - Validity end; defaults to type-specific TTL
 * @return {uuid} - Verification code identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AddVerificationCode (
  pUserId       uuid,
  pType         char,
  pCode         text,
  pDateFrom     timestamptz DEFAULT Now(),
  pDateTo       timestamptz DEFAULT null
) RETURNS       uuid
AS $$
DECLARE
  uId           uuid;
  dtDateFrom    timestamptz;
  dtDateTo      timestamptz;
BEGIN
  SELECT id, validFromDate, validToDate INTO uId, dtDateFrom, dtDateTo
    FROM db.verification_code
   WHERE type = pType
     AND userid = pUserId
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  IF coalesce(dtDateFrom, MINDATE()) = pDateFrom THEN
    UPDATE db.verification_code SET code = pCode
     WHERE type = pType
       AND userid = pUserId
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;
  ELSE
    -- Expire the previous code and insert a new one
    UPDATE db.verification_code SET used = Now(), validToDate = pDateFrom
     WHERE type = pType
       AND userid = pUserId
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;

    INSERT INTO db.verification_code (type, userid, code, validFromDate, validtodate)
    VALUES (pType, pUserId, pCode, pDateFrom, pDateTo)
    RETURNING id INTO uId;
  END IF;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewVerificationCode ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Generate a new verification code (auto-creates code if not supplied).
 * @param {uuid} pUserId - User account identifier
 * @param {char} pType - Channel type: M = email (UUID code), P = phone (6-digit code)
 * @param {text} pCode - Explicit code value (NULL to auto-generate)
 * @return {uuid} - Verification code identifier
 * @throws InvalidVerificationCodeType - When pType is not M or P
 * @see AddVerificationCode
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION NewVerificationCode (
  pUserId       uuid,
  pType         char DEFAULT 'M',
  pCode         text DEFAULT null
) RETURNS       uuid
AS $$
BEGIN
  CASE pType
  WHEN 'M' THEN
    pCode := coalesce(pCode, gen_random_uuid()::text);
  WHEN 'P' THEN
    pCode := coalesce(pCode, random_between(100000, 999999)::text);
  ELSE
    PERFORM InvalidVerificationCodeType(pType);
  END CASE;

  RETURN AddVerificationCode(pUserId, pType, pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------
-- GetVerificationCode ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up the code value for a verification record.
 * @param {uuid} pId - Verification code identifier
 * @return {text} - The code string, or NULL if not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetVerificationCode (
  pId           uuid
) RETURNS       text
AS $$
  SELECT code FROM db.verification_code WHERE id = pId;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION CheckVerificationCode ----------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Validate a verification code: mark it as used if valid and unused.
 * @param {text} pType - Channel type: M or P
 * @param {text} pCode - Code value to validate
 * @return {uuid} - User identifier on success, NULL on failure (message set via SetErrorMessage)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckVerificationCode (
  pType         text,
  pCode         text
) RETURNS       uuid
AS $$
DECLARE
  uId           uuid;
  uUserId       uuid;
  utilized      bool;
BEGIN
  SELECT id, userid, used IS NOT NULL INTO uId, uUserId, utilized
    FROM db.verification_code
   WHERE type = pType
     AND code = pCode
     AND validFromDate <= Now()
     AND validToDate > Now();

  IF FOUND THEN
    IF utilized THEN
      PERFORM SetErrorMessage('Код подтверждения уже был использован.');
    ELSE
      UPDATE db.verification_code SET used = Now() WHERE id = uId;
      PERFORM SetErrorMessage('Успешно.');
      RETURN uUserId;
    END IF;
  ELSE
    PERFORM SetErrorMessage('Код подтверждения не найден.');
  END IF;

  RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION ConfirmVerificationCode --------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Confirm a verification code and mark the user's email or phone as verified.
 * @param {text} pType - Channel type: M = email, P = phone
 * @param {text} pCode - Code value to confirm
 * @return {uuid} - User identifier on success, NULL on failure
 * @throws InvalidVerificationCodeType - When pType is not M or P
 * @see CheckVerificationCode
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ConfirmVerificationCode (
  pType         text,
  pCode         text
) RETURNS       uuid
AS $$
DECLARE
  uUserId       uuid;
BEGIN
  uUserId := CheckVerificationCode(pType, pCode);

  IF uUserId IS NOT NULL THEN
    CASE pType
    WHEN 'M' THEN
      UPDATE db.profile SET email_verified = true WHERE userId = uUserId;
      PERFORM SetErrorMessage('Электронный адрес подтверждён.');
    WHEN 'P' THEN
      UPDATE db.profile SET phone_verified = true WHERE userId = uUserId;
      PERFORM SetErrorMessage('Номер телефона подтверждён.');
    ELSE
      PERFORM InvalidVerificationCodeType(pType);
    END CASE;
  END IF;

  RETURN uUserId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
