--------------------------------------------------------------------------------
-- InitEntity ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION InitEntity()
RETURNS       void
AS $$
DECLARE
  uObject     uuid;
  uDocument   uuid;
  uReference  uuid;
BEGIN
  -- Объект

  PERFORM CreateEntityObject(null);

  uObject := GetClass('object');

    -- Документ

    PERFORM CreateEntityDocument(uObject);

    uDocument := GetClass('document');

      -- Задание

      PERFORM CreateEntityJob(uDocument);

      -- Сообщение

      PERFORM CreateEntityMessage(uDocument);

    -- Справочник

    PERFORM CreateEntityReference(uObject);

    uReference := GetClass('reference');

      -- Агент

      PERFORM CreateEntityAgent(uReference);

      -- Программа

      PERFORM CreateEntityProgram(uReference);

      -- Планировщик

      PERFORM CreateEntityScheduler(uReference);

	  -- Производитель

	  PERFORM CreateEntityVendor(uReference);

      -- Версия

      PERFORM CreateEntityVersion(uReference);

END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
