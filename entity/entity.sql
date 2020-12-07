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

      -- Задача

      PERFORM CreateEntityTask(nDocument);

    -- Справочник

    PERFORM CreateEntityReference(nObject);

    nReference := GetClass('reference');

      -- Агент

      PERFORM CreateEntityAgent(nReference);

      -- Календарь

      PERFORM CreateEntityCalendar(nReference);

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
 * @param {numeric} pId - Идентификатор кода подтверждения
 * @return {void}
 */
CREATE OR REPLACE FUNCTION DoConfirmEmail (
  pId		    numeric
) RETURNS       void
AS $$
DECLARE
  nUserId       numeric;
BEGIN
  SELECT userid INTO nUserId FROM db.verification_code WHERE id = pId;
  IF found THEN
    PERFORM ExecuteObjectAction(GetClientByUserId(nUserId), GetAction('confirm'));
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
 * @param {numeric} pUserId - Идентификатор клиента
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
    result := array_append(result, (RegGetValue(RegOpenKey('CURRENT_USER', 'CONFIG\Firebase\CloudMessaging', pUserId), 'Token')).vstring);
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
