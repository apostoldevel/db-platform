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

COMMENT ON TABLE db.verification_code IS 'One-time verification code for email/phone confirmation.';

COMMENT ON COLUMN db.verification_code.id IS 'Verification code identifier (UUID).';
COMMENT ON COLUMN db.verification_code.userId IS 'User account this code belongs to.';
COMMENT ON COLUMN db.verification_code.type IS 'Channel type: M = email, P = phone.';
COMMENT ON COLUMN db.verification_code.code IS 'The verification code value (UUID for email, 6-digit number for phone).';
COMMENT ON COLUMN db.verification_code.used IS 'Timestamp when the code was consumed (NULL if unused).';
COMMENT ON COLUMN db.verification_code.validFromDate IS 'Start of the validity window.';
COMMENT ON COLUMN db.verification_code.validToDate IS 'End of the validity window (email: +1 day, phone: +5 min).';

--------------------------------------------------------------------------------

CREATE UNIQUE INDEX ON db.verification_code (type, userid, validFromDate, validToDate);
CREATE INDEX ON db.verification_code (type, code, validFromDate, validToDate);

--------------------------------------------------------------------------------

/**
 * @brief Enforce immutability of type/code on UPDATE, auto-generate code and TTL on INSERT.
 * @throws InvalidVerificationCodeType - When the type is not M or P
 * @since 1.0.0
 */
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
