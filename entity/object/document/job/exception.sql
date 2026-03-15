--------------------------------------------------------------------------------
-- FUNCTION JobExists ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Raise an error when a job with the given code already exists.
 * @param {text} pCode - Duplicate job code
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION JobExists (
  pCode      text
) RETURNS    void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40000: Job with code "%" already exists.', pCode;
END;
$$ LANGUAGE plpgsql;
