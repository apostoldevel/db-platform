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
  uId			uuid;
  uArea			uuid;
  uSave			uuid;
BEGIN
  SELECT c.id, d.area INTO uId, uArea
    FROM db.client c INNER JOIN db.document d ON c.document = d.id
   WHERE userid = pUserId;

  IF FOUND THEN
    uSave := current_area();

    PERFORM SetSessionArea(uArea);

    IF IsCreated(uId) THEN
      PERFORM DoEnable(uId);
	END IF;

    IF IsEnabled(uId) THEN
	  PERFORM ExecuteObjectAction(uId, GetAction('confirm'));
	END IF;

    PERFORM SetSessionArea(uSave);
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
  uId			uuid;
  uArea			uuid;
  uSave			uuid;
BEGIN
  SELECT c.id, d.area INTO uId, uArea
    FROM db.client c INNER JOIN db.document d ON c.document = d.id
   WHERE userid = pUserId;

  IF FOUND THEN
    uSave := current_area();

    PERFORM SetSessionArea(uArea);

    IF IsCreated(uId) THEN
      PERFORM DoEnable(uId);
	END IF;

    IF IsEnabled(uId) THEN
	  PERFORM ExecuteObjectAction(uId, GetAction('confirm'));
	END IF;

    PERFORM SetSessionArea(uSave);
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
  uClient		uuid;
BEGIN
  SELECT c.id INTO uClient FROM db.client c WHERE c.userid = pUserId;

  IF NOT FOUND THEN
    result := array_append(result, RegGetValueString('CURRENT_USER', 'CONFIG\Firebase\CloudMessaging', 'Token', pUserId));
  ELSE
	FOR r IN SELECT address FROM db.device WHERE client = uClient AND IsEnabled(id)
	LOOP
      result := array_append(result, r.address);
	END LOOP;
  END IF;

  RETURN result;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
