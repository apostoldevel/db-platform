--------------------------------------------------------------------------------
-- VERIFICATION ----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.verification_code --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.verification_code (
    id              uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    userId          uuid NOT NULL REFERENCES db.user(id) ON DELETE CASCADE,
    type            char NOT NULL,
    code            text NOT NULL,
    used            timestamptz,
    validFromDate   timestamptz NOT NULL,
    validToDate     timestamptz NOT NULL,
    CHECK (type IN ('M', 'P'))
);

COMMENT ON TABLE db.verification_code IS 'Код подтверждения.';

COMMENT ON COLUMN db.verification_code.id IS 'Идентификатор';
COMMENT ON COLUMN db.verification_code.userId IS 'Идентификатор учётной записи';
COMMENT ON COLUMN db.verification_code.type IS 'Тип: [M]ail - Почта; [P]hone - Телефон;';
COMMENT ON COLUMN db.verification_code.code IS 'Код';
COMMENT ON COLUMN db.verification_code.used IS 'Использован';
COMMENT ON COLUMN db.verification_code.validFromDate IS 'Дата начала действия';
COMMENT ON COLUMN db.verification_code.validToDate IS 'Дата окончания действия';

--------------------------------------------------------------------------------

CREATE UNIQUE INDEX ON db.verification_code (type, userid, validFromDate, validToDate);
CREATE INDEX ON db.verification_code (type, code, validFromDate, validToDate);

--------------------------------------------------------------------------------

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

    IF OLD.code <> NEW.code THEN
      RAISE DEBUG 'Hacking alert: code (% <> %).', OLD.code, NEW.code;
      RETURN NULL;
    END IF;

    RETURN NEW;
  ELSIF (TG_OP = 'INSERT') THEN
    IF NEW.type = 'M' THEN
      NEW.type := 'M';
    END IF;

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

    IF NEW.code IS NULL THEN
      IF NEW.type = 'M' THEN
        NEW.code := gen_random_uuid()::text;
      ELSIF NEW.type = 'P' THEN
        NEW.code := random_between(100000, 999999)::text;
      ELSE
        PERFORM InvalidVerificationCodeType(NEW.type);
      END IF;
    END IF;

    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = db, kernel, public, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_verification_code_before
  BEFORE INSERT OR UPDATE OR DELETE ON db.verification_code
  FOR EACH ROW EXECUTE PROCEDURE db.ft_verification_code_before();
