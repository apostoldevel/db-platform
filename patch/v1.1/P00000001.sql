DROP FUNCTION api.sql(text, text, jsonb, jsonb, integer, integer, jsonb, jsonb);

DROP FUNCTION GetOperDate(character varying);
DROP FUNCTION api.oper_date();

DROP FUNCTION IF EXISTS kernel.AccessObjectUser(uuid, uuid) CASCADE;

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

--

DROP VIEW IF EXISTS api.reference CASCADE;
DROP VIEW IF EXISTS ObjectReference CASCADE;
DROP VIEW IF EXISTS AccessReference CASCADE;

DROP VIEW IF EXISTS AccessForm CASCADE;
DROP VIEW IF EXISTS AccessVendor CASCADE;
DROP VIEW IF EXISTS AccessAgent CASCADE;
DROP VIEW IF EXISTS AccessProgram CASCADE;
DROP VIEW IF EXISTS AccessScheduler CASCADE;
DROP VIEW IF EXISTS AccessVersion CASCADE;
DROP VIEW IF EXISTS AccessJob CASCADE;
DROP VIEW IF EXISTS AccessMessage CASCADE;
