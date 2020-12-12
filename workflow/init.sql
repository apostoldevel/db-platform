--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- DefaultMethods --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DefaultMethods (
  pClass            numeric
)
RETURNS             void
AS $$
BEGIN
  PERFORM AddMethod(null, pClass, null, GetAction('create'), null, 'Создать');
  PERFORM AddMethod(null, pClass, null, GetAction('open'), null, 'Открыть');
  PERFORM AddMethod(null, pClass, null, GetAction('edit'), null, 'Изменить');
  PERFORM AddMethod(null, pClass, null, GetAction('save'), null, 'Сохранить');
  PERFORM AddMethod(null, pClass, null, GetAction('enable'), null, 'Включить');
  PERFORM AddMethod(null, pClass, null, GetAction('disable'), null, 'Выключить');
  PERFORM AddMethod(null, pClass, null, GetAction('delete'), null, 'Удалить');
  PERFORM AddMethod(null, pClass, null, GetAction('restore'), null, 'Восстановить');
  PERFORM AddMethod(null, pClass, null, GetAction('drop'), null, 'Уничтожить');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DefaultTransition -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DefaultTransition (
  pClass            numeric
)
RETURNS             void
AS $$
DECLARE
  rec_method        record;
BEGIN
  -- Переходы в состояние

  FOR rec_method IN SELECT * FROM Method WHERE class = pClass AND state IS NULL
  LOOP
    IF rec_method.actioncode = 'create' THEN
      PERFORM AddTransition(null, rec_method.id, GetState(pClass, 'created'));
    END IF;

    IF rec_method.actioncode = 'enable' THEN
      PERFORM AddTransition(null, rec_method.id, GetState(pClass, 'enabled'));
    END IF;

    IF rec_method.actioncode = 'disable' THEN
      PERFORM AddTransition(null, rec_method.id, GetState(pClass, 'disabled'));
    END IF;

    IF rec_method.actioncode = 'delete' THEN
      PERFORM AddTransition(null, rec_method.id, GetState(pClass, 'deleted'));
    END IF;

    IF rec_method.actioncode = 'restore' THEN
      PERFORM AddTransition(null, rec_method.id, GetState(pClass, 'created'));
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddDefaultMethods -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddDefaultMethods (
  pClass            numeric,
  pNames            text[] DEFAULT null
)
RETURNS             void
AS $$
DECLARE
  nState            numeric;

  rec_type          record;
  rec_state         record;
  rec_method        record;
BEGIN
  IF pNames IS NULL THEN
    pNames := array_cat(pNames, ARRAY['Создан', 'Открыт', 'Закрыт', 'Удалён', 'Открыть', 'Закрыть', 'Удалить']);
  END IF;

  -- Операции (без учёта состояния)

  PERFORM DefaultMethods(pClass);

  -- Операции (с учётом состояния)

  FOR rec_type IN SELECT * FROM StateType
  LOOP

    CASE rec_type.code
    WHEN 'created' THEN

      nState := AddState(pClass, rec_type.id, rec_type.code, pNames[1]);

        PERFORM AddMethod(null, pClass, nState, GetAction('enable'), null, pNames[5]);
        PERFORM AddMethod(null, pClass, nState, GetAction('disable'), null, pNames[6]);
        PERFORM AddMethod(null, pClass, nState, GetAction('delete'), null, pNames[7]);

    WHEN 'enabled' THEN

      nState := AddState(pClass, rec_type.id, rec_type.code, pNames[2]);

        PERFORM AddMethod(null, pClass, nState, GetAction('disable'), null, pNames[6]);
        PERFORM AddMethod(null, pClass, nState, GetAction('delete'), null, pNames[7]);

    WHEN 'disabled' THEN

      nState := AddState(pClass, rec_type.id, rec_type.code, pNames[3]);

        PERFORM AddMethod(null, pClass, nState, GetAction('enable'), null, pNames[5]);
        PERFORM AddMethod(null, pClass, nState, GetAction('delete'), null, pNames[7]);

    WHEN 'deleted' THEN

      nState := AddState(pClass, rec_type.id, rec_type.code, pNames[4]);

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
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- InitWorkFlow ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION InitWorkFlow()
RETURNS     void
AS $$
BEGIN
  PERFORM AddAction('anything', 'Ничто');

  PERFORM AddAction('create', 'Создать');
  PERFORM AddAction('open', 'Открыть');
  PERFORM AddAction('edit', 'Изменить');
  PERFORM AddAction('save', 'Сохранить');
  PERFORM AddAction('enable', 'Включить');
  PERFORM AddAction('disable', 'Отключить');
  PERFORM AddAction('delete', 'Удалить');
  PERFORM AddAction('restore', 'Восстановить');
  PERFORM AddAction('update', 'Обновить');
  PERFORM AddAction('drop', 'Уничтожить');
  PERFORM AddAction('start', 'Запустить');
  PERFORM AddAction('stop', 'Остановить');
  PERFORM AddAction('check', 'Проверить');
  PERFORM AddAction('cancel', 'Отменить');
  PERFORM AddAction('postpone', 'Отложить');
  PERFORM AddAction('reserve', 'Резервировать');
  PERFORM AddAction('return', 'Вернуть');
  PERFORM AddAction('submit', 'Отправить');
  PERFORM AddAction('send', 'Отправить');
  PERFORM AddAction('abort', 'Прервать');
  PERFORM AddAction('repeat', 'Повторить');
  PERFORM AddAction('confirm', 'Подтвердить');
  PERFORM AddAction('reconfirm', 'Переподтвердить');
  PERFORM AddAction('execute', 'Выполнить');
  PERFORM AddAction('complete', 'Завершить');
  PERFORM AddAction('plan', 'Планировать');

  ------------------------------------------------------------------------------

  PERFORM AddAction('done', 'Сделано');
  PERFORM AddAction('fail', 'Неудача');
  PERFORM AddAction('expire', 'Истекло');
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
