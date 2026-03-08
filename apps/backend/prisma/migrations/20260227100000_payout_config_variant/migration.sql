ALTER TABLE payout_config ADD COLUMN IF NOT EXISTS variant TEXT NOT NULL DEFAULT '';

ALTER TABLE payout_config DROP CONSTRAINT IF EXISTS payout_config_bet_type_unique;
ALTER TABLE payout_config DROP CONSTRAINT IF EXISTS payout_config_bet_type_key;
ALTER TABLE payout_config DROP CONSTRAINT IF EXISTS payout_config_bet_type_variant_key;

ALTER TABLE payout_config ADD CONSTRAINT payout_config_bet_type_variant_key UNIQUE (bet_type, variant);

UPDATE payout_config SET variant = '1_2', multiplier = 1500 WHERE bet_type = 'pale' AND (variant = '' OR variant IS NULL);
INSERT INTO payout_config (id, bet_type, variant, multiplier, created_at, updated_at)
SELECT uuid_generate_v4(), 'pale', '2_3', 200, now(), now()
WHERE NOT EXISTS (SELECT 1 FROM payout_config WHERE bet_type = 'pale' AND variant = '2_3');

UPDATE payout_config SET variant = '1_2', multiplier = 10000 WHERE bet_type = 'tripleta' AND (variant = '' OR variant IS NULL);
INSERT INTO payout_config (id, bet_type, variant, multiplier, created_at, updated_at)
SELECT uuid_generate_v4(), 'tripleta', '2', 100, now(), now()
WHERE NOT EXISTS (SELECT 1 FROM payout_config WHERE bet_type = 'tripleta' AND variant = '2');

UPDATE payout_config SET multiplier = 2000 WHERE bet_type = 'superpale';
