--------------------------------------------------------------------------------
-- InitEntity ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION InitEntity()
RETURNS       void
AS $$
DECLARE
  nObject     uuid;
  nDocument   uuid;
  nReference  uuid;
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
