--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddProgramEvents ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddProgramEvents (
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
      PERFORM AddEvent(pClass, uEvent, r.id, 'Program created', 'EventProgramCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Program opened', 'EventProgramOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Program edited', 'EventProgramEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Program saved', 'EventProgramSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Program enabled', 'EventProgramEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Program disabled', 'EventProgramDisable();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Program will be deleted', 'EventProgramDelete();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Program restored', 'EventProgramRestore();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Program will be dropped', 'EventProgramDrop();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassProgram ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassProgram (
  pParent       uuid,
  pEntity       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uClass        uuid;
BEGIN
  -- Класс
  uClass := AddClass(pParent, pEntity, 'program', 'Program', false);
  PERFORM EditClassText(uClass, 'Программа', null, GetLocale('ru'));
  PERFORM EditClassText(uClass, 'Programm', null, GetLocale('de'));
  PERFORM EditClassText(uClass, 'Programme', null, GetLocale('fr'));
  PERFORM EditClassText(uClass, 'Programma', null, GetLocale('it'));
  PERFORM EditClassText(uClass, 'Programa', null, GetLocale('es'));

  -- Тип
  PERFORM AddType(uClass, 'plpgsql.program', 'PL/pgSQL', 'PL/pgSQL program code.');
  PERFORM EditTypeText(GetType('plpgsql.program'), 'PL/pgSQL', 'Код программы на PL/pgSQL.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('plpgsql.program'), 'PL/pgSQL', 'PL/pgSQL-Programmcode.', GetLocale('de'));
  PERFORM EditTypeText(GetType('plpgsql.program'), 'PL/pgSQL', 'Code de programme PL/pgSQL.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('plpgsql.program'), 'PL/pgSQL', 'Codice programma PL/pgSQL.', GetLocale('it'));
  PERFORM EditTypeText(GetType('plpgsql.program'), 'PL/pgSQL', 'Código de programa PL/pgSQL.', GetLocale('es'));

  -- Событие
  PERFORM AddProgramEvents(uClass);

  -- Метод
  PERFORM AddDefaultMethods(uClass,
    ARRAY['Created', 'Opened', 'Closed', 'Deleted', 'Open', 'Close', 'Delete'],
    ARRAY['Создана', 'Открыта', 'Закрыта', 'Удалена', 'Открыть', 'Закрыть', 'Удалить']);

  RETURN uClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityProgram ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityProgram (
  pParent       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uEntity       uuid;
BEGIN
  -- Сущность
  uEntity := AddEntity('program', 'Program');
  PERFORM EditEntityText(uEntity, 'Программа', null, GetLocale('ru'));
  PERFORM EditEntityText(uEntity, 'Programm', null, GetLocale('de'));
  PERFORM EditEntityText(uEntity, 'Programme', null, GetLocale('fr'));
  PERFORM EditEntityText(uEntity, 'Programma', null, GetLocale('it'));
  PERFORM EditEntityText(uEntity, 'Programa', null, GetLocale('es'));

  -- Класс
  PERFORM CreateClassProgram(pParent, uEntity);

  -- API
  PERFORM RegisterRoute('program', AddEndpoint('SELECT * FROM rest.program($1, $2);'));

  RETURN uEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
