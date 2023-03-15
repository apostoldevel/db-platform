--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddReportReadyMethods -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddReportReadyMethods (
  pClass            uuid
)
RETURNS             void
AS $$
DECLARE
  uState            uuid;

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

      uState := AddState(pClass, rec_type.id, rec_type.code, 'Создан');

        PERFORM AddMethod(null, pClass, uState, GetAction('execute'));
        PERFORM AddMethod(null, pClass, uState, GetAction('delete'));

    WHEN 'enabled' THEN

      uState := AddState(pClass, rec_type.id, 'progress', 'Выполняется');

        PERFORM AddMethod(null, pClass, uState, GetAction('complete'), pvisible => false);
        PERFORM AddMethod(null, pClass, uState, GetAction('fail'), pvisible => false);

        PERFORM AddMethod(null, pClass, uState, GetAction('cancel'));

      uState := AddState(pClass, rec_type.id, 'canceled', 'Отменяется');

        PERFORM AddMethod(null, pClass, uState, GetAction('abort'), pvisible => false);

    WHEN 'disabled' THEN

      uState := AddState(pClass, rec_type.id, 'completed', 'Завершён');

        PERFORM AddMethod(null, pClass, uState, GetAction('execute'));
        PERFORM AddMethod(null, pClass, uState, GetAction('delete'));

      uState := AddState(pClass, rec_type.id, 'aborted', 'Прерван');

        PERFORM AddMethod(null, pClass, uState, GetAction('execute'));
        PERFORM AddMethod(null, pClass, uState, GetAction('delete'));

      uState := AddState(pClass, rec_type.id, 'failed', 'Ошибка');

        PERFORM AddMethod(null, pClass, uState, GetAction('execute'));
        PERFORM AddMethod(null, pClass, uState, GetAction('delete'));

    WHEN 'deleted' THEN

      uState := AddState(pClass, rec_type.id, rec_type.code, 'Удалён');

        PERFORM AddMethod(null, pClass, uState, GetAction('restore'));
        PERFORM AddMethod(null, pClass, uState, GetAction('drop'));

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
        IF rec_method.actioncode = 'execute' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'progress'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'progress' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'complete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'completed'));
        END IF;

        IF rec_method.actioncode = 'fail' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'failed'));
        END IF;

        IF rec_method.actioncode = 'cancel' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'canceled'));
        END IF;
      END LOOP;

    WHEN 'canceled' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'abort' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'aborted'));
        END IF;
      END LOOP;

    WHEN 'completed' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'execute' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'progress'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'aborted' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'execute' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'progress'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'failed' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'execute' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'progress'));
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
-- AddReportReadyEvents --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddReportReadyEvents (
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
      PERFORM AddEvent(pClass, uEvent, r.id, 'Готовый отчёт создано', 'EventReportReadyCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Готовый отчёт открыто', 'EventReportReadyOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Готовый отчёт изменено', 'EventReportReadyEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Готовый отчёт сохранено', 'EventReportReadySave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Готовый отчёт включено', 'EventReportReadyEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Готовый отчёт отключено', 'EventReportReadyDisable();');
    END IF;

    IF r.code = 'execute' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Готовый отчёт выполняется', 'EventReportReadyExecute();');
    END IF;

    IF r.code = 'complete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Готовый отчёт выполнен', 'EventReportReadyComplete();');
    END IF;

    IF r.code = 'fail' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Сбой при выполнении задания', 'EventReportReadyFail();');
    END IF;

    IF r.code = 'abort' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Готовый отчёт прервано', 'EventReportReadyAbort();');
    END IF;

    IF r.code = 'cancel' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Готовый отчёт отменено', 'EventReportReadyCancel();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Готовый отчёт будет удалено', 'EventReportReadyDelete();');
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Готовый отчёт восстановлено', 'EventReportReadyRestore();');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Готовый отчёт будет уничтожено', 'EventReportReadyDrop();');
      PERFORM AddEvent(pClass, uParent, r.id, 'События класса родителя');
    END IF;

  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassReportReady ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassReportReady (
  pParent       uuid,
  pEntity       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uClass        uuid;
BEGIN
  -- Класс
  uClass := AddClass(pParent, pEntity, 'report_ready', 'Готовый отчёт', false);

  -- Тип
  PERFORM AddType(uClass, 'sync.report_ready', 'Синхронный', 'Синхронный отчёт.');
  PERFORM AddType(uClass, 'async.report_ready', 'Асинхронный', 'Асинхронный отчёт.');

  -- Событие
  PERFORM AddReportReadyEvents(uClass);

  -- Метод
  PERFORM AddReportReadyMethods(uClass);

  RETURN uClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityReportReady -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityReportReady (
  pParent       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uEntity       uuid;
BEGIN
  -- Сущность
  uEntity := AddEntity('report_ready', 'Готовый отчёт');

  -- Класс
  PERFORM CreateClassReportReady(pParent, uEntity);

  -- API
  PERFORM RegisterRoute('report/ready', AddEndpoint('SELECT * FROM rest.report_ready($1, $2);'));

  RETURN uEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
