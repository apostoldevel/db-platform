--------------------------------------------------------------------------------
-- FUNCTION InvalidReportType  -------------------------------------------------
--------------------------------------------------------------------------------

SELECT CreateExceptionResource('e467b6e4-9989-4521-8c7a-f5368c035657', 'ru', 'InvalidReportType', 'Неверный тип отчёта');
SELECT CreateExceptionResource('e467b6e4-9989-4521-8c7a-f5368c035657', 'en', 'InvalidReportType', 'Invalid report type');

CREATE OR REPLACE FUNCTION InvalidReportType (
) RETURNS   void
AS $$
BEGIN
  RAISE EXCEPTION 'ERR-40000: %', GetResource('e467b6e4-9989-4521-8c7a-f5368c035657');
END;
$$ LANGUAGE plpgsql;
