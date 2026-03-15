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
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Scheduler created', 'EventSchedulerCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Scheduler opened', 'EventSchedulerOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Scheduler edited', 'EventSchedulerEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Scheduler saved', 'EventSchedulerSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Scheduler enabled', 'EventSchedulerEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Scheduler disabled', 'EventSchedulerDisable();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Scheduler will be deleted', 'EventSchedulerDelete();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Scheduler restored', 'EventSchedulerRestore();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Scheduler will be dropped', 'EventSchedulerDrop();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
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
  uClass := AddClass(pParent, pEntity, 'scheduler', 'Scheduler', false);
  PERFORM EditClassText(uClass, 'Планировщик', null, GetLocale('ru'));
  PERFORM EditClassText(uClass, 'Planer', null, GetLocale('de'));
  PERFORM EditClassText(uClass, 'Planificateur', null, GetLocale('fr'));
  PERFORM EditClassText(uClass, 'Pianificatore', null, GetLocale('it'));
  PERFORM EditClassText(uClass, 'Planificador', null, GetLocale('es'));

  -- Тип
  PERFORM AddType(uClass, 'job.scheduler', 'Scheduler', 'Job scheduler.');
  PERFORM EditTypeText(GetType('job.scheduler'), 'Планировщик', 'Планировщик задач.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('job.scheduler'), 'Planer', 'Aufgabenplaner.', GetLocale('de'));
  PERFORM EditTypeText(GetType('job.scheduler'), 'Planificateur', 'Planificateur de tâches.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('job.scheduler'), 'Pianificatore', 'Pianificatore attività.', GetLocale('it'));
  PERFORM EditTypeText(GetType('job.scheduler'), 'Planificador', 'Planificador de tareas.', GetLocale('es'));

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
  uEntity       uuid;
BEGIN
  -- Сущность
  uEntity := AddEntity('scheduler', 'Scheduler');
  PERFORM EditEntityText(uEntity, 'Планировщик', null, GetLocale('ru'));
  PERFORM EditEntityText(uEntity, 'Planer', null, GetLocale('de'));
  PERFORM EditEntityText(uEntity, 'Planificateur', null, GetLocale('fr'));
  PERFORM EditEntityText(uEntity, 'Pianificatore', null, GetLocale('it'));
  PERFORM EditEntityText(uEntity, 'Planificador', null, GetLocale('es'));

  -- Класс
  PERFORM CreateClassScheduler(pParent, uEntity);

  -- API
  PERFORM RegisterRoute('scheduler', AddEndpoint('SELECT * FROM rest.scheduler($1, $2);'));

  RETURN uEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
