--------------------------------------------------------------------------------
-- db.object_reference ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_reference (
    id              uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    object          uuid NOT NULL REFERENCES db.object(id) ON DELETE CASCADE,
    key             text NOT NULL,
    reference       text NOT NULL,
    validFromDate   timestamptz DEFAULT Now() NOT NULL,
    validToDate     timestamptz DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.object_reference IS 'Объектная ссылка.';

COMMENT ON COLUMN db.object_reference.object IS 'Идентификатор объекта';
COMMENT ON COLUMN db.object_reference.key IS 'Ключ';
COMMENT ON COLUMN db.object_reference.reference IS 'Ссылка';
COMMENT ON COLUMN db.object_reference.validFromDate IS 'Дата начала периода действия';
COMMENT ON COLUMN db.object_reference.validToDate IS 'Дата окончания периода действия';

--------------------------------------------------------------------------------

CREATE UNIQUE INDEX ON db.object_reference (object, key, validFromDate, validToDate);
CREATE UNIQUE INDEX ON db.object_reference (reference, key, validFromDate, validToDate);
