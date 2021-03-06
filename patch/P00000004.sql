\ir '../entity/object/reference/property/create.psql'

DROP FUNCTION api.add_model(uuid,text,uuid,uuid,text,text,text);
DROP FUNCTION api.update_model(uuid,uuid,text,uuid,uuid,text,text,text);
DROP FUNCTION api.set_model(uuid,uuid,text,uuid,uuid,text,text,text);

--------------------------------------------------------------------------------
-- db.model_property -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.model_property (
    model		uuid NOT NULL REFERENCES db.model(id) ON DELETE CASCADE,
    property	uuid NOT NULL REFERENCES db.property(id) ON DELETE RESTRICT,
    measure		uuid REFERENCES db.measure(id),
    value		variant,
    format		text,
    sequence	integer NOT NULL,
    PRIMARY KEY (model, property)
);

COMMENT ON TABLE db.model_property IS 'Свойства модели.';

COMMENT ON COLUMN db.model_property.model IS 'Модель.';
COMMENT ON COLUMN db.model_property.property IS 'Свойство.';
COMMENT ON COLUMN db.model_property.measure IS 'Мера.';
COMMENT ON COLUMN db.model_property.value IS 'Значение.';
COMMENT ON COLUMN db.model_property.format IS 'Формат.';
COMMENT ON COLUMN db.model_property.sequence IS 'Очерёдность';

CREATE INDEX ON db.model_property (model);
CREATE INDEX ON db.model_property (property);
CREATE INDEX ON db.model_property (measure);

--------------------------------------------------------------------------------

\connect :dbname admin

SELECT SignIn(CreateSystemOAuth2(), 'admin', 'admin');

SELECT GetErrorMessage();

SELECT CreateEntityProperty(GetClass('reference'));

SELECT SignOut();

\connect :dbname kernel