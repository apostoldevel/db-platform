--------------------------------------------------------------------------------
-- InitAPI ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION InitAPI()
RETURNS			void
AS $$
DECLARE
  vNameSpace	text;
  vEndpoint		text;
BEGIN
  vNameSpace := '/api/v1';
  vEndpoint := 'rest.api($1, $2)';

  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/sign/up'), vEndpoint);
  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/sign/in'), vEndpoint);
  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/sign/out'), vEndpoint);

  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/authenticate'), vEndpoint);
  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/authorize'), vEndpoint);
  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/su'), vEndpoint);
  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/whoami'), vEndpoint);
  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/api'), vEndpoint);
  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/locale'), vEndpoint);
  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/entity'), vEndpoint);
  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/type'), vEndpoint);
  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/class'), vEndpoint);

  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/state'), vEndpoint);
  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/state/type'), vEndpoint);
  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/state/class'), vEndpoint);

  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/action'), vEndpoint);
  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/action/run'), vEndpoint);

  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/method'), vEndpoint);
  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/method'), vEndpoint);
  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/method/get'), vEndpoint);
  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/method/list'), vEndpoint);

  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/member/area'), vEndpoint);
  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/member/interface'), vEndpoint);

  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/user/set'), vEndpoint);
  PERFORM RegisterEndpoint(RegisterPath(vNameSpace || '/user/password'), vEndpoint);
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
