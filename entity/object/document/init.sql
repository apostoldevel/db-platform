--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddDocumentEvents -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddDocumentEvents (
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
      PERFORM AddEvent(pClass, nEvent, r.id, 'Документ создан', 'EventDocumentCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Документ открыт', 'EventDocumentOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Документ изменён', 'EventDocumentEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Документ сохранён', 'EventDocumentSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Документ включен', 'EventDocumentEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Документ отключен', 'EventDocumentDisable();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Документ будет удалён', 'EventDocumentDelete();');
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Документ восстановлен', 'EventDocumentRestore();');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Документ будет уничтожен', 'EventDocumentDrop();');
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
    END IF;

  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassDocument ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassDocument (
  pParent       numeric,
  pEntity       numeric
)
RETURNS         numeric
AS $$
DECLARE
  nClass        numeric;
BEGIN
  -- Класс
  nClass := AddClass(pParent, pEntity, 'document', 'Документ', true);

  -- Событие
  PERFORM AddDocumentEvents(nClass);

  -- Метод
  PERFORM AddDefaultMethods(nClass);

  RETURN nClass;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityDocument --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityDocument (
  pParent       numeric
)
RETURNS         numeric
AS $$
DECLARE
  nEntity       numeric;
BEGIN
  -- Сущность
  nEntity := AddEntity('document', 'Документ');

  -- Класс
  PERFORM CreateClassDocument(pParent, nEntity);

  -- API
  PERFORM RegisterRoute('document', AddEndpoint('SELECT * FROM rest.document($1, $2);'));

  RETURN nEntity;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
