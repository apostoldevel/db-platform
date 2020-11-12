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
      PERFORM AddEvent(pClass, nEvent, r.id, 'Календарь создан', 'EventProgramCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Календарь открыт', 'EventProgramOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Календарь изменён', 'EventProgramEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Календарь сохранён', 'EventProgramSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Календарь доступен', 'EventProgramEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Календарь недоступен', 'EventProgramDisable();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Календарь будет удалён', 'EventProgramDelete();');
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Календарь восстановлен', 'EventProgramRestore();');
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Календарь будет уничтожен', 'EventProgramDrop();');
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
  PERFORM AddDefaultMethods(nClass, ARRAY['Создана', 'Открыта', 'Закрыта', 'Удалёна', 'Открыть', 'Закрыть', 'Удалить']);

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

  RETURN nEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
