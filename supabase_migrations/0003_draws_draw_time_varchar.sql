-- Alinear draws.draw_time con Prisma (String). Evita error 500 al listar sorteos.
-- draw_time como VARCHAR(10) almacena 'HH24:MI:SS' (ej. 15:00:00).
ALTER TABLE draws
  ALTER COLUMN draw_time TYPE VARCHAR(10)
  USING to_char(draw_time, 'HH24:MI:SS');
