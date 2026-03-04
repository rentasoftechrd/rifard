-- Auditoría de pago de premios: quién y cuándo marcó el ticket como pagado.
ALTER TABLE tickets
  ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS paid_by UUID REFERENCES users(id) ON DELETE SET NULL;

COMMENT ON COLUMN tickets.paid_at IS 'Cuando se marcó el ticket como cobrado (premio pagado).';
COMMENT ON COLUMN tickets.paid_by IS 'Usuario que marcó el ticket como pagado (evitar doble cobro en otro punto).';
