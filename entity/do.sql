--------------------------------------------------------------------------------
-- DO --------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- DoConfirmEmail --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * DO: Подтверждает адрес электронной почты.
 * @param {uuid} pUserId - Идентификатор пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION DoConfirmEmail (
  pUserId		uuid
) RETURNS       void
AS $$
DECLARE
  nId			uuid;
BEGIN
  SELECT id INTO nId FROM db.client WHERE userid = pUserId;
  IF found AND IsEnabled(nId) THEN
	PERFORM ExecuteObjectAction(nId, GetAction('confirm'));
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DoConfirmPhone --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * DO: Подтверждает номер телефона.
 * @param {uuid} pUserId - Идентификатор пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION DoConfirmPhone (
  pUserId		uuid
) RETURNS       void
AS $$
DECLARE
  nId			uuid;
BEGIN
  SELECT id INTO nId FROM db.client WHERE userid = pUserId;
  IF found AND IsEnabled(nId) THEN
	PERFORM ExecuteObjectAction(nId, GetAction('confirm'));
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DoFCMTokens -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * DO: Возвращает токены FCM.
 * @param {uuid} pUserId - Идентификатор пользователя
 * @return {text[]}
 */
CREATE OR REPLACE FUNCTION DoFCMTokens (
  pUserId		uuid
) RETURNS       text[]
AS $$
DECLARE
  r				record;
  result		text[];
  nClient		uuid;
BEGIN
  SELECT c.id INTO nClient FROM db.client c WHERE c.userid = pUserId;

  IF NOT FOUND THEN
    result := array_append(result, RegGetValueString('CURRENT_USER', 'CONFIG\Firebase\CloudMessaging', 'Token', pUserId));
  ELSE
	FOR r IN SELECT address FROM db.device WHERE client = nClient
	LOOP
      result := array_append(result, r.address);
	END LOOP;
  END IF;

  RETURN result;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
