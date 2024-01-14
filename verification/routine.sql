--------------------------------------------------------------------------------
-- AddVerificationCode ---------------------------------------------------------
--------------------------------------------------------------------------------

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
  -- получим дату значения в текущем диапозоне дат
  SELECT id, validFromDate, validToDate INTO uId, dtDateFrom, dtDateTo
    FROM db.verification_code
   WHERE type = pType
     AND userid = pUserId
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  IF coalesce(dtDateFrom, MINDATE()) = pDateFrom THEN
    -- обновим значение в текущем диапозоне дат
    UPDATE db.verification_code SET code = pCode
     WHERE type = pType
       AND userid = pUserId
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;
  ELSE
    -- обновим дату значения в текущем диапозоне дат
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
