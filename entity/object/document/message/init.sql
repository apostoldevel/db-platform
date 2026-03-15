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
    PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
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
  -- Class
  uClass := AddClass(pParent, pEntity, 'message', 'Message', true);

  PERFORM EditClassText(uClass, 'Сообщение', GetLocale('ru'));
  PERFORM EditClassText(uClass, 'Nachricht', GetLocale('de'));
  PERFORM EditClassText(uClass, 'Message', GetLocale('fr'));
  PERFORM EditClassText(uClass, 'Messaggio', GetLocale('it'));
  PERFORM EditClassText(uClass, 'Mensaje', GetLocale('es'));

  -- Type

  -- Event
  PERFORM AddMessageEvents(uClass);

  -- Method
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
  -- Entity
  uEntity := AddEntity('message', 'Message');

  PERFORM EditEntityText(uEntity, 'Сообщение', null, GetLocale('ru'));
  PERFORM EditEntityText(uEntity, 'Nachricht', null, GetLocale('de'));
  PERFORM EditEntityText(uEntity, 'Message', null, GetLocale('fr'));
  PERFORM EditEntityText(uEntity, 'Messaggio', null, GetLocale('it'));
  PERFORM EditEntityText(uEntity, 'Mensaje', null, GetLocale('es'));

  -- Class
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
