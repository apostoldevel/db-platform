--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddVersionEvents ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddVersionEvents (
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
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Version created', 'EventVersionCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Version opened', 'EventVersionOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Version edited', 'EventVersionEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Version saved', 'EventVersionSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Version enabled', 'EventVersionEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Version disabled', 'EventVersionDisable();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Version will be deleted', 'EventVersionDelete();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Version restored', 'EventVersionRestore();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Version will be dropped', 'EventVersionDrop();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassVersion ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassVersion (
  pParent       uuid,
  pEntity       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uClass        uuid;
BEGIN
  -- Класс
  uClass := AddClass(pParent, pEntity, 'version', 'Version', false);
  PERFORM EditClassText(uClass, 'Версия', null, GetLocale('ru'));
  PERFORM EditClassText(uClass, 'Version', null, GetLocale('de'));
  PERFORM EditClassText(uClass, 'Version', null, GetLocale('fr'));
  PERFORM EditClassText(uClass, 'Versione', null, GetLocale('it'));
  PERFORM EditClassText(uClass, 'Versión', null, GetLocale('es'));

  -- Тип
  PERFORM AddType(uClass, 'api.version', 'API', 'API version.');
  PERFORM EditTypeText(GetType('api.version'), 'API', 'Версия API.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('api.version'), 'API', 'API-Version.', GetLocale('de'));
  PERFORM EditTypeText(GetType('api.version'), 'API', 'Version API.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('api.version'), 'API', 'Versione API.', GetLocale('it'));
  PERFORM EditTypeText(GetType('api.version'), 'API', 'Versión API.', GetLocale('es'));

  -- Событие
  PERFORM AddVersionEvents(uClass);

  -- Метод
  PERFORM AddDefaultMethods(uClass,
    ARRAY['Created', 'Opened', 'Closed', 'Deleted', 'Open', 'Close', 'Delete'],
    ARRAY['Создана', 'Открыта', 'Закрыта', 'Удалена', 'Открыть', 'Закрыть', 'Удалить']);

  RETURN uClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityVersion ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityVersion (
  pParent       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uEntity       uuid;
BEGIN
  -- Сущность
  uEntity := AddEntity('version', 'Version');
  PERFORM EditEntityText(uEntity, 'Версия', null, GetLocale('ru'));
  PERFORM EditEntityText(uEntity, 'Version', null, GetLocale('de'));
  PERFORM EditEntityText(uEntity, 'Version', null, GetLocale('fr'));
  PERFORM EditEntityText(uEntity, 'Versione', null, GetLocale('it'));
  PERFORM EditEntityText(uEntity, 'Versión', null, GetLocale('es'));

  -- Класс
  PERFORM CreateClassVersion(pParent, uEntity);

  -- API
  PERFORM RegisterRoute('version', AddEndpoint('SELECT * FROM rest.version($1, $2);'));

  RETURN uEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
