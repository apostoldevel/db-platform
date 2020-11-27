--------------------------------------------------------------------------------
-- CLIENT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventClientCreate -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventClientCreate (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1010, 'Клиент создан.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventClientOpen -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventClientOpen (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1011, 'Клиент открыт на просмотр.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventClientEdit -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventClientEdit (
  pObject	numeric default context_object(),
  pForm		jsonb default context_form()
) RETURNS	void
AS $$
DECLARE
  old_email	jsonb;
  new_email	jsonb;
BEGIN
  old_email = pForm#>'{old, email}';
  new_email = pForm#>'{new, email}';

  IF coalesce(old_email, '{}') <> coalesce(new_email, '{}') THEN
    PERFORM EventMessageConfirmEmail(pObject, new_email);
  END IF;

  PERFORM WriteToEventLog('M', 1012, 'Клиент изменён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventClientSave -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventClientSave (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1013, 'Клиент сохранён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventClientEnable -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventClientEnable (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
DECLARE
  r             record;

  nId           numeric;
  nArea         numeric;
  nUserId       numeric;
  nInterface    numeric;
BEGIN
  SELECT userid INTO nUserId FROM db.client WHERE id = pObject;

  IF nUserId IS NOT NULL THEN
    PERFORM UserUnLock(nUserId);

    PERFORM DeleteGroupForMember(nUserId, GetGroup('guest'));

    PERFORM AddMemberToGroup(nUserId, GetGroup('user'));

    nArea := GetArea('default');
    SELECT * INTO nId FROM db.member_area WHERE area = nArea AND member = nUserId;
    IF NOT FOUND THEN
      PERFORM AddMemberToArea(nUserId, nArea);
      PERFORM SetDefaultArea(nArea, nUserId);
    END IF;

    nInterface := GetInterface('I:1:0:0');
    SELECT * INTO nId FROM db.member_interface WHERE interface = nInterface AND member = nUserId;
    IF NOT FOUND THEN
      PERFORM AddMemberToInterface(nUserId, nInterface);
    END IF;

    nInterface := GetInterface('I:1:0:3');
    SELECT * INTO nId FROM db.member_interface WHERE interface = nInterface AND member = nUserId;
    IF NOT FOUND THEN
      PERFORM AddMemberToInterface(nUserId, nInterface);
      PERFORM SetDefaultInterface(nInterface, nUserId);
    END IF;

    FOR r IN SELECT code FROM db.session WHERE userid = nUserId
    LOOP
      PERFORM SetArea(GetDefaultArea(nUserId), nUserId, r.code);
      PERFORM SetInterface(GetDefaultInterface(nUserId), nUserId, r.code);
    END LOOP;

    PERFORM EventMessageConfirmEmail(pObject);
  END IF;

  PERFORM WriteToEventLog('M', 1014, 'Клиент утверждён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventClientDisable ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventClientDisable (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
DECLARE
  r         record;
  nUserId	numeric;
BEGIN
  SELECT userid INTO nUserId FROM db.client WHERE id = pObject;

  IF nUserId IS NOT NULL THEN
    PERFORM UserLock(nUserId);

    PERFORM DeleteGroupForMember(nUserId);
    PERFORM DeleteAreaForMember(nUserId);
    PERFORM DeleteInterfaceForMember(nUserId);

    PERFORM AddMemberToGroup(nUserId, GetGroup('guest'));
    PERFORM AddMemberToArea(nUserId, GetArea('guest'));

    PERFORM SetDefaultArea(GetArea('guest'), nUserId);
    PERFORM SetDefaultInterface(GetInterface('I:1:0:4'), nUserId);

    FOR r IN SELECT code FROM db.session WHERE userid = nUserId
    LOOP
      PERFORM SetArea(GetDefaultArea(nUserId), nUserId, r.code);
      PERFORM SetInterface(GetDefaultInterface(nUserId), nUserId, r.code);
    END LOOP;
  END IF;

  PERFORM WriteToEventLog('M', 1015, 'Клиент закрыт.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventClientDelete -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventClientDelete (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
DECLARE
  nUserId	numeric;
BEGIN
  SELECT userid INTO nUserId FROM db.client WHERE id = pObject;

  IF nUserId IS NOT NULL THEN
  END IF;

  IF nUserId IS NOT NULL THEN
    DELETE FROM db.session WHERE userid = nUserId;

    PERFORM UserLock(nUserId);

    PERFORM DeleteGroupForMember(nUserId);
    PERFORM DeleteAreaForMember(nUserId);
    PERFORM DeleteInterfaceForMember(nUserId);

    UPDATE db.user SET pswhash = null WHERE id = nUserId;
  END IF;

  PERFORM WriteToEventLog('M', 1016, 'Клиент удалён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventClientRestore ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventClientRestore (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1017, 'Клиент восстановлен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventClientDrop -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventClientDrop (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
DECLARE
  r		    record;
  nUserId   numeric;
BEGIN
  SELECT label INTO r FROM db.object WHERE id = pObject;

  SELECT userid INTO nUserId FROM client WHERE id = pObject;
  IF nUserId IS NOT NULL THEN
    UPDATE db.client SET userid = null WHERE id = pObject;
    DELETE FROM db.session WHERE userid = nUserId;
    PERFORM DeleteUser(nUserId);
  END IF;

  DELETE FROM db.client_name WHERE client = pObject;
  DELETE FROM db.client WHERE id = pObject;

  PERFORM WriteToEventLog('W', 2010, '[' || pObject || '] [' || coalesce(r.label, '<null>') || '] Клиент уничтожен.');
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventClientConfirm ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventClientConfirm (
  pObject	    numeric default context_object()
) RETURNS	    void
AS $$
DECLARE
  nUserId       numeric;
  vEmail        text;
  bVerified     bool;
BEGIN
  SELECT userid INTO nUserId FROM db.client WHERE id = pObject;

  IF nUserId IS NOT NULL THEN

	SELECT email, email_verified INTO vEmail, bVerified
	  FROM db.user u INNER JOIN db.profile p ON u.id = p.userid AND u.type = 'U'
	 WHERE id = nUserId;

	IF vEmail IS NULL THEN
      PERFORM EmailAddressNotSet();
    END IF;

    IF NOT bVerified THEN
      PERFORM EmailAddressNotVerified(vEmail);
    END IF;

    PERFORM EventMessageConfirmEmail(pObject);
  END IF;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventClientReconfirm --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventClientReconfirm (
  pObject	    numeric default context_object()
) RETURNS	    void
AS $$
DECLARE
  nUserId       numeric;
BEGIN
  SELECT userid INTO nUserId FROM db.client WHERE id = pObject;
  IF nUserId IS NOT NULL THEN
	UPDATE db.profile SET email_verified = false WHERE userid = nUserId;
    PERFORM EventMessageConfirmEmail(pObject);
  END IF;
END;
$$ LANGUAGE plpgsql;
