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
     AND a.mask = B'100'
   GROUP BY a.object
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--

DROP VIEW api.reference CASCADE;
DROP VIEW ObjectReference CASCADE;
DROP VIEW AccessReference CASCADE;

DROP VIEW AccessForm CASCADE;
DROP VIEW AccessVendor CASCADE;
DROP VIEW AccessAgent CASCADE;
DROP VIEW AccessProgram CASCADE;
DROP VIEW AccessScheduler CASCADE;
DROP VIEW AccessVersion CASCADE;
DROP VIEW AccessJob CASCADE;
DROP VIEW AccessMessage CASCADE;
