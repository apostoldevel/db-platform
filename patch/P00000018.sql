DROP FUNCTION IF EXISTS api.get_object_file(uuid, text);
DROP FUNCTION IF EXISTS api.get_session(text, text, inet);

DROP FUNCTION IF EXISTS GetSession(uuid, bigint, text, inet, bool);

--

CREATE OR REPLACE FUNCTION db.ft_user_after_insert()
RETURNS trigger AS $$
BEGIN
  CASE NEW.username
  WHEN 'system' THEN
    INSERT INTO db.acl SELECT NEW.id, B'00000000000000', B'10000000000011';
  WHEN 'administrator' THEN
    INSERT INTO db.acl SELECT NEW.id, B'00000000000000', B'01111111111111';
  WHEN 'guest' THEN
    INSERT INTO db.acl SELECT NEW.id, B'11111111111100', B'00000000000011';
  WHEN 'apibot' THEN
    INSERT INTO db.acl SELECT NEW.id, B'10000000000011', B'01111111111100';
  ELSE
    INSERT INTO db.acl SELECT NEW.id, B'00000000000000', B'00000000000011';
  END CASE;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--

SELECT SignIn(CreateSystemOAuth2(), 'admin', :'admin');

SELECT GetErrorMessage();

SELECT chmod(B'1000000000001101111111111100', GetUser('apibot'));

SELECT SignOut();


