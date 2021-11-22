CREATE OR REPLACE FUNCTION db.ft_object_after_insert()
RETURNS trigger AS $$
DECLARE
  uUserId    uuid;
  vEntity   text;
BEGIN
  INSERT INTO db.aom SELECT NEW.id;
  INSERT INTO db.aou (object, userid, deny, allow) SELECT NEW.id, userid, SubString(deny FROM 3 FOR 3), SubString(allow FROM 3 FOR 3) FROM db.acu WHERE class = NEW.class;

  INSERT INTO db.aou SELECT NEW.id, NEW.owner, B'000', B'111'
	ON CONFLICT (object, userid) DO UPDATE SET deny = B'000', allow = B'111';

  SELECT code INTO vEntity FROM db.entity WHERE id = NEW.entity;

  IF vEntity = 'message' THEN
	IF NEW.parent IS NOT NULL THEN
	  SELECT owner INTO uUserId FROM db.object WHERE id = NEW.parent;
	  IF NEW.owner <> uUserId THEN
		UPDATE db.aou SET allow = allow | B'100' WHERE object = NEW.id AND userid = NEW.owner;
		IF NOT FOUND THEN
		  INSERT INTO db.aou SELECT NEW.id, NEW.owner, B'000', B'100';
		END IF;
	  END IF;
	END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
