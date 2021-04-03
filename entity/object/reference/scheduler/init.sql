--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddSchedulerEvents ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddSchedulerEvents (
  pClass        uuid
)
RETURNS         void
AS $$
DECLARE
  r             record;

  uParent       uuid;
  uEvent        uuid;
BEGIN
  uParent := GetEventType('parent');
  uEvent := GetEventType('event');

  FOR r IN SELECT * FROM Action
  LOOP

    IF r.code = 'create' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Планировщик создан', 'EventSchedulerCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Планировщик открыт', 'EventSchedulerOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Планировщик изменён', 'EventSchedulerEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Планировщик сохранён', 'EventSchedulerSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Планировщик доступен', 'EventSchedulerEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Планировщик недоступен', 'EventSchedulerDisable();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Планировщик будет удалён', 'EventSchedulerDelete();');
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Планировщик восстановлен', 'EventSchedulerRestore();');
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Планировщик будет уничтожен', 'EventSchedulerDrop();');
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
    END IF;

  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassScheduler --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassScheduler (
  pParent       uuid,
  pEntity       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uClass        uuid;
BEGIN
  -- Класс
  uClass := AddClass(pParent, pEntity, 'scheduler', 'Планировщик', false);

  -- Тип
  PERFORM AddType(uClass, 'job.scheduler', 'Планировщик', 'Планировщик задач.');

  -- Событие
  PERFORM AddSchedulerEvents(uClass);

  -- Метод
  PERFORM AddDefaultMethods(uClass);

  RETURN uClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityScheduler -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityScheduler (
  pParent       uuid
)
RETURNS         uuid
AS $$
DECLARE
  nEntity       uuid;
BEGIN
  -- Сущность
  nEntity := AddEntity('scheduler', 'Планировщик');

  -- Класс
  PERFORM CreateClassScheduler(pParent, nEntity);

  -- API
  PERFORM RegisterRoute('scheduler', AddEndpoint('SELECT * FROM rest.scheduler($1, $2);'));

  RETURN nEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
