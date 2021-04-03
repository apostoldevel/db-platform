--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddProjectEvents ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddProjectEvents (
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
      PERFORM AddEvent(pClass, uEvent, r.id, 'Проект создан', 'EventProjectCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Проект открыт', 'EventProjectOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Проект изменён', 'EventProjectEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Проект сохранён', 'EventProjectSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Проект доступен', 'EventProjectEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Проект недоступен', 'EventProjectDisable();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Проект будет удалён', 'EventProjectDelete();');
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Проект восстановлен', 'EventProjectRestore();');
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Проект будет уничтожен', 'EventProjectDrop();');
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
    END IF;

  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassProject ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassProject (
  pParent       uuid,
  pEntity       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uClass        uuid;
BEGIN
  -- Класс
  uClass := AddClass(pParent, pEntity, 'project', 'Проект', false);

  -- Тип
  PERFORM AddType(uClass, 'ship.project', 'Судно', 'Проект судна.');

  -- Событие
  PERFORM AddProjectEvents(uClass);

  -- Метод
  PERFORM AddDefaultMethods(uClass);

  RETURN uClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityProject ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityProject (
  pParent       uuid
)
RETURNS         uuid
AS $$
DECLARE
  nEntity       uuid;
BEGIN
  -- Сущность
  nEntity := AddEntity('project', 'Проект');

  -- Класс
  PERFORM CreateClassProject(pParent, nEntity);

  -- API
  PERFORM RegisterRoute('project', AddEndpoint('SELECT * FROM rest.project($1, $2);'));

  RETURN nEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
