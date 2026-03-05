-- Personas: datos completos (vendedores, empleados): dirección, sector, ciudad, cédula, teléfono.
-- Usuario se vincula a una Persona opcionalmente (persona_id).

DO $$ BEGIN
  CREATE TYPE tipo_persona AS ENUM ('VENDEDOR', 'EMPLEADO', 'OTRO');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS personas (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  full_name  TEXT NOT NULL,
  cedula     TEXT,
  phone      TEXT,
  email      TEXT,
  address    TEXT,
  sector     TEXT,
  city       TEXT,
  tipo       tipo_persona NOT NULL DEFAULT 'OTRO',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_personas_tipo ON personas(tipo);
CREATE UNIQUE INDEX IF NOT EXISTS idx_personas_cedula ON personas(cedula) WHERE cedula IS NOT NULL AND cedula != '';

ALTER TABLE users ADD COLUMN IF NOT EXISTS persona_id UUID REFERENCES personas(id) ON DELETE SET NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_persona_id_unique ON users(persona_id) WHERE persona_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_persona_id ON users(persona_id);

CREATE OR REPLACE FUNCTION set_updated_at_personas()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS personas_updated_at ON personas;
CREATE TRIGGER personas_updated_at
  BEFORE UPDATE ON personas
  FOR EACH ROW EXECUTE PROCEDURE set_updated_at_personas();
