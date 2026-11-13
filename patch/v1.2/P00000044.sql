--------------------------------------------------------------------------------
-- P00000044 -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- N-1: contract; old binary: an old binary or configuration that moves an object into a class (by a change of its type)
-- on which its session holds no create bit gets ERR-400-001
--
-- The create bit of the class ACU ({acsud}, 'c') is checked when an object changes class.
--
-- P00000042 asks the bit on insert. An update that changes the type of an object recalculates its class from the new
-- type; db.ft_object_before_update now asks CheckClassAccess(NEW.class, B'01000') whenever the class changes, after
-- the update check of the object and the entity check, before the state is moved. Moving an object into a class
-- takes the same right as creating one there.
--
-- Who may move an object into a class: a caller holding 'c' on that class, as for creating one there. The kernel
-- connection (session_user kernel or postgres) is exempt, as on insert. An update that keeps the class (no change of
-- type, or a type of the same class) is not affected.
--
-- Behaviour change for every project: a road that changes the type of an object into another class, under a session
-- without 'c' on the new class, now fails with ERR-400-001. Grant the bit (chmodc) where the road is legitimate. A role
-- granted 'u' but not 'c' on the new class is refused now (chmodc opens the class methods on "c or u").
--
-- The trigger t_object_before_update exists; only its function is replaced. The text is the text of
-- entity/object/table.sql, byte for byte (update.psql does not reload table.sql -- hence this patch). Kernel phase, no
-- \connect, no session, repeatable.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_object_before_update()
RETURNS trigger AS $$
DECLARE
  bSystem   boolean;
BEGIN
  IF session_user NOT IN ('kernel', 'postgres') THEN
    IF NOT CheckObjectAccess(NEW.id, B'010') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  IF OLD.type IS DISTINCT FROM NEW.type THEN
    SELECT class INTO NEW.class FROM db.type WHERE id = NEW.type;
    SELECT entity INTO NEW.entity FROM db.class_tree WHERE id = NEW.class;

    IF OLD.entity IS DISTINCT FROM NEW.entity THEN
      PERFORM IncorrectEntity();
    END IF;
  END IF;

  IF OLD.class IS DISTINCT FROM NEW.class THEN
    -- An object that moves into another class is created in that class as
    -- far as its access is concerned: the create bit of the new class ACU
    -- ({acsud}, 'c') is asked, as ft_object_before_insert asks it. The same
    -- kernel and postgres exemption.
    IF NEW.class IS NOT NULL AND session_user NOT IN ('kernel', 'postgres') THEN
      IF NOT CheckClassAccess(NEW.class, B'01000') THEN
        PERFORM AccessDenied();
      END IF;
    END IF;

    NEW.state := GetState(NEW.class, OLD.state_type);

    IF OLD.state IS DISTINCT FROM NEW.state THEN
      UPDATE db.object_state SET state = NEW.state
       WHERE object = OLD.id
         AND state = OLD.state;
    END IF;
  END IF;

  IF OLD.state IS DISTINCT FROM NEW.state THEN
    IF NEW.state IS NOT NULL THEN
      SELECT type INTO NEW.state_type FROM db.state WHERE id = NEW.state;
    ELSE
      NEW.state_type := NULL;
    END IF;
  END IF;

  IF OLD.scope IS DISTINCT FROM NEW.scope THEN
    PERFORM FROM db.area WHERE id = GetSessionArea(current_session()) AND scope = NEW.scope;
    IF NOT FOUND THEN
      NEW.scope := OLD.scope;
    END IF;
  END IF;

  IF OLD.owner IS DISTINCT FROM NEW.owner THEN
    SELECT system INTO bSystem FROM users WHERE id = OLD.owner AND scope = NEW.scope;
    IF NOT bSystem THEN
      DELETE FROM db.aou WHERE object = NEW.id AND userid = OLD.owner AND mask = B'111';
    END IF;
    INSERT INTO db.aou (object, userid, deny, allow) SELECT NEW.id, NEW.owner, B'000', B'111'
      ON CONFLICT (object, userid) DO UPDATE SET deny = B'000', allow = B'111';
  END IF;

  NEW.oper := current_userid();

  NEW.ldate := oper_date();
  NEW.udate := now();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
