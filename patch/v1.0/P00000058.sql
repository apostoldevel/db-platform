ALTER TABLE http.request
  ADD COLUMN type text NOT NULL DEFAULT 'native' CHECK (type = ANY (ARRAY['native', 'curl'])),
  ADD COLUMN data jsonb;

COMMENT ON COLUMN http.request.type IS 'Способ отправки: native - родной; curl - через библиотеку cURL';
COMMENT ON COLUMN http.request.data IS 'Произвольные данные в формате JSON';

DROP FUNCTION IF EXISTS http.create_request(text, text, jsonb, text, text, text, text, text, text, text);
DROP FUNCTION IF EXISTS http."fetch"(text, text, jsonb, text, text, text, text, text, text, text);
DROP FUNCTION IF EXISTS http."fetch"(text, text, jsonb, jsonb, text, text, text, text, text, text);

