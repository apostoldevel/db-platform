--------------------------------------------------------------------------------
-- InitPlatform ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION InitPlatform()
RETURNS       void
AS $$
DECLARE
  nObject     numeric;
  nDocument   numeric;
  nReference  numeric;
BEGIN
  -- Документооборот
  PERFORM InitWorkFlow();

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
