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
