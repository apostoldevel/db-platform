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
      PERFORM AddEvent(pClass, uEvent, r.id, 'Create', 'EventObjectCreate();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'State change', 'ChangeObjectState();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Open', 'EventObjectOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Edit', 'EventObjectEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Save', 'EventObjectSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Enable', 'EventObjectEnable();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'State change', 'ChangeObjectState();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Disable', 'EventObjectDisable();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'State change', 'ChangeObjectState();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Delete', 'EventObjectDelete();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'State change', 'ChangeObjectState();');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Restore', 'EventObjectRestore();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'State change', 'ChangeObjectState();');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Drop', 'EventObjectDrop();');
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
  uClass := AddClass(pParent, pEntity, 'object', 'Object', true);

  PERFORM EditClassText(uClass, 'Объект', GetLocale('ru'));
  PERFORM EditClassText(uClass, 'Objekt', GetLocale('de'));
  PERFORM EditClassText(uClass, 'Objet', GetLocale('fr'));
  PERFORM EditClassText(uClass, 'Oggetto', GetLocale('it'));
  PERFORM EditClassText(uClass, 'Objeto', GetLocale('es'));

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
  uEntity       uuid;
BEGIN
  -- Сущность
  uEntity := AddEntity('object', 'Object');

  PERFORM EditEntityText(uEntity, 'Объект', null, GetLocale('ru'));
  PERFORM EditEntityText(uEntity, 'Objekt', null, GetLocale('de'));
  PERFORM EditEntityText(uEntity, 'Objet', null, GetLocale('fr'));
  PERFORM EditEntityText(uEntity, 'Oggetto', null, GetLocale('it'));
  PERFORM EditEntityText(uEntity, 'Objeto', null, GetLocale('es'));

  -- Класс
  PERFORM CreateClassObject(pParent, uEntity);

  -- API
  PERFORM RegisterRoute('object', AddEndpoint('SELECT * FROM rest.object($1, $2);'));

  RETURN uEntity;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
