--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddDeviceMethods ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddDeviceMethods (
  pClass        numeric
)
RETURNS void
AS $$
DECLARE
  nState        numeric;

  rec_type      record;
  rec_state     record;
  rec_method    record;
BEGIN
  -- Операции (без учёта состояния)

  PERFORM DefaultMethods(pClass);

  -- Операции (с учётом состояния)

  FOR rec_type IN SELECT * FROM StateType
  LOOP

    CASE rec_type.code
    WHEN 'created' THEN

      nState := AddState(pClass, rec_type.id, rec_type.code, 'Создано');

        PERFORM AddMethod(null, pClass, nState, GetAction('enable'), null, 'Включить');
        PERFORM AddMethod(null, pClass, nState, GetAction('delete'), null, 'Удалить');

    WHEN 'enabled' THEN

      nState := AddState(pClass, rec_type.id, 'available', 'Доступно');

        PERFORM AddMethod(null, pClass, nState, GetAction('heartbeat'), null, 'Heartbeat', null, false);

        PERFORM AddMethod(null, pClass, nState, GetAction('available'), null, 'Доступно', null, false);
        PERFORM AddMethod(null, pClass, nState, GetAction('unavailable'), null, 'Недоступно', null, false);
        PERFORM AddMethod(null, pClass, nState, GetAction('faulted'), null, 'Неисправно', null, false);

        PERFORM AddMethod(null, pClass, nState, GetAction('disable'), null, 'Отключить');

      nState := AddState(pClass, rec_type.id, 'unavailable', 'Недоступно');

        PERFORM AddMethod(null, pClass, nState, GetAction('heartbeat'), null, 'Heartbeat', null, false);

        PERFORM AddMethod(null, pClass, nState, GetAction('available'), null, 'Доступно', null, false);
        PERFORM AddMethod(null, pClass, nState, GetAction('unavailable'), null, 'Недоступно', null, false);
        PERFORM AddMethod(null, pClass, nState, GetAction('faulted'), null, 'Неисправно', null, false);

        PERFORM AddMethod(null, pClass, nState, GetAction('disable'), null, 'Отключить');

      nState := AddState(pClass, rec_type.id, 'faulted', 'Неисправно');

        PERFORM AddMethod(null, pClass, nState, GetAction('heartbeat'), null, 'Heartbeat', null, false);

        PERFORM AddMethod(null, pClass, nState, GetAction('available'), null, 'Доступно', null, false);
        PERFORM AddMethod(null, pClass, nState, GetAction('unavailable'), null, 'Недоступно');
        PERFORM AddMethod(null, pClass, nState, GetAction('faulted'), null, 'Неисправно', null, false);

        PERFORM AddMethod(null, pClass, nState, GetAction('disable'), null, 'Отключить');

    WHEN 'disabled' THEN

      nState := AddState(pClass, rec_type.id, rec_type.code, 'Отключено');

        PERFORM AddMethod(null, pClass, nState, GetAction('enable'), null, 'Включить');
        PERFORM AddMethod(null, pClass, nState, GetAction('delete'), null, 'Удалить');

    WHEN 'deleted' THEN

      nState := AddState(pClass, rec_type.id, rec_type.code, 'Удалено');

        PERFORM AddMethod(null, pClass, nState, GetAction('restore'), null, 'Восстановить');
        PERFORM AddMethod(null, pClass, nState, GetAction('drop'), null, 'Уничтожить');

    END CASE;

  END LOOP;

  PERFORM DefaultTransition(pClass);

  FOR rec_state IN SELECT * FROM State WHERE class = pClass
  LOOP
    CASE rec_state.code
    WHEN 'created' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'enable' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'unavailable'));
        END IF;

        IF rec_method.actioncode = 'delete' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'deleted'));
        END IF;
      END LOOP;

    WHEN 'available' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'unavailable' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'unavailable'));
        END IF;

        IF rec_method.actioncode = 'faulted' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'faulted'));
        END IF;

        IF rec_method.actioncode = 'disable' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'disabled'));
        END IF;
      END LOOP;

    WHEN 'unavailable' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'available' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'available'));
        END IF;

        IF rec_method.actioncode = 'faulted' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'faulted'));
        END IF;

        IF rec_method.actioncode = 'disable' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'disabled'));
        END IF;
      END LOOP;

    WHEN 'faulted' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'available' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'available'));
        END IF;

        IF rec_method.actioncode = 'unavailable' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'unavailable'));
        END IF;

        IF rec_method.actioncode = 'disable' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'disabled'));
        END IF;
      END LOOP;

    WHEN 'disabled' THEN

      FOR rec_method IN SELECT * FROM Method WHERE state = rec_state.id
      LOOP
        IF rec_method.actioncode = 'enable' THEN
          PERFORM AddTransition(rec_state.id, rec_method.id, GetState(pClass, 'unavailable'));
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
-- AddDeviceEvents -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddDeviceEvents (
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
	  PERFORM AddEvent(pClass, nEvent, r.id, 'Устройство создано', 'EventDeviceCreate();');
	END IF;

	IF r.code = 'open' THEN
	  PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
	  PERFORM AddEvent(pClass, nEvent, r.id, 'Устройство открыто', 'EventDeviceOpen();');
	END IF;

	IF r.code = 'edit' THEN
	  PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
	  PERFORM AddEvent(pClass, nEvent, r.id, 'Устройство измено', 'EventDeviceEdit();');
	END IF;

	IF r.code = 'save' THEN
	  PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
	  PERFORM AddEvent(pClass, nEvent, r.id, 'Устройство сохрано', 'EventDeviceSave();');
	END IF;

	IF r.code = 'enable' THEN
	  PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
	  PERFORM AddEvent(pClass, nEvent, r.id, 'Устройство включено', 'EventDeviceEnable();');
	END IF;

	IF r.code = 'heartbeat' THEN
	  PERFORM AddEvent(pClass, nEvent, r.id, 'Устройство на связи', 'EventDeviceHeartbeat();');
	END IF;

	IF r.code = 'available' THEN
	  PERFORM AddEvent(pClass, nEvent, r.id, 'Устройство доступно', 'EventDeviceAvailable();');
	  PERFORM AddEvent(pClass, nEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
	END IF;

	IF r.code = 'unavailable' THEN
	  PERFORM AddEvent(pClass, nEvent, r.id, 'Устройство недоступно', 'EventDeviceUnavailable();');
	  PERFORM AddEvent(pClass, nEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
	END IF;

	IF r.code = 'faulted' THEN
	  PERFORM AddEvent(pClass, nEvent, r.id, 'Устройство неисправно', 'EventDeviceFaulted();');
	  PERFORM AddEvent(pClass, nEvent, r.id, 'Смена состояния', 'ChangeObjectState();');
	END IF;

	IF r.code = 'disable' THEN
	  PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
	  PERFORM AddEvent(pClass, nEvent, r.id, 'Устройство отключено', 'EventDeviceDisable();');
	END IF;

	IF r.code = 'delete' THEN
	  PERFORM AddEvent(pClass, nEvent, r.id, 'Устройство будет удалено', 'EventDeviceDelete();');
	  PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
	END IF;

	IF r.code = 'restore' THEN
	  PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
	  PERFORM AddEvent(pClass, nEvent, r.id, 'Устройство восстановлено', 'EventDeviceRestore();');
	END IF;

	IF r.code = 'drop' THEN
	  PERFORM AddEvent(pClass, nEvent, r.id, 'Устройство будет уничтожено', 'EventDeviceDrop();');
	  PERFORM AddEvent(pClass, nParent, r.id, 'События класса родителя');
	END IF;

  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassDevice -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassDevice (
  pParent       numeric,
  pEntity       numeric
)
RETURNS         numeric
AS $$
DECLARE
  nClass        numeric;
BEGIN
  -- Класс
  nClass := AddClass(pParent, pEntity, 'device', 'Устройство', false);

  -- Тип
  PERFORM AddType(nClass, 'iot.device', 'IoT', 'Интернет вещь.');
  PERFORM AddType(nClass, 'mobile.device', 'Мобильное', 'Мобильное устройство.');
  PERFORM AddType(nClass, 'other.device', 'Иное', 'Иное.');

  -- Событие
  PERFORM AddDeviceEvents(nClass);

  -- Метод
  PERFORM AddDeviceMethods(nClass);

  RETURN nClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityDevice ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityDevice (
  pParent       numeric
)
RETURNS         numeric
AS $$
DECLARE
  nEntity       numeric;
BEGIN
  -- Сущность
  nEntity := AddEntity('device', 'Устройство');

  -- Класс
  PERFORM CreateClassDevice(pParent, nEntity);

  -- API
  PERFORM RegisterRoute('device', AddEndpoint('SELECT * FROM rest.device($1, $2);'));

  RETURN nEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Actions ---------------------------------------------------------------------
--------------------------------------------------------------------------------

SELECT AddAction('heartbeat', 'Heartbeat');

SELECT AddAction('available', 'Available');
SELECT AddAction('preparing', 'Preparing');
SELECT AddAction('finishing', 'Finishing');
SELECT AddAction('reserved', 'Reserved');
SELECT AddAction('unavailable', 'Unavailable');
SELECT AddAction('faulted', 'Faulted');

