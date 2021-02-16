--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddInboxMethods -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddInboxMethods (
  pClass            uuid
)
RETURNS             void
AS $$
DECLARE
  nState            uuid;

  rec_type          record;
  rec_state         record;
  rec_method        record;
BEGIN
  -- Операции (без учёта состояния)

  PERFORM DefaultMethods(pClass);

  -- Операции (с учётом состояния)

  FOR rec_type IN SELECT * FROM StateType
  LOOP

    CASE rec_type.code
    WHEN 'created' THEN

      nState := AddState(pClass, rec_type.id, rec_type.code, 'Новое');

        PERFORM AddMethod(null, pClass, nState, GetAction('enable'), null, 'Открыть');
        PERFORM AddMethod(null, pClass, nState, GetAction('disable'), null, 'Прочитать');
        PERFORM AddMethod(null, pClass, nState, GetAction('delete'), null, 'Удалить');

    WHEN 'enabled' THEN

      nState := AddState(pClass, rec_type.id, rec_type.code, 'Открыто');

        PERFORM AddMethod(null, pClass, nState, GetAction('disable'), null, 'Прочитать');
        PERFORM AddMethod(null, pClass, nState, GetAction('delete'), null, 'Удалить');

    WHEN 'disabled' THEN

      nState := AddState(pClass, rec_type.id, rec_type.code, 'Прочитано');

        PERFORM AddMethod(null, pClass, nState, GetAction('enable'), null, 'Открыть');
        PERFORM AddMethod(null, pClass, nState, GetAction('delete'), null, 'Удалить');

    WHEN 'deleted' THEN

      nState := AddState(pClass, rec_type.id, rec_type.code, 'Удалено');

        PERFORM AddMethod(null, pClass, nState, GetAction('restore'), null, 'Восстановить');
        PERFORM AddMethod(null, pClass, nState, GetAction('drop'), null, 'Уничтожить');

    END CASE;

  END LOOP;

  PERFORM DefaultTransition(pClass);

  -- Переходы из состояния в состояние

  FOR rec_state IN SELECT * FROM State WHERE class = pClass
  LOOP
    CASE rec_state.code
    WHEN 'created' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'enable' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'enabled'));
        END IF;

        IF rec_method.actioncode = 'disable' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'disabled'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'enabled' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'disable' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'disabled'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'disabled' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'enable' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'enabled'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'deleted' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'restore' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'created'));
        END IF;
      END LOOP;

    END CASE;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddOutboxMethods ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddOutboxMethods (
  pClass            uuid
)
RETURNS             void
AS $$
DECLARE
  nState            uuid;

  rec_type          record;
  rec_state         record;
  rec_method        record;
BEGIN
  -- Операции (без учёта состояния)

  PERFORM DefaultMethods(pClass);

  -- Операции (с учётом состояния)

  FOR rec_type IN SELECT * FROM StateType
  LOOP

    CASE rec_type.code
    WHEN 'created' THEN

      nState := AddState(pClass, rec_type.id, rec_type.code, 'Создано');

        PERFORM AddMethod(null, pClass, nState, GetAction('submit'));
        PERFORM AddMethod(null, pClass, nState, GetAction('delete'));

    WHEN 'enabled' THEN

      nState := AddState(pClass, rec_type.id, 'prepared', 'Подготовлено');

        PERFORM AddMethod(null, pClass, nState, GetAction('send'), pvisible => false);
        PERFORM AddMethod(null, pClass, nState, GetAction('done'), pvisible => false);
        PERFORM AddMethod(null, pClass, nState, GetAction('fail'), pvisible => false);

        PERFORM AddMethod(null, pClass, nState, GetAction('cancel'));

      nState := AddState(pClass, rec_type.id, 'sending', 'Отправка');

        PERFORM AddMethod(null, pClass, nState, GetAction('done'), pvisible => false);
        PERFORM AddMethod(null, pClass, nState, GetAction('fail'), pvisible => false);

        PERFORM AddMethod(null, pClass, nState, GetAction('delete'));

    WHEN 'disabled' THEN

      nState := AddState(pClass, rec_type.id, 'submitted', 'Отправлено');

        PERFORM AddMethod(null, pClass, nState, GetAction('repeat'));
        PERFORM AddMethod(null, pClass, nState, GetAction('delete'));

      nState := AddState(pClass, rec_type.id, 'failed', 'Ошибка');

        PERFORM AddMethod(null, pClass, nState, GetAction('repeat'));
        PERFORM AddMethod(null, pClass, nState, GetAction('delete'));

    WHEN 'deleted' THEN

      nState := AddState(pClass, rec_type.id, rec_type.code, 'Удалено');

        PERFORM AddMethod(null, pClass, nState, GetAction('restore'));
        PERFORM AddMethod(null, pClass, nState, GetAction('drop'));

    END CASE;

  END LOOP;

  PERFORM DefaultTransition(pClass);

  -- Переходы из состояния в состояние

  FOR rec_state IN SELECT * FROM State WHERE class = pClass
  LOOP
    CASE rec_state.code
    WHEN 'created' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'submit' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'prepared'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'prepared' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'send' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'sending'));
        END IF;

        IF rec_method.actioncode = 'done' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'submitted'));
        END IF;

        IF rec_method.actioncode = 'fail' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'failed'));
        END IF;

        IF rec_method.actioncode = 'cancel' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'created'));
        END IF;
      END LOOP;

    WHEN 'sending' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'done' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'submitted'));
        END IF;

        IF rec_method.actioncode = 'fail' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'failed'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'submitted' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'repeat' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'prepared'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'failed' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'repeat' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'prepared'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'deleted' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'restore' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'created'));
        END IF;
      END LOOP;
    END CASE;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

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

  nParent       uuid;
BEGIN
  nParent := GetEventType('parent');

  FOR r IN SELECT * FROM Action
  LOOP
    PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddInboxEvents --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddInboxEvents (
  pClass        uuid
)
RETURNS         void
AS $$
DECLARE
  r             record;

  nParent       uuid;
  nEvent        uuid;
BEGIN
  nParent := GetEventType('parent');
  nEvent := GetEventType('event');

  FOR r IN SELECT * FROM Action
  LOOP
  
    IF r.code = 'create' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Сообщение создано', 'EventMessageCreate();');
    END IF;
  
    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Сообщение открыто', 'EventMessageOpen();');
    END IF;
  
    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Сообщение изменёно', 'EventMessageEdit();');
    END IF;
  
    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Сообщение сохранёно', 'EventMessageSave();');
    END IF;
  
    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Сообщение не прочитано', 'EventMessageEnable();');
    END IF;
  
    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Сообщение прочитано', 'EventMessageDisable();');
    END IF;
  
    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Сообщение будет удалено', 'EventMessageDelete();');
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
    END IF;
  
    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Сообщение восстановлено', 'EventMessageRestore();');
    END IF;
  
    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Сообщение будет уничтожено', 'EventMessageDrop();');
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
    END IF;
  
  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddOutboxEvents -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddOutboxEvents (
  pClass        uuid
)
RETURNS         void
AS $$
DECLARE
  r             record;

  nParent       uuid;
  nEvent        uuid;
BEGIN
  nParent := GetEventType('parent');
  nEvent := GetEventType('event');

  FOR r IN SELECT * FROM Action
  LOOP

    IF r.code = 'create' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Сообщение создано', 'EventMessageCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Сообщение открыто', 'EventMessageOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Сообщение изменёно', 'EventMessageEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Сообщение сохранёно', 'EventMessageSave();');
    END IF;

    IF r.code = 'submit' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Сообщение готово к отправке', 'EventMessageSubmit();');
    END IF;

    IF r.code = 'send' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Сообщение отправляется', 'EventMessageSend();');
    END IF;

    IF r.code = 'cancel' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Отправка сообщения отменена', 'EventMessageCancel();');
    END IF;

    IF r.code = 'done' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Сообщение отправено', 'EventMessageDone();');
    END IF;

    IF r.code = 'fail' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Сбой при отправке сообщения', 'EventMessageFail();');
    END IF;

    IF r.code = 'repeat' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Повторная отправка сообщения', 'EventMessageRepeat();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Сообщение будет удалено', 'EventMessageDelete();');
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Сообщение восстановлено', 'EventMessageRestore();');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Сообщение будет уничтожено', 'EventMessageDrop();');
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
    END IF;

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
  nClass        uuid;
BEGIN
  -- Класс
  nClass := AddClass(pParent, pEntity, 'message', 'Сообщения', true);

  -- Тип

  -- Событие
  PERFORM AddMessageEvents(nClass);

  -- Метод
  PERFORM AddDefaultMethods(nClass);

  RETURN nClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassInbox ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassInbox (
  pParent       uuid,
  pEntity       uuid
)
RETURNS         uuid
AS $$
DECLARE
  nClass        uuid;
BEGIN
  -- Класс
  nClass := AddClass(pParent, pEntity, 'inbox', 'Входящее', false);

  -- Тип
  PERFORM AddType(nClass, 'message.inbox', 'Входящие', 'Входящие сообщения.');

  -- Событие
  PERFORM AddInboxEvents(nClass);

  -- Метод
  PERFORM AddInboxMethods(nClass);

  RETURN nClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassOutbox -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassOutbox (
  pParent       uuid,
  pEntity       uuid
)
RETURNS         uuid
AS $$
DECLARE
  nClass        uuid;
BEGIN
  -- Класс
  nClass := AddClass(pParent, pEntity, 'outbox', 'Исходящее', false);

  -- Тип
  PERFORM AddType(nClass, 'message.outbox', 'Исходящие', 'Исходящие сообщения.');

  -- Событие
  PERFORM AddOutboxEvents(nClass);

  -- Метод
  PERFORM AddOutboxMethods(nClass);

  RETURN nClass;
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
  nEntity       uuid;
  nClass        uuid;
BEGIN
  -- Сущность
  nEntity := AddEntity('message', 'Сообщение');

  -- Класс
  nClass := CreateClassMessage(pParent, nEntity);

  PERFORM CreateClassInbox(nClass, nEntity);
  PERFORM CreateClassOutbox(nClass, nEntity);

  -- API
  PERFORM RegisterRoute('message', AddEndpoint('SELECT * FROM rest.message($1, $2);'));

  RETURN nEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
