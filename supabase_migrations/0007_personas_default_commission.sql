-- Comisión por defecto para vendedores (opcional).
ALTER TABLE personas
  ADD COLUMN IF NOT EXISTS default_commission_percent NUMERIC(5,2) DEFAULT NULL;

COMMENT ON COLUMN personas.default_commission_percent IS 'Comisión % por defecto cuando la persona es vendedor (se usa al asignar puntos).';
