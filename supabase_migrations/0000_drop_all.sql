-- Borrar todo el schema Rifard en Supabase (ejecutar ANTES de 0001_core.sql)
-- Ejecuta este script en SQL Editor, luego ejecuta 0001_core.sql

-- 1) Tablas (orden: primero las que tienen FKs a otras)
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS refresh_tokens CASCADE;
DROP TABLE IF EXISTS limit_configs CASCADE;
DROP TABLE IF EXISTS draw_results CASCADE;
DROP TABLE IF EXISTS ticket_lines CASCADE;
DROP TABLE IF EXISTS tickets CASCADE;
DROP TABLE IF EXISTS pos_presence CASCADE;
DROP TABLE IF EXISTS pos_devices CASCADE;
DROP TABLE IF EXISTS point_assignments CASCADE;
DROP TABLE IF EXISTS pos_points CASCADE;
DROP TABLE IF EXISTS draws CASCADE;
DROP TABLE IF EXISTS lottery_draw_times CASCADE;
DROP TABLE IF EXISTS games CASCADE;
DROP TABLE IF EXISTS lotteries CASCADE;
DROP TABLE IF EXISTS user_roles CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS roles CASCADE;

-- 2) Función usada por los triggers
DROP FUNCTION IF EXISTS set_updated_at() CASCADE;

-- 3) Enums (CASCADE por si algo los referenciara)
DROP TYPE IF EXISTS draw_state CASCADE;
DROP TYPE IF EXISTS result_status CASCADE;
DROP TYPE IF EXISTS ticket_status CASCADE;
DROP TYPE IF EXISTS limit_type CASCADE;
DROP TYPE IF EXISTS bet_type CASCADE;

-- Listo. Ahora ejecuta 0001_core.sql para crear todo de nuevo.
