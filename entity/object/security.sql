--------------------------------------------------------------------------------
-- FUNCTION aou ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Compute aggregated access masks for all objects accessible by a user.
 * @param {uuid} pUserId - User identifier
 * @return {SETOF record} - (object, deny, allow, mask) per accessible object
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION aou (
  pUserId       uuid,
  OUT object    uuid,
  OUT deny      bit,
  OUT allow     bit,
  OUT mask      bit
) RETURNS       SETOF record
AS $$
  WITH member_group AS (
      SELECT pUserId AS userid UNION SELECT userid FROM db.member_group WHERE member = pUserId
  )
  SELECT a.object, bit_or(a.deny), bit_or(a.allow), bit_or(a.allow) & ~bit_or(a.deny)
    FROM db.aou a INNER JOIN db.object    o ON a.object = o.id
                  INNER JOIN member_group m ON a.userid = m.userid
   GROUP BY a.object;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION aou ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Compute aggregated access mask for a specific object and user.
 * @param {uuid} pUserId - User identifier
 * @param {uuid} pObject - Object identifier
 * @return {SETOF record} - (object, deny, allow, mask) for the given object
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION aou (
  pUserId       uuid,
  pObject       uuid,
  OUT object    uuid,
  OUT deny      bit,
  OUT allow     bit,
  OUT mask      bit
) RETURNS       SETOF record
AS $$
  WITH member_group AS (
      SELECT pUserId AS userid UNION SELECT userid FROM db.member_group WHERE member = pUserId
  )
  SELECT a.object, bit_or(a.deny), bit_or(a.allow), bit_or(a.allow) & ~bit_or(a.deny)
    FROM db.aou a INNER JOIN db.object    o ON a.object = o.id
                  INNER JOIN member_group m ON a.userid = m.userid
   WHERE a.object = pObject
   GROUP BY a.object
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION access_entity ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Compute aggregated access masks for all objects of a given entity.
 * @param {uuid} pUserId - User identifier
 * @param {uuid} pEntity - Entity identifier to filter by
 * @return {SETOF record} - (object, deny, allow, mask) per accessible object
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION access_entity (
  pUserId       uuid,
  pEntity       uuid,
  OUT object    uuid,
  OUT deny      bit,
  OUT allow     bit,
  OUT mask      bit
) RETURNS       SETOF record
AS $$
  WITH member_group AS (
      SELECT pUserId AS userid UNION SELECT userid FROM db.member_group WHERE member = pUserId
  )
  SELECT a.object, bit_or(a.deny), bit_or(a.allow), bit_or(a.allow) & ~bit_or(a.deny)
    FROM db.aou a INNER JOIN db.object    o ON a.object = o.id AND a.entity = pEntity
                  INNER JOIN member_group m ON a.userid = m.userid
   GROUP BY a.object;
$$ LANGUAGE SQL
   STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectMask ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch the POSIX-style access mask segment for an object based on user role.
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pUserId - User identifier (defaults to current)
 * @return {bit} - 3-bit mask (owner/group/other segment from aom)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectMask (
  pObject    uuid,
  pUserId    uuid DEFAULT current_userid()
) RETURNS    bit
AS $$
  SELECT CASE
         WHEN pUserId = o.owner THEN SubString(mask FROM 1 FOR 3)
         WHEN EXISTS (SELECT id FROM db.user WHERE id = pUserId AND type = 'G') THEN SubString(mask FROM 4 FOR 3)
         ELSE SubString(mask FROM 7 FOR 3)
         END
    FROM db.aom a INNER JOIN db.object o ON o.id = a.object
   WHERE object = pObject
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectAccessMask ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch the effective per-user access mask for an object (from AOU).
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pUserId - User identifier (defaults to current)
 * @return {bit} - 3-bit effective mask (allow & ~deny)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectAccessMask (
  pObject    uuid,
  pUserId    uuid DEFAULT current_userid()
) RETURNS    bit
AS $$
  SELECT mask FROM aou(pUserId, pObject)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckObjectAccess -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Check whether a user has a specific access permission on an object.
 * @param {uuid} pObject - Object identifier
 * @param {bit} pMask - Required permission bits (e.g. B'100' for select)
 * @param {uuid} pUserId - User identifier (defaults to current)
 * @return {boolean} - TRUE if the user has the required permission
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckObjectAccess (
  pObject    uuid,
  pMask      bit,
  pUserId    uuid DEFAULT current_userid()
) RETURNS    boolean
AS $$
BEGIN
  RETURN coalesce(coalesce(GetObjectAccessMask(pObject, pUserId), GetObjectMask(pObject, pUserId)) & pMask = pMask, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DecodeObjectAccess ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Decode the access mask for an object into boolean flags.
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pUserId - User identifier (defaults to current)
 * @return {record} - (s: select, u: update, d: delete) booleans
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DecodeObjectAccess (
  pObject    uuid,
  pUserId    uuid DEFAULT current_userid(),
  OUT s      boolean,
  OUT u      boolean,
  OUT d      boolean
) RETURNS    record
AS $$
DECLARE
  bMask        bit(3);
BEGIN
  bMask := coalesce(GetObjectAccessMask(pObject, pUserId), GetObjectMask(pObject, pUserId));

  s := bMask & B'100' = B'100';
  u := bMask & B'010' = B'010';
  d := bMask & B'001' = B'001';
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectMethodAccessMask ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch the cached method access mask for an object+method+user triple.
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pMethod - Method identifier
 * @param {uuid} pUserId - User identifier (defaults to current)
 * @return {bit} - 3-bit method mask (x=execute, v=visible, e=enable)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetObjectMethodAccessMask (
  pObject    uuid,
  pMethod    uuid,
  pUserId    uuid default current_userid()
) RETURNS    bit
AS $$
  SELECT mask FROM db.oma WHERE object = pObject AND method = pMethod AND userid = pUserId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckObjectMethodAccess -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Check whether a user has method-level access on an object (with cache population).
 * @param {uuid} pObject - Object identifier
 * @param {uuid} pMethod - Method identifier
 * @param {bit} pMask - Required method permission bits
 * @param {uuid} pUserId - User identifier (defaults to current)
 * @return {boolean} - TRUE if the user has the required method permission
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CheckObjectMethodAccess (
  pObject    uuid,
  pMethod    uuid,
  pMask      bit,
  pUserId    uuid default current_userid()
) RETURNS    boolean
AS $$
BEGIN
  PERFORM FROM db.oma WHERE object = pObject AND method = pMethod AND userid = pUserId;

  IF NOT FOUND THEN
    WITH access AS (
      SELECT method, bit_or(allow) & ~bit_or(deny) AS mask
        FROM db.amu
       WHERE method = pMethod
         AND userid IN (SELECT pUserId UNION SELECT userid FROM db.member_group WHERE member = pUserId)
       GROUP BY method
    ) INSERT INTO db.oma SELECT pObject, pMethod, pUserId, mask FROM access ON CONFLICT (object, method, userid) DO NOTHING;
  END IF;

  RETURN coalesce(GetObjectMethodAccessMask(pObject, pMethod, pUserId) & pMask = pMask, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AccessObjectUser ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List all objects of a given entity accessible (select) to a user in a scope.
 * @param {uuid} pEntity - Entity identifier
 * @param {uuid} pUserId - User identifier (defaults to current)
 * @param {uuid} pScope - Scope identifier (defaults to current)
 * @return {TABLE(object uuid)} - Accessible object identifiers
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AccessObjectUser (
  pEntity    uuid,
  pUserId    uuid DEFAULT current_userid(),
  pScope     uuid DEFAULT current_scope()
) RETURNS TABLE (
    object  uuid
)
AS $$
  WITH _membergroup AS (
      SELECT pUserId AS userid UNION SELECT userid FROM db.member_group WHERE member = pUserId
  )
  SELECT a.object
    FROM db.object o INNER JOIN db.aou       a ON a.object = o.id
                     INNER JOIN _membergroup m ON a.userid = m.userid
   WHERE o.scope = pScope
     AND o.entity = pEntity
   GROUP BY object
  HAVING (bit_or(a.allow) & ~bit_or(a.deny)) & B'100' = B'100'
$$ LANGUAGE SQL
   STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- chmodo ----------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Set the access bitmask (deny+allow) for an object and user pair.
 * @param {uuid} pObject - Object identifier
 * @param {bit} pMask - 6-bit mask: {deny:sud}{allow:sud} (NULL or B'000000' to remove)
 * @param {uuid} pUserId - User or group identifier (defaults to current)
 * @return {void}
 * @throws AccessDenied - When the caller is not an administrator
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION chmodo (
  pObject       uuid,
  pMask         bit,
  pUserId       uuid DEFAULT current_userid()
) RETURNS       void
AS $$
DECLARE
  bDeny         bit(3);
  bAllow        bit(3);
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  pMask := NULLIF(pMask, B'000000');

  IF pMask IS NOT NULL THEN
    bDeny := coalesce(SubString(pMask FROM 1 FOR 3), B'000');
    bAllow := coalesce(SubString(pMask FROM 4 FOR 3), B'000');

    INSERT INTO db.aou SELECT pObject, pUserId, bDeny, bAllow
      ON CONFLICT (object, userid) DO UPDATE SET deny = bDeny, allow = bAllow;
  ELSE
    DELETE FROM db.aou WHERE object = pObject AND userid = pUserId;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
