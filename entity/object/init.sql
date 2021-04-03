--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddObjectEvents -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddObjectEvents (
  pClass        uuid
)
RETURNS         void
AS $$
DECLARE
  r             record;

  uEvent        uuid;
BEGIN
  uEvent := GetEventType('event');

  FOR r IN SELECT * FROM Action
  LOOP

    IF r.code = 'create' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Создать', 'EventObjectCreate();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Открыть', 'EventObjectOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Изменить', 'EventObjectEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Сохранить', 'EventObjectSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Включить', 'EventObjectEnable();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Выключить', 'EventObjectDisable();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Удалить', 'EventObjectDelete();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Восстановить', 'EventObjectRestore();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Уничтожить', 'EventObjectDrop();');
    END IF;

  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassObject -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassObject (
  pParent       uuid,
  pEntity       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uClass        uuid;
BEGIN
  -- Класс
  uClass := AddClass(pParent, pEntity, 'object', 'Объект', true);

  -- Событие
  PERFORM AddObjectEvents(uClass);

  -- Метод
  PERFORM AddDefaultMethods(uClass);

  RETURN uClass;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityObject ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityObject (
  pParent       uuid
)
RETURNS         uuid
AS $$
DECLARE
  nEntity       uuid;
BEGIN
  -- Сущность
  nEntity := AddEntity('object', 'Объект');

  -- Класс
  PERFORM CreateClassObject(pParent, nEntity);

  -- API
  PERFORM RegisterRoute('object', AddEndpoint('SELECT * FROM rest.object($1, $2);'));

  RETURN nEntity;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
