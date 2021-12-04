--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddMessageEvents ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddMessageEvents (
  pClass        uuid
)
RETURNS         void
AS $$
DECLARE
  r             record;

  uParent       uuid;
BEGIN
  uParent := GetEventType('parent');

  FOR r IN SELECT * FROM Action
  LOOP
    PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassMessage ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassMessage (
  pParent       uuid,
  pEntity       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uClass        uuid;
BEGIN
  -- Класс
  uClass := AddClass(pParent, pEntity, 'message', 'Сообщения', true);

  -- Тип

  -- Событие
  PERFORM AddMessageEvents(uClass);

  -- Метод
  PERFORM AddDefaultMethods(uClass);

  RETURN uClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityMessage ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityMessage (
  pParent       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uEntity       uuid;
  uClass        uuid;
BEGIN
  -- Сущность
  uEntity := AddEntity('message', 'Сообщение');

  -- Класс
  uClass := CreateClassMessage(pParent, uEntity);

  PERFORM CreateClassInbox(uClass, uEntity);
  PERFORM CreateClassOutbox(uClass, uEntity);

  -- API
  PERFORM RegisterRoute('message', AddEndpoint('SELECT * FROM rest.message($1, $2);'));

  RETURN uEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
