--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- DefaultMethods --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DefaultMethods (
  pClass            uuid
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
  pClass            uuid
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
  pClass            uuid,
  pNames            text[] DEFAULT null
)
RETURNS             void
AS $$
DECLARE
  nState            uuid;

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

  INSERT INTO db.state_type (id, code, name) VALUES ('00000000-0000-4000-b001-000000000001', 'created', 'Создан');
  INSERT INTO db.state_type (id, code, name) VALUES ('00000000-0000-4000-b001-000000000002', 'enabled', 'Включен');
  INSERT INTO db.state_type (id, code, name) VALUES ('00000000-0000-4000-b001-000000000003', 'disabled', 'Отключен');
  INSERT INTO db.state_type (id, code, name) VALUES ('00000000-0000-4000-b001-000000000004', 'deleted', 'Удалён');

  --------------------------------------------------------------------------------

  INSERT INTO db.event_type (id, code, name) VALUES ('00000000-0000-4000-b002-000000000001', 'parent', 'События класса родителя');
  INSERT INTO db.event_type (id, code, name) VALUES ('00000000-0000-4000-b002-000000000002', 'event', 'Событие');
  INSERT INTO db.event_type (id, code, name) VALUES ('00000000-0000-4000-b002-000000000003', 'plpgsql', 'PL/pgSQL код');

  --------------------------------------------------------------------------------

  PERFORM AddAction('00000000-0000-4000-b003-000000000000', 'anything', 'Ничто');

  PERFORM AddAction('00000000-0000-4000-b003-000000000001', 'abort', 'Прервать');
  PERFORM AddAction('00000000-0000-4000-b003-000000000002', 'accept', 'Принять');
  PERFORM AddAction('00000000-0000-4000-b003-000000000003', 'add', 'Добавить');
  PERFORM AddAction('00000000-0000-4000-b003-000000000004', 'alarm', 'Тревога');
  PERFORM AddAction('00000000-0000-4000-b003-000000000005', 'approve', 'Утвердить');
  PERFORM AddAction('00000000-0000-4000-b003-000000000006', 'available', 'Доступен');
  PERFORM AddAction('00000000-0000-4000-b003-000000000007', 'cancel', 'Отменить');
  PERFORM AddAction('00000000-0000-4000-b003-000000000008', 'check', 'Проверить');
  PERFORM AddAction('00000000-0000-4000-b003-000000000009', 'complete', 'Завершить');
  PERFORM AddAction('00000000-0000-4000-b003-000000000010', 'confirm', 'Подтвердить');
  PERFORM AddAction('00000000-0000-4000-b003-000000000011', 'create', 'Создать');
  PERFORM AddAction('00000000-0000-4000-b003-000000000012', 'delete', 'Удалить');
  PERFORM AddAction('00000000-0000-4000-b003-000000000013', 'disable', 'Отключить');
  PERFORM AddAction('00000000-0000-4000-b003-000000000014', 'done', 'Сделано');
  PERFORM AddAction('00000000-0000-4000-b003-000000000015', 'drop', 'Уничтожить');
  PERFORM AddAction('00000000-0000-4000-b003-000000000016', 'edit', 'Изменить');
  PERFORM AddAction('00000000-0000-4000-b003-000000000017', 'enable', 'Включить');
  PERFORM AddAction('00000000-0000-4000-b003-000000000018', 'execute', 'Выполнить');
  PERFORM AddAction('00000000-0000-4000-b003-000000000019', 'expire', 'Истекло');
  PERFORM AddAction('00000000-0000-4000-b003-000000000020', 'fail', 'Неудача');
  PERFORM AddAction('00000000-0000-4000-b003-000000000021', 'faulted', 'Ошибка');
  PERFORM AddAction('00000000-0000-4000-b003-000000000022', 'finishing', 'Завершение');
  PERFORM AddAction('00000000-0000-4000-b003-000000000023', 'heartbeat', 'Сердцебиение');
  PERFORM AddAction('00000000-0000-4000-b003-000000000024', 'invite', 'Пригласить');
  PERFORM AddAction('00000000-0000-4000-b003-000000000025', 'open', 'Открыть');
  PERFORM AddAction('00000000-0000-4000-b003-000000000026', 'plan', 'Планировать');
  PERFORM AddAction('00000000-0000-4000-b003-000000000027', 'post', 'Публиковать');
  PERFORM AddAction('00000000-0000-4000-b003-000000000028', 'postpone', 'Отложить');
  PERFORM AddAction('00000000-0000-4000-b003-000000000029', 'preparing', 'Подготовка');
  PERFORM AddAction('00000000-0000-4000-b003-000000000030', 'reconfirm', 'Переподтвердить');
  PERFORM AddAction('00000000-0000-4000-b003-000000000031', 'remove', 'Удалить');
  PERFORM AddAction('00000000-0000-4000-b003-000000000032', 'repeat', 'Повторить');
  PERFORM AddAction('00000000-0000-4000-b003-000000000033', 'reserve', 'Резервировать');
  PERFORM AddAction('00000000-0000-4000-b003-000000000034', 'reserved', 'Зарезервирован');
  PERFORM AddAction('00000000-0000-4000-b003-000000000035', 'restore', 'Восстановить');
  PERFORM AddAction('00000000-0000-4000-b003-000000000036', 'return', 'Вернуть');
  PERFORM AddAction('00000000-0000-4000-b003-000000000037', 'save', 'Сохранить');
  PERFORM AddAction('00000000-0000-4000-b003-000000000038', 'send', 'Отправить');
  PERFORM AddAction('00000000-0000-4000-b003-000000000039', 'sign', 'Подписать');
  PERFORM AddAction('00000000-0000-4000-b003-000000000040', 'start', 'Запустить');
  PERFORM AddAction('00000000-0000-4000-b003-000000000041', 'stop', 'Остановить');
  PERFORM AddAction('00000000-0000-4000-b003-000000000042', 'submit', 'Отправить');
  PERFORM AddAction('00000000-0000-4000-b003-000000000043', 'unavailable', 'Недоступен');
  PERFORM AddAction('00000000-0000-4000-b003-000000000044', 'update', 'Обновить');

  PERFORM AddAction('00000000-0000-4000-b003-000000000045', 'reject', 'Отклонить');
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
