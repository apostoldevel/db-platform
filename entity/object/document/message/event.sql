--------------------------------------------------------------------------------
-- MESSAGE ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- EventMessageCreate ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageCreate (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'create', 'Сообщение создано.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageOpen ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageOpen (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'open', 'Сообщение открыто на просмотр.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageEdit ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageEdit (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'edit', 'Сообщение изменено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageSave ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageSave (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'save', 'Сообщение сохранено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageEnable ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageEnable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'enable', 'Сообщение открыто.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageDisable ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageDisable (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'disable', 'Сообщение закрыто.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageDelete ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageDelete (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'delete', 'Сообщение удалено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageRestore ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageRestore (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
BEGIN
  PERFORM WriteToEventLog('M', 1000, 'restore', 'Сообщение восстановлено.', pObject);
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageDrop ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageDrop (
  pObject    uuid default context_object()
) RETURNS    void
AS $$
DECLARE
  r          record;
BEGIN
  SELECT label INTO r FROM db.object_text WHERE object = pObject AND locale = current_locale();

  DELETE FROM db.object_link WHERE linked = pObject;
  DELETE FROM db.message WHERE id = pObject;

  PERFORM WriteToEventLog('W', 1000, 'drop', '[' || pObject || '] [' || coalesce(r.label, '') || '] Сообщение уничтожено.');
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageConfirmEmail ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageConfirmEmail (
  pObject        uuid default context_object(),
  pParams        jsonb default context_params()
) RETURNS        void
AS $$
DECLARE
  uUserId       uuid;
  vCode         text;
  vName         text;
  vDomain       text;
  vUserName     text;
  vEmail        text;
  vProject      text;
  vHost         text;
  vNoReply      text;
  vSupport      text;
  vSubject      text;
  vText         text;
  vHTML         text;
  vBody         text;
  vDescription  text;
  bVerified     bool;
BEGIN
  SELECT userid INTO uUserId FROM db.client WHERE id = pObject;
  IF uUserId IS NOT NULL THEN

    SELECT username, name, email, email_verified, locale INTO vUserName, vName, vEmail, bVerified
      FROM db.user u INNER JOIN db.profile p ON u.id = p.userid AND p.scope = current_scope()
     WHERE id = uUserId;

    IF vEmail IS NOT NULL AND NOT bVerified THEN

      vProject := RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject', 'Name', uUserId);
      vDomain := RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject', 'Domain', uUserId);

      vHost := current_scope_code();
      IF vHost = current_database()::text THEN
        vHost := RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject', 'Host', uUserId);
      END IF;

      vCode := GetVerificationCode(NewVerificationCode(uUserId));

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

      PERFORM SendMail(pObject, vNoReply, vEmail, vSubject, vBody, null, vDescription);
      PERFORM WriteToEventLog('M', 1001, 'email', vDescription, pObject);
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- EventMessageAccountInfo -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EventMessageAccountInfo (
  pObject        uuid default context_object()
) RETURNS        void
AS $$
DECLARE
  uUserId       uuid;
  vSecret       text;
  vName         text;
  vDomain       text;
  vUserName     text;
  vEmail        text;
  vProject      text;
  vHost         text;
  vNoReply      text;
  vSupport      text;
  vSubject      text;
  vText         text;
  vHTML         text;
  vBody         text;
  vDescription  text;
  bVerified     bool;
BEGIN
  SELECT userid INTO uUserId FROM db.client WHERE id = pObject;
  IF uUserId IS NOT NULL THEN

    SELECT username, name, encode(hmac(secret::text, GetSecretKey(), 'sha512'), 'hex'), email, email_verified INTO vUserName, vName, vSecret, vEmail, bVerified
      FROM db.user u INNER JOIN db.profile p ON u.id = p.userid AND p.scope = current_scope()
     WHERE id = uUserId;

    IF vEmail IS NOT NULL AND bVerified THEN
      vProject := RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject', 'Name', uUserId);
      vDomain := RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject', 'Domain', uUserId);

      vHost := current_scope_code();
      IF vHost = current_database()::text THEN
        vHost := RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject', 'Host', uUserId);
      END IF;

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

      PERFORM SendMail(pObject, vNoReply, vEmail, vSubject, vBody, null, vDescription);
      PERFORM WriteToEventLog('M', 1001, 'email', vDescription, pObject);
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql
   SET search_path = kernel, public, pg_temp;
