--------------------------------------------------------------------------------
-- P00000042 -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- N-1: contract; old binary: an old binary or configuration that creates an object of a class on which its session holds no create bit gets ERR-400-001
--
-- The create bit of the class ACU ({acsud}, 'c') is checked when an object is created.
--
-- The bit is written by ft_class_tree_after_insert (group user: document 11000, reference 10100);
-- db.ft_object_before_insert now asks CheckClassAccess(NEW.class, B'01000'). Update and delete stay held per object
-- (db.aou).
--
-- Who may create: a caller holding 'c' on the class. Group user holds it on documents and not on references; a project
-- that wants creation by role takes 'c' from user per class and gives it to the roles (chmodc). The kernel connection
-- (session_user kernel or postgres) is exempt, as in ft_object_before_update: it is the installer and the patches,
-- whatever session it holds.
--
-- Behaviour change for every project: a road that creates objects of a class without granting 'c' to its caller now
-- fails with ERR-400-001. Grant the bit (chmodc) where the road is legitimate. Known cases:
--   * a role granted 'u' but not 'c' on a class: chmodc opens the class methods, `create` among them, on "c or u",
--     while this trigger asks for 'c' only;
--   * a user outside the group user (a guest, a role removed from user) no longer creates documents under its own
--     session; a road that did so without the system substitution fails, and a caller that swallows the error
--     fails silently.
-- A connection with no platform session (current_userid() NULL: the daemon and apibot pools before a session is set)
-- that inserted an object failed on db.object.owner NOT NULL; it now gets ERR-400-001 first.
--
-- The trigger t_object_before_insert exists; only its function is replaced. The text is the text of
-- entity/object/table.sql, byte for byte (update.psql does not reload table.sql -- hence this patch). Kernel phase, no
-- \connect, no session, repeatable.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_object_before_insert()
RETURNS trigger AS $$
DECLARE
  bAbstract    boolean;
BEGIN
  IF NEW.id IS NULL THEN
    SELECT gen_kernel_uuid('8') INTO NEW.id;
  END IF;

  SELECT class INTO NEW.class FROM db.type WHERE id = NEW.type;
  SELECT entity, abstract INTO NEW.entity, bAbstract FROM db.class_tree WHERE id = NEW.class;

  IF bAbstract THEN
    PERFORM AbstractError();
  END IF;

  -- The create bit of the class ACU ({acsud}, 'c'). Update and delete are held
  -- per object by db.aou; creation has no object yet, so the class is the only
  -- place to ask. Same exemption as ft_object_before_update: the kernel and
  -- postgres connections are the installer and the patches, whatever session
  -- they hold. An unknown type leaves NEW.class NULL: a NOT NULL violation
  -- (entity/class) reports that, not this check.
  IF NEW.class IS NOT NULL AND session_user NOT IN ('kernel', 'postgres') THEN
    IF NOT CheckClassAccess(NEW.class, B'01000') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT type INTO NEW.state_type FROM db.state WHERE id = NEW.state;

  IF NEW.scope IS NULL THEN
    SELECT scope INTO NEW.scope FROM db.area WHERE id = GetSessionArea(current_session());
  ELSE
    PERFORM FROM db.area WHERE id = GetSessionArea(current_session()) AND scope = NEW.scope;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'ERR-40000: Area "%" not present in scope "%".', GetSessionArea(current_session()), GetScopeName(NEW.scope);
    END IF;
  END IF;

  NEW.suid := session_userid();
  NEW.owner := current_userid();
  NEW.oper := current_userid();

  NEW.pdate := now();
  NEW.ldate := oper_date();
  NEW.udate := now();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
