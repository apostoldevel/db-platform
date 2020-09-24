--------------------------------------------------------------------------------
-- VERIFICATION ----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.verification_code --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.verification_code (
    id              numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_CODE'),
    userId          numeric(12) NOT NULL,
    type            char NOT NULL,
    code            text NOT NULL,
    used            boolean NOT NULL DEFAULT false,
    validFromDate   timestamptz NOT NULL,
    validToDate     timestamptz NOT NULL,
    CONSTRAINT ch_verification_type CHECK (type IN ('M', 'P'))
);

COMMENT ON TABLE db.verification_code IS 'Код подтверждения.';

COMMENT ON COLUMN db.verification_code.id IS 'Идентификатор';
COMMENT ON COLUMN db.verification_code.userId IS 'Идентификатор учётной записи';
COMMENT ON COLUMN db.verification_code.type IS 'Тип: [M]ail - Почта; [P]hone - Телефон;';
COMMENT ON COLUMN db.verification_code.code IS 'Код';
COMMENT ON COLUMN db.verification_code.used IS 'Использован';
COMMENT ON COLUMN db.verification_code.validFromDate IS 'Дата начала действаия';
COMMENT ON COLUMN db.verification_code.validToDate IS 'Дата окончания действия';

CREATE UNIQUE INDEX ON db.verification_code (type, userId, validFromDate, validToDate);

CREATE OR REPLACE FUNCTION db.ft_verification_code_before()
RETURNS TRIGGER
AS $$
DECLARE
  delta   interval;
BEGIN
  IF (TG_OP = 'DELETE') THEN
    RETURN OLD;
  ELSIF (TG_OP = 'UPDATE') THEN
    IF OLD.type <> NEW.type THEN
      RAISE DEBUG 'Hacking alert: type (% <> %).', OLD.type, NEW.type;
      RETURN NULL;
    END IF;

    NEW.used = true;

    RETURN NEW;
  ELSIF (TG_OP = 'INSERT') THEN
    IF NEW.validFromDate IS NULL THEN
      NEW.validFromDate := Now();
    END IF;

    IF NEW.validToDate IS NULL THEN
      IF NEW.type = 'M' THEN
        delta := INTERVAL '1 day';
      ELSIF NEW.type = 'P' THEN
        delta := INTERVAL '5 min';
      END IF;

      NEW.validToDate := NEW.validFromDate + delta;
    END IF;

    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = db, kernel, pg_temp;

CREATE TRIGGER t_verification_code_before
  BEFORE INSERT OR UPDATE OR DELETE ON db.verification_code
  FOR EACH ROW EXECUTE PROCEDURE db.ft_verification_code_before();

--------------------------------------------------------------------------------
-- VIEW VerificationCode -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW VerificationCode
AS
  SELECT id,
         CASE type
         WHEN 'M' THEN 'email'
         WHEN 'P' THEN 'phone'
         END AS type,
         code, used, validfromdate, validtodate
    FROM db.verification_code WHERE userid = current_userid();

GRANT SELECT ON VerificationCode TO administrator;

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
  dtDateFrom 	timestamp;
  dtDateTo      timestamp;
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
    UPDATE db.verification_code SET validToDate = pDateFrom
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
  pCode		    text,
  pUserId       numeric DEFAULT current_userid()
) RETURNS       bool
AS $$
DECLARE
  passed        bool;
  utilized      bool;
BEGIN
  SELECT (code = pCode), used INTO passed, utilized
    FROM db.verification_code
   WHERE type = pType
     AND userId = pUserId
     AND validFromDate <= Now()
     AND validtoDate > Now();

  IF found THEN
    IF passed THEN
      IF utilized THEN
        PERFORM SetErrorMessage('Код подтверждения уже был использован.');
      ELSE
        PERFORM SetErrorMessage('Успешно.');
      END IF;
    ELSE
      PERFORM SetErrorMessage('Неверный код подтверждения.');
    END IF;
  ELSE
    PERFORM SetErrorMessage('Код подтверждения не найден.');
  END IF;

  RETURN coalesce(passed AND NOT utilized, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION TryVerificationCode ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION TryVerificationCode (
  pType         text,
  pCode		    text,
  pUserId       numeric DEFAULT current_userid()
) RETURNS       bool
AS $$
BEGIN
  IF CheckVerificationCode(pType, pCode, pUserId) THEN

    UPDATE db.verification_code SET used = true
     WHERE type = pType
       AND userId = pUserId
       AND validFromDate <= Now()
       AND validtoDate > Now();

    CASE pType
    WHEN 'M' THEN
      UPDATE db.profile SET email_verified = true WHERE userId = pUserId;
      PERFORM SetErrorMessage('Электронный адрес подтверждён.');
    WHEN 'P' THEN
      UPDATE db.profile SET phone_verified = true WHERE userId = pUserId;
      PERFORM SetErrorMessage('Номер телефона подтверждён.');
    ELSE
      PERFORM InvalidVerificationCodeType(pType);
    END CASE;

    RETURN true;
  END IF;

  RAISE EXCEPTION 'ERR-40000: %', GetErrorMessage();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewVerificationCode ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NewVerificationCode (
  pType         char,
  pCode		    text DEFAULT null,
  pUserId       numeric DEFAULT current_userid()
) RETURNS       numeric
AS $$
BEGIN
  CASE pType
  WHEN 'M' THEN
    pCode := coalesce(pCode, gen_random_uuid()::text);
    UPDATE db.profile SET email_verified = false WHERE userId = pUserId;
  WHEN 'P' THEN
    pCode := coalesce(pCode, random_between(100000, 999999)::text);
    UPDATE db.profile SET phone_verified = false WHERE userId = pUserId;
  ELSE
    PERFORM InvalidVerificationCodeType(pType);
  END CASE;

  RETURN AddVerificationCode(pUserId, pType, pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
