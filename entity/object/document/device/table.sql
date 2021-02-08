--------------------------------------------------------------------------------
-- DEVICE ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.device -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.device (
    id                  numeric(12) PRIMARY KEY,
    document            numeric(12) NOT NULL,
    model               numeric(12) NOT NULL,
    client				numeric(12),
    identity            text NOT NULL,
    version             text,
    serial              text,
    address				text,
    iccid               text,
    imsi                text,
    CONSTRAINT fk_device_document FOREIGN KEY (document) REFERENCES db.document(id),
    CONSTRAINT fk_device_client FOREIGN KEY (client) REFERENCES db.client(id)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.device IS 'Устройство.';

COMMENT ON COLUMN db.device.id IS 'Идентификатор.';
COMMENT ON COLUMN db.device.document IS 'Документ.';
COMMENT ON COLUMN db.device.model IS 'Идентификатор модели.';
COMMENT ON COLUMN db.device.client IS 'Идентификатор клиента.';
COMMENT ON COLUMN db.device.identity IS 'Строковый идентификатор.';
COMMENT ON COLUMN db.device.version IS 'Версия.';
COMMENT ON COLUMN db.device.serial IS 'Серийный номер.';
COMMENT ON COLUMN db.device.address IS 'Сетевой адрес.';
COMMENT ON COLUMN db.device.iccid IS 'Integrated circuit card identifier (ICCID) — уникальный серийный номер SIM-карты.';
COMMENT ON COLUMN db.device.imsi IS 'International Mobile Subscriber Identity (IMSI) — международный идентификатор мобильного абонента (индивидуальный номер абонента).';

--------------------------------------------------------------------------------

CREATE INDEX ON db.device (document);

CREATE UNIQUE INDEX ON db.device (identity);
CREATE UNIQUE INDEX ON db.device (model, serial);

CREATE INDEX ON db.device (model);
CREATE INDEX ON db.device (client);
CREATE INDEX ON db.device (serial);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_device_before_insert()
RETURNS trigger AS $$
DECLARE
  nOwner		numeric;
  nUserId		numeric;
BEGIN
  IF NEW.id IS NULL OR NEW.id = 0 THEN
    SELECT NEW.document INTO NEW.id;
  END IF;

  IF NEW.client IS NOT NULL THEN
    SELECT owner INTO nOwner FROM db.object WHERE id = NEW.document;

    nUserId := GetClientUserId(NEW.client);
    IF nOwner <> nUserId THEN
      UPDATE db.aou SET allow = allow | B'110' WHERE object = NEW.document AND userid = nUserId;
      IF NOT FOUND THEN
        INSERT INTO db.aou SELECT NEW.document, nUserId, B'000', B'110';
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_device_before_insert
  BEFORE INSERT ON db.device
  FOR EACH ROW
  EXECUTE PROCEDURE ft_device_before_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_device_before_update()
RETURNS trigger AS $$
DECLARE
  nOwner		numeric;
  nUserId		numeric;
BEGIN
  IF OLD.client <> NEW.client THEN
    SELECT owner INTO nOwner FROM db.object WHERE id = NEW.document;

    IF NEW.client IS NOT NULL THEN
      nUserId := GetClientUserId(NEW.client);
      IF nOwner <> nUserId THEN
        UPDATE db.aou SET allow = allow | B'110' WHERE object = NEW.document AND userid = nUserId;
        IF NOT found THEN
          INSERT INTO db.aou SELECT NEW.document, nUserId, B'000', B'110';
        END IF;
      END IF;
    END IF;

    IF OLD.client IS NOT NULL THEN
      nUserId := GetClientUserId(OLD.client);
      IF nOwner <> nUserId THEN
        DELETE FROM db.aou WHERE object = OLD.document AND userid = nUserId;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_device_before_update
  BEFORE UPDATE ON db.device
  FOR EACH ROW
  EXECUTE PROCEDURE ft_device_before_update();

--------------------------------------------------------------------------------
-- db.device_notification ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.device_notification (
    id              numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_STATUS'),
    device          numeric(12) NOT NULL,
    interfaceId		integer NOT NULL DEFAULT 0,
    status          text NOT NULL,
    errorCode       text NOT NULL,
    info            text,
    vendorErrorCode	text,
    validFromDate	timestamp DEFAULT NOW() NOT NULL,
    validToDate		timestamp DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL,
    CONSTRAINT fk_device_notification_device FOREIGN KEY (device) REFERENCES db.device(id)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.device_notification IS 'Уведомление о статусе устройства.';

COMMENT ON COLUMN db.device_notification.id IS 'Идентификатор.';
COMMENT ON COLUMN db.device_notification.device IS 'Идентификатор устройства.';
COMMENT ON COLUMN db.device_notification.interfaceId IS 'Идентификатор цифрового интерфейса или порта (при налиции). Где: 0 - это само устройство.';
COMMENT ON COLUMN db.device_notification.status IS 'Текущий статус устройства.';
COMMENT ON COLUMN db.device_notification.errorCode IS 'Код ошибки, сообщенный устройством.';
COMMENT ON COLUMN db.device_notification.info IS 'Дополнительная информация в свободном формате, связанная с ошибкой.';
COMMENT ON COLUMN db.device_notification.vendorErrorCode IS 'Код ошибки производителя.';
COMMENT ON COLUMN db.device_notification.validFromDate IS 'Дата начала периода действия';
COMMENT ON COLUMN db.device_notification.validToDate IS 'Дата окончания периода действия.';

--------------------------------------------------------------------------------

CREATE INDEX ON db.device_notification (device);
CREATE INDEX ON db.device_notification (interfaceId);
CREATE INDEX ON db.device_notification (device, validFromDate, validToDate);

CREATE UNIQUE INDEX ON db.device_notification (device, interfaceId, validFromDate, validToDate);

--------------------------------------------------------------------------------
-- db.device_value -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.device_value (
    id			    numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_STATUS'),
    device          numeric(12) NOT NULL,
    type			integer NOT NULL,
    value			jsonb NOT NULL,
    validFromDate	timestamp DEFAULT NOW() NOT NULL,
    validToDate		timestamp DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL,
    CONSTRAINT fk_device_value_device FOREIGN KEY (device) REFERENCES db.device(id)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.device_value IS 'Значения устройства.';

COMMENT ON COLUMN db.device_value.id IS 'Идентификатор.';
COMMENT ON COLUMN db.device_value.device IS 'Устройство.';
COMMENT ON COLUMN db.device_value.type IS 'Тип.';
COMMENT ON COLUMN db.device_value.value IS 'Значение.';
COMMENT ON COLUMN db.device_value.validFromDate IS 'Дата начала периода действия';
COMMENT ON COLUMN db.device_value.validToDate IS 'Дата окончания периода действия.';

--------------------------------------------------------------------------------

CREATE INDEX ON db.device_value (device);
CREATE INDEX ON db.device_value (type);

CREATE UNIQUE INDEX ON db.device_value (device, type, validFromDate, validToDate);

