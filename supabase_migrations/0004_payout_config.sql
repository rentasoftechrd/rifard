-- Tabla de multiplicadores de pago por tipo de jugada (quiniela, palé, tripleta, superpalé).
-- El pago potencial = monto * multiplicador.
CREATE TABLE IF NOT EXISTS payout_config (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  bet_type   bet_type NOT NULL,
  multiplier NUMERIC(12, 2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$ BEGIN
  ALTER TABLE payout_config ADD CONSTRAINT payout_config_bet_type_unique UNIQUE (bet_type);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_payout_config_bet_type ON payout_config(bet_type);

-- Trigger updated_at
DROP TRIGGER IF EXISTS set_updated_at ON payout_config;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON payout_config FOR EACH ROW EXECUTE PROCEDURE set_updated_at();

-- Valores por defecto (RD)
INSERT INTO payout_config (bet_type, multiplier) VALUES
  ('quiniela', 15),
  ('pale', 50),
  ('tripleta', 500),
  ('superpale', 1000)
ON CONFLICT (bet_type) DO NOTHING;
