--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddProgramEvents ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddProgramEvents (
  pClass        numeric
)
RETURNS         void
AS $$
DECLARE
  r             record;

  nParent       numeric;
  nEvent        numeric;
BEGIN
  nParent := GetEventType('parent');
  nEvent := GetEventType('event');

  FOR r IN SELECT * FROM Action
  LOOP

    IF r.code = 'create' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Программа создана', 'EventVersionCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Программа открыта', 'EventVersionOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Программа изменена', 'EventVersionEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Программа сохранена', 'EventVersionSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Программа доступна', 'EventVersionEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Программа недоступна', 'EventVersionDisable();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Программа будет удалена', 'EventVersionDelete();');
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Программа восстановлена', 'EventVersionRestore();');
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Программа будет уничтожена', 'EventVersionDrop();');
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
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
  pParent       numeric,
  pEntity       numeric
)
RETURNS         numeric
AS $$
DECLARE
  nClass        numeric;
BEGIN
  -- Класс
  nClass := AddClass(pParent, pEntity, 'program', 'Программа', false);

  -- Тип
  PERFORM AddType(nClass, 'plpgsql.program', 'PL/pgSQL', 'Код программы на PL/pgSQL.');

  -- Событие
  PERFORM AddProgramEvents(nClass);

  -- Метод
  PERFORM AddDefaultMethods(nClass, ARRAY['Создана', 'Открыта', 'Закрыта', 'Удалена', 'Открыть', 'Закрыть', 'Удалить']);

  RETURN nClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityProgram ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityProgram (
  pParent       numeric
)
RETURNS         numeric
AS $$
DECLARE
  nEntity       numeric;
BEGIN
  -- Сущность
  nEntity := AddEntity('program', 'Программа');

  -- Класс
  PERFORM CreateClassProgram(pParent, nEntity);

  -- API
  PERFORM RegisterRoute('program', AddEndpoint('SELECT * FROM rest.program($1, $2);'));

  RETURN nEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
