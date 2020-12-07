--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddJobMethods ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddJobMethods (
  pClass            numeric
)
RETURNS             void
AS $$
DECLARE
  nState            numeric;

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

        PERFORM AddMethod(null, pClass, nState, GetAction('enable'));
        PERFORM AddMethod(null, pClass, nState, GetAction('disable'));
        PERFORM AddMethod(null, pClass, nState, GetAction('delete'));

    WHEN 'enabled' THEN

      nState := AddState(pClass, rec_type.id, rec_type.code, 'Включено');

        PERFORM AddMethod(null, pClass, nState, GetAction('execute'));
        PERFORM AddMethod(null, pClass, nState, GetAction('disable'));
        PERFORM AddMethod(null, pClass, nState, GetAction('delete'));

      nState := AddState(pClass, rec_type.id, 'executed', 'Выполняется');

        PERFORM AddMethod(null, pClass, nState, GetAction('complete'), pvisible => false);
        PERFORM AddMethod(null, pClass, nState, GetAction('done'), pvisible => false);
        PERFORM AddMethod(null, pClass, nState, GetAction('fail'), pvisible => false);

        PERFORM AddMethod(null, pClass, nState, GetAction('cancel'));

      nState := AddState(pClass, rec_type.id, 'canceled', 'Отменяется');

        PERFORM AddMethod(null, pClass, nState, GetAction('abort'), pvisible => false);

      nState := AddState(pClass, rec_type.id, 'aborted', 'Прервано');

        PERFORM AddMethod(null, pClass, nState, GetAction('execute'));
        PERFORM AddMethod(null, pClass, nState, GetAction('disable'));
        PERFORM AddMethod(null, pClass, nState, GetAction('delete'));

      nState := AddState(pClass, rec_type.id, 'failed', 'Ошибка');

        PERFORM AddMethod(null, pClass, nState, GetAction('execute'));
        PERFORM AddMethod(null, pClass, nState, GetAction('disable'));
        PERFORM AddMethod(null, pClass, nState, GetAction('delete'));

    WHEN 'disabled' THEN

      nState := AddState(pClass, rec_type.id, 'disabled', 'Отключено');

        PERFORM AddMethod(null, pClass, nState, GetAction('enable'));
        PERFORM AddMethod(null, pClass, nState, GetAction('delete'));

      nState := AddState(pClass, rec_type.id, 'completed', 'Завершено');

        PERFORM AddMethod(null, pClass, nState, GetAction('enable'));
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
        IF rec_method.actioncode = 'execute' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'executed'));
        END IF;

        IF rec_method.actioncode = 'disable' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'disabled'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'executed' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'complete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'completed'));
        END IF;

        IF rec_method.actioncode = 'done' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'enabled'));
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

    WHEN 'failed' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'execute' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'executed'));
        END IF;

        IF rec_method.actioncode = 'disable' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'disabled'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'aborted' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'execute' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'executed'));
        END IF;

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

    WHEN 'completed' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'execute' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'executed'));
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
-- AddJobEvents ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddJobEvents (
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
      PERFORM AddEvent(pClass, nEvent, r.id, 'Задание создано', 'EventJobCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Задание открыто', 'EventJobOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Задание изменено', 'EventJobEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Задание сохранено', 'EventJobSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Задание включено', 'EventJobEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Задание отключено', 'EventJobDisable();');
    END IF;

    IF r.code = 'execute' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Задание выполняется', 'EventJobExecute();');
    END IF;

    IF r.code = 'complete' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Задание завершено', 'EventJobComplete();');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
    END IF;

    IF r.code = 'done' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Задание выполнено', 'EventJobDone();');
    END IF;

    IF r.code = 'fail' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Сбой при выполнении задания', 'EventJobFail();');
    END IF;

    IF r.code = 'abort' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Задание прервано', 'EventJobAbort();');
    END IF;

    IF r.code = 'cancel' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Задание отменено', 'EventJobCancel();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Задание будет удалено', 'EventJobDelete();');
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
      PERFORM AddEvent(pClass, nEvent, r.id, 'Задание восстановлено', 'EventJobRestore();');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, nEvent, r.id, 'Задание будет уничтожено', 'EventJobDrop();');
      PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
    END IF;

  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassJob --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassJob (
  pParent       numeric,
  pEntity       numeric
)
RETURNS         numeric
AS $$
DECLARE
  nClass        numeric;
BEGIN
  -- Класс
  nClass := AddClass(pParent, pEntity, 'job', 'Задание', false);

  -- Тип
  PERFORM AddType(nClass, 'periodic.job', 'Периодическое', 'Периодическое задание.');
  PERFORM AddType(nClass, 'disposable.job', 'Разовое', 'Разовое задание.');

  -- Событие
  PERFORM AddJobEvents(nClass);

  -- Метод
  PERFORM AddJobMethods(nClass);

  RETURN nClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityJob -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityJob (
  pParent       numeric
)
RETURNS         numeric
AS $$
DECLARE
  nEntity       numeric;
BEGIN
  -- Сущность
  nEntity := AddEntity('job', 'Задание');

  -- Класс
  PERFORM CreateClassJob(pParent, nEntity);

  -- API
  PERFORM RegisterRoute('job', AddEndpoint('SELECT * FROM rest.job($1, $2);'));

  RETURN nEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
