DROP VIEW Method CASCADE;

--------------------------------------------------------------------------------
-- TABLE db.oma ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.oma (
    object      uuid NOT NULL REFERENCES db.object(id) ON DELETE CASCADE,
    method      uuid NOT NULL REFERENCES db.method(id) ON DELETE CASCADE,
    userid      uuid NOT NULL REFERENCES db.user(id) ON DELETE CASCADE,
    mask        bit(3) DEFAULT B'000' NOT NULL,
    PRIMARY KEY (object, method, userid)
);

COMMENT ON TABLE db.oma IS 'Доступ пользователя к методам объекта.';

COMMENT ON COLUMN db.oma.object IS 'Объект';
COMMENT ON COLUMN db.oma.method IS 'Метод';
COMMENT ON COLUMN db.amu.userid IS 'Пользователь';
COMMENT ON COLUMN db.oma.mask IS 'Маска доступа: {xve}. Где: {x - execute, v - visible, e - enable}';

CREATE INDEX ON db.oma (object);
CREATE INDEX ON db.oma (method);
CREATE INDEX ON db.oma (userid);
