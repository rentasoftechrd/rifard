-- Añade la columna bet_type a limit_configs si no existe.
-- Necesario si la tabla se creó antes de tener este campo en el esquema Prisma.
-- Ejecutar en la base de datos del backend, por ejemplo:
--   psql $DATABASE_URL -f apps/backend/scripts/add-limit-configs-bet-type.sql

ALTER TABLE limit_configs
  ADD COLUMN IF NOT EXISTS bet_type bet_type NULL;
