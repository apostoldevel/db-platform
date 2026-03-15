--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddReportRoutineEvents ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddReportRoutineEvents (
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
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report routine created', 'EventReportRoutineCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report routine opened', 'EventReportRoutineOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report routine edited', 'EventReportRoutineEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report routine saved', 'EventReportRoutineSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report routine enabled', 'EventReportRoutineEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report routine disabled', 'EventReportRoutineDisable();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report routine will be deleted', 'EventReportRoutineDelete();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report routine restored', 'EventReportRoutineRestore();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Report routine will be dropped', 'EventReportRoutineDrop();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassReportRoutine ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassReportRoutine (
  pParent       uuid,
  pEntity       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uClass        uuid;
BEGIN
  -- Class
  uClass := AddClass(pParent, pEntity, 'report_routine', 'Report routine', false);

  PERFORM EditClassText(uClass, 'Функция отчёта', GetLocale('ru'));
  PERFORM EditClassText(uClass, 'Berichtsfunktion', GetLocale('de'));
  PERFORM EditClassText(uClass, 'Fonction de rapport', GetLocale('fr'));
  PERFORM EditClassText(uClass, 'Funzione di report', GetLocale('it'));
  PERFORM EditClassText(uClass, 'Función de informe', GetLocale('es'));

  -- Type
  PERFORM AddType(uClass, 'plpgsql.report_routine', 'PL/pgSQL', 'Report routine in PL/pgSQL.');
  PERFORM EditTypeText(GetType('plpgsql.report_routine'), 'PL/pgSQL', 'Функция отчёта на PL/pgSQL.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('plpgsql.report_routine'), 'PL/pgSQL', 'Berichtsfunktion in PL/pgSQL.', GetLocale('de'));
  PERFORM EditTypeText(GetType('plpgsql.report_routine'), 'PL/pgSQL', 'Fonction de rapport en PL/pgSQL.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('plpgsql.report_routine'), 'PL/pgSQL', 'Funzione di report in PL/pgSQL.', GetLocale('it'));
  PERFORM EditTypeText(GetType('plpgsql.report_routine'), 'PL/pgSQL', 'Función de informe en PL/pgSQL.', GetLocale('es'));

  -- Event
  PERFORM AddReportRoutineEvents(uClass);

  -- Method
  PERFORM AddDefaultMethods(uClass,
    ARRAY['Created', 'Opened', 'Closed', 'Deleted', 'Open', 'Close', 'Delete'],
    ARRAY['Создана', 'Открыта', 'Закрыта', 'Удалена', 'Открыть', 'Закрыть', 'Удалить']);

  RETURN uClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityReportRoutine ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityReportRoutine (
  pParent       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uEntity       uuid;
BEGIN
  -- Entity
  uEntity := AddEntity('report_routine', 'Report routine');

  PERFORM EditEntityText(uEntity, 'Функция отчёта', null, GetLocale('ru'));
  PERFORM EditEntityText(uEntity, 'Berichtsfunktion', null, GetLocale('de'));
  PERFORM EditEntityText(uEntity, 'Fonction de rapport', null, GetLocale('fr'));
  PERFORM EditEntityText(uEntity, 'Funzione di report', null, GetLocale('it'));
  PERFORM EditEntityText(uEntity, 'Función de informe', null, GetLocale('es'));

  -- Class
  PERFORM CreateClassReportRoutine(pParent, uEntity);

  -- API
  PERFORM RegisterRoute('report/routine', AddEndpoint('SELECT * FROM rest.report_routine($1, $2);'));

  RETURN uEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
