--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- DefaultMethods --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DefaultMethods (
  pClass    uuid
)
RETURNS     void
AS $$
DECLARE
  uMethod   uuid;
  uLocale   uuid;
BEGIN
  uLocale := GetLocale('en');

  uMethod := AddMethod(null, pClass, null, GetAction('create'), null, 'Создать');
  PERFORM EditMethodText(uMethod, 'Create', uLocale);

  uMethod := AddMethod(null, pClass, null, GetAction('open'), null, 'Открыть');
  PERFORM EditMethodText(uMethod, 'Open', uLocale);

  uMethod := AddMethod(null, pClass, null, GetAction('edit'), null, 'Изменить');
  PERFORM EditMethodText(uMethod, 'Edit', uLocale);

  uMethod := AddMethod(null, pClass, null, GetAction('save'), null, 'Сохранить');
  PERFORM EditMethodText(uMethod, 'Save', uLocale);

  uMethod := AddMethod(null, pClass, null, GetAction('enable'), null, 'Включить');
  PERFORM EditMethodText(uMethod, 'Enable', uLocale);

  uMethod := AddMethod(null, pClass, null, GetAction('disable'), null, 'Выключить');
  PERFORM EditMethodText(uMethod, 'Disable', uLocale);

  uMethod := AddMethod(null, pClass, null, GetAction('delete'), null, 'Удалить');
  PERFORM EditMethodText(uMethod, 'Delete', uLocale);

  uMethod := AddMethod(null, pClass, null, GetAction('restore'), null, 'Восстановить');
  PERFORM EditMethodText(uMethod, 'Restore', uLocale);

  uMethod := AddMethod(null, pClass, null, GetAction('drop'), null, 'Уничтожить');
  PERFORM EditMethodText(uMethod, 'Drop', uLocale);
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
  pClass        uuid,
  pNamesRU      text[] DEFAULT null,
  pNamesEN      text[] DEFAULT null
)
RETURNS         void
AS $$
DECLARE
  uState        uuid;
  uMethod       uuid;
  uLocale       uuid;

  rec_type      record;
  rec_state     record;
  rec_method    record;
BEGIN
  uLocale := GetLocale('en');

  IF pNamesRU IS NULL THEN
    pNamesRU := array_cat(pNamesRU, ARRAY['Создан', 'Открыт', 'Закрыт', 'Удалён', 'Открыть', 'Закрыть', 'Удалить']);
  END IF;

  IF pNamesEN IS NULL THEN
    pNamesEN := array_cat(pNamesEN, ARRAY['Created', 'Opened', 'Closed', 'Deleted', 'Open', 'Close', 'Delete']);
  END IF;

  -- Операции (без учёта состояния)

  PERFORM DefaultMethods(pClass);

  -- Операции (с учётом состояния)

  FOR rec_type IN SELECT * FROM StateType
  LOOP

    CASE rec_type.code
    WHEN 'created' THEN

      uState := AddState(pClass, rec_type.id, rec_type.code, pNamesRU[1]);
      PERFORM EditStateText(uState, pNamesEN[1], uLocale);

        uMethod := AddMethod(null, pClass, uState, GetAction('enable'), null, pNamesRU[5]);
        PERFORM EditMethodText(uMethod, pNamesEN[5], uLocale);

        uMethod := AddMethod(null, pClass, uState, GetAction('disable'), null, pNamesRU[6]);
        PERFORM EditMethodText(uMethod, pNamesEN[6], uLocale);

        uMethod := AddMethod(null, pClass, uState, GetAction('delete'), null, pNamesRU[7]);
        PERFORM EditMethodText(uMethod, pNamesEN[7], uLocale);

    WHEN 'enabled' THEN

      uState := AddState(pClass, rec_type.id, rec_type.code, pNamesRU[2]);
      PERFORM EditStateText(uState, pNamesEN[2], uLocale);

        uMethod := AddMethod(null, pClass, uState, GetAction('disable'), null, pNamesRU[6]);
        PERFORM EditMethodText(uMethod, pNamesEN[6], uLocale);

        uMethod := AddMethod(null, pClass, uState, GetAction('delete'), null, pNamesRU[7]);
        PERFORM EditMethodText(uMethod, pNamesEN[7], uLocale);

    WHEN 'disabled' THEN

      uState := AddState(pClass, rec_type.id, rec_type.code, pNamesRU[3]);
      PERFORM EditStateText(uState, pNamesEN[3], uLocale);

        uMethod := AddMethod(null, pClass, uState, GetAction('enable'), null, pNamesRU[5]);
        PERFORM EditMethodText(uMethod, pNamesEN[5], uLocale);

        uMethod := AddMethod(null, pClass, uState, GetAction('delete'), null, pNamesRU[7]);
        PERFORM EditMethodText(uMethod, pNamesEN[7], uLocale);

    WHEN 'deleted' THEN

      uState := AddState(pClass, rec_type.id, rec_type.code, pNamesRU[4]);
      PERFORM EditStateText(uState, pNamesEN[4], uLocale);

        uMethod := AddMethod(null, pClass, uState, GetAction('restore'));
        PERFORM EditMethodText(uMethod, 'Restore', uLocale);

        uMethod := AddMethod(null, pClass, uState, GetAction('drop'));
        PERFORM EditMethodText(uMethod, 'Drop', uLocale);

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
DECLARE
  uLocale   uuid;
  uAction   uuid;
  uPriority uuid;
BEGIN
  INSERT INTO db.state_type (id, code) VALUES ('00000000-0000-4000-b001-000000000001', 'created');
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000001', 'Created', GetLocale('en'));
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000001', 'Создан', GetLocale('ru'));

  INSERT INTO db.state_type (id, code) VALUES ('00000000-0000-4000-b001-000000000002', 'enabled');
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000002', 'Enabled', GetLocale('en'));
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000002', 'Включен', GetLocale('ru'));

  INSERT INTO db.state_type (id, code) VALUES ('00000000-0000-4000-b001-000000000003', 'disabled');
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000003', 'Disabled', GetLocale('en'));
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000003', 'Отключен', GetLocale('ru'));

  INSERT INTO db.state_type (id, code) VALUES ('00000000-0000-4000-b001-000000000004', 'deleted');
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000004', 'Deleted', GetLocale('en'));
  INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000004', 'Удалён', GetLocale('ru'));

  --------------------------------------------------------------------------------

  INSERT INTO db.event_type (id, code) VALUES ('00000000-0000-4000-b002-000000000001', 'parent');
  INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000001', 'Parent class events', GetLocale('en'));
  INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000001', 'События класса родителя', GetLocale('ru'));

  INSERT INTO db.event_type (id, code) VALUES ('00000000-0000-4000-b002-000000000002', 'event');
  INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000002', 'Event', GetLocale('en'));
  INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000002', 'Событие', GetLocale('ru'));

  INSERT INTO db.event_type (id, code) VALUES ('00000000-0000-4000-b002-000000000003', 'plpgsql');
  INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000003', 'PL/pgSQL code', GetLocale('en'));
  INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000003', 'PL/pgSQL код', GetLocale('ru'));

  --------------------------------------------------------------------------------

  uLocale := GetLocale('en');

  uAction := AddAction('00000000-0000-4000-b003-000000000000', 'anything', 'Ничто');
  PERFORM EditActionText(uAction, 'Anything', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000001', 'abort', 'Прервать');
  PERFORM EditActionText(uAction, 'Abort', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000002', 'accept', 'Принять');
  PERFORM EditActionText(uAction, 'Accept', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000003', 'add', 'Добавить');
  PERFORM EditActionText(uAction, 'Add', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000004', 'alarm', 'Тревога');
  PERFORM EditActionText(uAction, 'Alarm', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000005', 'approve', 'Утвердить');
  PERFORM EditActionText(uAction, 'Approve', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000006', 'available', 'Доступен');
  PERFORM EditActionText(uAction, 'Available', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000007', 'cancel', 'Отменить');
  PERFORM EditActionText(uAction, 'Cancel', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000008', 'check', 'Проверить');
  PERFORM EditActionText(uAction, 'Check', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000009', 'complete', 'Завершить');
  PERFORM EditActionText(uAction, 'Complete', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000010', 'confirm', 'Подтвердить');
  PERFORM EditActionText(uAction, 'Confirm', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000011', 'create', 'Создать');
  PERFORM EditActionText(uAction, 'Create', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000012', 'delete', 'Удалить');
  PERFORM EditActionText(uAction, 'Delete', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000013', 'disable', 'Отключить');
  PERFORM EditActionText(uAction, 'Disable', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000014', 'done', 'Сделано');
  PERFORM EditActionText(uAction, 'Done', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000015', 'drop', 'Уничтожить');
  PERFORM EditActionText(uAction, 'Drop', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000016', 'edit', 'Изменить');
  PERFORM EditActionText(uAction, 'Edit', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000017', 'enable', 'Включить');
  PERFORM EditActionText(uAction, 'Enable', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000018', 'execute', 'Выполнить');
  PERFORM EditActionText(uAction, 'Execute', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000019', 'expire', 'Истекло');
  PERFORM EditActionText(uAction, 'Expire', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000020', 'fail', 'Неудача');
  PERFORM EditActionText(uAction, 'Fail', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000021', 'faulted', 'Ошибка');
  PERFORM EditActionText(uAction, 'Faulted', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000022', 'finishing', 'Завершение');
  PERFORM EditActionText(uAction, 'Finishing', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000023', 'heartbeat', 'Сердцебиение');
  PERFORM EditActionText(uAction, 'Heartbeat', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000024', 'invite', 'Пригласить');
  PERFORM EditActionText(uAction, 'Invite', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000025', 'open', 'Открыть');
  PERFORM EditActionText(uAction, 'Open', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000026', 'plan', 'Планировать');
  PERFORM EditActionText(uAction, 'Plan', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000027', 'post', 'Публиковать');
  PERFORM EditActionText(uAction, 'Post', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000028', 'postpone', 'Отложить');
  PERFORM EditActionText(uAction, 'Postpone', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000029', 'preparing', 'Подготовка');
  PERFORM EditActionText(uAction, 'Preparing', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000030', 'reconfirm', 'Переподтвердить');
  PERFORM EditActionText(uAction, 'Reconfirm', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000031', 'remove', 'Удалить');
  PERFORM EditActionText(uAction, 'Remove', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000032', 'repeat', 'Повторить');
  PERFORM EditActionText(uAction, 'Repeat', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000033', 'reserve', 'Резервировать');
  PERFORM EditActionText(uAction, 'Reserve', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000034', 'reserved', 'Зарезервирован');
  PERFORM EditActionText(uAction, 'Reserved', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000035', 'restore', 'Восстановить');
  PERFORM EditActionText(uAction, 'Restore', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000036', 'return', 'Вернуть');
  PERFORM EditActionText(uAction, 'Return', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000037', 'save', 'Сохранить');
  PERFORM EditActionText(uAction, 'Save', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000038', 'send', 'Отправить');
  PERFORM EditActionText(uAction, 'Send', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000039', 'sign', 'Подписать');
  PERFORM EditActionText(uAction, 'Sign', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000040', 'start', 'Запустить');
  PERFORM EditActionText(uAction, 'Start', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000041', 'stop', 'Остановить');
  PERFORM EditActionText(uAction, 'Stop', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000042', 'submit', 'Отправить');
  PERFORM EditActionText(uAction, 'Submit', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000043', 'unavailable', 'Недоступен');
  PERFORM EditActionText(uAction, 'Unavailable', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000044', 'update', 'Обновить');
  PERFORM EditActionText(uAction, 'Update', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000045', 'reject', 'Отклонить');
  PERFORM EditActionText(uAction, 'Reject', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000046', 'pay', 'Оплатить');
  PERFORM EditActionText(uAction, 'Pay', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000047', 'continue', 'Продолжить');
  PERFORM EditActionText(uAction, 'Continue', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000048', 'agree', 'Согласовать');
  PERFORM EditActionText(uAction, 'Agree', null, uLocale);

  uAction := AddAction('00000000-0000-4000-b003-000000000049', 'close', 'Закрыть');
  PERFORM EditActionText(uAction, 'Close', null, uLocale);

  --

  uPriority := AddPriority('00000000-0000-4000-b004-000000000000', 'low', 'Низкий');
  PERFORM EditPriorityText(uPriority, 'Low', null, uLocale);

  uPriority := AddPriority('00000000-0000-4000-b004-000000000001', 'medium', 'Средний');
  PERFORM EditPriorityText(uPriority, 'Medium', null, uLocale);

  uPriority := AddPriority('00000000-0000-4000-b004-000000000002', 'high', 'Высокий');
  PERFORM EditPriorityText(uPriority, 'High', null, uLocale);

  uPriority := AddPriority('00000000-0000-4000-b004-000000000003', 'critical', 'Критический');
  PERFORM EditPriorityText(uPriority, 'Critical', null, uLocale);
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
