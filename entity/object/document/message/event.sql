--------------------------------------------------------------------------------
-- MESSAGE ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventMessageCreate ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageCreate (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1010, 'Сообщение создано.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageOpen ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageOpen (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1011, 'Сообщение открыто на просмотр.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageEdit ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageEdit (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1012, 'Сообщение изменёно.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageSave ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageSave (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1013, 'Сообщение сохранёно.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageEnable ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageEnable (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1014, 'Сообщение открыто.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageSubmit ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageSubmit (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1018, 'Сообщение готово к отправке.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageSend ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageSend (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1019, 'Сообщение отправляется.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageCancel ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageCancel (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1020, 'Отправка сообщения отменена.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageDone ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageDone (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1020, 'Сообщение отправено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageFail ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageFail (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1021, 'Сбой при отправке сообщения.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageRepeat ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageRepeat (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1022, 'Повторная отправка сообщения.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageDisable ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageDisable (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1015, 'Сообщение закрыто.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageDelete ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageDelete (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1016, 'Сообщение удалёно.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageRestore ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageRestore (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1017, 'Сообщение восстановлено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageDrop ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageDrop (
  pObject	numeric default context_object()
) RETURNS	void
AS $$
DECLARE
  r		record;
BEGIN
  SELECT label INTO r FROM db.object WHERE id = pObject;

  DELETE FROM db.object_link WHERE linked = pObject;
  DELETE FROM db.message WHERE id = pObject;

  PERFORM WriteToEventLog('W', 2010, '[' || pObject || '] [' || coalesce(r.label, '<null>') || '] Сообщение уничтожен.');
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageConfirmEmail ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageConfirmEmail (
  pObject		numeric default context_object(),
  pParams		jsonb default context_params()
) RETURNS		void
AS $$
DECLARE
  nUserId       numeric;
  vCode			text;
  vName			text;
  vDomain       text;
  vUserName     text;
  vEmail		text;
  vProject		text;
  vHost         text;
  vNoReply      text;
  vSupport		text;
  vSubject      text;
  vText			text;
  vHTML			text;
  vBody			text;
  vDescription  text;
  bVerified		bool;
BEGIN
  SELECT userid INTO nUserId FROM db.client WHERE id = pObject;
  IF nUserId IS NOT NULL THEN

    IF pParams IS NOT NULL THEN
	  UPDATE db.client SET email = pParams WHERE id = nUserId;
	END IF;

	SELECT username, name, email, email_verified, locale INTO vUserName, vName, vEmail, bVerified
	  FROM db.user u INNER JOIN db.profile p ON u.id = p.userid
	 WHERE id = nUserId;

	IF vEmail IS NOT NULL AND NOT bVerified THEN

	  vProject := (RegGetValue(RegOpenKey('CURRENT_CONFIG', 'CONFIG\CurrentProject'), 'Name')).vString;
	  vHost := (RegGetValue(RegOpenKey('CURRENT_CONFIG', 'CONFIG\CurrentProject'), 'Host')).vString;
	  vDomain := (RegGetValue(RegOpenKey('CURRENT_CONFIG', 'CONFIG\CurrentProject'), 'Domain')).vString;

	  vCode := GetVerificationCode(NewVerificationCode(nUserId));

	  vNoReply := format('noreply@%s', vDomain);
	  vSupport := format('support@%s', vDomain);

	  IF locale_code() = 'ru' THEN
        vSubject := 'Подтвердите, пожалуйста, адрес Вашей электронной почты.';
        vDescription := 'Подтверждение email: ' || vEmail;
	  ELSE
        vSubject := 'Please confirm your email address.';
        vDescription := 'Confirm email: ' || vEmail;
	  END IF;

	  vText := GetConfirmEmailText(vName, vUserName, vCode, vProject, vHost, vSupport);
	  vHTML := GetConfirmEmailHTML(vName, vUserName, vCode, vProject, vHost, vSupport);

	  vBody := CreateMailBody(vProject, vNoReply, null, vEmail, vSubject, vText, vHTML);

      PERFORM SendMail(pObject, vNoReply, vEmail, vSubject, vBody, vDescription);
      PERFORM WriteToEventLog('M', 1110, vDescription, pObject);
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageAccountInfo -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageAccountInfo (
  pObject		numeric default context_object()
) RETURNS		void
AS $$
DECLARE
  nUserId       numeric;
  vSecret       text;
  vName			text;
  vDomain       text;
  vUserName     text;
  vEmail		text;
  vProject		text;
  vHost         text;
  vNoReply      text;
  vSupport		text;
  vSubject      text;
  vText			text;
  vHTML			text;
  vBody			text;
  vDescription  text;
  bVerified		bool;
BEGIN
  SELECT userid INTO nUserId FROM db.client WHERE id = pObject;
  IF nUserId IS NOT NULL THEN

	SELECT username, name, encode(hmac(secret::text, GetSecretKey(), 'sha512'), 'hex'), email, email_verified INTO vUserName, vName, vSecret, vEmail, bVerified
	  FROM db.user u INNER JOIN db.profile p ON u.id = p.userid
	 WHERE id = nUserId;

	IF vEmail IS NOT NULL AND bVerified THEN
	  vProject := (RegGetValue(RegOpenKey('CURRENT_CONFIG', 'CONFIG\CurrentProject'), 'Name')).vString;
	  vHost := (RegGetValue(RegOpenKey('CURRENT_CONFIG', 'CONFIG\CurrentProject'), 'Host')).vString;
	  vDomain := (RegGetValue(RegOpenKey('CURRENT_CONFIG', 'CONFIG\CurrentProject'), 'Domain')).vString;

	  vNoReply := format('noreply@%s', vDomain);
	  vSupport := format('support@%s', vDomain);

	  IF locale_code() = 'ru' THEN
        vSubject := 'Информация о Вашей учетной записи.';
        vDescription := 'Информация об учетной записи: ' || vUserName;
	  ELSE
        vSubject := 'Your account information.';
        vDescription := 'Account information: ' || vUserName;
	  END IF;

	  vText := GetAccountInfoText(vName, vUserName, vSecret, vProject, vSupport);
	  vHTML := GetAccountInfoHTML(vName, vUserName, vSecret, vProject, vSupport);

	  vBody := CreateMailBody(vProject, vNoReply, null, vEmail, vSubject, vText, vHTML);

      PERFORM SendMail(pObject, vNoReply, vEmail, vSubject, vBody, vDescription);
      PERFORM WriteToEventLog('M', 1110, vDescription, pObject);
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;
