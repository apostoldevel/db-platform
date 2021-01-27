--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddReferenceEvents ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddReferenceEvents (
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
      PERFORM AddEvent(pClass, nEvent, r.id, 'Справочник создан', 'EventReferenceCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Справочник открыт', 'EventReferenceOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Справочник изменён', 'EventReferenceEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Справочник сохранён', 'EventReferenceSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Справочник доступен', 'EventReferenceEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Справочник недоступен', 'EventReferenceDisable();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Справочник будет удалён', 'EventReferenceDelete();');
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Справочник восстановлен', 'EventReferenceRestore();');
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Справочник будет уничтожен', 'EventReferenceDrop();');
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
    END IF;

  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassReference --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassReference (
  pParent       numeric,
  pEntity       numeric
)
RETURNS         numeric
AS $$
DECLARE
  nClass        numeric;
BEGIN
  -- Класс
  nClass := AddClass(pParent, pEntity, 'reference', 'Справочник', true);

  -- Событие
  PERFORM AddReferenceEvents(nClass);

  -- Метод
  PERFORM AddDefaultMethods(nClass);

  RETURN nClass;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityReference -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityReference (
  pParent       numeric
)
RETURNS         numeric
AS $$
DECLARE
  nEntity       numeric;
BEGIN
  -- Сущность
  nEntity := AddEntity('reference', 'Справочник');

  -- Класс
  PERFORM CreateClassReference(pParent, nEntity);

  -- API
  PERFORM RegisterRoute('reference', AddEndpoint('SELECT * FROM rest.reference($1, $2);'));

  RETURN nEntity;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
