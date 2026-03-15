--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AddVendorEvents -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddVendorEvents (
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
      PERFORM AddEvent(pClass, uEvent, r.id, 'Vendor created', 'EventVendorCreate();');
    END IF;

    IF r.code = 'open' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Vendor opened', 'EventVendorOpen();');
    END IF;

    IF r.code = 'edit' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Vendor edited', 'EventVendorEdit();');
    END IF;

    IF r.code = 'save' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Vendor saved', 'EventVendorSave();');
    END IF;

    IF r.code = 'enable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Vendor enabled', 'EventVendorEnable();');
    END IF;

    IF r.code = 'disable' THEN
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
      PERFORM AddEvent(pClass, uEvent, r.id, 'Vendor disabled', 'EventVendorDisable();');
    END IF;

    IF r.code = 'delete' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Vendor will be deleted', 'EventVendorDelete();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

    IF r.code = 'restore' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Vendor restored', 'EventVendorRestore();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

    IF r.code = 'drop' THEN
      PERFORM AddEvent(pClass, uEvent, r.id, 'Vendor will be dropped', 'EventVendorDrop();');
      PERFORM AddEvent(pClass, uParent, r.id, 'Parent class events');
    END IF;

  END LOOP;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateClassVendor -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateClassVendor (
  pParent       uuid,
  pEntity       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uClass        uuid;
BEGIN
  -- Класс
  uClass := AddClass(pParent, pEntity, 'vendor', 'Vendor', false);
  PERFORM EditClassText(uClass, 'Производитель', GetLocale('ru'));
  PERFORM EditClassText(uClass, 'Anbieter', GetLocale('de'));
  PERFORM EditClassText(uClass, 'Fournisseur', GetLocale('fr'));
  PERFORM EditClassText(uClass, 'Fornitore', GetLocale('it'));
  PERFORM EditClassText(uClass, 'Proveedor', GetLocale('es'));

  -- Тип
  PERFORM AddType(uClass, 'service.vendor', 'Service', 'Service provider.');
  PERFORM EditTypeText(GetType('service.vendor'), 'Услуга', 'Поставщик услуги.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('service.vendor'), 'Dienstleistung', 'Dienstanbieter.', GetLocale('de'));
  PERFORM EditTypeText(GetType('service.vendor'), 'Service', 'Fournisseur de services.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('service.vendor'), 'Servizio', 'Fornitore di servizi.', GetLocale('it'));
  PERFORM EditTypeText(GetType('service.vendor'), 'Servicio', 'Proveedor de servicios.', GetLocale('es'));

  PERFORM AddType(uClass, 'device.vendor', 'Hardware', 'Hardware manufacturer.');
  PERFORM EditTypeText(GetType('device.vendor'), 'Оборудование', 'Производитель оборудования.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('device.vendor'), 'Hardware', 'Hardwarehersteller.', GetLocale('de'));
  PERFORM EditTypeText(GetType('device.vendor'), 'Matériel', 'Fabricant de matériel.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('device.vendor'), 'Hardware', 'Produttore hardware.', GetLocale('it'));
  PERFORM EditTypeText(GetType('device.vendor'), 'Hardware', 'Fabricante de hardware.', GetLocale('es'));

  PERFORM AddType(uClass, 'car.vendor', 'Automobile', 'Automobile manufacturer.');
  PERFORM EditTypeText(GetType('car.vendor'), 'Автомобиль', 'Производитель автомобилей.', GetLocale('ru'));
  PERFORM EditTypeText(GetType('car.vendor'), 'Automobil', 'Automobilhersteller.', GetLocale('de'));
  PERFORM EditTypeText(GetType('car.vendor'), 'Automobile', 'Constructeur automobile.', GetLocale('fr'));
  PERFORM EditTypeText(GetType('car.vendor'), 'Automobile', 'Costruttore automobili.', GetLocale('it'));
  PERFORM EditTypeText(GetType('car.vendor'), 'Automóvil', 'Fabricante de automóviles.', GetLocale('es'));

  -- Событие
  PERFORM AddVendorEvents(uClass);

  -- Метод
  PERFORM AddDefaultMethods(uClass);

  RETURN uClass;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateEntityVendor ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateEntityVendor (
  pParent       uuid
)
RETURNS         uuid
AS $$
DECLARE
  uEntity       uuid;
BEGIN
  -- Сущность
  uEntity := AddEntity('vendor', 'Vendor');
  PERFORM EditEntityText(uEntity, 'Производитель', null, GetLocale('ru'));
  PERFORM EditEntityText(uEntity, 'Anbieter', null, GetLocale('de'));
  PERFORM EditEntityText(uEntity, 'Fournisseur', null, GetLocale('fr'));
  PERFORM EditEntityText(uEntity, 'Fornitore', null, GetLocale('it'));
  PERFORM EditEntityText(uEntity, 'Proveedor', null, GetLocale('es'));

  -- Класс
  PERFORM CreateClassVendor(pParent, uEntity);

  -- API
  PERFORM RegisterRoute('vendor', AddEndpoint('SELECT * FROM rest.vendor($1, $2);'));

  RETURN uEntity;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
