--------------------------------------------------------------------------------
-- CLIENT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventClientCreate -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventClientCreate (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'create', 'Клиент создан.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventClientOpen -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventClientOpen (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'open', 'Клиент открыт на просмотр.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventClientEdit -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventClientEdit (
  pObject	uuid default context_object(),
  pParams	jsonb default context_params()
) RETURNS	void
AS $$
DECLARE
  old_email	jsonb;
  new_email	jsonb;
BEGIN
  old_email = pParams#>'{old, email}';
  new_email = pParams#>'{new, email}';

  IF coalesce(old_email, '{}') <> coalesce(new_email, '{}') THEN
    PERFORM EventMessageConfirmEmail(pObject, new_email);
  END IF;

  PERFORM WriteToEventLog('M', 1000, 'edit', 'Клиент изменён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventClientSave -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventClientSave (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'save', 'Клиент сохранён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventClientEnable -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventClientEnable (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
DECLARE
  r             record;

  nArea         uuid;
  nUserId       uuid;
  nInterface    uuid;
BEGIN
  SELECT userid INTO nUserId FROM db.client WHERE id = pObject;

  IF nUserId IS NOT NULL THEN
    PERFORM UserUnLock(nUserId);

    PERFORM DeleteGroupForMember(nUserId, GetGroup('guest'));

    PERFORM AddMemberToGroup(nUserId, GetGroup('user'));

    SELECT area INTO nArea FROM db.document WHERE id = pObject;

    PERFORM AddMemberToArea(nUserId, nArea);
    PERFORM SetDefaultArea(nArea, nUserId);

    nInterface := GetInterface('all');
    PERFORM AddMemberToInterface(nUserId, nInterface);

    nInterface := GetInterface('user');
    PERFORM AddMemberToInterface(nUserId, nInterface);
    PERFORM SetDefaultInterface(nInterface, nUserId);

    FOR r IN SELECT code FROM db.session WHERE userid = nUserId
    LOOP
      PERFORM SetArea(GetDefaultArea(nUserId), nUserId, r.code);
      PERFORM SetInterface(GetDefaultInterface(nUserId), nUserId, r.code);
    END LOOP;

    PERFORM EventMessageConfirmEmail(pObject);
  END IF;

  PERFORM WriteToEventLog('M', 1000, 'enable', 'Клиент утверждён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventClientDisable ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventClientDisable (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
DECLARE
  r         record;
  nUserId	uuid;
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
    PERFORM SetDefaultInterface(GetInterface('guest'), nUserId);

    FOR r IN SELECT code FROM db.session WHERE userid = nUserId
    LOOP
      PERFORM SetArea(GetDefaultArea(nUserId), nUserId, r.code);
      PERFORM SetInterface(GetDefaultInterface(nUserId), nUserId, r.code);
    END LOOP;
  END IF;

  PERFORM WriteToEventLog('M', 1000, 'disable', 'Клиент закрыт.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventClientDelete -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventClientDelete (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
DECLARE
  nUserId	uuid;
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

  PERFORM WriteToEventLog('M', 1000, 'delete', 'Клиент удалён.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventClientRestore ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventClientRestore (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'restore', 'Клиент восстановлен.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventClientDrop -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventClientDrop (
  pObject	uuid default context_object()
) RETURNS	void
AS $$
DECLARE
  r		    record;
  nUserId   uuid;
BEGIN
  SELECT label INTO r FROM db.object_text WHERE object = pObject AND locale = current_locale();

  SELECT userid INTO nUserId FROM client WHERE id = pObject;
  IF nUserId IS NOT NULL THEN
    UPDATE db.client SET userid = null WHERE id = pObject;
    DELETE FROM db.session WHERE userid = nUserId;
    PERFORM DeleteUser(nUserId);
  END IF;

  DELETE FROM db.client_name WHERE client = pObject;
  DELETE FROM db.client WHERE id = pObject;

  PERFORM WriteToEventLog('W', 1000, 'drop', '[' || pObject || '] [' || coalesce(r.label, '<null>') || '] Клиент уничтожен.');
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventClientConfirm ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventClientConfirm (
  pObject	    uuid default context_object()
) RETURNS	    void
AS $$
DECLARE
  nUserId       uuid;
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

    PERFORM EventMessageAccountInfo(pObject);
  END IF;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventClientReconfirm --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventClientReconfirm (
  pObject	    uuid default context_object()
) RETURNS	    void
AS $$
DECLARE
  nUserId       uuid;
BEGIN
  SELECT userid INTO nUserId FROM db.client WHERE id = pObject;
  IF nUserId IS NOT NULL THEN
	UPDATE db.profile SET email_verified = false WHERE userid = nUserId;
    PERFORM EventMessageConfirmEmail(pObject);
  END IF;
END;
$$ LANGUAGE plpgsql;
