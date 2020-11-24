--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddObjectEvents -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddObjectEvents (
  pClass        numeric
)
RETURNS         void
AS $$
DECLARE
  r             record;

  nEvent        numeric;
BEGIN
  nEvent := GetEventType('event');

  FOR r IN SELECT * FROM Action
  LOOP

    IF r.code = 'create' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Создать', 'EventObjectCreate();');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Открыть', 'EventObjectOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Изменить', 'EventObjectEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Сохранить', 'EventObjectSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Включить', 'EventObjectEnable();');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Выключить', 'EventObjectDisable();');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Удалить', 'EventObjectDelete();');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Восстановить', 'EventObjectRestore();');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Уничтожить', 'EventObjectDrop();');
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
  pParent       numeric,
  pEntity       numeric
)
RETURNS         numeric
AS $$
DECLARE
  nClass        numeric;
BEGIN
  -- Класс
  nClass := AddClass(pParent, pEntity, 'object', 'Объект', true);

  -- Событие
  PERFORM AddObjectEvents(nClass);

  -- Метод
  PERFORM AddDefaultMethods(nClass);

  RETURN nClass;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityObject ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityObject (
  pParent       numeric
)
RETURNS         numeric
AS $$
DECLARE
  nEntity       numeric;
BEGIN
  -- Сущность
  nEntity := AddEntity('object', 'Объект');

  -- Класс
  PERFORM CreateClassObject(pParent, nEntity);

  -- API
  PERFORM RegisterRoute('/api/v1/object', AddEndpoint('SELECT * FROM rest.object($1, $2);'));

  RETURN nEntity;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
