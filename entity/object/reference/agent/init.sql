--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddAgentEvents --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddAgentEvents (
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
      PERFORM AddEvent(pClass, uEvent, r.id, 'Агент создан', 'EventAgentCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Агент открыт', 'EventAgentOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Агент изменён', 'EventAgentEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Агент сохранён', 'EventAgentSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Агент доступен', 'EventAgentEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Агент недоступен', 'EventAgentDisable();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Агент будет удалён', 'EventAgentDelete();');
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Агент восстановлен', 'EventAgentRestore();');
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Агент будет уничтожен', 'EventAgentDrop();');
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
    END IF;

  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassAgent ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassAgent (
  pParent       uuid,
  pEntity       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uClass        uuid;
BEGIN
  -- Класс
  uClass := AddClass(pParent, pEntity, 'agent', 'Агент', false);

  -- Тип
  PERFORM AddType(uClass, 'system.agent', 'Системные сообщения', 'Агент для доставки системных сообщений.');
  PERFORM AddType(uClass, 'api.agent', 'API', 'Агент для выполения API (REST/SOAP/RPC) запросов к внешним системам.');
  PERFORM AddType(uClass, 'email.agent', 'Электронная почта', 'Агент для обработки электронной почты.');
  PERFORM AddType(uClass, 'stream.agent', 'Потоковые данные', 'Агент для обработки потоковых данных.');

  -- Событие
  PERFORM AddAgentEvents(uClass);

  -- Метод
  PERFORM AddDefaultMethods(uClass);

  RETURN uClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityAgent -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityAgent (
  pParent       uuid
)
RETURNS         uuid
AS $$
DECLARE
  nEntity       uuid;
BEGIN
  -- Сущность
  nEntity := AddEntity('agent', 'Агент');

  -- Класс
  PERFORM CreateClassAgent(pParent, nEntity);

  -- API
  PERFORM RegisterRoute('agent', AddEndpoint('SELECT * FROM rest.agent($1, $2);'));

  RETURN nEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
