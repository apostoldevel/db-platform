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

      -- Готовый отчёт

      PERFORM CreateEntityReportReady(uDocument);

    -- Справочник

    PERFORM CreateEntityReference(uObject);

    uReference := GetClass('reference');

      -- Агент

      PERFORM CreateEntityAgent(uReference);

      -- Форма

      PERFORM CreateEntityForm(uReference);

      -- Программа

      PERFORM CreateEntityProgram(uReference);

      -- Планировщик

      PERFORM CreateEntityScheduler(uReference);

	  -- Производитель

	  PERFORM CreateEntityVendor(uReference);

      -- Версия

      PERFORM CreateEntityVersion(uReference);

	  -- Дерево отчётов

	  PERFORM CreateEntityReportTree(uReference);

	  -- Форма отчёта

	  PERFORM CreateEntityReportForm(uReference);

	  -- Функция отчёта

	  PERFORM CreateEntityReportRoutine(uReference);

	  -- Отчёт

	  PERFORM CreateEntityReport(uReference);

END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
