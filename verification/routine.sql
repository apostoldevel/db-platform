--------------------------------------------------------------------------------
-- AddVerificationCode ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddVerificationCode (
  pUserId       numeric,
  pType         char,
  pCode		    text,
  pDateFrom     timestamptz DEFAULT Now(),
  pDateTo       timestamptz DEFAULT null
) RETURNS       numeric
AS $$
DECLARE
  nId           numeric;
  dtDateFrom 	timestamptz;
  dtDateTo      timestamptz;
BEGIN
  -- получим дату значения в текущем диапозоне дат
  SELECT id, validFromDate, validToDate INTO nId, dtDateFrom, dtDateTo
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
    UPDATE db.verification_code SET used = true, validToDate = pDateFrom
     WHERE type = pType
       AND userid = pUserId
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;

    INSERT INTO db.verification_code (type, userid, code, validFromDate, validtodate)
    VALUES (pType, pUserId, pCode, pDateFrom, pDateTo)
    RETURNING id INTO nId;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewVerificationCode ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NewVerificationCode (
  pUserId       numeric,
  pType         char DEFAULT 'M',
  pCode		    text DEFAULT null
) RETURNS       numeric
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
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetVerificationCode ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetVerificationCode (
  pId           numeric
) RETURNS 	    text
AS $$
DECLARE
  vCode		    text;
BEGIN
  SELECT code INTO vCode FROM db.verification_code WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION CheckVerificationCode ----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckVerificationCode (
  pType         text,
  pCode		    text
) RETURNS       numeric
AS $$
DECLARE
  nId			numeric;
  nUserId		numeric;
  utilized      bool;
BEGIN
  SELECT id, userid, used INTO nId, nUserId, utilized
    FROM db.verification_code
   WHERE type = pType
     AND code = pCode
     AND validFromDate <= Now()
     AND validtoDate > Now();

  IF found THEN
    IF utilized THEN
      PERFORM SetErrorMessage('Код подтверждения уже был использован.');
    ELSE
      UPDATE db.verification_code SET used = true WHERE id = nId;
      PERFORM SetErrorMessage('Успешно.');
      RETURN nUserId;
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
  pCode		    text
) RETURNS       numeric
AS $$
DECLARE
  nUserId       numeric;
BEGIN
  nUserId := CheckVerificationCode(pType, pCode);

  IF nUserId IS NOT NULL THEN
    CASE pType
    WHEN 'M' THEN
      UPDATE db.profile SET email_verified = true WHERE userId = nUserId;
      PERFORM SetErrorMessage('Электронный адрес подтверждён.');
    WHEN 'P' THEN
      UPDATE db.profile SET phone_verified = true WHERE userId = nUserId;
      PERFORM SetErrorMessage('Номер телефона подтверждён.');
    ELSE
      PERFORM InvalidVerificationCodeType(pType);
    END CASE;
  END IF;

  RETURN nUserId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
