-- PayoutConfig: add variant for multiple prices per bet type (Palé 1-2, 2-3; Tripleta 1-2, 2 aciertos; etc.)
-- Run in Supabase SQL Editor if using PgBouncer.

ALTER TABLE payout_config ADD COLUMN IF NOT EXISTS variant TEXT NOT NULL DEFAULT '';

-- Drop old unique on bet_type (Supabase/Postgres can use either name)
ALTER TABLE payout_config DROP CONSTRAINT IF EXISTS payout_config_bet_type_unique;
ALTER TABLE payout_config DROP CONSTRAINT IF EXISTS payout_config_bet_type_key;
ALTER TABLE payout_config DROP CONSTRAINT IF EXISTS "payout_config_bet_type_key";

-- Add new unique (bet_type, variant); skip if already exists (re-runnable script)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'payout_config_bet_type_variant_key'
  ) THEN
    ALTER TABLE payout_config ADD CONSTRAINT payout_config_bet_type_variant_key UNIQUE (bet_type, variant);
  END IF;
END $$;

-- Backfill: set variant and multipliers per new rules
-- Palé: 1ra y 2da = 1500, 2da y 3ra = 200
UPDATE payout_config SET variant = '1_2', multiplier = 1500 WHERE bet_type = 'pale' AND (variant = '' OR variant IS NULL);
INSERT INTO payout_config (id, bet_type, variant, multiplier, created_at, updated_at)
SELECT uuid_generate_v4(), 'pale', '2_3', 200, now(), now()
WHERE NOT EXISTS (SELECT 1 FROM payout_config WHERE bet_type = 'pale' AND variant = '2_3');

-- Tripleta: 1ra y 2da = 10000, 2 aciertos = 100
UPDATE payout_config SET variant = '1_2', multiplier = 10000 WHERE bet_type = 'tripleta' AND (variant = '' OR variant IS NULL);
INSERT INTO payout_config (id, bet_type, variant, multiplier, created_at, updated_at)
SELECT uuid_generate_v4(), 'tripleta', '2', 100, now(), now()
WHERE NOT EXISTS (SELECT 1 FROM payout_config WHERE bet_type = 'tripleta' AND variant = '2');

-- Superpalé = 2000
UPDATE payout_config SET multiplier = 2000 WHERE bet_type = 'superpale';
