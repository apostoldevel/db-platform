--------------------------------------------------------------------------------
-- JWT -------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- FUNCTION url_encode ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Encode binary data as a URL-safe Base64 string (JWT variant).
 * @param {bytea} data - Raw bytes to encode
 * @return {text} - Base64 string with '+/=' replaced by '-_' (no padding)
 * @see url_decode
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION url_encode(data bytea) RETURNS text LANGUAGE sql AS $$
    SELECT translate(encode(data, 'base64'), E'+/=\n', '-_');
$$;

GRANT EXECUTE ON FUNCTION url_encode(bytea) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION url_decode ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Decode a URL-safe Base64 string back to binary data.
 * @param {text} data - URL-safe Base64 encoded string (no padding)
 * @return {bytea} - Decoded raw bytes
 * @see url_encode
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION url_decode(data text) RETURNS bytea LANGUAGE sql AS $$
WITH t AS (SELECT translate(data, '-_', '+/') AS trans),
     rem AS (SELECT length(t.trans) % 4 AS remainder FROM t)
    SELECT decode(
        t.trans ||
        CASE WHEN rem.remainder > 0
           THEN repeat('=', (4 - rem.remainder))
           ELSE '' END,
    'base64') FROM t, rem;
$$;

GRANT EXECUTE ON FUNCTION url_decode(text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION algorithm_sign -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Compute an HMAC signature using the specified JWT algorithm.
 * @param {text} signables - The data to sign (header.payload)
 * @param {text} secret - HMAC secret key
 * @param {text} algorithm - JWT algorithm identifier (HS256, HS384, HS512)
 * @return {text} - URL-safe Base64 encoded HMAC signature
 * @see sign, verify
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION algorithm_sign(signables text, secret text, algorithm text)
RETURNS text LANGUAGE sql AS $$
WITH
  alg AS (
    SELECT CASE
      WHEN algorithm = 'HS256' THEN 'sha256'
      WHEN algorithm = 'HS384' THEN 'sha384'
      WHEN algorithm = 'HS512' THEN 'sha512'
      ELSE '' END AS id)
SELECT url_encode(hmac(signables, secret, alg.id)) FROM alg;
$$ SET search_path = kernel, public, pg_temp;

GRANT EXECUTE ON FUNCTION algorithm_sign(text, text, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION sign ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Produce a signed JSON Web Token from a JSON payload.
 * @param {json} payload - JWT claims as a JSON object
 * @param {text} secret - HMAC secret key used for signing
 * @param {text} algorithm - JWT algorithm (default HS256)
 * @return {text} - Complete JWT string (header.payload.signature)
 * @see verify, algorithm_sign
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION sign(payload json, secret text, algorithm text DEFAULT 'HS256')
RETURNS text LANGUAGE sql AS $$
WITH
  header AS (
    SELECT url_encode(convert_to('{"alg":"' || algorithm || '","typ":"JWT"}', 'utf8')) AS data
    ),
  payload AS (
    SELECT url_encode(convert_to(payload::text, 'utf8')) AS data
    ),
  signables AS (
    SELECT header.data || '.' || payload.data AS data FROM header, payload
    )
SELECT
    signables.data || '.' ||
    algorithm_sign(signables.data, secret, algorithm) FROM signables;
$$;

GRANT EXECUTE ON FUNCTION sign(json, text, text) TO PUBLIC;

--------------------------------------------------------------------------------
-- FUNCTION verify -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Verify a JWT token and extract its header and payload.
 * @param {text} token - Complete JWT string to verify
 * @param {text} secret - HMAC secret key used for verification
 * @param {text} algorithm - JWT algorithm (default HS256)
 * @return {record} - Table with columns: header (json), payload (json), valid (boolean)
 * @see sign, algorithm_sign
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION verify(token text, secret text, algorithm text DEFAULT 'HS256')
RETURNS table(header json, payload json, valid boolean) LANGUAGE sql AS $$
  SELECT
    convert_from(url_decode(r[1]), 'utf8')::json AS header,
    convert_from(url_decode(r[2]), 'utf8')::json AS payload,
    r[3] = algorithm_sign(r[1] || '.' || r[2], secret, algorithm) AS valid
  FROM regexp_split_to_array(token, '\.') r;
$$;

GRANT EXECUTE ON FUNCTION verify(text, text, text) TO PUBLIC;
