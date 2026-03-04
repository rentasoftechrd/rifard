-- Sistema Loteria Dominicana - Core schema
-- UUIDs for all main entities. Si ya existe schema anterior, lo borra y recrea.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Borrar schema anterior (para que los enums se recreen con los valores correctos)
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
DROP FUNCTION IF EXISTS set_updated_at() CASCADE;
DROP TYPE IF EXISTS draw_state CASCADE;
DROP TYPE IF EXISTS result_status CASCADE;
DROP TYPE IF EXISTS ticket_status CASCADE;
DROP TYPE IF EXISTS limit_type CASCADE;
DROP TYPE IF EXISTS bet_type CASCADE;

-- Enums
CREATE TYPE draw_state AS ENUM ('scheduled', 'open', 'closed', 'posteado');
CREATE TYPE result_status AS ENUM ('pending_approval', 'approved', 'rejected');
CREATE TYPE ticket_status AS ENUM ('sold', 'voided', 'paid');
CREATE TYPE limit_type AS ENUM ('global', 'by_number', 'by_bet_type');
CREATE TYPE bet_type AS ENUM ('quiniela', 'pale', 'tripleta', 'superpale');

-- Roles (seed data applied separately if needed)
CREATE TABLE IF NOT EXISTS roles (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code       TEXT NOT NULL,
  name       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$ BEGIN
  ALTER TABLE roles ADD CONSTRAINT roles_code_unique UNIQUE (code);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Users
CREATE TABLE IF NOT EXISTS users (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email         TEXT NOT NULL,
  phone         TEXT,
  full_name     TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  active        BOOLEAN NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$ BEGIN
  ALTER TABLE users ADD CONSTRAINT users_email_unique UNIQUE (email);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE users ADD CONSTRAINT users_phone_unique UNIQUE (phone);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS user_roles (
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role_id    UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, role_id)
);

-- Lotteries (existing concept)
CREATE TABLE IF NOT EXISTS lotteries (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name       TEXT NOT NULL,
  code       TEXT NOT NULL,
  active     BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$ BEGIN
  ALTER TABLE lotteries ADD CONSTRAINT lotteries_code_unique UNIQUE (code);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Draw times per lottery (hour + close_minutes_before)
CREATE TABLE IF NOT EXISTS lottery_draw_times (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lottery_id           UUID NOT NULL REFERENCES lotteries(id) ON DELETE CASCADE,
  draw_time            TIME NOT NULL,
  close_minutes_before INT NOT NULL DEFAULT 0,
  active               BOOLEAN NOT NULL DEFAULT true,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$ BEGIN
  ALTER TABLE lottery_draw_times ADD CONSTRAINT lottery_draw_times_lottery_time_unique UNIQUE (lottery_id, draw_time);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Games (kept for compatibility; bet_type on lines is enum)
CREATE TABLE IF NOT EXISTS games (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name       TEXT NOT NULL,
  code       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Draws (actual draw instances per day)
CREATE TABLE IF NOT EXISTS draws (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lottery_id UUID NOT NULL REFERENCES lotteries(id) ON DELETE CASCADE,
  draw_date  DATE NOT NULL,
  draw_time  TIME NOT NULL,
  state      draw_state NOT NULL DEFAULT 'scheduled',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_draws_lottery_date ON draws(lottery_id, draw_date);

-- POS Points
CREATE TABLE IF NOT EXISTS pos_points (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name       TEXT NOT NULL,
  code       TEXT NOT NULL,
  address    TEXT,
  active     BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$ BEGIN
  ALTER TABLE pos_points ADD CONSTRAINT pos_points_code_unique UNIQUE (code);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Point assignments (seller <-> point with commission)
CREATE TABLE IF NOT EXISTS point_assignments (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  point_id          UUID NOT NULL REFERENCES pos_points(id) ON DELETE CASCADE,
  seller_user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  commission_percent NUMERIC(5,2) NOT NULL DEFAULT 0,
  active            BOOLEAN NOT NULL DEFAULT true,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$ BEGIN
  ALTER TABLE point_assignments ADD CONSTRAINT point_assignments_point_seller_unique UNIQUE (point_id, seller_user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- POS devices
CREATE TABLE IF NOT EXISTS pos_devices (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  device_id  TEXT NOT NULL,
  point_id   UUID NOT NULL REFERENCES pos_points(id) ON DELETE CASCADE,
  name       TEXT,
  active     BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$ BEGIN
  ALTER TABLE pos_devices ADD CONSTRAINT pos_devices_device_id_unique UNIQUE (device_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- POS presence (heartbeat)
CREATE TABLE IF NOT EXISTS pos_presence (
  device_id      TEXT NOT NULL PRIMARY KEY REFERENCES pos_devices(device_id) ON DELETE CASCADE,
  point_id       UUID NOT NULL REFERENCES pos_points(id) ON DELETE CASCADE,
  seller_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  app_version    TEXT,
  last_seen_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pos_presence_last_seen ON pos_presence(last_seen_at);

-- Tickets
CREATE TABLE IF NOT EXISTS tickets (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ticket_code  TEXT NOT NULL,
  point_id     UUID NOT NULL REFERENCES pos_points(id) ON DELETE RESTRICT,
  device_id    TEXT NOT NULL REFERENCES pos_devices(device_id) ON DELETE RESTRICT,
  seller_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  status       ticket_status NOT NULL DEFAULT 'sold',
  total_amount NUMERIC(12,2) NOT NULL,
  printed_at   TIMESTAMPTZ,
  voided_at    TIMESTAMPTZ,
  voided_by    UUID REFERENCES users(id) ON DELETE SET NULL,
  void_reason  TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$ BEGIN
  ALTER TABLE tickets ADD CONSTRAINT tickets_ticket_code_unique UNIQUE (ticket_code);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_tickets_point_created ON tickets(point_id, created_at);
CREATE INDEX IF NOT EXISTS idx_tickets_seller_created ON tickets(seller_user_id, created_at);

-- Ticket lines
CREATE TABLE IF NOT EXISTS ticket_lines (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ticket_id        UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  lottery_id       UUID NOT NULL REFERENCES lotteries(id) ON DELETE RESTRICT,
  draw_id          UUID NOT NULL REFERENCES draws(id) ON DELETE RESTRICT,
  bet_type         bet_type NOT NULL,
  numbers          TEXT NOT NULL,
  amount           NUMERIC(12,2) NOT NULL,
  potential_payout NUMERIC(12,2) NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ticket_lines_ticket ON ticket_lines(ticket_id);
CREATE INDEX IF NOT EXISTS idx_ticket_lines_draw ON ticket_lines(draw_id);

-- Draw results (one row per draw; status flow: pending_approval -> approved | rejected)
CREATE TABLE IF NOT EXISTS draw_results (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  draw_id           UUID NOT NULL REFERENCES draws(id) ON DELETE CASCADE,
  status            result_status NOT NULL DEFAULT 'pending_approval',
  results           JSONB NOT NULL DEFAULT '{}',
  entered_by        UUID REFERENCES users(id) ON DELETE SET NULL,
  entered_at        TIMESTAMPTZ,
  approved_by       UUID REFERENCES users(id) ON DELETE SET NULL,
  approved_at       TIMESTAMPTZ,
  rejection_reason  TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$ BEGIN
  ALTER TABLE draw_results ADD CONSTRAINT draw_results_draw_id_unique UNIQUE (draw_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Limit configs (global / by_number / by_bet_type; lottery_id/draw_id nullable for global bankroll)
CREATE TABLE IF NOT EXISTS limit_configs (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  type       limit_type NOT NULL,
  lottery_id UUID REFERENCES lotteries(id) ON DELETE CASCADE,
  draw_id    UUID REFERENCES draws(id) ON DELETE CASCADE,
  bet_type   bet_type,
  number_key TEXT,
  max_payout NUMERIC(14,2) NOT NULL,
  active     BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_limit_configs_lottery_draw_type ON limit_configs(lottery_id, draw_id, type);

-- Refresh tokens (for auth)
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires ON refresh_tokens(expires_at);

-- Audit logs
CREATE TABLE IF NOT EXISTS audit_logs (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  actor_user_id   UUID REFERENCES users(id) ON DELETE SET NULL,
  action          TEXT NOT NULL,
  entity          TEXT NOT NULL,
  entity_id       UUID,
  meta            JSONB DEFAULT '{}',
  ip              TEXT,
  user_agent      TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON audit_logs(actor_user_id);

-- updated_at triggers
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- updated_at triggers
DROP TRIGGER IF EXISTS set_updated_at ON users;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE PROCEDURE set_updated_at();

DROP TRIGGER IF EXISTS set_updated_at ON lotteries;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON lotteries FOR EACH ROW EXECUTE PROCEDURE set_updated_at();

DROP TRIGGER IF EXISTS set_updated_at ON lottery_draw_times;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON lottery_draw_times FOR EACH ROW EXECUTE PROCEDURE set_updated_at();

DROP TRIGGER IF EXISTS set_updated_at ON pos_points;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON pos_points FOR EACH ROW EXECUTE PROCEDURE set_updated_at();

DROP TRIGGER IF EXISTS set_updated_at ON point_assignments;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON point_assignments FOR EACH ROW EXECUTE PROCEDURE set_updated_at();

DROP TRIGGER IF EXISTS set_updated_at ON pos_devices;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON pos_devices FOR EACH ROW EXECUTE PROCEDURE set_updated_at();

DROP TRIGGER IF EXISTS set_updated_at ON tickets;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON tickets FOR EACH ROW EXECUTE PROCEDURE set_updated_at();

DROP TRIGGER IF EXISTS set_updated_at ON draws;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON draws FOR EACH ROW EXECUTE PROCEDURE set_updated_at();

DROP TRIGGER IF EXISTS set_updated_at ON draw_results;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON draw_results FOR EACH ROW EXECUTE PROCEDURE set_updated_at();

DROP TRIGGER IF EXISTS set_updated_at ON limit_configs;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON limit_configs FOR EACH ROW EXECUTE PROCEDURE set_updated_at();
