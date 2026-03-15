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
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Agent created', 'EventAgentCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Agent opened', 'EventAgentOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Agent edited', 'EventAgentEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Agent saved', 'EventAgentSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Agent enabled', 'EventAgentEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Agent disabled', 'EventAgentDisable();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Agent will be deleted', 'EventAgentDelete();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Agent restored', 'EventAgentRestore();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Agent will be dropped', 'EventAgentDrop();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
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
  uClass := AddClass(pParent, pEntity, 'agent', 'Agent', false);
  PERFORM EditClassText(uClass, 'Агент', null, GetLocale('ru'));
  PERFORM EditClassText(uClass, 'Agent', null, GetLocale('de'));
  PERFORM EditClassText(uClass, 'Agent', null, GetLocale('fr'));
  PERFORM EditClassText(uClass, 'Agente', null, GetLocale('it'));
  PERFORM EditClassText(uClass, 'Agente', null, GetLocale('es'));

  -- Тип
  PERFORM AddType(uClass, 'system.agent', 'System messages', 'Agent for delivering system messages.');
  PERFORM EditTypeText(GetType('system.agent'), 'Системные сообщения', 'Агент для доставки системных сообщений.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('system.agent'), 'Systemnachrichten', 'Agent für Systemnachrichten.', GetLocale('de'));
  PERFORM EditTypeText(GetType('system.agent'), 'Messages système', 'Agent de messages système.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('system.agent'), 'Messaggi di sistema', 'Agente per messaggi di sistema.', GetLocale('it'));
  PERFORM EditTypeText(GetType('system.agent'), 'Mensajes del sistema', 'Agente de mensajes del sistema.', GetLocale('es'));

  PERFORM AddType(uClass, 'api.agent', 'API', 'Agent for API (REST/SOAP/RPC) requests to external systems.');
  PERFORM EditTypeText(GetType('api.agent'), 'API', 'Агент для выполнения API (REST/SOAP/RPC) запросов к внешним системам.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('api.agent'), 'API', 'Agent für API-Anfragen an externe Systeme.', GetLocale('de'));
  PERFORM EditTypeText(GetType('api.agent'), 'API', 'Agent pour requêtes API vers systèmes externes.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('api.agent'), 'API', 'Agente per richieste API a sistemi esterni.', GetLocale('it'));
  PERFORM EditTypeText(GetType('api.agent'), 'API', 'Agente para solicitudes API a sistemas externos.', GetLocale('es'));

  PERFORM AddType(uClass, 'email.agent', 'Email', 'Agent for processing email.');
  PERFORM EditTypeText(GetType('email.agent'), 'Электронная почта', 'Агент для обработки электронной почты.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('email.agent'), 'E-Mail', 'Agent für E-Mail-Verarbeitung.', GetLocale('de'));
  PERFORM EditTypeText(GetType('email.agent'), 'E-mail', 'Agent de traitement des e-mails.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('email.agent'), 'E-mail', 'Agente per elaborazione e-mail.', GetLocale('it'));
  PERFORM EditTypeText(GetType('email.agent'), 'Correo electrónico', 'Agente de procesamiento de correo.', GetLocale('es'));

  PERFORM AddType(uClass, 'stream.agent', 'Data stream', 'Agent for processing data streams.');
  PERFORM EditTypeText(GetType('stream.agent'), 'Потоковые данные', 'Агент для обработки потоковых данных.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('stream.agent'), 'Datenstrom', 'Agent für Datenströme.', GetLocale('de'));
  PERFORM EditTypeText(GetType('stream.agent'), 'Flux de données', 'Agent de flux de données.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('stream.agent'), 'Flusso dati', 'Agente per flussi dati.', GetLocale('it'));
  PERFORM EditTypeText(GetType('stream.agent'), 'Flujo de datos', 'Agente de flujos de datos.', GetLocale('es'));

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
  uEntity       uuid;
BEGIN
  -- Сущность
  uEntity := AddEntity('agent', 'Agent');
  PERFORM EditEntityText(uEntity, 'Агент', null, GetLocale('ru'));
  PERFORM EditEntityText(uEntity, 'Agent', null, GetLocale('de'));
  PERFORM EditEntityText(uEntity, 'Agent', null, GetLocale('fr'));
  PERFORM EditEntityText(uEntity, 'Agente', null, GetLocale('it'));
  PERFORM EditEntityText(uEntity, 'Agente', null, GetLocale('es'));

  -- Класс
  PERFORM CreateClassAgent(pParent, uEntity);

  -- API
  PERFORM RegisterRoute('agent', AddEndpoint('SELECT * FROM rest.agent($1, $2);'));

  RETURN uEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
