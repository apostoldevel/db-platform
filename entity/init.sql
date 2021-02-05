--------------------------------------------------------------------------------
-- InitEntity ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION InitEntity()
RETURNS       void
AS $$
DECLARE
  nObject     numeric;
  nDocument   numeric;
  nReference  numeric;
BEGIN
  -- Объект

  PERFORM CreateEntityObject(null);

  nObject := GetClass('object');

    -- Документ

    PERFORM CreateEntityDocument(nObject);

    nDocument := GetClass('document');

      -- Адрес

      PERFORM CreateEntityAddress(nDocument);

      -- Клиент

      PERFORM CreateEntityClient(nDocument);

      -- Устройство

      PERFORM CreateEntityDevice(nDocument);

      -- Задание

      PERFORM CreateEntityJob(nDocument);

      -- Сообщение

      PERFORM CreateEntityMessage(nDocument);

    -- Справочник

    PERFORM CreateEntityReference(nObject);

    nReference := GetClass('reference');

      -- Агент

      PERFORM CreateEntityAgent(nReference);

      -- Календарь

      PERFORM CreateEntityCalendar(nReference);

      -- Категория

      PERFORM CreateEntityCategory(nReference);

      -- Модель

      PERFORM CreateEntityModel(nReference);

      -- Программа

      PERFORM CreateEntityProgram(nReference);

      -- Планировщик

      PERFORM CreateEntityScheduler(nReference);

      -- Производитель

      PERFORM CreateEntityVendor(nReference);

END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- TO DO -----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- DoConfirmEmail --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * DO: Подтверждает адрес электронной почты.
 * @param {numeric} pUserId - Идентификатор пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION DoConfirmEmail (
  pUserId		numeric
) RETURNS       void
AS $$
DECLARE
  nId			numeric;
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
 * @param {numeric} pUserId - Идентификатор пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION DoConfirmPhone (
  pUserId		numeric
) RETURNS       void
AS $$
DECLARE
  nId			numeric;
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
 * @param {numeric} pUserId - Идентификатор пользователя
 * @return {text[]}
 */
CREATE OR REPLACE FUNCTION DoFCMTokens (
  pUserId		numeric
) RETURNS       text[]
AS $$
DECLARE
  r				record;
  result		text[];
  nClient		numeric;
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
