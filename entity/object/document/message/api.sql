--------------------------------------------------------------------------------
-- MESSAGE ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.message -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.message
AS
  SELECT * FROM ObjectMessage;

GRANT SELECT ON api.message TO administrator;

--------------------------------------------------------------------------------
-- api.service_message ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.service_message
AS
  SELECT * FROM ServiceMessage WHERE scope = current_scope();

GRANT SELECT ON api.service_message TO administrator;
GRANT SELECT ON api.service_message TO apibot;

--------------------------------------------------------------------------------
-- FUNCTION api.service_message ------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve service messages filtered by class within the current scope.
 * @param {uuid} pClass - Class identifier (e.g., inbox or outbox)
 * @return {SETOF api.service_message} - Matching service message records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.service_message (
  pClass    uuid
) RETURNS   SETOF api.service_message
AS $$
  SELECT * FROM api.service_message WHERE class = pClass
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.message --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve messages filtered by type, agent, and state (UUID overload).
 * @param {uuid} pType - Message type identifier
 * @param {uuid} pAgent - Delivery agent identifier
 * @param {uuid} pState - State identifier
 * @return {SETOF api.message} - Matching message records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.message (
  pType     uuid,
  pAgent    uuid,
  pState    uuid
) RETURNS   SETOF api.message
AS $$
  SELECT * FROM api.message WHERE type = pType AND agent = pAgent AND state = pState;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.message --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve messages filtered by type, agent, and state (text code overload).
 * @param {text} pType - Message type code (e.g., 'message.outbox')
 * @param {text} pAgent - Agent code (e.g., 'smtp.agent')
 * @param {text} pState - State code (e.g., 'enabled')
 * @return {SETOF api.message} - Matching message records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.message (
  pType     text,
  pAgent    text,
  pState    text
) RETURNS   SETOF api.message
AS $$
  SELECT * FROM api.message(CodeToType(pType, 'message'), GetAgent(pAgent), GetState(GetClass(SubStr(pType, StrPos(pType, '.') + 1)), pState));
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_message -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new message via the API layer.
 * @param {uuid} pParent - Parent object reference
 * @param {uuid} pType - Message type identifier
 * @param {uuid} pAgent - Delivery agent
 * @param {text} pCode - Unique message code (MsgId)
 * @param {text} pProfile - Sender profile
 * @param {text} pAddress - Recipient address
 * @param {text} pSubject - Subject line
 * @param {text} pContent - Message body
 * @param {text} pLabel - Display label
 * @param {text} pDescription - Description
 * @return {uuid} - Identifier of the created message
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_message (
  pParent       uuid,
  pType         uuid,
  pAgent        uuid,
  pCode         text,
  pProfile      text,
  pAddress      text,
  pSubject      text,
  pContent      text,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateMessage(pParent, pType, pAgent, pCode, pProfile, pAddress, pSubject, pContent, pLabel, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_message ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing message via the API layer.
 * @param {uuid} pId - Message identifier
 * @param {uuid} pParent - New parent object (NULL keeps current)
 * @param {uuid} pType - New message type (NULL keeps current)
 * @param {uuid} pAgent - New delivery agent (NULL keeps current)
 * @param {text} pCode - New message code (NULL keeps current)
 * @param {text} pProfile - New sender profile (NULL keeps current)
 * @param {text} pAddress - New recipient address (NULL keeps current)
 * @param {text} pSubject - New subject line (NULL keeps current)
 * @param {text} pContent - New message body (NULL keeps current)
 * @param {text} pLabel - New display label (NULL keeps current)
 * @param {text} pDescription - New description (NULL keeps current)
 * @return {void}
 * @throws ObjectNotFound - When no message matches pId
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_message (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pAgent        uuid default null,
  pCode         text default null,
  pProfile      text default null,
  pAddress      text default null,
  pSubject      text default null,
  pContent      text default null,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       void
AS $$
DECLARE
  uMessage      uuid;
BEGIN
  SELECT a.id INTO uMessage FROM db.message a WHERE a.id = pId;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('message', 'id', pId);
  END IF;

  PERFORM EditMessage(uMessage, pParent, pType, pAgent, pCode, pProfile, pAddress, pSubject, pContent, pLabel, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_message -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create or update a message (upsert). Routes to add or update based on pId.
 * @param {uuid} pId - Message identifier (NULL to create)
 * @param {uuid} pParent - Parent object reference
 * @param {uuid} pType - Message type identifier
 * @param {uuid} pAgent - Delivery agent
 * @param {text} pCode - Message code
 * @param {text} pProfile - Sender profile
 * @param {text} pAddress - Recipient address
 * @param {text} pSubject - Subject line
 * @param {text} pContent - Message body
 * @param {text} pLabel - Display label
 * @param {text} pDescription - Description
 * @return {SETOF api.message} - The created or updated message
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_message (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pAgent        uuid default null,
  pCode         text default null,
  pProfile      text default null,
  pAddress      text default null,
  pSubject      text default null,
  pContent      text default null,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       SETOF api.message
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_message(pParent, pType, pAgent, pCode, pProfile, pAddress, pSubject, pContent, pLabel, pDescription);
  ELSE
    PERFORM api.update_message(pId, pParent, pType, pAgent, pCode, pProfile, pAddress, pSubject, pContent, pLabel, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.message WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_message -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single message by identifier with access check.
 * @param {uuid} pId - Message identifier
 * @return {SETOF api.message} - Matching message record
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_message (
  pId       uuid
) RETURNS   SETOF api.message
AS $$
  SELECT * FROM api.message WHERE id = pId AND CheckObjectAccess(id, B'100')
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_service_message -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single service message by identifier with access check.
 * @param {uuid} pId - Message identifier
 * @return {SETOF api.service_message} - Matching service message record
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_service_message (
  pId       uuid
) RETURNS   SETOF api.service_message
AS $$
  SELECT * FROM api.service_message WHERE id = pId AND CheckObjectAccess(id, B'100')
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_message ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List messages matching search, filter, and sort criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Field-level equality filter
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Array of fields to sort by
 * @return {SETOF api.message} - Matching message records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_message (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.message
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'message', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.send_message ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create and immediately submit a message for delivery via the specified agent.
 * @param {uuid} pParent - Parent object reference
 * @param {uuid} pAgent - Delivery agent
 * @param {text} pProfile - Sender profile
 * @param {text} pAddress - Recipient address
 * @param {text} pSubject - Subject line
 * @param {text} pContent - Message body
 * @param {text} pLabel - Display label
 * @param {text} pDescription - Description
 * @return {SETOF api.message} - The sent message record
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.send_message (
  pParent       uuid,
  pAgent        uuid,
  pProfile      text,
  pAddress      text,
  pSubject      text,
  pContent      text,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       SETOF api.message
AS $$
DECLARE
  uMessageId    uuid;
BEGIN
  uMessageId := SendMessage(pParent, pAgent, pProfile, pAddress, pSubject, pContent, pLabel, pDescription);
  RETURN QUERY SELECT * FROM api.message WHERE id = uMessageId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.send_mail ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Send an email to the current user's verified email address.
 * @param {text} pSubject - Email subject
 * @param {text} pText - Plain-text body
 * @param {text} pHTML - HTML body
 * @param {text} pDescription - Description for logging
 * @param {uuid} pUserId - Target user (defaults to current user)
 * @return {SETOF api.message} - The sent email message record
 * @throws EmailAddressNotSet - When the user has no email
 * @throws EmailAddressNotVerified - When the email is not verified
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.send_mail (
  pSubject      text,
  pText         text,
  pHTML         text,
  pDescription  text DEFAULT null,
  pUserId       uuid DEFAULT current_userid()
) RETURNS       SETOF api.message
AS $$
DECLARE
  uMessageId    uuid;
  vProject      text;
  vDomain       text;
  vSMTP         text;
  vProfile      text;
  vName         text;
  vEmail        text;
  vBody         text;
  bVerified     bool;
  vOAuthSecret  text;
BEGIN
  IF IsUserRole(GetGroup('system'), session_userid()) THEN
    SELECT secret INTO vOAuthSecret FROM oauth2.audience WHERE code = session_username();
    PERFORM SubstituteUser(GetUser('apibot'), vOAuthSecret);
  END IF;

  SELECT name, email, email_verified, locale INTO vName, vEmail, bVerified
    FROM db.user u INNER JOIN db.profile p ON u.id = p.userid AND p.scope = current_scope()
   WHERE id = pUserId;

  IF vEmail IS NULL THEN
    PERFORM EmailAddressNotSet();
  END IF;

  IF NOT bVerified THEN
    PERFORM EmailAddressNotVerified(vEmail);
  END IF;

  vProject := RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject', 'Name', pUserId);
  vSMTP := RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject', 'SMTP', pUserId);
  vDomain := RegGetValueString('CURRENT_CONFIG', 'CONFIG\CurrentProject', 'Domain', pUserId);

  vProfile := format('info@%s', coalesce(vSMTP, vDomain));

  vBody := CreateMailBody(vProject, vProfile, vName, vEmail, pSubject, pText, pHTML);

  uMessageId := SendMail(null, vProfile, vEmail, pSubject, vBody, null, pDescription);

  IF vOAuthSecret IS NOT NULL THEN
    PERFORM SubstituteUser(session_userid(), vOAuthSecret);
  END IF;

  RETURN QUERY SELECT * FROM api.message WHERE id = uMessageId;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.send_sms ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Send an SMS to the current user's verified phone number.
 * @param {text} pProfile - SMS sender address / profile
 * @param {text} pMessage - SMS text content
 * @param {uuid} pUserId - Target user (defaults to current user)
 * @return {SETOF api.message} - The sent SMS message record
 * @throws PhoneNumberNotSet - When the user has no phone number
 * @throws PhoneNumberNotVerified - When the phone is not verified
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.send_sms (
  pProfile      text,
  pMessage      text,
  pUserId       uuid DEFAULT current_userid()
) RETURNS       SETOF api.message
AS $$
DECLARE
  uMessageId    uuid;

  vName         text;
  vPhone        text;
  bVerified     bool;
  vOAuthSecret  text;
BEGIN
  IF IsUserRole(GetGroup('system'), session_userid()) THEN
    SELECT secret INTO vOAuthSecret FROM oauth2.audience WHERE code = session_username();
    PERFORM SubstituteUser(GetUser('admin'), vOAuthSecret);
  END IF;

  SELECT name, phone, phone_verified, locale INTO vName, vPhone, bVerified
    FROM db.user u INNER JOIN db.profile p ON u.id = p.userid AND p.scope = current_scope()
   WHERE id = pUserId;

  IF vPhone IS NULL THEN
    PERFORM PhoneNumberNotSet();
  END IF;

  IF NOT bVerified THEN
    PERFORM PhoneNumberNotVerified(vPhone);
  END IF;

  uMessageId := SendSMS(null, pProfile, pMessage, pUserId);

  RETURN QUERY SELECT * FROM api.message WHERE id = uMessageId;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.send_push ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Send a push notification to a user via FCM.
 * @param {uuid} pObject - Context object for event logging
 * @param {text} pTitle - Notification title
 * @param {text} pBody - Notification body text
 * @param {uuid} pUserId - Target user (defaults to current user)
 * @param {jsonb} pData - Custom data payload
 * @param {jsonb} pAndroid - Android-specific options
 * @param {jsonb} pApns - APNs-specific options
 * @return {SETOF api.message} - The sent push message record
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.send_push (
  pObject       uuid,
  pTitle        text,
  pBody         text,
  pUserId       uuid DEFAULT current_userid(),
  pData         jsonb DEFAULT null,
  pAndroid      jsonb DEFAULT null,
  pApns         jsonb DEFAULT null
) RETURNS       SETOF api.message
AS $$
DECLARE
  uMessageId    uuid;
  vOAuthSecret  text;
BEGIN
  IF IsUserRole(GetGroup('system'), session_userid()) THEN
    SELECT secret INTO vOAuthSecret FROM oauth2.audience WHERE code = session_username();
    PERFORM SubstituteUser(GetUser('admin'), vOAuthSecret);
  END IF;

  uMessageId := SendPush(pObject, pTitle, pBody, pUserId, pData, pAndroid, pApns);

  RETURN QUERY SELECT * FROM api.message WHERE id = uMessageId;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.send_push_data ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Send a data-only push notification via FCM (no visible notification).
 * @param {uuid} pObject - Context object for event logging
 * @param {text} pSubject - Subject for logging
 * @param {json} pData - Data payload
 * @param {uuid} pUserId - Target user (defaults to current user)
 * @param {text} pPriority - Android priority ('normal' or 'high')
 * @param {text} pCollapse - Collapse key for grouping
 * @return {SETOF api.message} - The sent push message record
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.send_push_data (
  pObject       uuid,
  pSubject      text,
  pData         json,
  pUserId       uuid DEFAULT current_userid(),
  pPriority     text DEFAULT null,
  pCollapse     text DEFAULT null
) RETURNS       SETOF api.message
AS $$
DECLARE
  uMessageId    uuid;
  vOAuthSecret  text;
BEGIN
  IF IsUserRole(GetGroup('system'), session_userid()) THEN
    SELECT secret INTO vOAuthSecret FROM oauth2.audience WHERE code = session_username();
    PERFORM SubstituteUser(GetUser('admin'), vOAuthSecret);
  END IF;

  uMessageId := SendPushData(pObject, pSubject, pData, pUserId, pPriority, pCollapse);

  RETURN QUERY SELECT * FROM api.message WHERE id = uMessageId;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.send_push_to_role -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Send a push notification to all members of a role/group.
 * @param {text} pRoleName - Username or group name
 * @param {text} pTitle - Notification title
 * @param {text} pBody - Notification body text
 * @param {jsonb} pData - Custom data payload
 * @param {jsonb} pAndroid - Android-specific options
 * @param {jsonb} pApns - APNs-specific options
 * @return {integer} - Number of users notified
 * @throws AccessDenied - When the caller lacks the 'message' role
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.send_push_to_role (
  pRoleName     text,
  pTitle        text,
  pBody         text,
  pData         jsonb DEFAULT null,
  pAndroid      jsonb DEFAULT null,
  pApns         jsonb DEFAULT null
) RETURNS       integer
AS $$
DECLARE
  r             record;
  nCount        integer;
  uUserId       uuid;
  vType         char;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('message')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  nCount := 0;

  SELECT id, type INTO uUserId, vType FROM db.user WHERE status & B'0100' != B'0100' AND username = pRoleName;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  IF vType = 'G' THEN
    FOR r IN SELECT member FROM db.member_group WHERE userid = uUserId
    LOOP
      PERFORM SendPush(null, pTitle, pBody, r.member, pData, pAndroid, pApns);
      nCount := nCount + 1;
    END LOOP;
  ELSE
    PERFORM SendPush(null, pTitle, pBody, uUserId, pData, pAndroid, pApns);
    nCount := 1;
  END IF;

  RETURN nCount;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.send_push_all -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Broadcast a push notification to all registered users.
 * @param {text} pTitle - Notification title
 * @param {text} pBody - Notification body text
 * @return {integer} - Number of users notified
 * @throws AccessDenied - When the caller lacks the 'message' role
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.send_push_all (
  pTitle        text,
  pBody         text
) RETURNS       integer
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('message')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  RETURN SendPushAll(pTitle, pBody);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
